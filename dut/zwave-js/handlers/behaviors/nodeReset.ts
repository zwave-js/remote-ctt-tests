import { wait } from "alcalzone-shared/async";
import { registerHandler } from "../../prompt-handlers.ts";

registerHandler(/.*/, {
  onPrompt: async (ctx) => {
    let match = /indicate.+node.+ID = (?<nodeId>\d+).+reset and left/i.exec(
      ctx.promptText
    );
    if (match?.groups) {
      const nodeID = parseInt(match.groups["nodeId"]!);
      for (let attempt = 1; attempt <= 5; attempt++) {
        if (!ctx.includedNodes.some((n) => n.id === nodeID)) {
          return "Yes";
        }
        // Wait a bit before retrying
        await wait(1000 * attempt);
      }
      return "No";
    }

    match = /DUT removed this node.+ID = (?<nodeId>\d+).+list/i.exec(
      ctx.promptText
    );
    if (match?.groups) {
      const nodeID = parseInt(match.groups["nodeId"]!);
      return ctx.driver.controller.nodes.has(nodeID) ? "No" : "Yes";
    }

    // Let other prompts fall through to manual handling
    return undefined;
  },
});
