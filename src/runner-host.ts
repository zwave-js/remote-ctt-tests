/**
 * RunnerHost - Spawns and manages communication with runner processes
 *
 * This class handles:
 * 1. Starting a WebSocket IPC server
 * 2. Spawning the runner process as a subprocess
 * 3. Waiting for the runner to connect and send "ready"
 * 4. Sending requests and receiving responses via JSON-RPC
 */

import { spawn, ChildProcess } from "child_process";
import * as path from "path";
import { WebSocketServer, WebSocket } from "ws";
import {
  type StartParams,
  type CttPromptParams,
  type TestCaseStartedParams,
  type IpcRequest,
  type IpcResponse,
  type ReadyNotification,
  isSuccessResponse,
  isErrorResponse,
  isReadyNotification,
  DEFAULT_IPC_PORT,
  IPC_PORT_ENV_VAR,
} from "./runner-ipc.ts";
import c from "ansi-colors";

export interface RunnerHostOptions {
  /** Path to the runner script */
  runnerPath: string;
  /** Port for the IPC WebSocket server (default: 4713) */
  ipcPort?: number;
  /** Timeout for runner to connect and send ready (ms, default: 30000) */
  readyTimeout?: number;
}

export class RunnerHost {
  private runnerPath: string;
  private ipcPort: number;
  private readyTimeout: number;

  private wss?: WebSocketServer;
  private runnerProcess?: ChildProcess;
  private runnerSocket?: WebSocket;
  private runnerName: string = "Unknown Runner";

  private messageId = 0;
  private pendingRequests = new Map<
    number,
    {
      resolve: (result: string) => void;
      reject: (error: Error) => void;
    }
  >();

  constructor(options: RunnerHostOptions) {
    this.runnerPath = path.resolve(options.runnerPath);
    this.ipcPort = options.ipcPort ?? DEFAULT_IPC_PORT;
    this.readyTimeout = options.readyTimeout ?? 30000;
  }

  /**
   * Initialize the runner host:
   * 1. Start WebSocket IPC server
   * 2. Spawn runner process
   * 3. Wait for runner to connect and send "ready"
   */
  async initialize(): Promise<void> {
    // Start IPC server
    await this.startIpcServer();

    // Spawn runner process
    this.spawnRunner();

    // Wait for runner to connect and be ready
    await this.waitForReady();

    console.log(c.green(`✓ Runner "${this.runnerName}" is ready`));
  }

  /**
   * Start the Z-Wave driver/server in the runner
   */
  async start(params: StartParams): Promise<void> {
    const response = await this.sendRequest("start", params);
    if (response !== "ok") {
      throw new Error(`Runner start failed: ${response}`);
    }
  }

  /**
   * Stop the Z-Wave driver/server in the runner
   */
  async stop(): Promise<void> {
    try {
      await this.sendRequest("stop", {});
    } catch (error) {
      console.warn("Failed to stop runner gracefully:", error);
    }
  }

  /**
   * Handle a CTT prompt by forwarding to the runner
   */
  async handleCttPrompt(params: CttPromptParams): Promise<string> {
    return await this.sendRequest("handleCttPrompt", params);
  }

  /**
   * Notify the runner that a test case has started
   */
  async testCaseStarted(testName: string): Promise<void> {
    const params: TestCaseStartedParams = { testName };
    await this.sendRequest("testCaseStarted", params);
  }

  /**
   * Cleanup: stop runner, close connections
   */
  async cleanup(): Promise<void> {
    // Try to stop gracefully first
    if (this.runnerSocket?.readyState === WebSocket.OPEN) {
      try {
        await this.stop();
      } catch {
        // Ignore errors during cleanup
      }
    }

    // Close WebSocket connection
    if (this.runnerSocket) {
      this.runnerSocket.close();
      this.runnerSocket = undefined;
    }

    // Close IPC server
    if (this.wss) {
      this.wss.close();
      this.wss = undefined;
    }

    // Kill runner process
    if (this.runnerProcess && !this.runnerProcess.killed) {
      this.runnerProcess.kill();
      this.runnerProcess = undefined;
    }

    // Reject any pending requests
    for (const [id, { reject }] of this.pendingRequests) {
      reject(new Error("Runner host shutting down"));
      this.pendingRequests.delete(id);
    }
  }

  /**
   * Get the runner's PID for process management
   */
  getRunnerPid(): number | undefined {
    return this.runnerProcess?.pid;
  }

  // === Private Methods ===

