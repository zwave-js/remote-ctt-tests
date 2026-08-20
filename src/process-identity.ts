import * as fs from "fs";

export interface ProcessIdentity {
  pid: number;
  startTime: string;
}

export function getProcessIdentity(pid: number): ProcessIdentity {
  const startTime = readProcessStartTime(pid);
  if (!startTime) {
    throw new Error(`Could not read process identity for PID ${pid}`);
  }
  return { pid, startTime };
}

export function matchesProcessIdentity(identity: ProcessIdentity): boolean {
  return readProcessStartTime(identity.pid) === identity.startTime;
}

export function processGroupCanBeTerminated(
  identity: ProcessIdentity
): boolean {
  const currentLeaderStart = readProcessStartTime(identity.pid);
  if (currentLeaderStart) {
    return currentLeaderStart === identity.startTime;
  }
  return processGroupHasMembers(identity.pid);
}

export function readProcessStartTime(pid: number): string | undefined {
  try {
    const stat = fs.readFileSync(`/proc/${pid}/stat`, "utf8");
    const fields = parseStatFields(stat);
    return fields?.[19];
  } catch {
    return undefined;
  }
}

function processGroupHasMembers(processGroupId: number): boolean {
  for (const entry of fs.readdirSync("/proc", { withFileTypes: true })) {
    if (!entry.isDirectory() || !/^\d+$/.test(entry.name)) continue;
    try {
      const stat = fs.readFileSync(`/proc/${entry.name}/stat`, "utf8");
      const fields = parseStatFields(stat);
      if (fields?.[2] === processGroupId.toString()) return true;
    } catch {
      // Processes can exit while /proc is being scanned.
    }
  }
  return false;
}

function parseStatFields(stat: string): string[] | undefined {
  const commandEnd = stat.lastIndexOf(") ");
  if (commandEnd === -1) return undefined;
  return stat.slice(commandEnd + 2).trim().split(/\s+/);
}
