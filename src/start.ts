import { spawn, ChildProcess } from "child_process";
import * as path from "path";
import * as fs from "fs";
import * as readline from "readline";
import { fileURLToPath } from "url";
import { createWebSocketServer } from "./ws-server.ts";
import type { ManagedWebSocketServer, PromptHandler } from "./ws-server.ts";
import { runTestCases, closeCTT } from "./ctt-client.ts";
import { Driver } from "zwave-js";
import { ZwavejsServer } from "@zwave-js/server";
import {
  formatPromptForCli,
  parseUserResponse,
  type CttPrompt,
} from "./ctt-output.ts";
import c from "ansi-colors";
import { setTimeout } from "timers/promises";

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

const PORT = process.env.PORT ? parseInt(process.env.PORT, 10) : 4712;
const ZWAVE_JS_SERVER_PORT = 3000;
const IS_CI = !!(process.env.CI || process.env.GITHUB_ACTIONS);

/**
 * Create a CLI prompt handler that asks the user for input
 * This is used for local development; CI should use automated handlers
 */
function createCliPromptHandler(): PromptHandler {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  return async (prompt: CttPrompt): Promise<string> => {
    // Display the prompt content
    console.log();
    console.log(prompt.rawText);
    console.log();

    const question = formatPromptForCli(prompt);

    return new Promise((resolve) => {
      const askQuestion = () => {
        rl.question(c.yellow(question), (answer) => {
          const response = parseUserResponse(answer, prompt);
          if (response) {
            resolve(response);
          } else {
            console.log(c.red("Invalid input. Please try again."));
            askQuestion();
          }
        });
      };
      askQuestion();
    });
  };
}

interface ManagedProcess {
  name: string;
  process: ChildProcess;
  pid?: number;
}

class ProcessManager {
  private processes: ManagedProcess[] = [];
  private wsServer?: ManagedWebSocketServer;
  private zwaveDriver?: Driver;
  private zwaveServer?: ZwavejsServer;

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
    const data: PidFileData = {
      startTime: new Date().toISOString(),
      pids: this.processes
        .filter((p) => p.pid !== undefined)
        .map((p) => ({
          name: p.name,
          pid: p.pid!,
          platform: p.name.includes("WSL") ? "wsl" : "windows",
        })),
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

    // Give processes a moment to die
    await setTimeout(1000);

    // Clean up the old PID file
    this.deletePidFile();
    console.log(c.green("✓ Orphaned processes cleaned up\n"));
  }

