import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import test from "node:test";
import { cleanupStaleRuns, ProcessManifest } from "./process-manifest.ts";
import {
  createRunContext,
  replaceExactlyOnce,
  type RuntimePaths,
  type RuntimePorts,
} from "./run-context.ts";

test("concurrent run contexts isolate ports, state, and CTT projects", async () => {
  const repoRoot = createFixtureRepository();
  const firstContext = await createRunContext(repoRoot);
  for (const name of Object.keys(firstContext.ports.tcp)) {
    await firstContext.reservations.release(
      name as keyof RuntimePorts["tcp"]
    );
  }
  await firstContext.reservations.release("znifferDiscovery");
  await firstContext.reservations.releaseZneBlock();
  const contexts = [firstContext, await createRunContext(repoRoot)] as const;

  try {
    assert.notEqual(contexts[0].paths.root, contexts[1].paths.root);

    const firstTcpPorts = new Set(Object.values(contexts[0].ports.tcp));
    for (const port of Object.values(contexts[1].ports.tcp)) {
      assert(!firstTcpPorts.has(port), `TCP port ${port} was reserved twice`);
    }

    const firstUdpPorts = new Set([
      contexts[0].ports.udp.znifferDiscovery,
      ...znePorts(contexts[0].ports.zneBase),
    ]);
    for (const port of [
      contexts[1].ports.udp.znifferDiscovery,
      ...znePorts(contexts[1].ports.zneBase),
    ]) {
      assert(!firstUdpPorts.has(port), `UDP port ${port} was reserved twice`);
    }

    for (const context of contexts) {
      assert(fs.existsSync(path.join(context.paths.stackStorage, "controller1")));
      assert(fs.existsSync(path.join(context.paths.dutStorage, "cache.jsonl")));

      const solution = fs.readFileSync(context.paths.cttSolution, "utf8");
      assert.match(
        solution,
        new RegExp(
          `<FirstController>[\\s\\S]*?<SPort>${context.ports.tcp.proxyController2}</SPort>`
        )
      );
      assert.match(
        solution,
        new RegExp(
          `<Zniffer>[\\s\\S]*?<SPort>${context.ports.tcp.zniffer}</SPort>`
        )
      );

      const definition = fs.readFileSync(
        path.join(context.paths.cttProject, "Config", "ZatsDefinition.xml"),
        "utf8"
      );
      assert(definition.includes(path.join(context.paths.cttProject, "Log")));

      const settings = JSON.parse(
        fs.readFileSync(
          path.join(context.paths.cttHome, ".ctt4", "settings.json"),
          "utf8"
        )
      ) as { KeyStorageFolder: string };
      assert.equal(settings.KeyStorageFolder, path.join(repoRoot, "ctt", "keys"));
    }
  } finally {
    await Promise.all(
      contexts.map((context) => context.reservations.releaseAll())
    );
    fs.rmSync(repoRoot, { recursive: true, force: true });
  }
});

test("CTT template patches fail when the expected field is ambiguous", () => {
  assert.throws(
    () =>
      replaceExactlyOnce(
        "<SPort>1</SPort><SPort>2</SPort>",
        /<SPort>\d+<\/SPort>/,
        "<SPort>3</SPort>",
        "test port"
      ),
    /Expected one test port/
  );
});

test("stale cleanup leaves active runs and marks dead runs", () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "ctt-manifest-test-"));
  const runRoot = path.join(root, "active");
  fs.mkdirSync(runRoot);
  const paths = createRuntimePaths(runRoot);
  const manifest = new ProcessManifest("active", paths, createRuntimePorts());

  cleanupStaleRuns(root);
  let data = JSON.parse(fs.readFileSync(paths.manifest, "utf8")) as {
    status: string;
    owner: { pid: number };
  };
  assert.equal(data.status, "running");

  data.owner.pid = 2_000_000_000;
  fs.writeFileSync(paths.manifest, JSON.stringify(data));
  cleanupStaleRuns(root);
  data = JSON.parse(fs.readFileSync(paths.manifest, "utf8")) as typeof data;
  assert.equal(data.status, "stale-cleaned");

  fs.rmSync(root, { recursive: true, force: true });
});

function createFixtureRepository(): string {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "ctt-context-test-"));
  const configDir = path.join(root, "ctt", "project", "Config");
  fs.mkdirSync(configDir, { recursive: true });
  fs.mkdirSync(path.join(root, "ctt", "keys"), { recursive: true });
  fs.mkdirSync(path.join(root, "setup"), { recursive: true });

  fs.writeFileSync(
    path.join(configDir, "ZatsDefinition.xml"),
    `<ZatsDefinition>
  <Profile Reports="ctt/project/Log">
    <DeviceHost Alias="Controller1" SPort="5001" />
    <DeviceHost Alias="Controller3" SPort="5002" />
    <DeviceHost Alias="EndDevice1" SPort="5003" />
    <DeviceHost Alias="EndDevice2" SPort="5004" />
  </Profile>
</ZatsDefinition>`
  );
  fs.writeFileSync(
    path.join(configDir, "ZatsSettings.json"),
    JSON.stringify({ KeysStoragePath: "" })
  );
  fs.writeFileSync(
    path.join(root, "ctt", "project", "zwave-js.cttsln"),
    `<Project>
  <Zniffer><SPort>4905</SPort></Zniffer>
  <FirstController><SPort>5001</SPort></FirstController>
  <ThirdController><SPort>5002</SPort></ThirdController>
  <FirstEndDevice><SPort>5003</SPort></FirstEndDevice>
  <SecondEndDevice><SPort>5004</SPort></SecondEndDevice>
</Project>`
  );

  const archiveRoot = path.join(root, "archive");
  fs.mkdirSync(path.join(archiveRoot, "storage", "controller1"), {
    recursive: true,
  });
  fs.mkdirSync(path.join(archiveRoot, "dut-storage"), { recursive: true });
  fs.writeFileSync(
    path.join(archiveRoot, "dut-storage", "cache.jsonl"),
    "{}"
  );
  execFileSync(
    "zip",
    [
      "-q",
      "-r",
      path.join(root, "setup", "network-state.zip"),
      "storage",
      "dut-storage",
    ],
    { cwd: archiveRoot }
  );
  fs.rmSync(archiveRoot, { recursive: true });
  return root;
}

function znePorts(base: number): number[] {
  return Array.from({ length: 6 }, (_, offset) => base + offset);
}

function createRuntimePaths(root: string): RuntimePaths {
  return {
    root,
    cttProject: path.join(root, "ctt", "project"),
    cttSolution: path.join(root, "ctt", "project", "project.cttsln"),
    cttHome: path.join(root, "home"),
    cttLog: path.join(root, "logs", "ctt.log"),
    stackStorage: path.join(root, "state", "zwave-stack"),
    dutStorage: path.join(root, "state", "dut"),
    dutLogs: path.join(root, "logs", "dut"),
    nodeTemp: path.join(root, "tmp", "nodes"),
    manifest: path.join(root, "run.json"),
  };
}

function createRuntimePorts(): RuntimePorts {
  return {
    tcp: {
      controller1: 10001,
      controller2: 10002,
      controller3: 10003,
      endDevice1: 10004,
      endDevice2: 10005,
      proxyController2: 10006,
      proxyController3: 10007,
      proxyEndDevice1: 10008,
      proxyEndDevice2: 10009,
      zniffer: 10010,
      cttRpc: 10011,
      cttCallback: 10012,
      runnerIpc: 10013,
      dutServer: 10014,
    },
    udp: { znifferDiscovery: 10015 },
    zneBase: 10020,
  };
}
