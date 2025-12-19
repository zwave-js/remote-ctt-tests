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
  type CttLogParams,
  type TestCaseStartedParams,
  type IpcRequest,
  isSuccessResponse,
  isErrorResponse,
  isReadyNotification,
  isNoHandlerNotification,
  DEFAULT_IPC_PORT,
  IPC_PORT_ENV_VAR,
} from "./runner-ipc.ts";
import { parseLog, parsePrompt } from "./ctt-parser.ts";
import type { OrchestratorState } from "./ctt-message-types.ts";
import { cancelTestRun } from "./ctt-client.ts";
import c from "ansi-colors";
import * as readline from "readline";

export interface RunnerHostOptions {
  /** Path to the runner script */
  runnerPath: string;
  /** Port for the IPC WebSocket server (default: 4713) */
  ipcPort?: number;
  /** Timeout for runner to connect and send ready (ms, default: 30000) */
  readyTimeout?: number;
  /** Callback when runner process exits unexpectedly */
  onUnexpectedExit?: () => void;
  /** CI mode - cancel test run on unhandled prompts (default: auto-detect via CI env var) */
  ciMode?: boolean;
}

export class RunnerHost {
  private runnerPath: string;
  private ipcPort: number;
  private readyTimeout: number;
  private onUnexpectedExit?: () => void;
  private ciMode: boolean;

  private wss?: WebSocketServer;
  private runnerProcess?: ChildProcess;
  private runnerSocket?: WebSocket;
  private runnerName: string = "Unknown Runner";

  // Test context for parsing (reset per test)
  private testContext: OrchestratorState = {};

  private messageId = 0;
  private pendingRequests = new Map<
    number,
    {
      resolve: (result: string) => void;
      reject: (error: Error) => void;
    }
  >();

  // Readline interface for user input prompts
  private rl?: readline.Interface;
  private activePrompt?: {
    resolve: (result: { source: "user" | "auto"; value: string }) => void;
    ipcRequestId: number;
  };

