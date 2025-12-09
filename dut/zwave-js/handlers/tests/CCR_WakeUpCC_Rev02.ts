import { registerHandler, type PromptContext } from "../../prompt-handlers.ts";

registerHandler("CCR_WakeUpCC_Rev02", {
  onPrompt: async (ctx: PromptContext) => {
    // We use Supervision for Wake Up Interval Set if supported
    if (
      /used Supervision encapsulation for sending the Wake Up Interval Set/i.test(
        ctx.promptText
      )
    ) {
      return "Yes";
    }

    // Let other prompts fall through to manual handling
    return undefined;
  },
});
