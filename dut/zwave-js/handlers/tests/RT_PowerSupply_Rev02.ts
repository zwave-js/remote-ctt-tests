import { registerHandler, type PromptContext } from "../../prompt-handlers.ts";

registerHandler("RT_PowerSupply_Rev02", {
  onPrompt: async (ctx: PromptContext) => {
    // Auto-click Ok for "observe the DUT" prompts
    if (ctx.promptText.includes("Is the DUT mains-powered")) {
      return "Yes";
    }

    // Let other prompts fall through to manual handling
    return undefined;
  },
});