  private async startIpcServer(): Promise<void> {
    return new Promise((resolve, reject) => {
      this.wss = new WebSocketServer({ port: this.ipcPort });

      this.wss.on("listening", () => {
        console.log(c.dim(`IPC server listening on port ${this.ipcPort}`));
        resolve();
      });

      this.wss.on("error", (error) => {
        reject(new Error(`Failed to start IPC server: ${error.message}`));
      });

      this.wss.on("connection", (ws) => {
        if (this.runnerSocket) {
          console.warn("Multiple runners trying to connect, rejecting");
          ws.close();
          return;
        }

        console.log(c.dim("Runner connected to IPC server"));
        this.runnerSocket = ws;

        ws.on("message", (data) => {
          this.handleMessage(data.toString());
        });

        ws.on("close", () => {
          console.log(c.dim("Runner disconnected from IPC server"));
          this.runnerSocket = undefined;
        });

        ws.on("error", (error) => {
          console.error("Runner WebSocket error:", error);
        });
      });
    });
  }

  private spawnRunner(): void {
    const ext = path.extname(this.runnerPath).toLowerCase();
    let command: string;
    let args: string[];

    switch (ext) {
      case ".ts":
        command = "node";
        args = ["--experimental-transform-types", this.runnerPath];
        break;
      case ".js":
      case ".mjs":
        command = "node";
        args = [this.runnerPath];
        break;
      case ".py":
        command = "python";
        args = [this.runnerPath];
        break;
      default:
        // Try to run directly (relies on shebang)
        command = this.runnerPath;
        args = [];
    }

    console.log(c.dim(`Spawning runner: ${command} ${args.join(" ")}`));

    this.runnerProcess = spawn(command, args, {
      env: {
        ...process.env,
        [IPC_PORT_ENV_VAR]: this.ipcPort.toString(),
      },
      stdio: ["inherit", "inherit", "pipe"],
    });

    this.runnerProcess.stderr?.on("data", (data) => {
      const lines = data.toString().trim().split("\n");
      for (const line of lines) {
        console.error(c.red(`[Runner] ${line}`));
      }
    });

    this.runnerProcess.on("error", (error) => {
      console.error(c.red(`Failed to spawn runner: ${error.message}`));
    });

    this.runnerProcess.on("exit", (code, signal) => {
      if (code !== null) {
        console.log(c.dim(`Runner exited with code ${code}`));
      } else if (signal) {
        console.log(c.dim(`Runner killed by signal ${signal}`));
      }
    });
  }

  private waitForReady(): Promise<void> {
    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        reject(
          new Error(
            `Runner did not send ready notification within ${this.readyTimeout}ms`
          )
        );
      }, this.readyTimeout);

      const checkReady = () => {
        if (this.runnerName !== "Unknown Runner") {
          clearTimeout(timeout);
          resolve();
        }
      };

      // Store the callback so handleMessage can trigger it
      (this as { onReadyCallback?: () => void }).onReadyCallback = () => {
        clearTimeout(timeout);
        resolve();
      };
    });
  }

  private handleMessage(data: string): void {
    let msg: unknown;
    try {
      msg = JSON.parse(data);
    } catch {
      console.error("Failed to parse IPC message:", data);
      return;
    }

    // Check for ready notification
    if (isReadyNotification(msg)) {
      this.runnerName = msg.params.name;
      console.log(c.dim(`Runner identified as: ${this.runnerName}`));
      const callback = (this as { onReadyCallback?: () => void })
        .onReadyCallback;
      if (callback) {
        callback();
      }
      return;
    }

    // Check for response to a pending request
    if (isSuccessResponse(msg)) {
      const pending = this.pendingRequests.get(msg.id);
      if (pending) {
        pending.resolve(msg.result);
        this.pendingRequests.delete(msg.id);
      }
      return;
    }

    if (isErrorResponse(msg)) {
      const pending = this.pendingRequests.get(msg.id);
      if (pending) {
        pending.reject(new Error(msg.error.message));
        this.pendingRequests.delete(msg.id);
      }
      return;
    }

    console.warn("Unknown IPC message:", msg);
  }

  private sendRequest(
    method: IpcRequest["method"],
    params: Record<string, unknown>
  ): Promise<string> {
    return new Promise((resolve, reject) => {
      if (!this.runnerSocket || this.runnerSocket.readyState !== WebSocket.OPEN) {
        reject(new Error("Runner not connected"));
        return;
      }

      const id = ++this.messageId;
      const request: IpcRequest = {
        jsonrpc: "2.0",
        id,
        method,
        params,
      } as IpcRequest;

      this.pendingRequests.set(id, { resolve, reject });

      this.runnerSocket.send(JSON.stringify(request), (error) => {
        if (error) {
          this.pendingRequests.delete(id);
          reject(error);
        }
      });
    });
  }
}
