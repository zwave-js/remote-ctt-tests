/**
 * IPC Message Types for Runner Communication
 *
 * All runners (regardless of language) communicate with the orchestrator
 * via WebSocket using these JSON-RPC message formats.
 */

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
  type: string; // "YesNo", "OkCancel", "WaitForDutResponse", etc.
  rawText: string; // The prompt content/message
  buttons: string[]; // Available button options
  testName: string; // Name of the test case
}

// === CTT Log Parameters ===

export interface CttLogParams {
  logText: string; // The log message content
  testName: string; // Name of the test case
}

// === Test Case Started Parameters ===

export interface TestCaseStartedParams {
  testName: string;
}

// === Request Messages (Orchestrator -> Runner) ===

export interface StartRequest {
  jsonrpc: "2.0";
  id: number;
  method: "start";
  params: StartParams;
}

export interface StopRequest {
  jsonrpc: "2.0";
  id: number;
  method: "stop";
  params: Record<string, never>;
}

export interface HandleCttPromptRequest {
  jsonrpc: "2.0";
  id: number;
  method: "handleCttPrompt";
  params: CttPromptParams;
}

export interface TestCaseStartedRequest {
  jsonrpc: "2.0";
  id: number;
  method: "testCaseStarted";
  params: TestCaseStartedParams;
}

export interface HandleCttLogRequest {
  jsonrpc: "2.0";
  id: number;
  method: "handleCttLog";
  params: CttLogParams;
}

export type IpcRequest = StartRequest | StopRequest | HandleCttPromptRequest | TestCaseStartedRequest | HandleCttLogRequest;

// === Response Messages (Runner -> Orchestrator) ===

export interface SuccessResponse {
  jsonrpc: "2.0";
  id: number;
  result: string; // "ok" for start/stop, button name for handleCttPrompt
}

export interface ErrorResponse {
  jsonrpc: "2.0";
  id: number;
  error: {
    code: number;
    message: string;
  };
}

export type IpcResponse = SuccessResponse | ErrorResponse;

// === Notification Messages (Runner -> Orchestrator) ===

export interface ReadyNotification {
  jsonrpc: "2.0";
  method: "ready";
  params: {
    name: string; // Runner name for logging
  };
}

export type IpcNotification = ReadyNotification;

// === Type Guards ===

export function isSuccessResponse(msg: unknown): msg is SuccessResponse {
  return (
    typeof msg === "object" &&
    msg !== null &&
    "jsonrpc" in msg &&
    msg.jsonrpc === "2.0" &&
    "id" in msg &&
    "result" in msg
  );
}

export function isErrorResponse(msg: unknown): msg is ErrorResponse {
  return (
    typeof msg === "object" &&
    msg !== null &&
    "jsonrpc" in msg &&
    msg.jsonrpc === "2.0" &&
    "id" in msg &&
    "error" in msg
  );
}

export function isReadyNotification(msg: unknown): msg is ReadyNotification {
  return (
    typeof msg === "object" &&
    msg !== null &&
    "jsonrpc" in msg &&
    msg.jsonrpc === "2.0" &&
    "method" in msg &&
    msg.method === "ready" &&
    "params" in msg
  );
}

// === Constants ===

export const DEFAULT_IPC_PORT = 4713;
export const IPC_PORT_ENV_VAR = "RUNNER_IPC_PORT";
