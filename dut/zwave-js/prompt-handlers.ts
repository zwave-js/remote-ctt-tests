/**
 * Prompt Handler System
 *
 * Provides a registry for automatic prompt handlers that can respond
 * to CTT prompts based on test name patterns.
 */

import type { Driver } from "zwave-js";

// === Types ===

export interface PromptContext {
  testName: string;
  promptType: string;
  promptText: string;
  buttons: string[];
  driver: Driver;
  state: Map<string, unknown>; // Test-specific state storage
}

export interface TestStartContext {
  testName: string;
  driver: Driver;
  state: Map<string, unknown>;
}

export type PromptHandler = (ctx: PromptContext) => Promise<string | undefined>;

export interface TestHandlers {
  onTestStart?: (ctx: TestStartContext) => Promise<void>;
  onPrompt?: PromptHandler;
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
