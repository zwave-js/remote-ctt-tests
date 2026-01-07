import { registerHandler } from "../../prompt-handlers.ts";
import { UI_CONTEXT, type UIContext } from "./uiContext.ts";

registerHandler(/.*/, {
  onPrompt: async (ctx) => {
    if (ctx.message?.type === "WAIT_FOR_INTERVIEW") {
      const { client } = ctx;

      // Capture embedded UI context if present
      if (ctx.message.uiContext) {
        ctx.state.set(UI_CONTEXT, {
          commandClass: ctx.message.uiContext.commandClass,
          nodeId: ctx.message.uiContext.nodeId,
        } satisfies UIContext);
      }

      // Check if the last node's interview is already complete
      const lastNode = ctx.includedNodes.at(-1);
      if (lastNode?.interviewComplete) {
        return "Ok";
      }

      // Wait for interview completed event
      return new Promise((resolve) => {
        client.once("node interview completed", () => {
          resolve("Ok");
        });
      });
    }

    // Let other prompts fall through to manual handling
    return undefined;
  },
});
