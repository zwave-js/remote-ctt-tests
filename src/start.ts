import { spawn, ChildProcess } from "child_process";
import * as path from "path";
import * as fs from "fs";
import { fileURLToPath } from "url";
import { createWebSocketServer } from "./ws-server.ts";
import type { ManagedWebSocketServer } from "./ws-server.ts";
import {
  runTestCases,
  closeCTT,
  getTestCases,
  cancelTestRun,
} from "./ctt-client.ts";
import { RunnerHost } from "./runner-host.ts";
import { CTTDeviceProxy, type FrameHandler } from "./ctt-device-proxy.ts";
import c from "ansi-colors";
import { setTimeout } from "timers/promises";
import JSON5 from "json5";

// In CI, Z-Wave stack runs from native WSL filesystem for better performance
const ZWAVE_STACK_PATH = !!process.env.CI ? "~/zwave_stack" : "./zwave_stack";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const PID_FILE = path.join(__dirname, "..", ".ctt-pids.json");

interface PidFileData {
  startTime: string;
  pids: {
    name: string;
    pid: number;
    platform: "windows" | "wsl";
  }[];
}

// Parse command line arguments
const args = process.argv.slice(2);
const DEVICES_ONLY = args.includes("--devices-only");
const VERBOSE = args.includes("--verbose");
const DISCOVER_MODE = args.includes("--discover");
// Support multiple --test= arguments or comma-separated names
const testArgs = args.filter((arg) => arg.startsWith("--test="));
// Also treat all positional arguments (not starting with --) as test names
const positionalArgs = args.filter((arg) => !arg.startsWith("--"));
const TEST_NAMES: string[] = [
  ...testArgs.flatMap((arg) => arg.split("=")[1].split(",")),
  ...positionalArgs,
];
// Support multiple --category= arguments or comma-separated categories
const categoryArgs = args.filter((arg) => arg.startsWith("--category="));
const CATEGORIES: string[] = categoryArgs.flatMap((arg) =>
  arg.split("=")[1].split(",")
);
// Support multiple --group= arguments or comma-separated groups (e.g., Automatic, Interactive)
const groupArgs = args.filter((arg) => arg.startsWith("--group="));
const GROUPS: string[] = groupArgs.flatMap((arg) =>
  arg.split("=")[1].split(",")
);
// Support multiple --exclude= arguments or comma-separated test names to exclude
const excludeArgs = args.filter((arg) => arg.startsWith("--exclude="));
const EXCLUDE_TESTS: string[] = excludeArgs.flatMap((arg) =>
  arg.split("=")[1].split(",")
);

// Load config.json
interface Config {
  dut: {
    name: string;
    runnerPath: string;
  };
}

function loadConfig(): Config {
  const configPath = path.join(__dirname, "..", "config.json");
  try {
    const content = fs.readFileSync(configPath, "utf-8");
    return JSON5.parse(content) as Config;
  } catch (error) {
    console.error("Failed to load config.json:", error);
    process.exit(1);
  }
}

const config = loadConfig();

// Parse --dut argument (default to config runner path)
const dutArg = args.find((arg) => arg.startsWith("--dut="));
const DUT_PATH = dutArg
  ? dutArg.split("=")[1]
  : path.join(__dirname, "..", config.dut.runnerPath);

const CTT_PATH =
  process.env.CTT_PATH ||
  "C:\\Program Files (x86)\\Z-Wave Alliance\\Z-Wave CTT 3";

interface ManagedProcess {
  name: string;
  process: ChildProcess;
  pid?: number;
}

class ProcessManager {
  private processes: ManagedProcess[] = [];
  private wsServer?: ManagedWebSocketServer;
  private runnerHost?: RunnerHost;
  private deviceProxy?: CTTDeviceProxy;
  private isCleaningUp = false;

  /**
   * Load PID file data if it exists
   */
  private loadPidFile(): PidFileData | null {
    try {
      if (fs.existsSync(PID_FILE)) {
        const data = fs.readFileSync(PID_FILE, "utf-8");
        return JSON.parse(data) as PidFileData;
      }
    } catch (error) {
      console.warn("Failed to read PID file:", error);
    }
    return null;
  }

