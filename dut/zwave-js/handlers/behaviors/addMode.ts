import {
  createDeferredPromise,
  type DeferredPromise,
} from "alcalzone-shared/deferred-promise";
import { registerHandler } from "../../prompt-handlers.ts";
import { InclusionStrategy, type InclusionOptions } from "zwave-js";
import { SecurityClass } from "@zwave-js/core";
import { wait } from "alcalzone-shared/async";

export const FORCE_S0 = "force_s0";
const PIN_PROMISE = "pin promise";

registerHandler(/.*/, {
  onPrompt: async (ctx) => {
    if (/Include.+into the DUT network/i.test(ctx.promptText)) {
      // This is an empty prompt, just click Ok to proceed
      return "Ok";
    }

    // Auto-click Ok for "observe the DUT" prompts
    if (ctx.promptText.toLowerCase().includes("activate the add mode")) {
      const { driver, state } = ctx;
      state.set(PIN_PROMISE, createDeferredPromise<string>());

      const forceS0 = state.get(FORCE_S0) === true;
      let inclusionOptions: InclusionOptions;
      if (forceS0) {
        state.delete(FORCE_S0);
        inclusionOptions = {
          strategy: InclusionStrategy.Security_S0,
        };
      } else {
        inclusionOptions = {
          strategy: InclusionStrategy.Default,
          userCallbacks: {
            abort() {},
            async grantSecurityClasses(requested) {
              return requested;
            },
            async validateDSKAndEnterPIN(dsk) {
              const pin = await (state.get(PIN_PROMISE) as Promise<string>);
              return pin;
            },
          },
        };
      }

      for (let attempt = 1; attempt <= 5; attempt++) {
        const inclusionStarted = await driver.controller.beginInclusion(
          inclusionOptions
        );

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
