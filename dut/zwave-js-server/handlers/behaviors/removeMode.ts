/**
 * Handler for remove mode prompts
 *
 * Automates Z-Wave node exclusion (removing devices from the network).
 */

import { registerHandler } from "../../prompt-handlers.ts";

// Module-level variable to track cleanup function (persists across test state clears)
let currentRemovalCleanup: (() => void) | undefined;

registerHandler(/.*/, {
  async onTestStart(ctx) {
    const { client, includedNodes } = ctx;

    // Clean up any leftover listener from previous test
    if (currentRemovalCleanup) {
      currentRemovalCleanup();
      currentRemovalCleanup = undefined;
    }

    // Listen for node removal to update includedNodes
    const onNodeRemoved = (nodeId: number) => {
      const index = includedNodes.findIndex((n) => n.id === nodeId);
      if (index !== -1) {
        includedNodes.splice(index, 1);
      }
    };

    client.on("node removed", onNodeRemoved);
    currentRemovalCleanup = () => {
      client.off("node removed", onNodeRemoved);
    };
  },

  onPrompt: async (ctx) => {
    // Handle ACTIVATE_NETWORK_MODE for REMOVE mode
    if (
      ctx.message?.type === "ACTIVATE_NETWORK_MODE" &&
      ctx.message.mode === "REMOVE"
    ) {
      const { client } = ctx;

      await client.sendCommand("controller.begin_exclusion", {});
      return "Ok";
    }

    // Let other prompts fall through to manual handling
    return undefined;
  },
});
