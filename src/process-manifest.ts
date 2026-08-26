// Run manifests preserve process ownership data for crash recovery

import * as fs from "fs";
import * as path from "path";
import { randomUUID } from "crypto";
import type { RuntimePaths, RuntimePorts } from "./run-context.ts";
import {
  getProcessIdentity,
  matchesProcessIdentity,
  processGroupCanBeTerminated,
  signalOwnedProcess,
  type ProcessIdentity,
} from "./process-identity.ts";

const RUN_MANIFEST_SCHEMA_VERSION = 1;

interface ManagedProcessIdentity extends ProcessIdentity {
  name: string;
  processGroup: boolean;
}

interface RunManifest {
  schemaVersion: typeof RUN_MANIFEST_SCHEMA_VERSION;
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
      schemaVersion: RUN_MANIFEST_SCHEMA_VERSION,
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
    writeJsonAtomic(this.file, this.data);
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
        signalOwnedProcess(
          processIdentity.pid,
          processIdentity.processGroup,
          "SIGKILL"
        );
      } catch {
        // The process may have exited after its identity was checked.
      }
    }

    manifest.status = "stale-cleaned";
    manifest.finishedAt = new Date().toISOString();
    writeJsonAtomic(manifestPath, manifest);
  }
}

function readManifest(file: string): RunManifest | undefined {
  if (!fs.existsSync(file)) return undefined;
  try {
    const manifest: unknown = JSON.parse(fs.readFileSync(file, "utf8"));
    if (!isRunManifest(manifest)) {
      console.warn(`Skipping unsupported run manifest ${file}`);
      return undefined;
    }
    return manifest;
  } catch (error) {
    console.warn(`Skipping unreadable run manifest ${file}:`, error);
    return undefined;
  }
}

function isRunManifest(value: unknown): value is RunManifest {
  if (!isRecord(value)) return false;
  if (value.schemaVersion !== RUN_MANIFEST_SCHEMA_VERSION) return false;
  if (typeof value.id !== "string") return false;
  if (
    value.status !== "running" &&
    value.status !== "completed" &&
    value.status !== "failed" &&
    value.status !== "stale-cleaned"
  ) {
    return false;
  }
  if (!isProcessIdentity(value.owner)) return false;
  if (!Array.isArray(value.processes)) return false;
  return value.processes.every(isManagedProcessIdentity);
}

function isManagedProcessIdentity(
  value: unknown
): value is ManagedProcessIdentity {
  return (
    isRecord(value) &&
    isProcessIdentity(value) &&
    typeof value.name === "string" &&
    typeof value.processGroup === "boolean"
  );
}

function isProcessIdentity(value: unknown): value is ProcessIdentity {
  return (
    isRecord(value) &&
    typeof value.pid === "number" &&
    Number.isInteger(value.pid) &&
    typeof value.startTime === "string"
  );
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}

function writeJsonAtomic(file: string, value: unknown): void {
  const temporaryFile = `${file}.${process.pid}.${randomUUID()}.tmp`;
  try {
    fs.writeFileSync(temporaryFile, JSON.stringify(value, null, 2));
    fs.renameSync(temporaryFile, file);
  } finally {
    try {
      fs.unlinkSync(temporaryFile);
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
    }
  }
}
