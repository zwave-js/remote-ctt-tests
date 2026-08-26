// These tests verify isolation between concurrent harness invocations

import assert from "node:assert/strict";
import { execFileSync, spawn } from "node:child_process";
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
  const contexts = await Promise.all([
    createRunContext(repoRoot),
    createRunContext(repoRoot),
  ]);

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

    const [ephemeralStart, ephemeralEnd] = fs
      .readFileSync("/proc/sys/net/ipv4/ip_local_port_range", "utf8")
      .trim()
      .split(/\s+/)
      .map(Number);
    for (const context of contexts) {
      for (const port of [
        ...Object.values(context.ports.tcp),
        context.ports.udp.znifferDiscovery,
        ...znePorts(context.ports.zneBase),
      ]) {
        assert(
          port < ephemeralStart! || port > ephemeralEnd!,
          `Port ${port} is inside the ephemeral range`
        );
      }

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
      ) as {
        KeyStorageFolder: string;
        SimplicityCommanderPath: string;
      };
      assert.equal(settings.KeyStorageFolder, path.join(repoRoot, "ctt", "keys"));
      assert.equal(settings.SimplicityCommanderPath, "/usr/bin/true");
    }
  } finally {
    await Promise.all(
      contexts.map((context) => context.reservations.close())
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

test("stale cleanup kills owned processes and skips reused PIDs", async () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "ctt-stale-test-"));
  const runRoot = path.join(root, "stale");
  fs.mkdirSync(runRoot);
  const paths = createRuntimePaths(runRoot);
  const manifest = new ProcessManifest("stale", paths, createRuntimePorts());
  const orphan = spawn(process.execPath, ["-e", "setInterval(() => {}, 1000)"], {
    stdio: "ignore",
  });
  const reused = spawn(process.execPath, ["-e", "setInterval(() => {}, 1000)"], {
    stdio: "ignore",
  });

  try {
    manifest.register("Owned orphan", orphan.pid, false);
    const data = JSON.parse(fs.readFileSync(paths.manifest, "utf8")) as {
      owner: { pid: number };
      processes: Array<{
        name: string;
        pid: number;
        startTime: string;
        processGroup: boolean;
      }>;
    };
    data.owner.pid = 2_000_000_000;
    data.processes.push({
      name: "Reused PID",
      pid: reused.pid!,
      startTime: "0",
      processGroup: false,
    });
    fs.writeFileSync(paths.manifest, JSON.stringify(data));

    const orphanExit = new Promise<void>((resolve) =>
      orphan.once("exit", () => resolve())
    );
    cleanupStaleRuns(root);
    await orphanExit;
    assert.doesNotThrow(() => process.kill(reused.pid!, 0));
  } finally {
    reused.kill("SIGKILL");
    orphan.kill("SIGKILL");
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test("stale cleanup skips unknown manifest schemas", () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "ctt-schema-test-"));
  const runRoot = path.join(root, "unknown");
  fs.mkdirSync(runRoot);
  const manifestPath = path.join(runRoot, "run.json");
  fs.writeFileSync(
    manifestPath,
    JSON.stringify({ schemaVersion: 999, status: "running" })
  );

  assert.doesNotThrow(() => cleanupStaleRuns(root));
  assert.equal(
    JSON.parse(fs.readFileSync(manifestPath, "utf8")).status,
    "running"
  );
  fs.rmSync(root, { recursive: true, force: true });
});

test("failed run construction removes its partial directory", async () => {
  const repoRoot = fs.mkdtempSync(path.join(os.tmpdir(), "ctt-failed-run-"));
  fs.mkdirSync(path.join(repoRoot, "ctt", "project"), { recursive: true });

  await assert.rejects(createRunContext(repoRoot));
  assert.deepEqual(fs.readdirSync(path.join(repoRoot, ".ctt-runs")), []);
  fs.rmSync(repoRoot, { recursive: true, force: true });
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