  constructor(options: RunnerHostOptions) {
    this.runnerPath = path.resolve(options.runnerPath);
    this.ipcPort = options.ipcPort ?? DEFAULT_IPC_PORT;
    this.readyTimeout = options.readyTimeout ?? 30000;
    this.onUnexpectedExit = options.onUnexpectedExit;
    this.ciMode = options.ciMode ?? !!process.env.CI;

    // Create readline interface for user prompts
    this.rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
    });

    // Start with input paused - only resume when waiting for prompt
    process.stdin.pause();

    // Persistent listener - dispatches to active prompt if any
    this.rl.on("line", (input) => {
      if (this.activePrompt) {
        // Pause input immediately to prevent double-firing
        process.stdin.pause();
        this.activePrompt.resolve({ source: "user", value: input.trim() });
        this.activePrompt = undefined;
      }
      // If no active prompt, input is ignored
    });
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
    const response = await this.sendRequest("start", params as unknown as Record<string, unknown>);
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
   * Handle a CTT log message by parsing and forwarding to the runner
   */
  async handleCttLog(logText: string, testName: string): Promise<void> {
    // Normalize whitespace: CTT sometimes formats with line breaks and multiple spaces
    const normalizedText = logText.replace(/\s+/g, " ").trim();

    // Parse the log to extract structured message or state updates
    const result = parseLog(normalizedText, this.testContext);

    if (result.action === "modify_context") {
      // Modify test context (e.g., forceS0 flag)
      this.testContext = { ...this.testContext, ...result.stateUpdate };
      // No message to send to DUT
    } else if (result.action === "send_to_dut") {
      // Send structured message to runner
      const params: CttLogParams = { testName, message: result.message };
      await this.sendRequest("handleCttLog", params as unknown as Record<string, unknown>);
    }
    // action === "none" - nothing to send to runner
  }

  /**
   * Notify the runner that a test case has started
   */
  async testCaseStarted(testName: string): Promise<void> {
    const params: TestCaseStartedParams = { testName };
    await this.sendRequest("testCaseStarted", params as unknown as Record<string, unknown>);
    // Reset orchestrator state for new test
    this.testContext = {};
  }

  /**
   * Unified prompt handling - waits for either user input or runner response
   * Whichever resolves first wins.
   */
  async promptForResponse(
    userPromptText: string,
    rawText: string,
    testName: string
  ): Promise<{ source: "user" | "auto"; value: string }> {
    // Normalize whitespace: CTT sometimes formats with line breaks and multiple spaces
    const normalizedText = rawText.replace(/\s+/g, " ").trim();

    // Parse the prompt to check for auto-answers or structured messages
    const parseResult = parsePrompt(normalizedText, this.testContext);

    // Handle orchestrator auto-answers (no DUT involvement)
    if (parseResult.action === "auto_answer") {
      return { source: "auto", value: parseResult.answer };
    }

    // Handle send_to_dut with optional auto-answer
    if (parseResult.action === "send_to_dut" && parseResult.answer) {
      // Send message to DUT (fire-and-forget, no response expected)
      if (this.runnerSocket?.readyState === WebSocket.OPEN) {
        const params: CttLogParams = { testName, message: parseResult.message };
        this.runnerSocket.send(
          JSON.stringify({
            jsonrpc: "2.0",
            method: "handleCttLog", // Use log handler since no response needed
            params,
          })
        );
      }
      return { source: "auto", value: parseResult.answer };
    }

    // Create deferred promise for response
    let resolve: (result: { source: "user" | "auto"; value: string }) => void;
    const promise = new Promise<{ source: "user" | "auto"; value: string }>((res) => {
      resolve = res;
    });

    // Show prompt to user and resume stdin for input
    process.stdout.write(userPromptText);
    process.stdin.resume();

    // Only send to runner if we have a structured message
    if (parseResult.action === "send_to_dut" && this.runnerSocket?.readyState === WebSocket.OPEN) {
      const ipcRequestId = ++this.messageId;
      this.activePrompt = { resolve: resolve!, ipcRequestId };

      const params: CttPromptParams = { testName, message: parseResult.message };
      this.runnerSocket.send(
        JSON.stringify({
          jsonrpc: "2.0",
          id: ipcRequestId,
          method: "handleCttPrompt",
          params,
        })
      );
    } else {
      // No message to send - only user can respond
      this.activePrompt = { resolve: resolve!, ipcRequestId: -1 };
    }

    // Wait for either user input or runner response
    const result = await promise;
    this.activePrompt = undefined;

    // Clear consumed state after successful response
    if (parseResult.action === "send_to_dut") {
      const msg = parseResult.message;
      if (this.testContext.forceS0 && msg.type === "ACTIVATE_NETWORK_MODE" && msg.mode === "ADD") {
        this.testContext = { ...this.testContext, forceS0: undefined };
      }
      if (this.testContext.recommendationContext && msg.type === "SHOULD_DISREGARD_RECOMMENDATION") {
        this.testContext = { ...this.testContext, recommendationContext: undefined };
      }
    }

    return result;
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

    // Close readline interface
    if (this.rl) {
      this.activePrompt = undefined;
      this.rl.close();
      this.rl = undefined;
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
      stdio: ["ignore", "inherit", "pipe"],
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
        console.error(`Runner exited with code ${code}`);
      } else if (signal) {
        console.log(c.dim(`Runner killed by signal ${signal}`));
      }
      if (this.onUnexpectedExit) {
        this.onUnexpectedExit();
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

    // Check for no-handler notification (no prompt handler matched)
    if (isNoHandlerNotification(msg)) {
      this.handleNoHandler();
      return;
    }

    // Check for response to a pending request
    if (isSuccessResponse(msg)) {
      // Check if this is a response to the active prompt
      if (this.activePrompt?.ipcRequestId === msg.id) {
        // Pause stdin to prevent buffered input from affecting next prompt
        process.stdin.pause();
        this.activePrompt.resolve({ source: "auto", value: msg.result });
        this.activePrompt = undefined;
        return;
      }

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

  private async handleNoHandler(): Promise<void> {
    if (this.ciMode) {
      console.error("\n[CI] Unhandled prompt - cancelling test run to prevent hang\n");

      try {
        await cancelTestRun();
      } catch (error) {
        console.error("Failed to cancel test run:", error);
      }
    }
    // In non-CI mode, do nothing - let user input work
  }
}
