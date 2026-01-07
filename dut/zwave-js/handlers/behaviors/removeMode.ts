/**
 * Handler for remove mode prompts
 *
 * Automates Z-Wave node exclusion (removing devices from the network).
 */

import { registerHandler } from "../../prompt-handlers.ts";
import type { ZWaveNode } from "zwave-js";

// Module-level variable to track cleanup function (persists across test state clears)
let currentRemovalCleanup: (() => void) | undefined;

registerHandler(/.*/, {
  async onTestStart(ctx) {
    const { driver, includedNodes } = ctx;

    // Clean up any leftover listener from previous test
    if (currentRemovalCleanup) {
      currentRemovalCleanup();
      currentRemovalCleanup = undefined;
    }

    // Listen for node removal to update includedNodes
    const onNodeRemoved = (node: ZWaveNode) => {
      const index = includedNodes.indexOf(node);
      if (index !== -1) {
        includedNodes.splice(index, 1);
      }
    };

    driver.controller.on("node removed", onNodeRemoved);
    currentRemovalCleanup = () => {
      driver.controller.off("node removed", onNodeRemoved);
    };
  },

  onPrompt: async (ctx) => {
    // Handle ACTIVATE_NETWORK_MODE for REMOVE mode
    if (
      ctx.message?.type === "ACTIVATE_NETWORK_MODE" &&
      ctx.message.mode === "REMOVE"
    ) {
      const { driver } = ctx;

      await driver.controller.beginExclusion();
      return "Ok";
    }

    // Let other prompts fall through to manual handling
    return undefined;
  },
});
