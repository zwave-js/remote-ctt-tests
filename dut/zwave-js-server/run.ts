/**
 * Z-Wave JS Server Runner
 *
 * This is a standalone process that implements the IPC protocol to communicate
 * with the orchestrator. It manages the Z-Wave JS driver and server, and
 * communicates with the server via WebSocket (through ZWaveClient).
 *
 * Usage: Spawned by RunnerHost, connects via WebSocket IPC
 */

import WebSocket from "ws";
import * as path from "path";
import * as fs from "fs";
import { fileURLToPath } from "url";
import { Driver } from "zwave-js";
import type { ZWaveNodeValueNotificationArgs } from "zwave-js";
import { CommandClasses } from "@zwave-js/core";
import { ZwavejsServer } from "@zwave-js/server";
import type {
  StartParams,
  CttPromptParams,
  CttLogParams,
  TestCaseStartedParams,
  IpcRequest,
  SuccessResponse,
  ErrorResponse,
  ReadyNotification,
  NoHandlerNotification,
} from "../../src/runner-ipc.ts";
import {
  getHandlersForTest,
  type PromptContext,
  type LogContext,
} from "./prompt-handlers.ts";
import { ZWaveClient, NodeProxy } from "./zwave-client.ts";
import type { NodeNotificationArgs } from "./prompt-handlers.ts";

// Load all registered handlers
import "./handlers/index.ts";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// === Constants ===

const RUNNER_NAME = "Z-Wave JS Server";
const IPC_PORT = parseInt(process.env.RUNNER_IPC_PORT || "4713", 10);
const IPC_URL = `ws://127.0.0.1:${IPC_PORT}`;

// Directories relative to this file's location
const STORAGE_DIR = path.join(__dirname, "storage");
const LOG_DIR = path.join(__dirname, "log");
const SERVER_PORT = 3333;
const CLIENT_URL = `ws://127.0.0.1:${SERVER_PORT}`;

// === State ===

let driver: Driver | undefined;
let server: ZwavejsServer | undefined;
let client: ZWaveClient | undefined;
let ws: WebSocket | undefined;

// Test case state for prompt handlers
let testContext: Map<string, unknown> = new Map();
let includedNodes: NodeProxy[] = [];
let nodeNotifications: {
  nodeId: number;
  endpointIndex: number;
  ccId: CommandClasses;
  args: NodeNotificationArgs;
}[] = [];
let valueNotifications: {
  node: NodeProxy;
  args: ZWaveNodeValueNotificationArgs;
}[] = [];

// === Debug Helpers ===

function formatValueId(args: {
  commandClass: number;
  endpoint?: number;
  property: string | number;
  propertyKey?: string | number;
}): string {
  const ccName = CommandClasses[args.commandClass] ?? "Unknown";
  let result = `CC=${ccName} (0x${args.commandClass.toString(16)}), EP=${
    args.endpoint ?? 0
  }, property=${args.property}`;
  if (args.propertyKey !== undefined) {
    result += `, propertyKey=${args.propertyKey}`;
  }
  return result;
}

// === IPC Communication ===

function sendResponse(id: number, result: string): void {
  const response: SuccessResponse = {
    jsonrpc: "2.0",
    id,
    result,
  };
  ws?.send(JSON.stringify(response));
}

function sendError(id: number, code: number, message: string): void {
  const response: ErrorResponse = {
    jsonrpc: "2.0",
    id,
    error: { code, message },
  };
  ws?.send(JSON.stringify(response));
}

function sendReady(): void {
  const notification: ReadyNotification = {
    jsonrpc: "2.0",
    method: "ready",
    params: { name: RUNNER_NAME },
  };
  ws?.send(JSON.stringify(notification));
}

function sendNoHandlerNotification(): void {
  const notification: NoHandlerNotification = {
    jsonrpc: "2.0",
    method: "noHandler",
  };
  ws?.send(JSON.stringify(notification));
}

// === Request Handlers ===

