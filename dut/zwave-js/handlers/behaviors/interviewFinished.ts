import { InterviewStage } from "zwave-js";
import { registerHandler } from "../../prompt-handlers.ts";
import { UI_CONTEXT, type UIContext } from "./uiContext.ts";

registerHandler(/.*/, {
  onPrompt: async (ctx) => {
    if (ctx.message?.type === "WAIT_FOR_INTERVIEW") {
      const { driver } = ctx;

      // Capture embedded UI context if present
      if (ctx.message.uiContext) {
        ctx.state.set(UI_CONTEXT, {
          commandClass: ctx.message.uiContext.commandClass,
          nodeId: ctx.message.uiContext.nodeId,
        } satisfies UIContext);
      }

      if (
        ctx.includedNodes.at(-1)?.interviewStage === InterviewStage.Complete
      ) {
        return "Ok";
      }

      return new Promise((resolve) => {
        driver.once("node interview completed", () => {
          resolve("Ok");
        });
      });
    }

    // Let other prompts fall through to manual handling
    return undefined;
  },
});
