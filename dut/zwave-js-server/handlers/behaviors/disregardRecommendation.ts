import {
  registerHandler,
  type PromptResponse,
} from "../../prompt-handlers.ts";

// Rules for how to respond based on recommendation type
const rules: Record<string, PromptResponse> = {
  INDICATOR_REPORT_IN_AGI: "Yes",
};

registerHandler(/.*/, {
  onPrompt: async (ctx) => {
    if (ctx.message?.type !== "SHOULD_DISREGARD_RECOMMENDATION") {
      return undefined;
    }

    const rule = rules[ctx.message.recommendationType];
    return rule ?? undefined;
  },
});
