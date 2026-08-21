import { WebSocketServer, WebSocket } from 'ws';
import { EventEmitter } from 'events';
import {
  getTestCases,
  abortTestRun,
  submitTestCaseMessageBoxResult,
} from './ctt-client.ts';
import { convertCttColorsToAnsi, stripCttColors } from './ctt-output.ts';
import type { RunnerHost } from './runner-host.ts';

// Global event emitter for test case events
export const testCaseEvents = new EventEmitter();

// Opt-in WebSocket tracing (CTT_WS_TRACE=1). Timestamps use local-clock
// HH:MM:SS.mmm to match CTT's ctt-remote.log and the Z-Wave JS driver log.
const WS_TRACE = !!process.env.CTT_WS_TRACE;
function wsTraceTs(): string {
  const d = new Date();
  return d.toTimeString().slice(0, 8) + '.' + String(d.getMilliseconds()).padStart(3, '0');
}
function wsTrace(dir: 'IN ' | 'OUT' | 'DUT', detail: string): void {
  if (WS_TRACE) console.log(`[WSTRACE ${wsTraceTs()}] ${dir} ${detail}`);
}
function traceSnippet(method: string, params: Record<string, unknown> | undefined): string {
  if (!params) return '';
  const raw =
    method === 'generalLogMsg' ? String(params.output ?? '') :
    method === 'testCaseLogMsg' ? String(params.logOutput ?? '') :
    method === 'testCaseMsgBox' ? `${params.type ?? ''} | ${String((params as { content?: unknown }).content ?? '')}` :
    '';
  // eslint-disable-next-line no-control-regex
  return raw.replace(/\x1b\[[0-9;]*m/g, '').replace(/\{color[^}]*\}/g, '').replace(/\s+/g, ' ').trim().slice(0, 120);
}

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
  // Ensure the project-loaded sequence runs at most once
  let projectLoadHandled = false;
  // CTT 4 streams all test output via `generalLogMsg`; we parse the verdict from
  // the text. Set once we see "final Test Result:" until the verdict word lands.
  let awaitingVerdict = false;

  // CTT verdict keywords (as printed in the log) -> normalized result string.
  // runTestCases/runTests treat anything other than 'PASSED' as a failure.
  const VERDICT_RESULTS: Record<string, string> = {
    pass: 'PASSED',
    passed: 'PASSED',
    fail: 'FAILED',
    failed: 'FAILED',
    skip: 'SKIPPED',
    skipped: 'SKIPPED',
    inconclusive: 'INCONCLUSIVE',
    aborted: 'ABORTED',
    cancelled: 'CANCELLED',
    canceled: 'CANCELLED',
    na: 'NA',
  };

  // Emit a synthesized testCaseFinished for the current test (CTT 4 path).
  const emitTestCaseFinished = (result: string) => {
    const name = currentTestName ?? 'Unknown';
    const icon = result === 'PASSED' ? '✓' : '✗';
    console.log(`\n${icon} ${name}: ${result}`);
    const testCaseResult: TestCaseResult = {
      name,
      endPoint: '0',
      executionMode: 'Classic',
      result,
      isLongRange: false,
      category: '',
      group: '',
    };
    testCaseEvents.emit('testCaseFinished', testCaseResult);
    currentTestName = null;
    awaitingVerdict = false;
  };

  // Parse a chunk of CTT 4 generalLogMsg output: render it, detect the current
  // test name, forward to the runner, and synthesize verdicts.
  const handleGeneralLogOutput = (rawOutput: string) => {
    const plain = stripCttColors(rawOutput);
    const lines = plain.split('\n');

    for (const rawLine of lines) {
      const line = rawLine.trim();
      if (!line) continue;

      // Test header: CTT prints the test name twice ("Name Name") between
      // dashed separator lines. Capture it as the current test.
      const headerMatch = line.match(/^(\S+)\s+\1$/);
      const headerName = headerMatch?.[1];
      if (headerName && headerName !== currentTestName) {
        currentTestName = headerName;
        awaitingVerdict = false;
        if (runnerHost) {
          runnerHost.testCaseStarted(currentTestName).catch((error) => {
            console.error('[TestCase] Failed to notify runner of test start:', error);
          });
        }
        continue;
      }

      // Verdict detection. The marker line and the verdict word can arrive in
      // the same or in separate messages, so we latch `awaitingVerdict`.
      if (line.includes('final Test Result:')) {
        awaitingVerdict = true;
        continue;
      }
      if (awaitingVerdict) {
        const verdict = VERDICT_RESULTS[line.toLowerCase()];
        if (verdict) {
          emitTestCaseFinished(verdict);
          continue;
        }
      }
    }

    // Render the output for the user (colored), skipping blank lines.
    const colored = convertCttColorsToAnsi(rawOutput);
    for (const rawLine of colored.split('\n')) {
      const out = rawLine.replace(/\s+$/, '');
      if (out.trim()) console.log(out);
    }

    // Forward to the runner so its handlers can react (e.g. interactive tests).
    if (runnerHost && plain.trim()) {
      runnerHost.handleCttLog(plain, currentTestName ?? '').catch((error) => {
        console.error('[Log] Failed to forward to runner:', error);
      });
    }
  };

  const handleProjectLoaded = () => {
    if (projectLoadHandled) return;
    projectLoadHandled = true;
    console.log('Project loaded successfully detected!');
    if (onProjectLoaded) {
      onProjectLoaded();
    }
  };

  const wss = new WebSocketServer({ port });

  console.log(`WebSocket server listening on port ${port}`);

  wss.on('connection', (ws: WebSocket) => {
    console.log('New client connected');

    ws.on('message', async (data: Buffer) => {
      const messageStr = data.toString();

      // Parse JSON-RPC message and check for fatal errors or success
      try {
        const message = JSON.parse(messageStr);

        wsTrace('IN ', `${message.method} id=${message.id ?? '-'} ${traceSnippet(message.method, message.params)}`);

        // Log received messages, except for ones we handle separately
        const silentMethods = ['generalLogMsg', 'testCaseLogMsg', 'testCaseMsgBox', 'testCaseFinished', 'closeProjectDone'];
        if (!silentMethods.includes(message.method)) {
          console.log('Received message:', messageStr);
        }

        // Handle closeProjectDone event
        if (message.method === 'closeProjectDone') {
          const result = message.params?.result || 'Unknown';
          console.log(`Project close: ${result}`);
          testCaseEvents.emit('closeProjectDone', { result });
        }

        // CTT 4 signals project-load completion via a structured `projectLoaded`
        // method (CTT 3 used a generalLogMsg containing "Project loaded
        // successfully", handled below for backwards compatibility).
        if (message.method === 'projectLoaded') {
          const state = message.params?.state;
          if (state === 'Success') {
            handleProjectLoaded();
          } else if (state === 'Failed') {
            console.error(
              `Project failed to load: ${message.params?.msg ?? 'unknown error'}`
            );
            if (onFatalError) {
              onFatalError();
            }
          }
        }

        // Prepare acknowledgement response (CTT expects this for every message)
        const responseData: { jsonrpc: string; result: string; id: number } = {
          jsonrpc: '2.0',
          result: 'null',
          id: message.id,
        };
        let responseSent = false;

        if (message.method === 'generalLogMsg' && message.params?.output) {
          // Emit event for external listeners
          testCaseEvents.emit('generalLogMsg', { output: message.params.output, errorType: message.params.errorType });

          // Check for project loaded success (CTT 3 style)
          if (message.params.errorType === 'None' &&
              message.params.output.includes('Project loaded successfully')) {
            handleProjectLoaded();
          }

          // Check for fatal errors
          if (message.params.errorType === 'Error' &&
              shouldShutdownOnError(message.params.output, fatalErrorPatterns)) {
            console.error('Fatal error detected, shutting down...');
            if (onFatalError) {
              onFatalError();
            }
          }

          // CTT 4 streams test logs + verdicts through generalLogMsg: render,
          // track the current test, forward to the runner, parse the result.
          handleGeneralLogOutput(message.params.output);
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
          ws.send(JSON.stringify(responseData));
          responseSent = true;

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
              // CTT is dismissing the box because it observed the expected event.
              // Resolve any still-pending prompt so the orchestrator can proceed.
              runnerHost?.closeActivePrompt();
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

            // Strictly resolve an answer (a 1-based number or an exact button
            // label) to one of the buttons CTT offered. Returns null for
            // anything that isn't an offered button - we must never silently
            // swap one valid button for another, and sending a label CTT
            // doesn't recognise (e.g. "Ok" to a Yes/No box) just hangs the box.
            const resolveButton = (value: string): string | null => {
              const num = parseInt(value, 10);
              if (!isNaN(num) && num >= 1 && num <= buttons.length) {
                return buttons[num - 1] ?? null;
              }
              const match = buttons.find(
                (b) => b.toLowerCase() === value.trim().toLowerCase()
              );
              return match ?? null;
            };

            // Wait for user input or a runner handler response, re-prompting the
            // user on invalid input. The loop only repeats for bad user input;
            // every other branch settles the box.
            try {
              for (;;) {
                const result = await runnerHost.promptForResponse(
                  userPrompt,
                  stripCttColors(content),
                  testCase.TestCaseName || currentTestName || '',
                  // "Skip" boxes are self-closing. CTT dismisses them once it
                  // observes the expected event.
                  { autoCloseable: msgType === 'Skip' }
                );

                // CTT already dismissed the box after observing the expected
                // event. Acknowledge with an empty result since the box is gone.
                if (result.source === 'closed') {
                  process.stdout.write('\r\x1b[K');
                  console.log('[MsgBox] CTT closed the box (event satisfied) - acknowledging');
                  responseData.result = '';
                  break;
                }

                // CTT never dismissed this self-closing box within the safety
                // timeout. Skip just this step.
                if (result.source === 'skip') {
                  process.stdout.write('\r\x1b[K');
                  console.log(`[MsgBox] Self-closing prompt not satisfied - skipping step with "${buttons[0]}"`);
                  responseData.result = buttons[0]!;
                  break;
                }

                // No answer is coming (timed out, or unhandled with no handler).
                // runner-host has already aborted the whole run; we only need a
                // valid button so CTT can close the box.
                if (result.source === 'timeout' || result.source === 'unhandled') {
                  process.stdout.write('\r\x1b[K');
                  const reason = result.source === 'unhandled' ? 'unhandled' : 'timed out';
                  console.log(`[MsgBox] Prompt ${reason} - run aborted; closing box with "${buttons[0]}"`);
                  responseData.result = buttons[0]!;
                  break;
                }

                const mapped = resolveButton(result.value);

                if (result.source === 'auto') {
                  process.stdout.write('\r\x1b[K');
                  if (mapped) {
                    console.log(`[Auto] ${mapped}`);
                    responseData.result = mapped;
                  } else {
                    // The handler produced something that isn't an offered
                    // button - we can't answer correctly, so abort the run
                    // rather than guess (same policy as a missing handler).
                    console.error(
                      `[Auto] handler returned "${result.value}", not one of (${buttons.join(', ')}) - aborting run`
                    );
                    await abortTestRun('handler returned an invalid answer');
                    responseData.result = buttons[0]!;
                  }
                  break;
                }

                // User input.
                if (mapped) {
                  responseData.result = mapped;
                  break;
                }
                console.log(`Invalid input "${result.value}". Choose one of: ${buttons.join(', ')}`);
              }
            } catch (error) {
              console.error('[MsgBox] Prompt handler error:', error);
              responseData.result = buttons[0]!; // Fallback to first button
            }
          } else if (buttons.length > 0) {
            // No runner host - auto-respond with first button
            responseData.result = buttons[0]!;
            console.log('[MsgBox] Auto-responding:', buttons[0], '-', coloredContent);
          }
        }

        // Send acknowledgement back to CTT
        if (message.method === 'testCaseMsgBox') {
          wsTrace('OUT', `testCaseMsgBoxResult result="${responseData.result}"`);
        }
        if (!responseSent) {
          ws.send(JSON.stringify(responseData));
        }

        if (
          message.method === 'testCaseMsgBox' &&
          responseData.result !== '' &&
          responseData.result !== 'null'
        ) {
          await submitTestCaseMessageBoxResult(responseData.result);
        }
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