async function handleStart(id: number, params: StartParams): Promise<void> {
  console.log("Starting Z-Wave JS driver, server, and client...");

  try {
    // Ensure directories exist
    fs.mkdirSync(STORAGE_DIR, { recursive: true });
    fs.mkdirSync(LOG_DIR, { recursive: true });

    // Parse security keys from hex strings to Buffers
    const securityKeys = {
      S2_Unauthenticated: Buffer.from(
        params.securityKeys.S2_Unauthenticated,
        "hex"
      ),
      S2_Authenticated: Buffer.from(
        params.securityKeys.S2_Authenticated,
        "hex"
      ),
      S2_AccessControl: Buffer.from(
        params.securityKeys.S2_AccessControl,
        "hex"
      ),
      S0_Legacy: Buffer.from(params.securityKeys.S0_Legacy, "hex"),
    };

    const securityKeysLongRange = {
      S2_Authenticated: Buffer.from(
        params.securityKeysLongRange.S2_Authenticated,
        "hex"
      ),
      S2_AccessControl: Buffer.from(
        params.securityKeysLongRange.S2_AccessControl,
        "hex"
      ),
    };

    process.env.NODE_ENV = "development";

    // Create driver
    driver = new Driver(params.controllerUrl, {
      storage: {
        cacheDir: STORAGE_DIR,
      },
      logConfig: {
        logToFile: true,
        level: "debug",
        filename: path.join(LOG_DIR, "zwave-js.log"),
      },
      securityKeys,
      securityKeysLongRange,
    });

    // Wait for driver to be ready
    await new Promise<void>((resolve, reject) => {
      driver!.once("driver ready", () => {
        console.log("Z-Wave JS driver is ready");
        resolve();
      });

      driver!.once("error", (error) => {
        console.error("Z-Wave JS driver error:", error);
        reject(error);
      });

      driver!.start().catch(reject);
    });

    // Start WebSocket server
    server = new ZwavejsServer(driver!, {
      port: SERVER_PORT,
    });

    // Pass true to enable inclusion user callbacks (required for S2 events)
    await server.start(true);
    console.log(`Z-Wave JS server listening on port ${SERVER_PORT}`);

    // Connect our WebSocket client to the server
    client = new ZWaveClient({ url: CLIENT_URL });
    await client.connect();
    console.log("Z-Wave client connected to server");

    // Set up event handlers for tracking
    setupClientEventHandlers();

    sendResponse(id, "ok");
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("Failed to start Z-Wave JS:", message);
    sendError(id, -32000, message);
  }
}

function setupClientEventHandlers(): void {
  if (!client) return;

  // Debug logging for value events
  if (process.env.ZWAVE_JS_DEBUG) {
    client.on("node value updated", (node, args) => {
      if (node) {
        console.log(
          `[VALUE UPDATED] Node ${node.id}: ${formatValueId(args)} => ${JSON.stringify(args.newValue)}`
        );
      }
    });

    client.on("node notification", (node, data) => {
      if (node) {
        console.log(
          `[NOTIFICATION] Node ${node.id}, data=${JSON.stringify(data)}`
        );
      }
    });
  }

  // Track node added events
  client.on("node added", (node: NodeProxy) => {
    includedNodes.push(node);
  });

  // Track notification events for test handlers
  client.on("node notification", (node: NodeProxy | undefined, data: Record<string, unknown>) => {
    if (node) {
      nodeNotifications.push({
        nodeId: node.id,
        endpointIndex: (data.endpointIndex as number) ?? 0,
        ccId: data.ccId as CommandClasses,
        args: data.args as NodeNotificationArgs,
      });
    }
  });

  client.on("node value notification", (node: NodeProxy | undefined, args: ZWaveNodeValueNotificationArgs) => {
    if (node) {
      valueNotifications.push({ node, args });
    }
  });
}

async function handleStop(id: number): Promise<void> {
  console.log("Stopping Z-Wave JS driver, server, and client...");

  try {
    if (client) {
      client.disconnect();
      client = undefined;
    }

    if (server) {
      await server.destroy();
      server = undefined;
    }

    if (driver) {
      await driver.destroy();
      driver = undefined;
    }

    console.log("Z-Wave JS stopped successfully");
    sendResponse(id, "ok");
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("Failed to stop Z-Wave JS:", message);
    sendError(id, -32000, message);
  }
}

async function handleTestCaseStarted(
  id: number,
  params: TestCaseStartedParams
): Promise<void> {
  const { testName } = params;

  // Clear previous test context
  testContext = new Map();
  includedNodes = [];
  nodeNotifications = [];
  valueNotifications = [];

  console.log(`Test case started: ${testName}`);

  // Get handlers for this test and call onTestStart hooks
  if (client) {
    const handlers = getHandlersForTest(testName);
    for (const handler of handlers) {
      if (handler.onTestStart) {
        try {
          await handler.onTestStart({
            testName,
            client,
            state: testContext,
            includedNodes,
            nodeNotifications,
            valueNotifications,
          });
        } catch (error) {
          console.error(`[Handler] onTestStart error:`, error);
        }
      }
    }
  }

  sendResponse(id, "ok");
}

