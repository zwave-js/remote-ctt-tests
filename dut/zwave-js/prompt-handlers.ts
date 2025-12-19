/**
 * Prompt Handler System
 *
 * Provides a registry for automatic prompt handlers that can respond
 * to CTT prompts based on test name patterns.
 */

import type {
  Driver,
  Endpoint,
  ZWaveNode,
  ZWaveNodeValueNotificationArgs,
  ZWaveNotificationCallback,
} from "zwave-js";
import type { CommandClasses } from "@zwave-js/core";
import type { DUTMessage } from "../../src/ctt-message-types.ts";

// === Types ===

export type NodeNotificationArgs = Parameters<ZWaveNotificationCallback>[2];

// Base context without message (for test start)
interface BaseContext {
  testName: string;
  driver: Driver;
  state: Map<string, unknown>;
  includedNodes: ZWaveNode[];
  nodeNotifications: {
    endpoint: Endpoint;
    ccId: CommandClasses;
    args: NodeNotificationArgs;
  }[];
  valueNotifications: {
    node: ZWaveNode;
    args: ZWaveNodeValueNotificationArgs;
  }[];
}

// Context with required message (for prompts and logs)
export interface HandlerContext extends BaseContext {
  message: DUTMessage;
}

// Aliases for clarity in handler signatures
export type PromptContext = HandlerContext;
export type LogContext = HandlerContext;
export type TestStartContext = BaseContext;

export type PromptResponse = "Ok" | "Cancel" | "Yes" | "No" | "Open" | "Skip";

export type PromptHandler = (
  ctx: PromptContext
) => Promise<PromptResponse | undefined>;
export type LogHandler = (ctx: LogContext) => Promise<boolean | void>;

export interface TestHandlers {
  onTestStart?: (ctx: TestStartContext) => Promise<void>;
  onPrompt?: PromptHandler;
  onLog?: LogHandler;
}

// === Registry ===

interface RegisteredHandler {
  pattern: string | RegExp;
  handlers: TestHandlers;
}

const registeredHandlers: RegisteredHandler[] = [];

/**
 * Register a handler for test cases matching the given pattern.
 *
 * @param pattern - A string for exact match, or RegExp for pattern matching
 * @param handlers - The handlers to invoke for matching tests
 */
export function registerHandler(
  pattern: string | RegExp,
  handlers: TestHandlers
): void {
  registeredHandlers.push({ pattern, handlers });
}

/**
 * Get all handlers that match the given test name.
 * Returns exact string matches first, then RegExp matches.
 *
 * @param testName - The name of the test case
 * @returns Array of matching TestHandlers
 */
export function getHandlersForTest(testName: string): TestHandlers[] {
  const exactMatches: TestHandlers[] = [];
  const patternMatches: TestHandlers[] = [];

  for (const { pattern, handlers } of registeredHandlers) {
    if (typeof pattern === "string") {
      if (pattern === testName) {
        exactMatches.push(handlers);
      }
    } else {
      if (pattern.test(testName)) {
        patternMatches.push(handlers);
      }
    }
  }

  // Return exact matches first, then pattern matches
  return [...exactMatches, ...patternMatches];
}

/**
 * Clear all registered handlers (useful for testing)
 */
export function clearHandlers(): void {
  registeredHandlers.length = 0;
}
