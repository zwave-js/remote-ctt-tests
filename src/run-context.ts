import { execFileSync } from "child_process";
import * as dgram from "dgram";
import * as fs from "fs";
import * as net from "net";
import * as os from "os";
import * as path from "path";
import { randomUUID } from "crypto";
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
      await reservations.releaseAll();
      throw error;
    }
  }

  async release(name: TcpPortName | UdpPortName): Promise<void> {
    await this.releaseKey(name);
  }

  async releaseZneBlock(): Promise<void> {
    const keys = [...this.reservations.keys()].filter((key) =>
      key.startsWith("zne:")
    );
    await Promise.all(keys.map((key) => this.releaseKey(key)));
  }

  async releaseAll(): Promise<void> {
    const keys = new Set([
      ...this.reservations.keys(),
      ...this.leases.keys(),
    ]);
    await Promise.all([...keys].map((key) => this.releaseKey(key, true)));
  }

  private async reserveTcp(name: TcpPortName): Promise<number> {
    for (let attempt = 0; attempt < 100; attempt++) {
      const { server, port } = await this.bindTcp();
      if (this.claimLease(name, "tcp", port)) {
        this.reservations.set(name, server);
        return port;
      }
      await new Promise<void>((resolve) => server.close(() => resolve()));
    }
    throw new Error(`Could not reserve a leased TCP port for ${name}`);
  }

  private async reserveUdp(name: UdpPortName): Promise<number> {
    for (let attempt = 0; attempt < 100; attempt++) {
      try {
        return await this.bindUdp(name, 0);
      } catch (error) {
        if (!(error instanceof PortAlreadyLeasedError)) throw error;
      }
    }
    throw new Error(`Could not reserve a leased UDP port for ${name}`);
  }

  private async reserveUdpBlock(
    name: string,
    size: number
  ): Promise<number> {
    for (let attempt = 0; attempt < 100; attempt++) {
      const keys: string[] = [];
      try {
        const baseKey = `${name}:0`;
        const base = await this.bindUdp(baseKey, 0);
        keys.push(baseKey);
        if (base + size > 65536) {
          throw new Error("Allocated UDP base is too close to port 65535");
        }
        for (let offset = 1; offset < size; offset++) {
          const key = `${name}:${offset}`;
          await this.bindUdp(key, base + offset);
          keys.push(key);
        }
        return base;
      } catch {
        await Promise.all(keys.map((key) => this.releaseKey(key, true)));
      }
    }
    throw new Error(`Could not reserve a contiguous UDP block of ${size} ports`);
  }

  private bindUdp(name: string, port: number): Promise<number> {
    return new Promise((resolve, reject) => {
      const socket = dgram.createSocket("udp4");
      const onError = (error: Error) => {
        socket.close();
        reject(error);
      };
      socket.once("error", onError);
      socket.bind(port, "127.0.0.1", () => {
        socket.off("error", onError);
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
      });
    });
  }

  private bindTcp(): Promise<{ server: net.Server; port: number }> {
    return new Promise((resolve, reject) => {
      const server = net.createServer();
      const onError = (error: Error) => {
        server.close();
        reject(error);
      };
      server.once("error", onError);
      server.listen(0, "127.0.0.1", () => {
        server.off("error", onError);
        const address = server.address();
        if (!address || typeof address === "string") {
          server.close();
          reject(new Error("Could not reserve a TCP port"));
          return;
        }
        resolve({ server, port: address.port });
      });
    });
  }

  private claimLease(
    name: string,
    protocol: "tcp" | "udp",
    port: number
  ): boolean {
    const leasesRoot = path.join(
      os.tmpdir(),
      "remote-ctt-tests-port-leases"
    );
    fs.mkdirSync(leasesRoot, { recursive: true });
    const leaseFile = path.join(leasesRoot, `${protocol}-${port}.json`);
    const candidateFile = `${leaseFile}.${process.pid}.${randomUUID()}.tmp`;
    fs.writeFileSync(
      candidateFile,
      JSON.stringify({ name, owner: this.owner }),
      { flag: "wx" }
    );

    try {
      for (let attempt = 0; attempt < 3; attempt++) {
        try {
          fs.linkSync(candidateFile, leaseFile);
          this.leases.set(name, leaseFile);
          return true;
        } catch (error) {
          if ((error as NodeJS.ErrnoException).code !== "EEXIST") throw error;
        }

        const existingOwner = readLeaseOwner(leaseFile);
        if (existingOwner && matchesProcessIdentity(existingOwner)) return false;
        try {
          fs.unlinkSync(leaseFile);
        } catch (error) {
          if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
        }
      }
      return false;
    } finally {
      fs.unlinkSync(candidateFile);
    }
  }

  private async releaseKey(
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

function cleanupStaleLeases(): void {
  const leasesRoot = path.join(os.tmpdir(), "remote-ctt-tests-port-leases");
  if (!fs.existsSync(leasesRoot)) return;

  for (const entry of fs.readdirSync(leasesRoot, { withFileTypes: true })) {
    if (!entry.isFile() || !/^(tcp|udp)-\d+\.json$/.test(entry.name)) continue;
    const leaseFile = path.join(leasesRoot, entry.name);
    const owner = readLeaseOwner(leaseFile);
    if (owner && matchesProcessIdentity(owner)) continue;
    try {
      fs.unlinkSync(leaseFile);
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "ENOENT") throw error;
    }
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

  for (const directory of [
    paths.cttHome,
    path.dirname(paths.cttLog),
    paths.dutLogs,
    paths.nodeTemp,
  ]) {
    fs.mkdirSync(directory, { recursive: true });
  }

  const { ports, reservations } = await PortReservations.create();
  try {
    initializeNetworkState(repoRoot, paths);
    initializeCttProject(repoRoot, paths, ports);
  } catch (error) {
    await reservations.releaseAll();
    throw error;
  }

  return { id, paths, ports, reservations };
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
        SimplicityCommanderPath: "",
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