  /**
   * Save current PIDs to file
   */
  private savePidFile(): void {
    const pids: PidFileData["pids"] = this.processes
      .filter((p) => p.pid !== undefined)
      .map((p) => ({
        name: p.name,
        pid: p.pid!,
        platform: p.name.includes("WSL")
          ? ("wsl" as const)
          : ("windows" as const),
      }));

    // Add runner PID if available
    const runnerPid = this.runnerHost?.getRunnerPid();
    if (runnerPid) {
      pids.push({
        name: `${config.dut.name} Runner`,
        pid: runnerPid,
        platform: "windows",
      });
    }

    const data: PidFileData = {
      startTime: new Date().toISOString(),
      pids,
    };

    try {
      fs.writeFileSync(PID_FILE, JSON.stringify(data, null, 2));
      console.log(c.dim(`PIDs saved to ${PID_FILE}`));
    } catch (error) {
      console.warn("Failed to write PID file:", error);
    }
  }

  /**
   * Delete the PID file
   */
  private deletePidFile(): void {
    try {
      if (fs.existsSync(PID_FILE)) {
        fs.unlinkSync(PID_FILE);
        console.log(c.dim("PID file cleaned up"));
      }
    } catch (error) {
      console.warn("Failed to delete PID file:", error);
    }
  }

  /**
   * Kill any orphaned processes from a previous run
   */
  async killOrphanedProcesses(): Promise<void> {
    const pidData = this.loadPidFile();
    if (!pidData) {
      return;
    }

    console.log(c.yellow(`\nFound PID file from ${pidData.startTime}`));
    console.log(c.yellow("Cleaning up orphaned processes...\n"));

    for (const { name, pid, platform } of pidData.pids) {
      try {
        if (platform === "wsl") {
          // Kill WSL process - use wsl kill command
          console.log(c.dim(`Killing WSL process: ${name} (PID ${pid})`));
          spawn("wsl", ["kill", "-9", pid.toString()], { stdio: "ignore" });
        } else {
          // Kill Windows process
          console.log(c.dim(`Killing Windows process: ${name} (PID ${pid})`));
          spawn("taskkill", ["/pid", pid.toString(), "/T", "/F"], {
            stdio: "ignore",
          });
        }
      } catch (error) {
        // Ignore errors - process may already be dead
      }
    }

    // Also kill any Z-Wave processes that might be lingering in WSL
    try {
      console.log(
        c.dim("Cleaning up any lingering Z-Wave processes in WSL...")
      );
      spawn("wsl", ["pkill", "-f", "ZW_zwave"], { stdio: "ignore" });
    } catch (error) {
      // Ignore
    }

    // Kill ZatsTestConsole.exe if it's still running
    try {
      console.log(c.dim("Killing any running ZatsTestConsole.exe..."));
      spawn("taskkill", ["/IM", "ZatsTestConsole.exe", "/F"], {
        stdio: "ignore",
      });
    } catch (error) {
      // Ignore - process may not be running
    }

    // Give processes a moment to die
    await setTimeout(1000);

    // Clean up the old PID file
    this.deletePidFile();
    console.log(c.green("✓ Orphaned processes cleaned up\n"));
  }

  startZWaveStackWSL(): void {
    console.log("Starting Z-Wave stack in WSL...");

    const timestamp = () => {
      const now = new Date();
      return (
        now.toTimeString().slice(0, 8) +
        "." +
        now.getMilliseconds().toString().padStart(3, "0")
      );
    };

    const proc = spawn("wsl", ["bash", `${ZWAVE_STACK_PATH}/run.sh`], {
      cwd: path.join(__dirname, ".."),
      stdio: "pipe",
    });

    proc.stdout?.on("data", (data) => {
      console.log(`[${timestamp()}] [WSL Z-Wave] ${data.toString().trim()}`);
    });

    proc.stderr?.on("data", (data) => {
      console.error(`[${timestamp()}] [WSL Z-Wave] ${data.toString().trim()}`);
    });

    proc.on("error", (error) => {
      console.error("Failed to start Z-Wave stack in WSL:", error);
    });

    proc.on("exit", (code) => {
      console.error(
        `Z-Wave stack WSL process exited with code ${code}, aborting...`
      );
      this.cleanup();
    });

    this.processes.push({
      name: "Z-Wave Stack (WSL)",
      process: proc,
      pid: proc.pid,
    });

    // Save PIDs after adding this process
    this.savePidFile();

    console.log("Z-Wave stack started in WSL");
  }

