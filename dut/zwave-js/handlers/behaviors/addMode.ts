import {
  createDeferredPromise,
  type DeferredPromise,
} from "alcalzone-shared/deferred-promise";
import { registerHandler } from "../../prompt-handlers.ts";
import { InclusionStrategy, type InclusionOptions, type ZWaveNode } from "zwave-js";
import { wait } from "alcalzone-shared/async";

const PIN_PROMISE = "pin promise";

// Module-level variable to track cleanup function (persists across test state clears)
let currentNodeAddedCleanup: (() => void) | undefined;

registerHandler(/.*/, {
  onTestStart: async () => {
    // Clean up any leftover listener from previous test
    if (currentNodeAddedCleanup) {
      currentNodeAddedCleanup();
      currentNodeAddedCleanup = undefined;
    }
  },

  onPrompt: async (ctx) => {
    // Handle ACTIVATE_NETWORK_MODE for ADD mode
    if (
      ctx.message?.type === "ACTIVATE_NETWORK_MODE" &&
      ctx.message.mode === "ADD"
    ) {
      const { driver, state, message } = ctx;
      state.set(PIN_PROMISE, createDeferredPromise<string>());

      // Clean up any existing listener first
      if (currentNodeAddedCleanup) {
        currentNodeAddedCleanup();
        currentNodeAddedCleanup = undefined;
      }

      let inclusionOptions: InclusionOptions;
      if (message.forceS0) {
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
      const onNodeAdded = (node: ZWaveNode) => {
        ctx.includedNodes.push(node);
      };
      driver.controller.on("node added", onNodeAdded);
      currentNodeAddedCleanup = () => {
        driver.controller.off("node added", onNodeAdded);
      };

      return "Ok";
    }

    // Let other prompts fall through to manual handling
    return undefined;
  },

  onLog: async (ctx) => {
    if (ctx.message?.type === "S2_PIN_CODE") {
      const pinPromise = ctx.state.get(PIN_PROMISE) as
        | DeferredPromise<string>
        | undefined;
      if (!pinPromise) return;

      console.log("Detected PIN code:", ctx.message.pin);
      pinPromise.resolve(ctx.message.pin);
      return true;
    }
  },
});
