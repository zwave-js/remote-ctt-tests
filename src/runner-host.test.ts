// This test verifies that the runner PID is recorded before readiness

import assert from "node:assert/strict";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import test from "node:test";
import { ProcessManifest } from "./process-manifest.ts";
import { PortReservations } from "./run-context.ts";
import { RunnerHost } from "./runner-host.ts";

test("records the runner as soon as it is spawned", async () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "runner-spawn-test-"));
  const runnerPath = path.join(root, "runner.js");
  const manifestPath = path.join(root, "run.json");
  fs.writeFileSync(runnerPath, "setInterval(() => {}, 1000);\n");

  const { ports, reservations } = await PortReservations.create();
  await reservations.handoff("runnerIpc");
  const manifest = new ProcessManifest(
    "runner-spawn-test",
    {
      root,
      cttProject: path.join(root, "ctt", "project"),
      cttSolution: path.join(root, "ctt", "project", "project.cttsln"),
      cttKeys: path.join(root, "ctt", "keys"),
      cttHome: path.join(root, "home"),
      cttLog: path.join(root, "logs", "ctt.log"),
      stackStorage: path.join(root, "state", "zwave-stack"),
      dutStorage: path.join(root, "state", "dut"),
      dutLogs: path.join(root, "logs", "dut"),
      nodeTemp: path.join(root, "tmp", "nodes"),
      manifest: manifestPath,
    },
    ports
  );
  const spawned = Promise.withResolvers<number>();
  const host = new RunnerHost({
    runnerPath,
    ipcPort: ports.tcp.runnerIpc,
    readyTimeout: 25,
    onSpawn: (pid) => {
      manifest.register("Test Runner", pid, false);
      spawned.resolve(pid);
    },
  });

  try {
    const initialization = host.initialize();
    const pid = await spawned.promise;
    const stored = JSON.parse(fs.readFileSync(manifestPath, "utf8")) as {
      processes: Array<{ name: string; pid: number }>;
    };
    assert.equal(stored.processes.length, 1);
    assert.equal(stored.processes[0]?.name, "Test Runner");
    assert.equal(stored.processes[0]?.pid, pid);
    await assert.rejects(initialization, /did not send ready notification/);
  } finally {
    await host.cleanup();
    await reservations.close();
    fs.rmSync(root, { recursive: true, force: true });
  }
});
