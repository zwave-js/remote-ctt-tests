/**
 * Handler for CDR_ZWPv2IndicatorCCRequirements_Rev01 test case
 *
 * This test validates Indicator Command Class requirements.
 */

import { registerHandler } from "../../prompt-handlers.ts";

const IDENTIFY_EMITTED = "identify event emitted";

registerHandler("CDR_ZWPv2IndicatorCCRequirements_Rev01", {
  onTestStart: async (ctx) => {
    // Set up identify event listener when test starts
    ctx.driver.controller.once("identify", () => {
      ctx.state.set(IDENTIFY_EMITTED, true);
    });
  },

  onPrompt: async (ctx) => {
    // Handle VERIFY_INDICATOR_IDENTIFY
    if (ctx.message?.type === "VERIFY_INDICATOR_IDENTIFY") {
      return ctx.state.get(IDENTIFY_EMITTED) ? "Yes" : "No";
    }

    return undefined;
  },
});