async function handleCttPrompt(
  id: number,
  params: CttPromptParams
): Promise<void> {
  const { testName, message } = params;

  // Try registered handlers - only respond if one matches
  if (client && testName) {
    const handlers = getHandlersForTest(testName);
    const context: PromptContext = {
      testName,
      client,
      state: testContext,
      includedNodes,
      nodeNotifications,
      valueNotifications,
      message,
    };

    for (const handler of handlers) {
      if (handler.onPrompt) {
        try {
          const response = await handler.onPrompt(context);
          if (response !== undefined) {
            sendResponse(id, response);
            return;
          }
        } catch (error) {
          console.error(`[Handler] onPrompt error:`, error);
        }
      }
    }
  }

  // No automatic handler - notify orchestrator so it can cancel in CI mode
  sendNoHandlerNotification();
}

async function handleCttLog(id: number | undefined, params: CttLogParams): Promise<void> {
  const { testName, message } = params;

  if (client && testName) {
    const handlers = getHandlersForTest(testName);
    const context: LogContext = {
      testName,
      client,
      state: testContext,
      includedNodes,
      nodeNotifications,
      valueNotifications,
      message,
    };

    for (const handler of handlers) {
      if (handler.onLog) {
        try {
          const stopPropagation = await handler.onLog(context);
          if (stopPropagation === true) {
            break;
          }
        } catch (error) {
          console.error(`[Handler] onLog error:`, error);
        }
      }
    }
  }

  // Only send response if this was a request (has id), not a notification
  if (id !== undefined) {
    sendResponse(id, "ok");
  }
}

// === Message Handler ===

async function handleMessage(data: string): Promise<void> {
  let request: IpcRequest;

  try {
    request = JSON.parse(data) as IpcRequest;
  } catch {
    console.error("Failed to parse IPC message:", data);
    return;
  }

  switch (request.method) {
    case "start":
      await handleStart(request.id, request.params);
      break;

    case "stop":
      await handleStop(request.id);
      break;

    case "testCaseStarted":
      await handleTestCaseStarted(request.id, request.params);
      break;

    case "handleCttPrompt":
      await handleCttPrompt(request.id, request.params);
      break;

    case "handleCttLog":
      await handleCttLog(request.id, request.params);
      break;

    default: {
      const unknownRequest = request as { method: string; id: number };
      console.warn("Unknown IPC method:", unknownRequest.method);
      sendError(unknownRequest.id, -32601, "Method not found");
    }
  }
}

// === Main ===

async function main(): Promise<void> {
  console.log(`Z-Wave JS Server Runner starting...`);
  console.log(`  IPC URL: ${IPC_URL}`);
  console.log(`  Storage: ${STORAGE_DIR}`);
  console.log(`  Logs: ${LOG_DIR}`);

  // Connect to IPC server
  ws = new WebSocket(IPC_URL);

  ws.on("open", () => {
    console.log("Connected to orchestrator IPC server");
    sendReady();
  });

  ws.on("message", (data) => {
    handleMessage(data.toString());
  });

  ws.on("close", () => {
    console.log("Disconnected from orchestrator IPC server");
    process.exit(0);
  });

  ws.on("error", (error) => {
    console.error("IPC connection error:", error);
    process.exit(1);
  });

  async function shutdown(code: number): Promise<never> {
    if (client) client.disconnect();
    if (server) await server.destroy().catch(() => {});
    if (driver) await driver.destroy().catch(() => {});
    ws?.close();
    process.exit(code);
  }

  process.on("SIGINT", () => {
    console.log("Received SIGINT, shutting down...");
    shutdown(0);
  });

  process.on("SIGTERM", () => {
    console.log("Received SIGTERM, shutting down...");
    shutdown(0);
  });

  process.on("uncaughtException", (error) => {
    console.error("Uncaught exception in runner:", error);
    shutdown(1);
  });

  process.on("unhandledRejection", (reason) => {
    console.error("Unhandled rejection in runner:", reason);
    shutdown(1);
  });
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
