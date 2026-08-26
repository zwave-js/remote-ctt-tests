// A run context isolates ports, writable state, generated configuration, and logs

import { execFileSync } from "child_process";
import * as dgram from "dgram";
import * as fs from "fs";
import * as net from "net";
import * as os from "os";
import * as path from "path";
import { randomInt, randomUUID } from "crypto";
import {
  getProcessIdentity,
  matchesProcessIdentity,
  type ProcessIdentity,
} from "./process-identity.ts";

export type TcpPortName =
  | "controller1"
  | "controller2"
  | "controller3"
  | "endDevice1"
  | "endDevice2"
  | "proxyController2"
  | "proxyController3"
  | "proxyEndDevice1"
  | "proxyEndDevice2"
  | "zniffer"
  | "cttRpc"
  | "cttCallback"
  | "runnerIpc"
  | "dutServer";

export type UdpPortName = "znifferDiscovery";

export interface RuntimePorts {
  tcp: Record<TcpPortName, number>;
  udp: Record<UdpPortName, number>;
  zneBase: number;
}

export interface RuntimePaths {
  root: string;
  cttProject: string;
  cttSolution: string;
  cttHome: string;
  cttLog: string;
  stackStorage: string;
  dutStorage: string;
  dutLogs: string;
  nodeTemp: string;
  manifest: string;
}

type Reservation = net.Server | dgram.Socket;

class PortAlreadyLeasedError extends Error {}

export class PortReservations {
  private readonly reservations = new Map<string, Reservation>();
  private readonly leases = new Map<string, string>();
  private readonly owner: ProcessIdentity = getProcessIdentity(process.pid);

  static async create(): Promise<{
    ports: RuntimePorts;
    reservations: PortReservations;
  }> {
    cleanupStaleLeases();
    const reservations = new PortReservations();
    const tcpNames: TcpPortName[] = [
      "controller1",
      "controller2",
      "controller3",
      "endDevice1",
      "endDevice2",
      "proxyController2",
      "proxyController3",
      "proxyEndDevice1",
      "proxyEndDevice2",
      "zniffer",
      "cttRpc",
      "cttCallback",
      "runnerIpc",
      "dutServer",
    ];

    const tcp = {} as Record<TcpPortName, number>;
    try {
      for (const name of tcpNames) {
        tcp[name] = await reservations.reserveTcp(name);
      }
      const znifferDiscovery = await reservations.reserveUdp(
        "znifferDiscovery"
      );
      const zneBase = await reservations.reserveUdpBlock("zne", 6);

      return {
        ports: {
          tcp,
          udp: { znifferDiscovery },
          zneBase,
        },
        reservations,
      };
    } catch (error) {
      await reservations.close();
      throw error;
    }
  }

  async handoff(name: TcpPortName | UdpPortName): Promise<void> {
    await this.closeReservation(name);
  }

  async handoffZneBlock(): Promise<void> {
    const keys = [...this.reservations.keys()].filter((key) =>
      key.startsWith("zne:")
    );
    await Promise.all(keys.map((key) => this.closeReservation(key)));
  }

  async close(): Promise<void> {
    const keys = new Set([
      ...this.reservations.keys(),
      ...this.leases.keys(),
    ]);
    await Promise.all(
      [...keys].map((key) => this.closeReservation(key, true))
    );
  }

  private async reserveTcp(name: TcpPortName): Promise<number> {
    const ranges = getNonEphemeralPortRanges();
    for (let attempt = 0; attempt < 100; attempt++) {
      let server: net.Server;
      let port: number;
      try {
        port = randomPort(ranges);
        if (hasActiveLease("tcp", port)) continue;
        server = await this.bindTcp(port);
      } catch (error) {
        if ((error as NodeJS.ErrnoException).code === "EADDRINUSE") continue;
        throw error;
      }
      let claimed: boolean;
      try {
        claimed = this.claimLease(name, "tcp", port);
      } catch (error) {
        await new Promise<void>((resolve) => server.close(() => resolve()));
        throw error;
      }
      if (claimed) {
        this.reservations.set(name, server);
        return port;
      }
      await new Promise<void>((resolve) => server.close(() => resolve()));
    }
    throw new Error(`Could not reserve a leased TCP port for ${name}`);
  }

  private async reserveUdp(name: UdpPortName): Promise<number> {
    const ranges = getNonEphemeralPortRanges();
    for (let attempt = 0; attempt < 100; attempt++) {
      try {
        return await this.bindUdp(name, randomPort(ranges));
      } catch (error) {
        if (
          !(error instanceof PortAlreadyLeasedError) &&
          (error as NodeJS.ErrnoException).code !== "EADDRINUSE"
        ) {
          throw error;
        }
      }
    }
    throw new Error(`Could not reserve a leased UDP port for ${name}`);
  }

