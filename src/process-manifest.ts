import * as fs from "fs";
import * as path from "path";
import { randomUUID } from "crypto";
import type { RuntimePaths, RuntimePorts } from "./run-context.ts";
import {
  getProcessIdentity,
  matchesProcessIdentity,
  processGroupCanBeTerminated,
  type ProcessIdentity,
} from "./process-identity.ts";

interface ManagedProcessIdentity extends ProcessIdentity {
  name: string;
  processGroup: boolean;
}

interface RunManifest {
  id: string;
  status: "running" | "completed" | "failed" | "stale-cleaned";
  startedAt: string;
  finishedAt?: string;
  owner: ProcessIdentity;
  ports: RuntimePorts;
  processes: ManagedProcessIdentity[];
}

export class ProcessManifest {
  private readonly file: string;
  private data: RunManifest;

  constructor(
    id: string,
    paths: RuntimePaths,
    ports: RuntimePorts
  ) {
    this.file = paths.manifest;
    this.data = {
      id,
      status: "running",
      startedAt: new Date().toISOString(),
      owner: getProcessIdentity(process.pid),
      ports,
      processes: [],
    };
    this.write();
  }

  register(name: string, pid: number | undefined, processGroup: boolean): void {
    if (!pid) return;
    this.data.processes.push({
      name,
      processGroup,
      ...getProcessIdentity(pid),
    });
    this.write();
  }

  complete(failed: boolean): void {
    this.data.status = failed ? "failed" : "completed";
    this.data.finishedAt = new Date().toISOString();
    this.write();
  }

  private write(): void {
    const temporaryFile = `${this.file}.tmp`;
    fs.writeFileSync(temporaryFile, JSON.stringify(this.data, null, 2));
    fs.renameSync(temporaryFile, this.file);
  }
}

export function cleanupStaleRuns(runsRoot: string): void {
  if (!fs.existsSync(runsRoot)) return;

  for (const entry of fs.readdirSync(runsRoot, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    const manifestPath = path.join(runsRoot, entry.name, "run.json");
    const manifest = readManifest(manifestPath);
    if (!manifest || manifest.status !== "running") continue;
    if (matchesProcessIdentity(manifest.owner)) continue;

    for (const processIdentity of manifest.processes) {
      const canTerminate = processIdentity.processGroup
        ? processGroupCanBeTerminated(processIdentity)
        : matchesProcessIdentity(processIdentity);
      if (!canTerminate) continue;
      try {
        process.kill(
          processIdentity.processGroup
            ? -processIdentity.pid
            : processIdentity.pid,
          "SIGKILL"
        );
      } catch {
        // The process may have exited after its identity was checked.
      }
    }

    manifest.status = "stale-cleaned";
    manifest.finishedAt = new Date().toISOString();
    const temporaryFile = `${manifestPath}.${process.pid}.${randomUUID()}.tmp`;
    fs.writeFileSync(temporaryFile, JSON.stringify(manifest, null, 2));
    fs.renameSync(temporaryFile, manifestPath);
  }
}

function readManifest(file: string): RunManifest | undefined {
  if (!fs.existsSync(file)) return undefined;
  try {
    return JSON.parse(fs.readFileSync(file, "utf8")) as RunManifest;
  } catch (error) {
    console.warn(`Skipping unreadable run manifest ${file}:`, error);
    return undefined;
  }
}
