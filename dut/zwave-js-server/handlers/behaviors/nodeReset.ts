import { wait } from "alcalzone-shared/async";
import { registerHandler } from "../../prompt-handlers.ts";

registerHandler(/.*/, {
  onPrompt: async (ctx) => {
    if (ctx.message?.type === "CHECK_NETWORK_STATUS") {
      const { check, nodeId } = ctx.message;

      if (check === "RESET_AND_LEFT") {
        // Wait for the node to be removed from includedNodes
        for (let attempt = 1; attempt <= 5; attempt++) {
          if (!ctx.includedNodes.some((n) => n.id === nodeId)) {
            return "Yes";
          }
          // Wait a bit before retrying
          await wait(1000 * attempt);
        }
        return "No";
      }

      if (check === "REMOVED_FROM_LIST") {
        // Check if node is still in the client's node list
        return ctx.client.hasNode(nodeId) ? "No" : "Yes";
      }
    }

    // Let other prompts fall through to manual handling
    return undefined;
  },
});
