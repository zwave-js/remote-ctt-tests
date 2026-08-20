import WebSocket from 'ws';
import { testCaseEvents, type TestCaseResult } from './ws-server.ts';

let cttUrl: string | undefined;

let messageId = 0;

export function configureCttClient(port: number, host = '127.0.0.1'): void {
  cttUrl = `ws://${host}:${port}/json-rpc`;
}

function getCttUrl(): string {
  if (!cttUrl) {
    throw new Error('CTT client endpoint has not been configured');
  }
  return cttUrl;
}

interface JsonRpcRequest {
  jsonrpc: '2.0';
  method: string;
  params: Record<string, unknown>;
  id: number;
}

interface JsonRpcResponse {
  jsonrpc: '2.0';
  result?: unknown;
  error?: { code: number; message: string };
  id: number;
}

interface TestCaseRequestDTO {
  groups: string[];
  results: string[];
  endPointIds: (string | number)[];
  testCaseNames: string[];
  ZWaveExecutionModes?: string[];
}

function createRequest(method: string, params: Record<string, unknown>): JsonRpcRequest {
  return {
    jsonrpc: '2.0',
    method,
    params,
    id: messageId++,
  };
}

async function sendRequest(request: JsonRpcRequest): Promise<JsonRpcResponse> {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(getCttUrl());
    const timeout = setTimeout(() => {
      ws.close();
      reject(new Error('Request timeout'));
    }, 30000);

    ws.on('open', () => {
      const data = JSON.stringify(request);
      console.log(`[CTT Client] Sending: ${data}`);
      ws.send(data);
    });

    ws.on('message', (data: Buffer) => {
      clearTimeout(timeout);
      const response = JSON.parse(data.toString()) as JsonRpcResponse;
      console.log(`[CTT Client] Received response for id ${response.id}`);
      ws.close();
      resolve(response);
    });

    ws.on('error', (error) => {
      clearTimeout(timeout);
      reject(error);
    });
  });
}

export async function getTestCases(options: Partial<TestCaseRequestDTO> = {}): Promise<unknown> {
  const testCaseRequestDTO: TestCaseRequestDTO = {
    groups: options.groups ?? [],
    results: options.results ?? [],
    endPointIds: options.endPointIds ?? [],
    testCaseNames: options.testCaseNames ?? [],
    ZWaveExecutionModes: options.ZWaveExecutionModes ?? [],
  };

  const request = createRequest('getTestCases', { testCaseRequestDTO });
  const response = await sendRequest(request);

  if (response.error) {
    throw new Error(`RPC Error: ${response.error.message}`);
  }

  return response.result;
}

/**
 * Runs test cases and waits for all of them to complete.
 * Returns an array of test case results.
 */
export async function runTestCases(options: Partial<TestCaseRequestDTO> = {}): Promise<TestCaseResult[]> {
  const testCaseNames = options.testCaseNames ?? [];

  if (testCaseNames.length === 0) {
    throw new Error('At least one test case name must be provided');
  }

  // Set up listener before starting tests
  const results: TestCaseResult[] = [];
  const pendingTests = new Set(testCaseNames);

  const completionPromise = new Promise<TestCaseResult[]>((resolve) => {
    const cleanup = () => {
      testCaseEvents.removeListener('testCaseFinished', onTestCaseFinished);
      testCaseEvents.removeListener('runAborted', onRunAborted);
    };

    const onTestCaseFinished = (result: TestCaseResult) => {
      // Check if this is one of the tests we're waiting for
      if (pendingTests.has(result.name)) {
        results.push(result);
        pendingTests.delete(result.name);

        if (pendingTests.size === 0) {
          cleanup();
          resolve(results);
        }
      }
    };

    // The run was aborted (e.g. CI hit a prompt that can never be answered).
    // CTT aborts the whole run without emitting a per-test verdict, so without
    // this we would wait forever for testCaseFinished events that never come.
    // Mark every still-pending test as ABORTED and resolve.
    const onRunAborted = ({ reason }: { reason: string }) => {
      console.warn(
        `[CTT Client] Test run aborted (${reason}); marking ${pendingTests.size} pending test(s) as ABORTED`
      );
      for (const name of pendingTests) {
        results.push({
          name,
          endPoint: '0',
          executionMode: 'Classic',
          result: 'ABORTED',
          isLongRange: false,
          category: '',
          group: '',
        });
      }
      pendingTests.clear();
      cleanup();
      resolve(results);
    };

    testCaseEvents.on('testCaseFinished', onTestCaseFinished);
    testCaseEvents.on('runAborted', onRunAborted);
  });

  // Start the test cases via RPC
  const testCaseRequestDTO: TestCaseRequestDTO = {
    groups: options.groups ?? [],
    results: options.results ?? [],
    endPointIds: options.endPointIds ?? [],
    testCaseNames,
    ZWaveExecutionModes: options.ZWaveExecutionModes ?? [],
  };

  const request = createRequest('runTestCases', { testCaseRequestDTO });
  const response = await sendRequest(request);

  if (response.error) {
    throw new Error(`RPC Error: ${response.error.message}`);
  }

  if (response.result !== 'Completed') {
    throw new Error(`Failed to start test cases: ${response.result}`);
  }

  // Wait for all test cases to complete
  return completionPromise;
}

