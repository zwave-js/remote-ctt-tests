import {
  createDeferredPromise,
  type DeferredPromise,
} from "alcalzone-shared/deferred-promise";
import { registerHandler } from "../../prompt-handlers.ts";
import {
  InclusionStrategy,
  InclusionState,
  type InclusionOptions,
} from "zwave-js";
import { wait } from "alcalzone-shared/async";

const PIN_PROMISE = "pin promise";

registerHandler(/.*/, {
  onPrompt: async (ctx) => {
    if (
      ctx.message?.type === "ACTIVATE_NETWORK_MODE" &&
      ctx.message.mode === "STOP_ADD"
    ) {
      await ctx.driver.controller.stopInclusion();
      return "Ok";
    }

    // Handle ACTIVATE_NETWORK_MODE for ADD mode
    if (
      ctx.message?.type === "ACTIVATE_NETWORK_MODE" &&
      ctx.message.mode === "ADD"
    ) {
      const { driver, state, message } = ctx;
      state.set(PIN_PROMISE, createDeferredPromise<string>());

      let inclusionOptions: InclusionOptions;
      if (
        message.forceS0 ||
        state.get("force S0 inclusion") === true
      ) {
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

      return "Ok";
    }

    if (ctx.message?.type === "WAIT_FOR_INCLUSION_IDLE") {
      const isActive = () =>
        ctx.driver.controller.inclusionState === InclusionState.Including ||
        ctx.driver.controller.inclusionState === InclusionState.Excluding ||
        ctx.driver.controller.inclusionState === InclusionState.Busy;
      if (!isActive()) return "Ok";

      await new Promise<void>((resolve) => {
        const onStateChanged = () => {
          if (!isActive()) {
            ctx.driver.controller.off("inclusion state changed", onStateChanged);
            resolve();
          }
        };
        ctx.driver.controller.on("inclusion state changed", onStateChanged);
        onStateChanged();
      });
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
