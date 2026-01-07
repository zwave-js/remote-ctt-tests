/**
 * Handler for triggering capability discovery (re-interview) on a node
 */

import { registerHandler } from "../../prompt-handlers.ts";

registerHandler(/.*/, {
  onLog: async (ctx) => {
    if (ctx.message?.type === "TRIGGER_RE_INTERVIEW") {
      const { client } = ctx;
      const node = client.getNode(ctx.message.nodeId);
      if (!node) return;

      // Trigger re-interview after the orchestrator sends Ok to CTT
      setTimeout(() => {
        node.refreshInfo();
      }, 10);
      return true; // Stop propagation
    }
  },
});
