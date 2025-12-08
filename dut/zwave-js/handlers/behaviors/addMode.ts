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
import { wait } from "alcalzone-shared/async";

const PIN_PROMISE = "pin promise";

registerHandler(/.*/, {
  onPrompt: async (ctx) => {
    // Auto-click Ok for "observe the DUT" prompts
    if (ctx.promptText.toLowerCase().includes("activate the add mode")) {
      const { driver, state } = ctx;
      state.set(PIN_PROMISE, createDeferredPromise<string>());

      for (let attempt = 1; attempt <= 5; attempt++) {
        const inclusionStarted = await driver.controller.beginInclusion({
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

        if (inclusionStarted) break;

        // Backoff in case another in-/exclusion process is still busy
        if (attempt < 5) {
          await wait(1000 * attempt);
        } else {
          throw new Error("Failed to start inclusion after 5 attempts");
        }
      }

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
