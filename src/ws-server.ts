import { WebSocketServer, WebSocket } from 'ws';
import { EventEmitter } from 'events';
import { getTestCases } from './ctt-client.ts';
import { convertCttColorsToAnsi, type CttPrompt } from './ctt-output.ts';

// Global event emitter for test case events
export const testCaseEvents = new EventEmitter();

export interface TestCaseResult {
  name: string;
  endPoint: string;
  executionMode: string;
  result: string;
  isLongRange: boolean;
  category: string;
  group: string;
}

/**
 * Handler for CTT prompts (like YES-NO dialogs)
 * @param prompt - The parsed prompt information
 * @returns Promise resolving to the button to click (e.g., "YES", "NO", or custom button text)
 */
export type PromptHandler = (prompt: CttPrompt) => Promise<string>;

export interface WebSocketServerOptions {
  port: number;
  onFatalError?: () => void;
  onProjectLoaded?: () => void;
  fatalErrorPatterns?: string[];
  /** Handler for user prompts. If not provided, prompts will be auto-skipped. */
  promptHandler?: PromptHandler;
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
  const { port, onFatalError, onProjectLoaded, fatalErrorPatterns = DEFAULT_FATAL_ERROR_PATTERNS, promptHandler } = options;

  const wss = new WebSocketServer({ port });

  console.log(`WebSocket server listening on port ${port}`);

  wss.on('connection', (ws: WebSocket) => {
    console.log('New client connected');

    ws.on('message', async (data: Buffer) => {
      const messageStr = data.toString();

      // Parse JSON-RPC message and check for fatal errors or success
      try {
        const message = JSON.parse(messageStr);

        // Log received messages, except for ones we handle separately
        const silentMethods = ['testCaseLogMsg', 'testCaseMsgBox', 'testCaseFinished'];
        if (!silentMethods.includes(message.method)) {
          console.log('Received message:', messageStr);
        }

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

            // // Query and display available test cases
            // queryTestCases();

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
          // Log test case output with ANSI colors
          const logOutput = message.params?.logOutput || '';
          // Convert CTT color format to ANSI escape codes
          const coloredOutput = convertCttColorsToAnsi(logOutput).trim();
          if (coloredOutput) {
            console.log(coloredOutput);
          }
        } else if (message.method === 'testCaseFinished') {
          // Print test case result
          const params = message.params || {};
          const name = params.Name || 'Unknown';
          const result = params.Result || 'Unknown';
          const icon = result === 'PASSED' ? '✓' : '✗';
          console.log(`\n${icon} ${name}: ${result}`);

          // Emit event for test case completion tracking
          const testCaseResult: TestCaseResult = {
            name,
            endPoint: params.EndPoint || '0',
            executionMode: params.IsLongRange ? 'LongRangeStar' : 'Classic',
            result,
            isLongRange: params.IsLongRange || false,
            category: params.Category || '',
            group: params.Group || '',
          };
          testCaseEvents.emit('testCaseFinished', testCaseResult);
        } else if (message.method === 'testCaseMsgBox') {
          // Handle message box based on documented TestCaseMsgBoxTypes:
          // OkCancel, Ok, YesNo, UrlOpenCancel, Skip, WaitForDutResponse,
          // CloseCurrentMsgBox, Yes, No
          const msgType = message.params?.type || '';
          const content = message.params?.content || '';
          const coloredContent = convertCttColorsToAnsi(content).trim();

          // Build prompt based on message type
          let prompt: CttPrompt | null = null;

          switch (msgType) {
            case 'WaitForDutResponse':
              // Must be confirmed by TestCaseConfirmation.Ok, cannot be skipped
              responseData.result = '';
              console.log('[MsgBox] Waiting for DUT Response:', coloredContent);
              break;

            case 'CloseCurrentMsgBox':
              // Just closes the current message box
              responseData.result = '';
              console.log('[MsgBox] Closing current message box');
              break;

            case 'YesNo':
              prompt = { type: 'YES_NO', rawText: coloredContent, buttons: ['Yes', 'No'] };
              break;

            case 'OkCancel':
              prompt = { type: 'BUTTON_LIST', rawText: coloredContent, buttons: ['Ok', 'Cancel'] };
              break;

            case 'Ok':
              prompt = { type: 'BUTTON_LIST', rawText: coloredContent, buttons: ['Ok'] };
              break;

            case 'Yes':
              prompt = { type: 'BUTTON_LIST', rawText: coloredContent, buttons: ['Yes'] };
              break;

            case 'No':
              prompt = { type: 'BUTTON_LIST', rawText: coloredContent, buttons: ['No'] };
              break;

            case 'Skip':
              prompt = { type: 'BUTTON_LIST', rawText: coloredContent, buttons: ['Skip'] };
              break;

            case 'UrlOpenCancel':
              prompt = { type: 'BUTTON_LIST', rawText: coloredContent, buttons: ['Open', 'Cancel'] };
              break;

            default:
              // Unknown type - auto-skip
              responseData.result = 'Skip';
              console.log('[MsgBox] Unknown type, auto-skipping:', msgType, coloredContent);
              break;
          }

          // Handle prompt if we built one
          if (prompt && promptHandler) {
            try {
              const response = await promptHandler(prompt);
              responseData.result = response;
            } catch (error) {
              console.error('[MsgBox] Prompt handler error:', error);
              responseData.result = 'Skip';
            }
          } else if (prompt) {
            // No prompt handler (CI mode) - auto-respond
            responseData.result = prompt.buttons[0]; // Default to first button
            console.log('[MsgBox] Auto-responding:', prompt.buttons[0], '-', coloredContent);
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
