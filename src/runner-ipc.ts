/**
 * IPC Message Types for Runner Communication
 *
 * All runners (regardless of language) communicate with the orchestrator
 * via WebSocket using these JSON-RPC message formats.
 */

import type { DUTMessage } from "./ctt-message-types.ts";

export type CttExecutionMode = "Classic" | "LR";

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
  executionMode: CttExecutionMode;
  message: DUTMessage;
}

// === CTT Log Parameters ===

export interface CttLogParams {
  testName: string;
  executionMode: CttExecutionMode;
  message: DUTMessage;
}

// === Test Case Started Parameters ===

export interface TestCaseStartedParams {
  testName: string;
  executionMode: CttExecutionMode;
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

export interface NodeAddedNotification extends JsonRpcMethodMessage {
  method: "nodeAdded";
  params: {
    nodeId: number;
  };
}

export interface NodeRemovedNotification extends JsonRpcMethodMessage {
  method: "nodeRemoved";
  params: {
    nodeId: number;
  };
}

export interface ProvisioningEntryAddedNotification extends JsonRpcMethodMessage {
  method: "provisioningEntryAdded";
  params: {
    dsk: string;
  };
}

export interface ProvisioningEntryRemovedNotification
  extends JsonRpcMethodMessage {
  method: "provisioningEntryRemoved";
  params: {
    dsk: string;
  };
}

export type IpcNotification =
  | ReadyNotification
  | NoHandlerNotification
  | NodeAddedNotification
  | NodeRemovedNotification
  | ProvisioningEntryAddedNotification
  | ProvisioningEntryRemovedNotification;

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

export function isNodeAddedNotification(msg: unknown): msg is NodeAddedNotification {
  return (
    isJsonRpcMethodMessage(msg) &&
    msg.method === "nodeAdded" &&
    "params" in msg &&
    typeof msg.params === "object" &&
    msg.params !== null &&
    "nodeId" in msg.params &&
    typeof msg.params.nodeId === "number"
  );
}

export function isNodeRemovedNotification(
  msg: unknown
): msg is NodeRemovedNotification {
  return (
    isJsonRpcMethodMessage(msg) &&
    msg.method === "nodeRemoved" &&
    "params" in msg &&
    typeof msg.params === "object" &&
    msg.params !== null &&
    "nodeId" in msg.params &&
    typeof msg.params.nodeId === "number"
  );
}

export function isProvisioningEntryAddedNotification(
  msg: unknown
): msg is ProvisioningEntryAddedNotification {
  return (
    isJsonRpcMethodMessage(msg) &&
    msg.method === "provisioningEntryAdded" &&
    "params" in msg &&
    typeof msg.params === "object" &&
    msg.params !== null &&
    "dsk" in msg.params &&
    typeof msg.params.dsk === "string"
  );
}

export function isProvisioningEntryRemovedNotification(
  msg: unknown
): msg is ProvisioningEntryRemovedNotification {
  return (
    isJsonRpcMethodMessage(msg) &&
    msg.method === "provisioningEntryRemoved" &&
    "params" in msg &&
    typeof msg.params === "object" &&
    msg.params !== null &&
    "dsk" in msg.params &&
    typeof msg.params.dsk === "string"
  );
}

// === Constants ===

export const DEFAULT_IPC_PORT = 4713;
export const IPC_PORT_ENV_VAR = "RUNNER_IPC_PORT";
