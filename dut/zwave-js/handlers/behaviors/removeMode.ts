/**
 * Handler for remove mode prompts
 *
 * Automates Z-Wave node exclusion (removing devices from the network).
 */

import { registerHandler } from "../../prompt-handlers.ts";

registerHandler(/.*/, {
  onPrompt: async (ctx) => {
    if (ctx.promptText.toLowerCase().includes("activate the remove mode")) {
      const { driver, includedNodes } = ctx;

      // Listen for node removal to update includedNodes
      driver.controller.on("node removed", (node) => {
        const index = includedNodes.indexOf(node);
        if (index !== -1) {
          includedNodes.splice(index, 1);
        }
      });

      await driver.controller.beginExclusion();
      return "Ok";
    }

    // Let other prompts fall through to manual handling
    return undefined;
  },
});
