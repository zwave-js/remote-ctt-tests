/**
 * Handler for CDR_ZWPv2IndicatorCCRequirements_Rev01 test case
 *
 * This test validates Indicator Command Class requirements.
 */

import {
  createDeferredPromise,
  type DeferredPromise,
} from "alcalzone-shared/deferred-promise";
import { registerHandler } from "../../prompt-handlers.ts";
import { InclusionStrategy } from "zwave-js";

const PIN_PROMISE = "pin promise";

registerHandler(/.*/, {
  onPrompt: async (ctx) => {
    // Auto-click Ok for "observe the DUT" prompts
    if (ctx.promptText.toLowerCase().includes("activate the add mode")) {
      const { driver, state } = ctx;
      state.set(PIN_PROMISE, createDeferredPromise<string>());
      await driver.controller.beginInclusion({
        strategy: InclusionStrategy.Default,
        userCallbacks: {
          abort() {},
          async grantSecurityClasses(requested) {
            return requested;
          },
          async validateDSKAndEnterPIN(dsk) {
            console.log("Validating DSK:", dsk);
            const pin = await (state.get(PIN_PROMISE) as Promise<string>);
            console.log("Entering PIN:", pin);
            return pin;
          },
        },
      });

      // Remember all included nodes
      driver.controller.on("node added", (node) => {
        ctx.includedNodes.push(node);
      });

      return "Ok";
    }

    // Let other prompts fall through to manual handling
    return undefined;
  },

  onLog: async (ctx) => {
    const pinPromise = ctx.state.get(PIN_PROMISE) as
      | DeferredPromise<string>
      | undefined;
    if (!pinPromise) return;

    const match = ctx.logText.match(/PIN( Code)?: (?<pin>\d{5})/i);
    const pin = match?.groups?.pin;
    if (pin) {
      console.log("Detected PIN code:", pin);
      pinPromise.resolve(pin);
      // handled
      return true;
    }
  },
});
