import { WebSocketServer, WebSocket } from 'ws';
import { getTestCases } from './ctt-client.ts';

export interface WebSocketServerOptions {
  port: number;
  onFatalError?: () => void;
  onProjectLoaded?: () => void;
  fatalErrorPatterns?: string[];
}

interface TestCaseDTO {
  Name: string;
  EndPoint: string;
  Group: string;
  Category: string;
  Result: string;
  IsLongRange: boolean;
}

export interface ManagedWebSocketServer {
  wss: WebSocketServer;
  close: () => Promise<void>;
}

// Error messages that should trigger shutdown
const DEFAULT_FATAL_ERROR_PATTERNS = [
  'Controller is not accessible, aborting',
  // Add more error patterns here as needed
];

function shouldShutdownOnError(message: string, patterns: string[]): boolean {
  return patterns.some(pattern => message.includes(pattern));
}

async function queryTestCases(): Promise<void> {
  console.log('\n--- Querying available test cases from CTT ---');

  // Give CTT a moment to fully initialize after project load
  await new Promise(resolve => setTimeout(resolve, 1000));

  try {
    const result = await getTestCases();
    const testCases = result as TestCaseDTO[];

    console.log(`\nFound ${testCases.length} test cases:\n`);

    // Group by category for better readability
    const byCategory = new Map<string, TestCaseDTO[]>();
    for (const tc of testCases) {
      const category = tc.Category || 'Uncategorized';
      if (!byCategory.has(category)) {
        byCategory.set(category, []);
      }
      byCategory.get(category)!.push(tc);
    }

    for (const [category, cases] of byCategory) {
      console.log(`\n[${category}] (${cases.length} tests)`);
      for (const tc of cases.slice(0, 5)) { // Show first 5 per category
        const mode = tc.IsLongRange ? 'LR' : 'Classic';
        console.log(`  - ${tc.Name} (EP${tc.EndPoint}, ${tc.Group}, ${mode}) [${tc.Result}]`);
      }
      if (cases.length > 5) {
        console.log(`  ... and ${cases.length - 5} more`);
      }
    }

    console.log('\n--- End of test cases ---\n');
  } catch (error) {
    console.error('Failed to query test cases:', error);
  }
}

export function createWebSocketServer(options: WebSocketServerOptions): ManagedWebSocketServer {
  const { port, onFatalError, onProjectLoaded, fatalErrorPatterns = DEFAULT_FATAL_ERROR_PATTERNS } = options;

  const wss = new WebSocketServer({ port });

  console.log(`WebSocket server listening on port ${port}`);

  wss.on('connection', (ws: WebSocket) => {
    console.log('New client connected');

    ws.on('message', (data: Buffer) => {
      const messageStr = data.toString();
      console.log('Received message:', messageStr);

      // Parse JSON-RPC message and check for fatal errors or success
      try {
        const message = JSON.parse(messageStr);

        // Prepare acknowledgement response (CTT expects this for every message)
        const responseData: { jsonrpc: string; result: string; id: number } = {
          jsonrpc: '2.0',
          result: 'null',
          id: message.id,
        };

        if (message.method === 'generalLogMsg' && message.params?.output) {
          // Check for project loaded success
          if (message.params.errorType === 'None' &&
              message.params.output.includes('Project loaded successfully')) {
            console.log('Project loaded successfully detected!');

            // Query and display available test cases
            queryTestCases();

            if (onProjectLoaded) {
              onProjectLoaded();
            }
          }

          // Check for fatal errors
          if (message.params.errorType === 'Error' &&
              shouldShutdownOnError(message.params.output, fatalErrorPatterns)) {
            console.error('Fatal error detected, shutting down...');
            if (onFatalError) {
              onFatalError();
            }
          }
        } else if (message.method === 'testCaseLogMsg') {
          // Log test case output
          const logOutput = message.params?.logOutput || '';
          // Strip color codes for cleaner console output
          const cleanOutput = logOutput.replace(/\{color:[^}]+\}/g, '').trim();
          if (cleanOutput) {
            console.log('[Test Log]', cleanOutput);
          }
        } else if (message.method === 'testCaseFinished') {
          // Log test case completion
          const params = message.params || {};
          console.log('\n=== Test Case Finished ===');
          console.log('Test:', params.testCase?.TestCaseName || 'Unknown');
          console.log('Result:', params.result || 'Unknown');
          console.log('========================\n');
        } else if (message.method === 'testCaseMsgBox') {
          // Handle message box - auto-respond with appropriate action
          const msgType = message.params?.type || '';
          if (msgType === 'WaitForDutResponse') {
            responseData.result = '';
            console.log('[MsgBox] Waiting for DUT Response:', message.params?.content);
          } else {
            // Auto-skip message boxes in automated mode
            responseData.result = 'Skip';
            console.log('[MsgBox] Auto-skipping:', message.params?.content);
          }
        }

        // Send acknowledgement back to CTT
        ws.send(JSON.stringify(responseData));
      } catch {
        // Ignore JSON parse errors
      }
    });

    ws.on('close', () => {
      console.log('Client disconnected');
    });

    ws.on('error', (error: Error) => {
      console.error('WebSocket error:', error);
    });
  });

  wss.on('error', (error: Error) => {
    console.error('Server error:', error);
  });

  const close = (): Promise<void> => {
    return new Promise((resolve) => {
      wss.close(() => {
        console.log('WebSocket server closed');
        resolve();
      });
    });
  };

  return { wss, close };
}
