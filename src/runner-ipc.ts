/**
 * IPC Message Types for Runner Communication
 *
 * All runners (regardless of language) communicate with the orchestrator
 * via WebSocket using these JSON-RPC message formats.
 */

import type { DUTMessage } from "./ctt-message-types.ts";

// === Base JSON-RPC Types ===

interface JsonRpcMessage {
  jsonrpc: "2.0";
}

interface JsonRpcMethodMessage extends JsonRpcMessage {
  method: string;
}

// === Security Key Types ===

export interface SecurityKeys {
  S2_Unauthenticated: string; // hex string
  S2_Authenticated: string;
  S2_AccessControl: string;
  S0_Legacy: string;
}

export interface SecurityKeysLongRange {
  S2_Authenticated: string;
  S2_AccessControl: string;
}

// === Start Request Parameters ===

export interface StartParams {
  controllerUrl: string; // e.g., "tcp://127.0.0.1:5000"
  securityKeys: SecurityKeys;
  securityKeysLongRange: SecurityKeysLongRange;
}

// === CTT Prompt Parameters ===

export interface CttPromptParams {
  testName: string;
  message: DUTMessage;
}

// === CTT Log Parameters ===

export interface CttLogParams {
  testName: string;
  message: DUTMessage;
}

// === Test Case Started Parameters ===

export interface TestCaseStartedParams {
  testName: string;
}

// === Request Messages (Orchestrator -> Runner) ===

export interface StartRequest extends JsonRpcMethodMessage {
  id: number;
  method: "start";
  params: StartParams;
}

export interface StopRequest extends JsonRpcMethodMessage {
  id: number;
  method: "stop";
  params: Record<string, never>;
}

export interface HandleCttPromptRequest extends JsonRpcMethodMessage {
  id: number;
  method: "handleCttPrompt";
  params: CttPromptParams;
}

export interface TestCaseStartedRequest extends JsonRpcMethodMessage {
  id: number;
  method: "testCaseStarted";
  params: TestCaseStartedParams;
}

export interface HandleCttLogRequest extends JsonRpcMethodMessage {
  id: number;
  method: "handleCttLog";
  params: CttLogParams;
}

export type IpcRequest = StartRequest | StopRequest | HandleCttPromptRequest | TestCaseStartedRequest | HandleCttLogRequest;

// === Response Messages (Runner -> Orchestrator) ===

export interface SuccessResponse extends JsonRpcMessage {
  id: number;
  result: string; // "ok" for start/stop, button name for handleCttPrompt
}

export interface ErrorResponse extends JsonRpcMessage {
  id: number;
  error: {
    code: number;
    message: string;
  };
}

export type IpcResponse = SuccessResponse | ErrorResponse;

// === Notification Messages (Runner -> Orchestrator) ===

export interface ReadyNotification extends JsonRpcMethodMessage {
  method: "ready";
  params: {
    name: string; // Runner name for logging
  };
}

export interface NoHandlerNotification extends JsonRpcMethodMessage {
  method: "noHandler";
}

export type IpcNotification = ReadyNotification | NoHandlerNotification;

// === Type Guards ===

function isJsonRpcMessage(msg: unknown): msg is JsonRpcMessage {
  return (
    typeof msg === "object" &&
    msg !== null &&
    "jsonrpc" in msg &&
    msg.jsonrpc === "2.0"
  );
}

function isJsonRpcMethodMessage(msg: unknown): msg is JsonRpcMethodMessage {
  return isJsonRpcMessage(msg) && "method" in msg;
}

export function isSuccessResponse(msg: unknown): msg is SuccessResponse {
  return isJsonRpcMessage(msg) && "id" in msg && "result" in msg;
}

export function isErrorResponse(msg: unknown): msg is ErrorResponse {
  return isJsonRpcMessage(msg) && "id" in msg && "error" in msg;
}

export function isReadyNotification(msg: unknown): msg is ReadyNotification {
  return isJsonRpcMethodMessage(msg) && msg.method === "ready" && "params" in msg;
}

export function isNoHandlerNotification(msg: unknown): msg is NoHandlerNotification {
  return isJsonRpcMethodMessage(msg) && msg.method === "noHandler";
}

// === Constants ===

export const DEFAULT_IPC_PORT = 4713;
export const IPC_PORT_ENV_VAR = "RUNNER_IPC_PORT";
