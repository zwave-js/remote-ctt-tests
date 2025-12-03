/**
 * Z-Wave JS Runner
 *
 * This is a standalone process that implements the IPC protocol to communicate
 * with the orchestrator. It manages the Z-Wave JS driver and server.
 *
 * Usage: Spawned by RunnerHost, connects via WebSocket IPC
 */

import WebSocket from "ws";
import * as path from "path";
import * as fs from "fs";
import { fileURLToPath } from "url";
import { Driver } from "zwave-js";
import { ZwavejsServer } from "@zwave-js/server";
import type {
  StartParams,
  CttPromptParams,
  IpcRequest,
  SuccessResponse,
  ErrorResponse,
  ReadyNotification,
} from "../src/runner-ipc.ts";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// === Constants ===

const RUNNER_NAME = "Z-Wave JS";
const IPC_PORT = parseInt(process.env.RUNNER_IPC_PORT || "4713", 10);
const IPC_URL = `ws://127.0.0.1:${IPC_PORT}`;

// Directories relative to this file's location
const STORAGE_DIR = path.join(__dirname, "storage");
const LOG_DIR = path.join(__dirname, "log");
const SERVER_PORT = 3000;

// === State ===

let driver: Driver | undefined;
let server: ZwavejsServer | undefined;
let ws: WebSocket | undefined;

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

// === Request Handlers ===

async function handleStart(id: number, params: StartParams): Promise<void> {
  console.log("Starting Z-Wave JS driver and server...");

  try {
    // Ensure directories exist
    fs.mkdirSync(STORAGE_DIR, { recursive: true });
    fs.mkdirSync(LOG_DIR, { recursive: true });

    // Parse security keys from hex strings to Buffers
    const securityKeys = {
      S2_Unauthenticated: Buffer.from(params.securityKeys.S2_Unauthenticated, "hex"),
      S2_Authenticated: Buffer.from(params.securityKeys.S2_Authenticated, "hex"),
      S2_AccessControl: Buffer.from(params.securityKeys.S2_AccessControl, "hex"),
      S0_Legacy: Buffer.from(params.securityKeys.S0_Legacy, "hex"),
    };

    const securityKeysLongRange = {
      S2_Authenticated: Buffer.from(params.securityKeysLongRange.S2_Authenticated, "hex"),
      S2_AccessControl: Buffer.from(params.securityKeysLongRange.S2_AccessControl, "hex"),
    };

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

    await server.start();
    console.log(`Z-Wave JS server listening on port ${SERVER_PORT}`);

    sendResponse(id, "ok");
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error("Failed to start Z-Wave JS:", message);
    sendError(id, -32000, message);
  }
}

async function handleStop(id: number): Promise<void> {
  console.log("Stopping Z-Wave JS driver and server...");

  try {
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

async function handleCttPrompt(id: number, params: CttPromptParams): Promise<void> {
  console.log(`CTT Prompt [${params.type}]: ${params.rawText}`);
  console.log(`  Buttons: ${params.buttons.join(", ")}`);

  // Default response logic based on prompt type
  let response: string;

  switch (params.type) {
    case "YesNo":
      // Default to "Yes" for most prompts
      response = "Yes";
      break;

    case "OkCancel":
      response = "Ok";
      break;

    case "Ok":
      response = "Ok";
      break;

    case "WaitForDutResponse":
      // This typically means CTT is waiting for the DUT to do something
      // The Z-Wave JS driver should handle this automatically
      response = "Ok";
      break;

    case "Skip":
      response = "Skip";
      break;

    default:
      // Default to first available button
      response = params.buttons[0] || "Ok";
      break;
  }

  console.log(`  Response: ${response}`);
  sendResponse(id, response);
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

    case "handleCttPrompt":
      await handleCttPrompt(request.id, request.params);
      break;

    default:
      console.warn("Unknown IPC method:", (request as { method: string }).method);
      sendError(request.id, -32601, "Method not found");
  }
}

// === Main ===

async function main(): Promise<void> {
  console.log(`Z-Wave JS Runner starting...`);
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

  // Handle shutdown signals
  process.on("SIGINT", async () => {
    console.log("Received SIGINT, shutting down...");
    if (server) await server.destroy().catch(() => {});
    if (driver) await driver.destroy().catch(() => {});
    ws?.close();
    process.exit(0);
  });

  process.on("SIGTERM", async () => {
    console.log("Received SIGTERM, shutting down...");
    if (server) await server.destroy().catch(() => {});
    if (driver) await driver.destroy().catch(() => {});
    ws?.close();
    process.exit(0);
  });
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
