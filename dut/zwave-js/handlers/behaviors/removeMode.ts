/**
 * Handler for remove mode prompts
 *
 * Automates Z-Wave node exclusion (removing devices from the network).
 */

import { registerHandler } from "../../prompt-handlers.ts";

registerHandler(/.*/, {
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
