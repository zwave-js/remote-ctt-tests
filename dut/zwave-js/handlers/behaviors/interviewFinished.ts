import { InterviewStage } from "zwave-js";
import { registerHandler } from "../../prompt-handlers.ts";
import { captureUIContext } from "./uiContext.ts";

registerHandler(/.*/, {
  onPrompt: async (ctx) => {
    if (
      /wait for (the )?(node )?interview to (be )?finish(ed)?/i.test(
        ctx.promptText
      ) ||
      /inclusion (process )?(has )?finish(ed)?/i.test(ctx.promptText) ||
      /inclusion.+finished.+click(ing)?.+OK/i.test(ctx.promptText) ||
      /Inclusion and interview passed.+click 'OK'/i.test(ctx.promptText) ||
      /wait.+dut is ready/i.test(ctx.promptText)
    ) {
      const { driver } = ctx;

      // Capture UI context before responding (e.g., "visit the Basic Command Class visualisation")
      captureUIContext(ctx.promptText, ctx.state);

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