  private async reserveUdpBlock(
    name: string,
    size: number
  ): Promise<number> {
    const ranges = getNonEphemeralPortRanges().filter(
      (range) => range.end - range.start + 1 >= size
    );
    if (ranges.length === 0) {
      throw new Error(
        `No non-ephemeral UDP range can fit a block of ${size} ports`
      );
    }
    for (let attempt = 0; attempt < 100; attempt++) {
      const keys: string[] = [];
      try {
        const baseKey = `${name}:0`;
        const base = randomPort(ranges, size);
        if (
          Array.from({ length: size }, (_, offset) => base + offset).some(
            (port) => hasActiveLease("udp", port)
          )
        ) {
          continue;
        }
        await this.bindUdp(baseKey, base);
        keys.push(baseKey);
        for (let offset = 1; offset < size; offset++) {
          const key = `${name}:${offset}`;
          await this.bindUdp(key, base + offset);
          keys.push(key);
        }
        return base;
      } catch {
        await Promise.all(
          keys.map((key) => this.closeReservation(key, true))
        );
      }
    }
    throw new Error(`Could not reserve a contiguous UDP block of ${size} ports`);
  }

  private bindUdp(name: string, port: number): Promise<number> {
    return new Promise((resolve, reject) => {
      if (hasActiveLease("udp", port)) {
        reject(new PortAlreadyLeasedError(`UDP port ${port} is leased`));
        return;
      }
      const socket = dgram.createSocket("udp4");
      const onError = (error: Error) => {
        socket.close();
        reject(error);
      };
      socket.once("error", onError);
      socket.bind(port, "127.0.0.1", () => {
        socket.off("error", onError);
        try {
          const address = socket.address();
          if (!this.claimLease(name, "udp", address.port)) {
            socket.close();
            reject(
              new PortAlreadyLeasedError(
                `UDP port ${address.port} already has a lease`
              )
            );
            return;
          }
          this.reservations.set(name, socket);
          resolve(address.port);
        } catch (error) {
          socket.close();
          reject(error);
        }
      });
    });
  }

  private bindTcp(port: number): Promise<net.Server> {
    return new Promise((resolve, reject) => {
      const server = net.createServer();
      const onError = (error: Error) => {
        server.close();
        reject(error);
      };
      server.once("error", onError);
      server.listen(port, "127.0.0.1", () => {
        server.off("error", onError);
        resolve(server);
      });
    });
  }

  private claimLease(
    name: string,
    protocol: "tcp" | "udp",
    port: number
  ): boolean {
    const leaseFile = getLeaseFile(protocol, port);
    const candidateFile = `${leaseFile}.${process.pid}.${randomUUID()}.tmp`;
    fs.writeFileSync(
      candidateFile,
      JSON.stringify({ name, owner: this.owner }),
      { flag: "wx" }
    );

    try {
      for (let attempt = 0; attempt < 3; attempt++) {
        if (hasActiveLease(protocol, port)) return false;
        try {
          fs.linkSync(candidateFile, leaseFile);
          this.leases.set(name, leaseFile);
          return true;
        } catch (error) {
          if ((error as NodeJS.ErrnoException).code !== "EEXIST") throw error;
        }
      }
      return false;
    } finally {
      fs.unlinkSync(candidateFile);
    }
  }

  private async closeReservation(
    name: string,
    removeLease = false
  ): Promise<void> {
    const reservation = this.reservations.get(name);
    if (reservation) {
      this.reservations.delete(name);
      await new Promise<void>((resolve) => reservation.close(() => resolve()));
    }
    if (!removeLease) return;

    const leaseFile = this.leases.get(name);
    if (!leaseFile) return;
    this.leases.delete(name);
    try {
      fs.unlinkSync(leaseFile);
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
    }
  }
}

interface PortRange {
  start: number;
  end: number;
}

function getNonEphemeralPortRanges(): PortRange[] {
  const [ephemeralStart, ephemeralEnd] = fs
    .readFileSync("/proc/sys/net/ipv4/ip_local_port_range", "utf8")
    .trim()
    .split(/\s+/)
    .map(Number);
  if (
    !Number.isInteger(ephemeralStart) ||
    !Number.isInteger(ephemeralEnd) ||
    ephemeralStart! < 1 ||
    ephemeralEnd! > 65535 ||
    ephemeralStart! > ephemeralEnd!
  ) {
    throw new Error("Could not determine the Linux ephemeral port range");
  }

  return [
    { start: 1024, end: ephemeralStart! - 1 },
    { start: ephemeralEnd! + 1, end: 65535 },
  ].filter((range) => range.start <= range.end);
}