  async startCTTDeviceProxy(): Promise<void> {
    const TARGET_FRAME = Buffer.from("01060028432003b1", "hex");

    let expectHostAck = new Set<string>();

    const frameHandler: FrameHandler = (
      config,
      data,
      direction,
      forward,
      respond
    ) => {
      // if (direction === "toDevice") {
      //   console.log(c.dim(`CTT -> ${config.name}: ${data.toString("hex")}`));
      // } else {
      //   console.log(c.dim(`${config.name} -> CTT: ${data.toString("hex")}`));
      // }

      // We need to intercept the ACKs we receive in response to our injected frame
      // otherwise this will hang the simulated end devices
      if (
        data.length === 1 &&
        data[0] === 0x06 &&
        expectHostAck.has(config.name)
      ) {
        expectHostAck.delete(config.name);
        return;
      }

      if (data.equals(TARGET_FRAME) && config.name.includes("EndDevice")) {
        // Target frame detected - handle it
        console.log(
          c.yellow(
            `[Proxy ${config.name}] NVR_GetValue for private key intercepted`
          )
        );
        respond(Buffer.from([0x06])); // ACK

        // Read the private key from the device's manufacturer token storage
        // Always read from Windows path (in CI, files exist in both places)
        const tokenPath = path.join(
          __dirname,
          "../zwave_stack/storage",
          config.name.toLowerCase(),
          "nvm_stack/20.bin"
        );
        const token = fs.readFileSync(tokenPath);

        const response = Buffer.alloc(5 + 32);
        response[0] = 0x01; // SOF
        response[1] = response.length - 2; // Length
        response[2] = 0x01; // response
        response[3] = 0x28; // NVR_GetValue
        response.set(token, 4); // Token data
        let chksum = 0xff;
        for (let i = 1; i < response.length - 1; i++) {
          chksum ^= response[i]!;
        }
        response[response.length - 1] = chksum; // Checksum
        expectHostAck.add(config.name);
        respond(response);
      } else {
        // Normal data - forward as-is
        forward(data);
      }
    };

    const configs = [
      {
        name: "Controller2",
        listenPort: 5001,
        targetHost: "127.0.0.1",
        targetPort: 6001,
      },
      {
        name: "Controller3",
        listenPort: 5002,
        targetHost: "127.0.0.1",
        targetPort: 6002,
      },
      {
        name: "EndDevice1",
        listenPort: 5003,
        targetHost: "127.0.0.1",
        targetPort: 6003,
      },
      {
        name: "EndDevice2",
        listenPort: 5004,
        targetHost: "127.0.0.1",
        targetPort: 6004,
      },
    ];

    this.deviceProxy = new CTTDeviceProxy(configs, frameHandler);
    await this.deviceProxy.start();
  }

  async startRunner(): Promise<void> {
    console.log(`Starting ${config.dut.name} runner: ${DUT_PATH}`);

    this.runnerHost = new RunnerHost({
      runnerPath: DUT_PATH,
      onUnexpectedExit: () => this.cleanup(),
    });

    // Initialize the runner (spawns process, waits for ready)
    await this.runnerHost.initialize();

    // Start the DUT
    await this.runnerHost.start({
      controllerUrl: "tcp://127.0.0.1:5000",
      securityKeys: {
        S2_Unauthenticated: "CE07372267DCB354DB216761B6E9C378",
        S2_Authenticated: "30B5CCF3F482A92E2F63A5C5E218149A",
        S2_AccessControl: "21A29A69145E38C1601DFF55E2658521",
        S0_Legacy: "C6D90542DE4E66BBE66FBFCB84E9FF67",
      },
      securityKeysLongRange: {
        S2_Authenticated: "0F4F7E178A4207A0BBEFBF991C66F814",
        S2_AccessControl: "72D42391F7ECE63BE1B38B25D085ECD4",
      },
    });

    // Update PID file with runner PID
    this.savePidFile();
  }

  async stopRunner(): Promise<void> {
    if (this.runnerHost) {
      await this.runnerHost.cleanup();
      this.runnerHost = undefined;
    }
  }