  startZWaveStackWSL(): void {
    console.log("Starting Z-Wave stack in WSL...");

    const proc = spawn("wsl", ["bash", "./start-zwave-stack.sh"], {
      cwd: path.join(__dirname, ".."),
      stdio: "pipe",
    });

    proc.stdout?.on("data", (data) => {
      console.log(`[WSL Z-Wave] ${data.toString().trim()}`);
    });

    proc.stderr?.on("data", (data) => {
      console.error(`[WSL Z-Wave] ${data.toString().trim()}`);
    });

    proc.on("error", (error) => {
      console.error("Failed to start Z-Wave stack in WSL:", error);
    });

    proc.on("exit", (code) => {
      console.log(`Z-Wave stack WSL process exited with code ${code}`);
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

  async startZWaveJSServer(): Promise<void> {
    console.log("Starting Z-Wave JS driver and server...");

    const cacheDir = path.join(__dirname, "..", ".zwave-js-cache");
    fs.mkdirSync(cacheDir, { recursive: true });

    // Connect to the simulated controller via TCP
    this.zwaveDriver = new Driver("tcp://127.0.0.1:5000", {
      storage: {
        cacheDir,
      },
      logConfig: {
        // enabled: true,
        // level: "warn",
        logToFile: true,
        level: "debug",
      },
      securityKeys: {
        S2_Unauthenticated: Buffer.from(
          "CE07372267DCB354DB216761B6E9C378",
          "hex"
        ),
        S2_Authenticated: Buffer.from(
          "30B5CCF3F482A92E2F63A5C5E218149A",
          "hex"
        ),
        S2_AccessControl: Buffer.from(
          "21A29A69145E38C1601DFF55E2658521",
          "hex"
        ),
        S0_Legacy: Buffer.from("C6D90542DE4E66BBE66FBFCB84E9FF67", "hex"),
      },
      securityKeysLongRange: {
        S2_Authenticated: Buffer.from(
          "0F4F7E178A4207A0BBEFBF991C66F814",
          "hex"
        ),
        S2_AccessControl: Buffer.from(
          "72D42391F7ECE63BE1B38B25D085ECD4",
          "hex"
        ),
      },
    });

    // Wait for driver to be ready
    await new Promise<void>((resolve, reject) => {
      this.zwaveDriver!.once("driver ready", () => {
        console.log("Z-Wave JS driver is ready");
        resolve();
      });

      this.zwaveDriver!.once("error", (error) => {
        console.error("Z-Wave JS driver error:", error);
        reject(error);
      });

      this.zwaveDriver!.start().catch(reject);
    });

    // Start the Z-Wave JS WebSocket server
    this.zwaveServer = new ZwavejsServer(this.zwaveDriver!, {
      port: ZWAVE_JS_SERVER_PORT,
    });

    await this.zwaveServer.start();
    console.log(`Z-Wave JS server listening on port ${ZWAVE_JS_SERVER_PORT}`);
  }

  async stopZWaveJSServer(): Promise<void> {
    if (this.zwaveServer) {
      console.log("Stopping Z-Wave JS server...");
      await this.zwaveServer.destroy();
    }
    if (this.zwaveDriver) {
      console.log("Stopping Z-Wave JS driver...");
      await this.zwaveDriver.destroy();
    }
  }

  startCTTRemote(verbose: boolean = false): ManagedProcess {
    const cttRemotePath = path.join(
      __dirname,
      "..",
      "CTT-Remote",
      "CTT-Remote.exe"
    );
    const solutionPath = path.join(
      __dirname,
      "..",
      "Project",
      "zwave-js.cttsln"
    );

    console.log(`Starting CTT-Remote: ${cttRemotePath} ${solutionPath}`);

    // On Windows, run directly
    // Hide console output unless verbose mode is enabled
    const cttProcess = spawn(cttRemotePath, [solutionPath], {
      cwd: path.join(__dirname, "..", "CTT-Remote"),
      stdio: verbose ? "inherit" : "ignore",
      windowsHide: true,
    });

    cttProcess.on("error", (error) => {
      console.error("Failed to start CTT-Remote:", error);
    });

    cttProcess.on("exit", (code) => {
      console.log(`CTT-Remote exited with code ${code}`);
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

  startWebSocketServer(promptHandler?: PromptHandler): void {
    this.wsServer = createWebSocketServer({
      port: PORT,
      onFatalError: () => this.cleanup(),
      onProjectLoaded: async () => {
        console.log("\n✓ Project loaded successfully!");

        await setTimeout(1000);

        try {
          const results = await runTestCases({
            testCaseNames: ["AGD_AssociationGroupData_Rev01"],
            endPointIds: [0],
            ZWaveExecutionModes: ["Classic"],
          });

          // Print user-friendly summary
          const passed = results.filter(r => r.result === "PASSED");
          const failed = results.filter(r => r.result !== "PASSED");
          const total = results.length;

          console.log("\n" + "=".repeat(50));
          console.log("Test Results Summary");
          console.log("=".repeat(50));
          console.log(c.green(`✅ Passing tests: ${passed.length}/${total}`));
          if (failed.length > 0) {
            console.log(c.red(`❌ Failing tests: ${failed.length}/${total}`));
            for (const test of failed) {
              console.log(c.red(`   - ${test.name} (${test.result})`));
            }
          }
          console.log("=".repeat(50) + "\n");
        } catch (error) {
          console.error("Failed to run test case:", error);
        }

        // Quit after test cases complete
        console.log("\nTest cases completed. Shutting down...");
        try {
          console.log("Closing CTT...");
          await closeCTT();
          console.log("CTT closed successfully.");
        } catch (error) {
          console.warn("Failed to close CTT gracefully:", error);
        }
        await this.cleanup();
      },
      promptHandler,
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
    console.log("Shutting down...");

    // Stop Z-Wave JS server and driver
    await this.stopZWaveJSServer();

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

    // Close WebSocket server
    if (this.wsServer) {
      await this.wsServer.close();
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
    await setTimeout(2000)

    if (DEVICES_ONLY) {
      console.log("\n--devices-only mode: Only emulated devices are running.");
      console.log("Z-Wave devices available at:");
      console.log("  Controller 1: localhost:5000");
      console.log("  Controller 2: localhost:5001");
      console.log("  Controller 3: localhost:5002");
      console.log("  End Device 1: localhost:5003");
      console.log("  End Device 2: localhost:5004");
      console.log("\nPress Ctrl+C to stop.");
      return;
    }

    // Start Z-Wave JS driver and server (connects to simulated controller on port 5000)
    await manager.startZWaveJSServer();

    // Start WebSocket server for CTT communication
    // Use CLI prompt handler for local development, no handler for CI (auto-skip)
    const promptHandler = IS_CI ? undefined : createCliPromptHandler();
    manager.startWebSocketServer(promptHandler);

    // Start CTT-Remote
    manager.startCTTRemote(VERBOSE);

    console.log("\nAll services started successfully!");
    console.log("Z-Wave devices available at:");
    console.log("  Controller 1 (Z-Wave JS): localhost:5000");
    console.log("  Controller 2 (CTT):       localhost:5001");
    console.log("  Controller 3 (CTT):       localhost:5002");
    console.log("  End Device 1 (CTT):       localhost:5003");
    console.log("  End Device 2 (CTT):       localhost:5004");
    console.log(
      `  Z-Wave JS Server:         ws://localhost:${ZWAVE_JS_SERVER_PORT}`
    );
  } catch (error) {
    console.error("Failed to start services:", error);
    await manager.cleanup();
  }
}

main();
