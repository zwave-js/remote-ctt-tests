import { InterviewStage } from "zwave-js";
import { registerHandler } from "../../prompt-handlers.ts";

registerHandler(/.*/, {
  // onTestStart: async ({ driver, state }) => {
  //   console.log("[IndicatorCC] Test started, setting up handlers...");
  //   // Set up any driver event listeners needed for this test
  // },

  onPrompt: async (ctx) => {
    if (
      /wait for (the )?(node )?interview to (be )?finish(ed)?/i.test(
        ctx.promptText
      ) ||
      /inclusion (process )?(has )?finish(ed)?/i.test(ctx.promptText) ||
      /inclusion.+finished.+click(ing)?.+OK/i.test(ctx.promptText)
    ) {
      const { driver } = ctx;
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
