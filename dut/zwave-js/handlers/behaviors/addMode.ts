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
import { SecurityClass } from "@zwave-js/core";
import { wait } from "alcalzone-shared/async";

const PIN_PROMISE = "pin promise";
const PIN_CODE = "pin code";
const S2_REQUESTED_CLASSES = "S2 requested security classes";
const S2_GRANTED_CLASSES = "S2 granted security classes";
const S2_PIN_REQUESTED = "S2 PIN requested";
const GRANT_NO_CLASSES = "grant no security classes";

export function resetS2InteractionObservations(
  state: Map<string, unknown>
): void {
  state.delete(S2_REQUESTED_CLASSES);
  state.delete(S2_GRANTED_CLASSES);
  state.delete(S2_PIN_REQUESTED);
}

// The CTT asks the DUT to delay its user interaction so the joining node runs into the S2 bootstrapping timeouts
async function applyS2InteractionDelay(
  state: Map<string, unknown>
): Promise<void> {
  const delay = state.get("S2 interaction delay");
  if (typeof delay === "number") {
    await wait(delay);
  }
}

export async function waitForS2Pin(
  state: Map<string, unknown>
): Promise<string> {
  state.set(S2_PIN_REQUESTED, true);

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
  state: Map<string, unknown>,
  requested: InclusionGrant
): Promise<InclusionGrant> {
  // Record the request before the delay so a check during bootstrapping still sees it
  state.set(S2_REQUESTED_CLASSES, [...requested.securityClasses]);
  await applyS2InteractionDelay(state);

  let granted = requested;
  if (state.get(GRANT_NO_CLASSES) === true) {
    granted = { ...requested, securityClasses: [] };
  } else if (state.get("exclude S2 Access") === true) {
    granted = {
      ...requested,
      securityClasses: requested.securityClasses.filter(
        (securityClass) => securityClass !== SecurityClass.S2_AccessControl
      ),
    };
  }

  state.set(S2_GRANTED_CLASSES, [...granted.securityClasses]);
  return granted;
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
      ctx.state.delete(PIN_PROMISE);
      ctx.state.delete(PIN_CODE);
      return "Ok";
    }

    // Handle ACTIVATE_NETWORK_MODE for ADD mode
    if (
      ctx.message?.type === "ACTIVATE_NETWORK_MODE" &&
      ctx.message.mode === "ADD"
    ) {
      const { driver, state, message } = ctx;
      state.delete(PIN_PROMISE);
      resetS2InteractionObservations(state);
      // Keep the policy in state because run.ts also grants keys for inclusions this handler did not start
      if (message.grantNoSecurityClasses) {
        state.set(GRANT_NO_CLASSES, true);
      } else {
        state.delete(GRANT_NO_CLASSES);
      }

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
              const pin = await waitForS2Pin(state);
              await applyS2InteractionDelay(state);
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
      await waitForInclusionIdle(ctx.driver);
      return "Ok";
    }

    if (ctx.message?.type === "CHECK_S2_GRANT_REQUEST") {
      const requested = ctx.state.get(S2_REQUESTED_CLASSES) as
        | SecurityClass[]
        | undefined;
      const granted = ctx.state.get(S2_GRANTED_CLASSES) as
        | SecurityClass[]
        | undefined;
      let answer: boolean;
      switch (ctx.message.check) {
        case "REQUEST_OBSERVED":
          answer = requested !== undefined;
          break;
        case "REQUESTED_S2_AUTHENTICATED":
          answer =
            requested?.includes(SecurityClass.S2_Authenticated) === true;
          break;
        case "ALL_REQUESTED_GRANTED":
          answer =
            requested !== undefined &&
            granted !== undefined &&
            requested.every((securityClass) =>
              granted.includes(securityClass)
            );
          break;
        case "NOT_HIGHEST_SECURITY_WARNING":
          // zwave-js has no user interface to raise this optional warning
          answer = false;
          break;
        case "NO_SECURITY_WARNING":
          answer = granted?.length === 0;
          break;
      }
      return answer ? "Yes" : "No";
    }

    if (ctx.message?.type === "CHECK_S2_PIN_REQUEST") {
      return ctx.state.get(S2_PIN_REQUESTED) === true ? "Yes" : "No";
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
