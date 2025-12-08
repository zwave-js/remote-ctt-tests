/**
 * Handler for CDR_ZWPv2IndicatorCCRequirements_Rev01 test case
 *
 * This test validates Indicator Command Class requirements.
 */

import {
  createDeferredPromise,
  type DeferredPromise,
} from "alcalzone-shared/deferred-promise";
import { registerHandler, type PromptContext } from "../../prompt-handlers.ts";
import { InclusionStrategy } from "zwave-js";

const PIN_PROMISE = "pin promise";

registerHandler(/.*/, {
  onPrompt: async (ctx) => {
    if (ctx.promptText.toLowerCase().includes("activate the remove mode")) {
      const { driver } = ctx;
      await driver.controller.beginExclusion();
      return "Ok";
    }

    // Let other prompts fall through to manual handling
    return undefined;
  },
});
