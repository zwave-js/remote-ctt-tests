/**
 * Handler for remove mode prompts
 *
 * Automates Z-Wave node exclusion (removing devices from the network).
 */

import { wait } from "alcalzone-shared/async";
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

    if (ctx.message?.type === "WAIT_FOR_NODE_REMOVAL") {
      const { nodeId } = ctx.message;
      for (let attempt = 0; attempt < 30; attempt++) {
        if (!ctx.driver.controller.nodes.has(nodeId)) return "Ok";
        await wait(1000);
      }
      throw new Error(`Node ${nodeId} was not removed within 30 seconds`);
    }

    // Let other prompts fall through to manual handling
    return undefined;
  },
});