function randomPort(ranges: PortRange[], blockSize = 1): number {
  const weightedRanges = ranges
    .map((range) => ({
      range,
      choices: range.end - range.start - blockSize + 2,
    }))
    .filter(({ choices }) => choices > 0);
  const totalChoices = weightedRanges.reduce(
    (total, { choices }) => total + choices,
    0
  );
  if (totalChoices === 0) {
    throw new Error(`No non-ephemeral port range can fit ${blockSize} ports`);
  }

  let choice = randomInt(totalChoices);
  for (const { range, choices } of weightedRanges) {
    if (choice < choices) return range.start + choice;
    choice -= choices;
  }
  throw new Error("Could not select a non-ephemeral port");
}

function readLeaseOwner(file: string): ProcessIdentity | undefined {
  try {
    const parsed = JSON.parse(fs.readFileSync(file, "utf8")) as {
      owner?: ProcessIdentity;
    };
    return parsed.owner;
  } catch {
    return undefined;
  }
}

function hasActiveLease(protocol: "tcp" | "udp", port: number): boolean {
  const leaseFile = getLeaseFile(protocol, port);
  for (let attempt = 0; attempt < 3; attempt++) {
    let before: fs.Stats;
    try {
      before = fs.lstatSync(leaseFile);
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === "ENOENT") return false;
      throw error;
    }

    const owner = readLeaseOwner(leaseFile);
    if (owner && matchesProcessIdentity(owner)) return true;

    try {
      const current = fs.lstatSync(leaseFile);
      if (current.dev !== before.dev || current.ino !== before.ino) continue;
      fs.unlinkSync(leaseFile);
      return false;
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code === "ENOENT") return false;
      throw error;
    }
  }
  return true;
}

function getLeaseFile(protocol: "tcp" | "udp", port: number): string {
  return path.join(getLeaseRoot(), `${protocol}-${port}.json`);
}

function getLeaseRoot(): string {
  const uid = process.getuid?.();
  if (uid === undefined) {
    throw new Error("Port leases require a Linux user ID");
  }

  const leasesRoot = path.join(
    os.tmpdir(),
    `remote-ctt-tests-${uid}-port-leases`
  );
  try {
    fs.mkdirSync(leasesRoot, { mode: 0o700 });
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code !== "EEXIST") throw error;
  }

  const stat = fs.lstatSync(leasesRoot);
  if (
    stat.isSymbolicLink() ||
    !stat.isDirectory() ||
    stat.uid !== uid ||
    (stat.mode & 0o077) !== 0
  ) {
    throw new Error(
      `Port lease directory must be owned by UID ${uid} with mode 0700: ${leasesRoot}`
    );
  }
  return leasesRoot;
}

function cleanupStaleLeases(): void {
  const leasesRoot = getLeaseRoot();

  for (const entry of fs.readdirSync(leasesRoot, { withFileTypes: true })) {
    if (!entry.isFile() || !/^(tcp|udp)-\d+\.json$/.test(entry.name)) continue;
    const leaseFile = path.join(leasesRoot, entry.name);
    const [, protocol, port] = /^(tcp|udp)-(\d+)\.json$/.exec(entry.name)!;
    hasActiveLease(protocol as "tcp" | "udp", Number(port));
  }
}

export interface RunContext {
  id: string;
  paths: RuntimePaths;
  ports: RuntimePorts;
  reservations: PortReservations;
}

export async function createRunContext(repoRoot: string): Promise<RunContext> {
  const runsRoot = path.join(repoRoot, ".ctt-runs");
  fs.mkdirSync(runsRoot, { recursive: true });

  const id = randomUUID().replace(/-/g, "").slice(0, 12);
  const root = path.join(runsRoot, id);
  fs.mkdirSync(root);

  const paths: RuntimePaths = {
    root,
    cttProject: path.join(root, "ctt", "project"),
    cttSolution: path.join(root, "ctt", "project", "zwave-js.cttsln"),
    cttHome: path.join(root, "home"),
    cttLog: path.join(root, "logs", "ctt-remote.log"),
    stackStorage: path.join(root, "state", "zwave-stack"),
    dutStorage: path.join(root, "state", "dut"),
    dutLogs: path.join(root, "logs", "dut"),
    nodeTemp: path.join(root, "tmp", "nodes"),
    manifest: path.join(root, "run.json"),
  };

  let reservations: PortReservations | undefined;
  try {
    for (const directory of [
      paths.cttHome,
      path.dirname(paths.cttLog),
      paths.dutLogs,
      paths.nodeTemp,
    ]) {
      fs.mkdirSync(directory, { recursive: true });
    }

    const allocation = await PortReservations.create();
    reservations = allocation.reservations;
    const { ports } = allocation;
    initializeNetworkState(repoRoot, paths);
    initializeCttProject(repoRoot, paths, ports);
    return { id, paths, ports, reservations };
  } catch (error) {
    await reservations?.close();
    fs.rmSync(root, { recursive: true, force: true });
    throw error;
  }
}