  startCTTRemote(verbose: boolean = false): ManagedProcess {
    const cttRemotePath = path.join(CTT_PATH, "CTT-Remote.exe");
    const solutionPath = path.join(
      __dirname,
      "..",
      "ctt",
      "project",
      "zwave-js.cttsln"
    );

    console.log(`Starting CTT-Remote: ${cttRemotePath} ${solutionPath}`);

    // On Windows, run directly
    // Hide console output unless verbose mode is enabled
    const cttProcess = spawn(cttRemotePath, [solutionPath], {
      cwd: CTT_PATH,
      stdio: verbose ? "inherit" : "ignore",
      windowsHide: true,
    });

    cttProcess.on("error", (error) => {
      console.error("Failed to start CTT-Remote:", error);
    });

    cttProcess.on("exit", (code) => {
      console.error(`CTT-Remote exited with code ${code}, aborting...`);
      this.cleanup();
    });

    const managedProcess: ManagedProcess = {
      name: "CTT-Remote",
      process: cttProcess,
      pid: cttProcess.pid,
    };

    this.processes.push(managedProcess);

    // Save PIDs after adding this process
    this.savePidFile();

    return managedProcess;
  }

  /**
   * Run specific tests by name
   */
  async runTests(testNames: string[]): Promise<void> {
    console.log(`Running ${testNames.length} test(s)...\n`);

    const startTime = Date.now();

    const results = await runTestCases({
      testCaseNames: testNames,
      endPointIds: [],
      ZWaveExecutionModes: [],
    });

    const elapsed = Date.now() - startTime;
    const minutes = Math.floor(elapsed / 60000);
    const seconds = ((elapsed % 60000) / 1000).toFixed(1);

    // Print summary
    const passed = results.filter((r) => r.result === "PASSED");
    const failed = results.filter((r) => r.result !== "PASSED");

    console.log("\n" + "=".repeat(50));
    console.log("Test Results Summary");
    console.log("=".repeat(50));
    console.log(c.green(`✅ Passed: ${passed.length}/${results.length}`));
    if (failed.length > 0) {
      console.log(c.red(`❌ Failed: ${failed.length}/${results.length}`));
      for (const test of failed) {
        console.log(c.red(`   - ${test.name} (${test.result})`));
      }
    }
    console.log(c.dim(`⏱  Total time: ${minutes}m ${seconds}s`));
    console.log("=".repeat(50));
  }

  /**
   * Run all tests matching the specified categories and/or groups
   */
  async runTestsByFilter(
    categories: string[],
    groups: string[]
  ): Promise<void> {
    // Get all tests
    const allTests = (await getTestCases({})) as Array<{
      Name: string;
      Category: string;
      Group: string;
    }>;

    // Filter by categories and/or groups (case-insensitive partial match)
    let matchingTests = allTests;

    if (categories.length > 0) {
      matchingTests = matchingTests.filter((tc) =>
        categories.some((cat) =>
          tc.Category.toLowerCase().includes(cat.toLowerCase())
        )
      );
    }

    if (groups.length > 0) {
      matchingTests = matchingTests.filter((tc) =>
        groups.some((grp) => tc.Group.toLowerCase().includes(grp.toLowerCase()))
      );
    }

    // Apply exclusions
    if (EXCLUDE_TESTS.length > 0) {
      const beforeCount = matchingTests.length;
      matchingTests = matchingTests.filter(
        (tc) => !EXCLUDE_TESTS.some((ex) => tc.Name.includes(ex))
      );
      const excluded = beforeCount - matchingTests.length;
      if (excluded > 0) {
        console.log(
          c.dim(
            `Excluded ${excluded} test(s) matching: ${EXCLUDE_TESTS.join(", ")}`
          )
        );
      }
    }

    if (matchingTests.length === 0) {
      const filters: string[] = [];
      if (categories.length > 0)
        filters.push(`categories: ${categories.join(", ")}`);
      if (groups.length > 0) filters.push(`groups: ${groups.join(", ")}`);
      console.log(c.yellow(`No tests found matching ${filters.join(" and ")}`));

      console.log("\nAvailable categories:");
      const cats = new Set(allTests.map((tc) => tc.Category));
      for (const cat of cats) {
        console.log(`  - ${cat}`);
      }
      console.log("\nAvailable groups:");
      const grps = new Set(allTests.map((tc) => tc.Group));
      for (const grp of grps) {
        console.log(`  - ${grp}`);
      }
      return;
    }

    const testNames = matchingTests.map((tc) => tc.Name);
    const filters: string[] = [];
    if (categories.length > 0)
      filters.push(`categories: ${categories.join(", ")}`);
    if (groups.length > 0) filters.push(`groups: ${groups.join(", ")}`);
    console.log(
      `Found ${testNames.length} tests matching ${filters.join(" and ")}\n`
    );

    await this.runTests(testNames);
  }

