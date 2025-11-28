import WebSocket from 'ws';

const CTT_HOST = '127.0.0.1';
const CTT_PORT = 4711;
const CTT_URL = `ws://${CTT_HOST}:${CTT_PORT}/json-rpc`;

let messageId = 0;

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
    const ws = new WebSocket(CTT_URL);
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

export async function runTestCases(options: Partial<TestCaseRequestDTO> = {}): Promise<unknown> {
  const testCaseRequestDTO: TestCaseRequestDTO = {
    groups: options.groups ?? [],
    results: options.results ?? [],
    endPointIds: options.endPointIds ?? [],
    testCaseNames: options.testCaseNames ?? [],
    ZWaveExecutionModes: options.ZWaveExecutionModes ?? [],
  };

  const request = createRequest('runTestCases', { testCaseRequestDTO });
  const response = await sendRequest(request);

  if (response.error) {
    throw new Error(`RPC Error: ${response.error.message}`);
  }

  return response.result;
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

export async function closeCTT(): Promise<unknown> {
  const request = createRequest('closeCTT', {});
  const response = await sendRequest(request);

  if (response.error) {
    throw new Error(`RPC Error: ${response.error.message}`);
  }

  return response.result;
}

export function isCTTAvailable(): Promise<boolean> {
  return new Promise((resolve) => {
    const ws = new WebSocket(CTT_URL);
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
