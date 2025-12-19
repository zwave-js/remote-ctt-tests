import { WebSocketServer, WebSocket } from 'ws';
import { EventEmitter } from 'events';
import { getTestCases } from './ctt-client.ts';
import { convertCttColorsToAnsi, stripCttColors } from './ctt-output.ts';
import type { RunnerHost } from './runner-host.ts';

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

export interface WebSocketServerOptions {
  port: number;
  onFatalError?: () => void;
  onProjectLoaded?: () => void;
  fatalErrorPatterns?: string[];
  /** Runner host for handling CTT prompts via IPC */
  runnerHost?: RunnerHost;
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
  const { port, onFatalError, onProjectLoaded, fatalErrorPatterns = DEFAULT_FATAL_ERROR_PATTERNS, runnerHost } = options;

  // Track current test case name for detecting test start
  let currentTestName: string | null = null;

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
        const silentMethods = ['testCaseLogMsg', 'testCaseMsgBox', 'testCaseFinished', 'closeProjectDone'];
        if (!silentMethods.includes(message.method)) {
          console.log('Received message:', messageStr);
        }

        // Handle closeProjectDone event
        if (message.method === 'closeProjectDone') {
          const result = message.params?.result || 'Unknown';
          console.log(`Project close: ${result}`);
          testCaseEvents.emit('closeProjectDone', { result });
        }

        // Prepare acknowledgement response (CTT expects this for every message)
        const responseData: { jsonrpc: string; result: string; id: number } = {
          jsonrpc: '2.0',
          result: 'null',
          id: message.id,
        };

        if (message.method === 'generalLogMsg' && message.params?.output) {
          // Emit event for external listeners
          testCaseEvents.emit('generalLogMsg', { output: message.params.output, errorType: message.params.errorType });

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

          // Detect test case start by tracking testCase.TestCaseName changes
          const testCase = message.params?.testCase || {};
          const testName = testCase.TestCaseName || '';
          if (testName && testName !== currentTestName) {
            currentTestName = testName;
            // Notify runner that a new test case has started
            if (runnerHost) {
              runnerHost.testCaseStarted(testName).catch((error) => {
                console.error('[TestCase] Failed to notify runner of test start:', error);
              });
            }
          }

          // Forward log to runner for handler processing (strip colors for plain text matching)
          if (runnerHost && coloredOutput && (testName || currentTestName)) {
            runnerHost.handleCttLog(
              stripCttColors(logOutput),
              testName || currentTestName || ''
            ).catch((error) => {
              console.error('[Log] Failed to forward to runner:', error);
            });
          }
        } else if (message.method === 'testCaseFinished') {
          // Print test case result
          const params = message.params || {};
          const name = params.Name || 'Unknown';
          const result = params.Result || 'Unknown';
          const icon = result === 'PASSED' ? '✓' : '✗';
          console.log(`\n${icon} ${name}: ${result}`);

          // Clear current test name
          currentTestName = null;

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
          const testCase = message.params?.testCase || {};
          const coloredContent = convertCttColorsToAnsi(content).trim();

          // Emit event for external listeners (e.g., discovery script)
          testCaseEvents.emit('testCaseMsgBox', { testCase, type: msgType, content: coloredContent });

          // Determine available buttons based on message type
          let buttons: string[] = [];

          switch (msgType) {
            case 'WaitForDutResponse':
              buttons = ['Ok'];
              break;

            case 'CloseCurrentMsgBox':
              // Just closes the current message box
              responseData.result = '';
              console.log('[MsgBox] Closing current message box');
              break;

            case 'YesNo':
              buttons = ['Yes', 'No'];
              break;

            case 'OkCancel':
              buttons = ['Ok', 'Cancel'];
              break;

            case 'Ok':
              buttons = ['Ok'];
              break;

            case 'Yes':
              buttons = ['Yes'];
              break;

            case 'No':
              buttons = ['No'];
              break;

            case 'Skip':
              buttons = ['Skip'];
              break;

            case 'UrlOpenCancel':
              buttons = ['Open', 'Cancel'];
              break;

            default:
              // Unknown type - auto-skip
              responseData.result = 'Skip';
              console.log('[MsgBox] Unknown type, auto-skipping:', msgType, coloredContent);
              break;
          }

          // Forward prompt to runner via IPC if we have buttons to show
          if (buttons.length > 0 && runnerHost) {
            // Print the prompt cleanly
            console.log(`\n${coloredContent}`);

            // Build user prompt string
            let userPrompt: string;
            if (buttons.length === 1) {
              userPrompt = `\nPress Enter to select [${buttons[0]}]: `;
            } else {
              const options = buttons.map((b, i) => `${i + 1}=${b}`).join(', ');
              userPrompt = `Select (${options}): `;
            }

            // Wait for either user input or runner handler response
            try {
              const result = await runnerHost.promptForResponse(
                userPrompt,
                stripCttColors(content),
                testCase.TestCaseName || currentTestName || ''
              );

              if (result.source === 'auto') {
                // Auto-handler responded
                process.stdout.write('\r\x1b[K');
                console.log(`[Auto] ${result.value}`);
                responseData.result = result.value;
              } else {
                // User responded - parse their input
                if (buttons.length === 1) {
                  responseData.result = buttons[0];
                } else {
                  const num = parseInt(result.value, 10);
                  if (!isNaN(num) && num >= 1 && num <= buttons.length) {
                    responseData.result = buttons[num - 1];
                  } else {
                    const match = buttons.find((b) => b.toLowerCase() === result.value.toLowerCase());
                    responseData.result = match || buttons[0];
                  }
                }
              }
            } catch (error) {
              console.error('[MsgBox] Prompt handler error:', error);
              responseData.result = buttons[0]; // Fallback to first button
            }
          } else if (buttons.length > 0) {
            // No runner host - auto-respond with first button
            responseData.result = buttons[0];
            console.log('[MsgBox] Auto-responding:', buttons[0], '-', coloredContent);
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
