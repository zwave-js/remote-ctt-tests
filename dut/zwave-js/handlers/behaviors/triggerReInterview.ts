/**
 * Handler for CDR_ZWPv2IndicatorCCRequirements_Rev01 test case
 *
 * This test validates Indicator Command Class requirements.
 */

import { registerHandler } from "../../prompt-handlers.ts";

registerHandler(/.*/, {
  // onTestStart: async ({ driver, state }) => {
  //   console.log("[IndicatorCC] Test started, setting up handlers...");
  //   // Set up any driver event listeners needed for this test
  // },

  onPrompt: async (ctx) => {
    if (ctx.promptText.includes("trigger a capability discovery")) {
      const { driver } = ctx;

      const nodeId = /for node (\d+)/.exec(ctx.promptText)?.[1];
      if (!nodeId) return undefined;
      const node = driver.controller.nodes.get(parseInt(nodeId));
      if (!node) return undefined;

      // Trigger re-interview after pressing OK
      setTimeout(() => {
        node.refreshInfo();
      }, 10);
      return "Ok";
    }

    // Let other prompts fall through to manual handling
    return undefined;
  },
});