function initializeNetworkState(
  repoRoot: string,
  paths: RuntimePaths
): void {
  const archive = path.join(repoRoot, "setup", "network-state.zip");
  const stateRoot = path.dirname(paths.stackStorage);
  execFileSync("unzip", ["-q", archive, "-d", stateRoot]);

  const extractedStackStorage = path.join(stateRoot, "storage");
  const extractedDutStorage = path.join(stateRoot, "dut-storage");
  if (!fs.existsSync(extractedStackStorage)) {
    throw new Error(`Network state archive has no storage directory: ${archive}`);
  }
  if (!fs.existsSync(extractedDutStorage)) {
    throw new Error(
      `Network state archive has no dut-storage directory: ${archive}`
    );
  }
  fs.renameSync(extractedStackStorage, paths.stackStorage);
  fs.renameSync(extractedDutStorage, paths.dutStorage);
}

function initializeCttProject(
  repoRoot: string,
  paths: RuntimePaths,
  ports: RuntimePorts
): void {
  const sourceProject = path.join(repoRoot, "ctt", "project");
  fs.cpSync(sourceProject, paths.cttProject, { recursive: true });

  const keysDir = path.join(repoRoot, "ctt", "keys");
  const cttSettingsDir = path.join(paths.cttHome, ".ctt4");
  fs.mkdirSync(cttSettingsDir, { recursive: true });
  fs.writeFileSync(
    path.join(cttSettingsDir, "settings.json"),
    JSON.stringify(
      {
        KeyStorageFolder: keysDir,
        SimplicityCommanderPath: "/usr/bin/true",
      },
      null,
      2
    )
  );

  const zatsSettingsPath = path.join(
    paths.cttProject,
    "Config",
    "ZatsSettings.json"
  );
  const zatsSettings = JSON.parse(
    fs.readFileSync(zatsSettingsPath, "utf8").replace(/^\uFEFF/, "")
  ) as Record<string, unknown>;
  zatsSettings.KeysStoragePath = keysDir;
  fs.writeFileSync(zatsSettingsPath, JSON.stringify(zatsSettings, null, 2));

  patchZatsDefinition(paths, ports);
  patchCttSolution(paths, ports);
}

function patchZatsDefinition(
  paths: RuntimePaths,
  ports: RuntimePorts
): void {
  const definitionPath = path.join(
    paths.cttProject,
    "Config",
    "ZatsDefinition.xml"
  );
  let content = fs.readFileSync(definitionPath, "utf8");
  content = replaceExactlyOnce(
    content,
    /Reports="[^"]*"/,
    `Reports="${escapeXmlAttribute(
      path.join(paths.cttProject, "Log")
    )}"`,
    "CTT report path"
  );

  const devicePorts: Record<string, number> = {
    Controller1: ports.tcp.proxyController2,
    Controller3: ports.tcp.proxyController3,
    EndDevice1: ports.tcp.proxyEndDevice1,
    EndDevice2: ports.tcp.proxyEndDevice2,
  };
  for (const [alias, port] of Object.entries(devicePorts)) {
    content = replaceExactlyOnce(
      content,
      new RegExp(
        `(<DeviceHost\\s+Alias="${alias}"[^>]*\\sSPort=")\\d+(")`
      ),
      `$1${port}$2`,
      `${alias} profile port`
    );
  }
  fs.writeFileSync(definitionPath, content);
}

function patchCttSolution(paths: RuntimePaths, ports: RuntimePorts): void {
  let content = fs.readFileSync(paths.cttSolution, "utf8");
  const sectionPorts: Record<string, number> = {
    Zniffer: ports.tcp.zniffer,
    FirstController: ports.tcp.proxyController2,
    ThirdController: ports.tcp.proxyController3,
    FirstEndDevice: ports.tcp.proxyEndDevice1,
    SecondEndDevice: ports.tcp.proxyEndDevice2,
  };

  for (const [section, port] of Object.entries(sectionPorts)) {
    content = replaceExactlyOnce(
      content,
      new RegExp(`(<${section}>[\\s\\S]*?<SPort>)\\d+(</SPort>)`),
      `$1${port}$2`,
      `${section} solution port`
    );
  }
  fs.writeFileSync(paths.cttSolution, content);
}

export function replaceExactlyOnce(
  content: string,
  pattern: RegExp,
  replacement: string,
  description: string
): string {
  const matches = content.match(
    new RegExp(pattern.source, pattern.flags.replace("g", "") + "g")
  );
  if (matches?.length !== 1) {
    throw new Error(
      `Expected one ${description} in the CTT project, found ${
        matches?.length ?? 0
      }`
    );
  }
  return content.replace(pattern, replacement);
}

function escapeXmlAttribute(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/"/g, "&quot;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}