  /**
   * List all test cases grouped by category
   */
  async listTestCases(): Promise<void> {
    const allTests = (await getTestCases({})) as Array<{
      Name: string;
      Category: string;
      Group: string;
      EndPoint: string;
      IsLongRange: boolean;
      Result: string;
    }>;

    // Group by category
    const byCategory = new Map<string, typeof allTests>();
    for (const tc of allTests) {
      const category = tc.Category || "Uncategorized";
      if (!byCategory.has(category)) {
        byCategory.set(category, []);
      }
      byCategory.get(category)!.push(tc);
    }

    console.log(
      `\nFound ${allTests.length} test cases in ${byCategory.size} categories:\n`
    );

    for (const [category, tests] of byCategory) {
      console.log(c.bold(`[${category}]`) + c.dim(` (${tests.length} tests)`));
      for (const tc of tests) {
        const mode = tc.IsLongRange ? c.cyan("LR") : c.dim("Classic");
        const group =
          tc.Group === "Automatic" ? c.green(tc.Group) : c.yellow(tc.Group);
        console.log(
          `  ${tc.Name} ${c.dim(`EP${tc.EndPoint}`)} ${mode} ${group}`
        );
      }
      console.log();
    }
  }

  startWebSocketServer(): void {
    this.wsServer = createWebSocketServer({
      port: 4712,
      runnerHost: this.runnerHost,
      onFatalError: () => this.cleanup(),
      onProjectLoaded: async () => {
        console.log("\n✓ Project loaded successfully!");
        await setTimeout(1000);

        try {
          if (DISCOVER_MODE) {
            await this.listTestCases();
          } else if (CATEGORIES.length > 0 || GROUPS.length > 0) {
            await this.runTestsByFilter(CATEGORIES, GROUPS);
          } else if (TEST_NAMES.length > 0) {
            await this.runTests(TEST_NAMES);
          } else {
            // Default: show usage
            console.log("\nUsage:");
            console.log(
              "  npm start -- --discover                List all test cases by category"
            );
            console.log(
              "  npm start -- --test=<name>             Run a specific test by name"
            );
            console.log(
              "  npm start -- --test=<n1>,<n2>          Run multiple tests (comma-separated)"
            );
            console.log(
              "  npm start -- --category=<cat>          Run all tests in a category"
            );
            console.log(
              "  npm start -- --category=<c1>,<c2>      Run tests from multiple categories"
            );
            console.log(
              "  npm start -- --group=<grp>             Run tests in a group (Automatic, Interactive)"
            );
            console.log(
              "  npm start -- --group=<g1>,<g2>         Run tests from multiple groups"
            );
            console.log(
              "  npm start -- --exclude=<name>          Exclude tests matching name"
            );
            console.log(
              "  npm start -- --devices-only            Only start emulated devices"
            );
            console.log(
              "  npm start -- --verbose                 Show CTT log output"
            );
          }
        } catch (error) {
          console.error("Operation failed:", error);
        }

        // Shutdown
        // Wait before first attempt to let CTT finish processing
        await setTimeout(3000);
        console.log("\nShutting down...");
        try {
          await closeCTT();
        } catch (error) {
          console.warn("Failed to close CTT gracefully:", error);
        }
        await this.cleanup();
      },
    });
  }

  killProcess(managedProcess: ManagedProcess): void {
    const { pid, process: proc } = managedProcess;

    if (pid && process.platform === "win32") {
      // On Windows, use taskkill to kill the process tree
      try {
        spawn("taskkill", ["/pid", pid.toString(), "/T", "/F"], {
          stdio: "ignore",
        });
      } catch (error) {
        console.error(`Error killing ${managedProcess.name}:`, error);
      }
    } else if (proc && !proc.killed) {
      proc.kill();
    }
  }

