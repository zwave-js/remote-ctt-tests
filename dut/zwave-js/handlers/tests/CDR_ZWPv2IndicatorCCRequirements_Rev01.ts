/**
 * Handler for CDR_ZWPv2IndicatorCCRequirements_Rev01 test case
 *
 * This test validates Indicator Command Class requirements.
 */

import { registerHandler, type PromptContext } from "../../prompt-handlers.ts";

const IDENTIFY_EMITTED = "identify event emitted";

registerHandler("CDR_ZWPv2IndicatorCCRequirements_Rev01", {
  onPrompt: async (ctx: PromptContext) => {
    // Auto-click Ok for "observe the DUT" prompts
    if (ctx.promptText.includes("observe the DUT")) {
      ctx.driver.controller.once("identify", () => {
        ctx.state.set(IDENTIFY_EMITTED, true);
      });
      return "Ok";
    }

    if (/did .+ indicator .+ blink \w+ times/i.test(ctx.promptText)) {
      return ctx.state.get(IDENTIFY_EMITTED) ? "Yes" : "No";
    }

    // Let other prompts fall through to manual handling
    return undefined;
  },
});
