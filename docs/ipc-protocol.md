# DUT Runner IPC Protocol

This document describes the IPC (Inter-Process Communication) protocol used between the orchestrator and DUT runners.

## Overview

- **Transport**: WebSocket
- **Port**: 4713 (configurable via `RUNNER_IPC_PORT` environment variable)
- **Protocol**: JSON-RPC 2.0

The runner connects to the orchestrator's WebSocket server at `ws://127.0.0.1:<port>`.

## Message Flow

```
Runner                              Orchestrator
   │                                     │
   │──── connect to WebSocket ──────────>│
   │                                     │
   │<─────── connection established ─────│
   │                                     │
   │──── ready notification ────────────>│
   │                                     │
   │<─────── start request ──────────────│
   │                                     │
   │──── start response ────────────────>│
   │                                     │
   │         ... test execution ...      │
   │                                     │
   │<─────── handleCttPrompt request ────│
   │                                     │
   │──── handleCttPrompt response ──────>│  (if handler matched)
   │  OR                                 │
   │──── noHandler notification ────────>│  (if no handler matched)
   │                                     │
   │         ... more prompts ...        │
   │                                     │
   │<─────── stop request ───────────────│
   │                                     │
   │──── stop response ─────────────────>│
   │                                     │
   │<─────── connection closed ──────────│
```

## Notifications (Runner → Orchestrator)

### ready

Sent immediately after WebSocket connection is established.

```json
{
  "jsonrpc": "2.0",
  "method": "ready",
  "params": {
    "name": "Your DUT Name"
  }
}
```

**Parameters:**
- `name` (string): Display name for the runner, used in logs

### noHandler

Sent when a `handleCttPrompt` request was received but no prompt handler matched. This allows the orchestrator to cancel the test run in CI mode to prevent hanging.

```json
{
  "jsonrpc": "2.0",
  "method": "noHandler"
}
```

**Note:** This is a notification only - no response is expected. The runner does not send a response to the original `handleCttPrompt` request when no handler matches, allowing interactive user input to work in non-CI environments.

## Requests (Orchestrator → Runner)

### start

Initialize the DUT and connect to the Z-Wave controller.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "start",
  "params": {
    "controllerUrl": "tcp://127.0.0.1:5000",
    "securityKeys": {
      "S2_Unauthenticated": "CE07372267DCB354DB216761B6E9C378",
      "S2_Authenticated": "30B5CCF3F482A92E2F63A5C5E218149A",
      "S2_AccessControl": "21A29A69145E38C1601DFF55E2658521",
      "S0_Legacy": "C6D90542DE4E66BBE66FBFCB84E9FF67"
    },
    "securityKeysLongRange": {
      "S2_Authenticated": "0F4F7E178A4207A0BBEFBF991C66F814",
      "S2_AccessControl": "72D42391F7ECE63BE1B38B25D085ECD4"
    }
  }
}
```

**Parameters:**
- `controllerUrl` (string): TCP URL for the Z-Wave controller (e.g., `tcp://127.0.0.1:5000`)
- `securityKeys` (object): Z-Wave security keys as hex strings
  - `S2_Unauthenticated` (string): 16-byte hex string
  - `S2_Authenticated` (string): 16-byte hex string
  - `S2_AccessControl` (string): 16-byte hex string
  - `S0_Legacy` (string): 16-byte hex string
- `securityKeysLongRange` (object): Long Range security keys as hex strings
  - `S2_Authenticated` (string): 16-byte hex string
  - `S2_AccessControl` (string): 16-byte hex string

**Success Response:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": "ok"
}
```

**Error Response:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32000,
    "message": "Failed to connect to controller"
  }
}
```

### stop

Shutdown the DUT gracefully.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "stop",
  "params": {}
}
```

**Success Response:**
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "result": "ok"
}
```

### handleCttPrompt

Handle an interactive prompt from CTT. The runner should return the name of the button to click.

**Request:**
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "handleCttPrompt",
  "params": {
    "type": "YesNo",
    "rawText": "Is the DUT ready to receive commands?",
    "buttons": ["Yes", "No"]
  }
}
```

**Parameters:**
- `type` (string): Prompt type, one of:
  - `YesNo` - Yes/No question
  - `OkCancel` - Ok/Cancel confirmation
  - `Ok` - Information dialog
  - `WaitForDutResponse` - CTT is waiting for DUT action
  - `Skip` - Option to skip a test step
- `rawText` (string): The prompt message/question
- `buttons` (string[]): Available button options

**Response:**
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "result": "Yes"
}
```

The `result` must be one of the strings from the `buttons` array.

## Error Codes

| Code | Description |
|------|-------------|
| -32700 | Parse error |
| -32600 | Invalid request |
| -32601 | Method not found |
| -32602 | Invalid params |
| -32603 | Internal error |
| -32000 | Application error (custom) |

## TypeScript Types

See [src/runner-ipc.ts](../src/runner-ipc.ts) for the complete TypeScript type definitions.

```typescript
interface SecurityKeys {
  S2_Unauthenticated: string;
  S2_Authenticated: string;
  S2_AccessControl: string;
  S0_Legacy: string;
}

interface SecurityKeysLongRange {
  S2_Authenticated: string;
  S2_AccessControl: string;
}

interface StartParams {
  controllerUrl: string;
  securityKeys: SecurityKeys;
  securityKeysLongRange: SecurityKeysLongRange;
}

interface CttPromptParams {
  type: string;
  rawText: string;
  buttons: string[];
}
```

## Reference Implementation

See [dut/zwave-js/run.ts](../dut/zwave-js/run.ts) for a complete working implementation of a DUT runner.