  async cleanup(): Promise<void> {
    if (this.isCleaningUp) return;
    this.isCleaningUp = true;

    console.log("Shutting down...");

    // Cancel any running test and close CTT gracefully first (skip in devices-only mode)
    if (!DEVICES_ONLY) {
      try {
        await cancelTestRun();
        // Wait for test to actually stop before trying to close
        await setTimeout(2000);
      } catch {
        // Ignore - test may not be running
      }
      try {
        await closeCTT();
      } catch {
        // Ignore - CTT may already be closed
      }
    }

    // Close WebSocket server to stop incoming CTT messages
    if (this.wsServer) {
      await this.wsServer.close();
    }

    // Stop DUT runner
    await this.stopRunner();

    // Close device proxy
    if (this.deviceProxy) {
      await this.deviceProxy.close();
    }

    // Kill all managed processes
    for (const managedProcess of this.processes) {
      this.killProcess(managedProcess);
    }

    // Also kill any Z-Wave processes in WSL to be thorough
    try {
      spawn("wsl", ["pkill", "-f", "ZW_zwave"], { stdio: "ignore" });
    } catch (error) {
      // Ignore
    }

    // Clean up PID file on successful shutdown
    this.deletePidFile();

    process.exit(0);
  }

  setupExitHandlers(): void {
    // Handle various exit signals
    process.on("SIGINT", () => this.cleanup()); // Ctrl+C
    process.on("SIGTERM", () => this.cleanup()); // Termination signal

    process.on("exit", () => {
      // Synchronous kill on exit
      for (const managedProcess of this.processes) {
        const { pid } = managedProcess;
        if (pid && process.platform === "win32") {
          try {
            require("child_process").execSync(`taskkill /pid ${pid} /T /F`, {
              stdio: "ignore",
            });
          } catch (error) {
            // Ignore errors on exit
          }
        }
      }
    });

    // Handle uncaught errors
    process.on("uncaughtException", (error) => {
      console.error("Uncaught exception:", error);
      this.cleanup();
    });

    process.on("unhandledRejection", (reason, promise) => {
      console.error("Unhandled rejection at:", promise, "reason:", reason);
      this.cleanup();
    });
  }
}

// Main execution
async function main() {
  const manager = new ProcessManager();
  manager.setupExitHandlers();

  try {
    // Kill any orphaned processes from a previous run
    await manager.killOrphanedProcesses();

    // Start Z-Wave stack in WSL
    console.log("Starting Z-Wave stack in WSL...");
    manager.startZWaveStackWSL();

    // Give Z-Wave devices a moment to fully initialize
    await setTimeout(2000);

    // Start CTT device proxy (intercepts CTT <-> device communication)
    await manager.startCTTDeviceProxy();

    if (DEVICES_ONLY) {
      console.log("\n--devices-only mode: Only emulated devices are running.");
      console.log("Z-Wave devices available at:");
      console.log("  Controller 1: localhost:5000 (direct)");
      console.log("  Controller 2: localhost:5001 (proxied from 6001)");
      console.log("  Controller 3: localhost:5002 (proxied from 6002)");
      console.log("  End Device 1: localhost:5003 (proxied from 6003)");
      console.log("  End Device 2: localhost:5004 (proxied from 6004)");
      console.log("  Zniffer:      localhost:4905 (direct)");
      console.log("\nPress Ctrl+C to stop.");
      return;
    }

    // Start DUT runner (via IPC)
    await manager.startRunner();

    // Start WebSocket server for CTT communication
    // The runner handles CTT prompts via IPC
    manager.startWebSocketServer();

    // Start CTT-Remote
    manager.startCTTRemote(VERBOSE);

    console.log("\nAll services started successfully!");
    console.log("Z-Wave devices available at:");
    console.log(`  Controller 1 (${config.dut.name}): localhost:5000 (direct)`);
    console.log(
      "  Controller 2 (CTT):       localhost:5001 (proxied from 6001)"
    );
    console.log(
      "  Controller 3 (CTT):       localhost:5002 (proxied from 6002)"
    );
    console.log(
      "  End Device 1 (CTT):       localhost:5003 (proxied from 6003)"
    );
    console.log(
      "  End Device 2 (CTT):       localhost:5004 (proxied from 6004)"
    );
    console.log("  Zniffer (CTT):            localhost:4905 (direct)");
    console.log(`  ${config.dut.name} Server:         ws://localhost:3000`);
  } catch (error) {
    console.error("Failed to start services:", error);
    await manager.cleanup();
  }
}

main();