export async function cancelTestRun(): Promise<void> {
  const request = createRequest('cancelTestRun', {});
  const response = await sendRequest(request);

  if (response.error) {
    throw new Error(`RPC Error: ${response.error.message}`);
  }
}

/**
 * Aborts the whole test run with the given reason.
 */
export async function abortTestRun(reason: string): Promise<void> {
  testCaseEvents.emit('runAborted', { reason });
  await cancelTestRun();
}

export async function resetController(): Promise<unknown> {
  const request = createRequest('resetController', {});
  const response = await sendRequest(request);

  if (response.error) {
    throw new Error(`RPC Error: ${response.error.message}`);
  }

  return response.result;
}

export async function setupSerialDevices(
  serialDevices: Record<string, unknown>,
  configureDevices: boolean = false
): Promise<unknown> {
  const request = createRequest('setupSerialDevices', { serialDevices, configureDevices });
  const response = await sendRequest(request);

  if (response.error) {
    throw new Error(`RPC Error: ${response.error.message}`);
  }

  return response.result;
}

export async function closeCTT(): Promise<void> {
  const maxRetries = 5;
  const retryDelay = 3000; // 3 seconds between retries

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    // Set up listener for closeProjectDone
    const closeResult = await new Promise<{ success: boolean; unreachable?: boolean }>((resolve) => {
      const timeout = setTimeout(() => {
        testCaseEvents.removeListener('closeProjectDone', onClose);
        resolve({ success: false });
      }, 10000);

      const onClose = (data: { result?: string }) => {
        clearTimeout(timeout);
        testCaseEvents.removeListener('closeProjectDone', onClose);
        resolve({ success: data.result === 'Completed' });
      };

      testCaseEvents.on('closeProjectDone', onClose);

      // Send the close request
      const request = createRequest('closeCTT', {});
      sendRequest(request).catch((error: NodeJS.ErrnoException) => {
        clearTimeout(timeout);
        testCaseEvents.removeListener('closeProjectDone', onClose);
        // An unreachable endpoint means CTT has already closed.
        const unreachable =
          error?.code === 'ECONNREFUSED' || error?.code === 'ECONNRESET';
        resolve({ success: false, unreachable });
      });
    });

    if (closeResult.success) {
      console.log('[CTT Client] Project closed successfully');
      return;
    }

    if (closeResult.unreachable) {
      console.log('[CTT Client] CTT already closed (not reachable)');
      return;
    }

    if (attempt < maxRetries) {
      console.log(`[CTT Client] Close failed (attempt ${attempt}/${maxRetries}), retrying in ${retryDelay / 1000}s...`);
      await new Promise((r) => setTimeout(r, retryDelay));
    }
  }

  console.log('[CTT Client] Failed to close project gracefully after all retries');
}

export function isCTTAvailable(): Promise<boolean> {
  return new Promise((resolve) => {
    const ws = new WebSocket(getCttUrl());
    const timeout = setTimeout(() => {
      ws.close();
      resolve(false);
    }, 2000);

    ws.on('open', () => {
      clearTimeout(timeout);
      ws.close();
      resolve(true);
    });

    ws.on('error', () => {
      clearTimeout(timeout);
      resolve(false);
    });
  });
}
