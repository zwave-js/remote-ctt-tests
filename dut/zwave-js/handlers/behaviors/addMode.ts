import {
  createDeferredPromise,
  type DeferredPromise,
} from "alcalzone-shared/deferred-promise";
import { registerHandler } from "../../prompt-handlers.ts";
import {
  InclusionStrategy,
  InclusionState,
  type InclusionGrant,
  type Driver,
  type InclusionOptions,
} from "zwave-js";
import { wait } from "alcalzone-shared/async";

const PIN_PROMISE = "pin promise";
const PIN_CODE = "pin code";

export async function waitForS2Pin(
  state: Map<string, unknown>
): Promise<string> {
  const bufferedPin = state.get(PIN_CODE);
  if (typeof bufferedPin === "string") {
    state.delete(PIN_CODE);
    return bufferedPin;
  }

  let pinPromise = state.get(PIN_PROMISE) as
    | DeferredPromise<string>
    | undefined;
  if (!pinPromise) {
    pinPromise = createDeferredPromise<string>();
    state.set(PIN_PROMISE, pinPromise);
  }
  const pin = await pinPromise;
  state.delete(PIN_PROMISE);
  return pin;
}

export async function grantS2SecurityClasses(
  _state: Map<string, unknown>,
  requested: InclusionGrant
): Promise<InclusionGrant> {
  return requested;
}

export function waitForInclusionIdle(driver: Driver): Promise<void> {
  const { controller } = driver;
  const isActive = () =>
    controller.inclusionState === InclusionState.Including ||
    controller.inclusionState === InclusionState.Excluding ||
    controller.inclusionState === InclusionState.Busy;
  if (!isActive()) return Promise.resolve();

  return new Promise<void>((resolve) => {
    const onStateChanged = () => {
      if (!isActive()) {
        controller.off("inclusion state changed", onStateChanged);
        resolve();
      }
    };
    controller.on("inclusion state changed", onStateChanged);
  });
}

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
              return grantS2SecurityClasses(state, requested);
            },
            async validateDSKAndEnterPIN() {
              return waitForS2Pin(state);
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
      await waitForInclusionIdle(ctx.driver);
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
      if (!pinPromise) {
        ctx.state.set(PIN_CODE, ctx.message.pin);
        return true;
      }

      console.log("Detected PIN code:", ctx.message.pin);
      pinPromise.resolve(ctx.message.pin);
      return true;
    }
  },
});
