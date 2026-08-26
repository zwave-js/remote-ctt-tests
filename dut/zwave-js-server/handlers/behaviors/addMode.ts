/**
 * Handler for add mode prompts
 *
 * Automates Z-Wave node inclusion (adding devices to the network).
 * For S2 inclusion, uses event-driven flow via WebSocket:
 * 1. Send controller.begin_inclusion
 * 2. Listen for "grant security classes" event and respond
 * 3. Wait for PIN from CTT log message
 * 4. Listen for "validate dsk and enter pin" event and respond with PIN
 */

import {
  createDeferredPromise,
  type DeferredPromise,
} from "alcalzone-shared/deferred-promise";
import { registerHandler } from "../../prompt-handlers.ts";
import { wait } from "alcalzone-shared/async";
import { InclusionStrategy } from "zwave-js";

const PIN_PROMISE = "pin promise";

// Module-level variable to track cleanup function (persists across test state clears)
let currentInclusionCleanup: (() => void) | undefined;

registerHandler(/.*/, {
  onTestStart: async () => {
    // Clean up any leftover listeners from previous tests
    if (currentInclusionCleanup) {
      currentInclusionCleanup();
      currentInclusionCleanup = undefined;
    }
  },

  onPrompt: async (ctx) => {
    // Handle ACTIVATE_NETWORK_MODE for ADD mode
    if (
      ctx.message?.type === "ACTIVATE_NETWORK_MODE" &&
      ctx.message.mode === "ADD"
    ) {
      const { client, state, message } = ctx;
      state.set(PIN_PROMISE, createDeferredPromise<string>());

      // Clean up any existing listeners first
      if (currentInclusionCleanup) {
        currentInclusionCleanup();
        currentInclusionCleanup = undefined;
      }

      // Set up S2 inclusion event handlers
      const grantSecurityClasses = async (data: { requested: unknown }) => {
        await client.sendCommand("controller.grant_security_classes", {
          inclusionGrant: data.requested,
        });
      };

      const validateDsk = async () => {
        const pinPromise = state.get(PIN_PROMISE) as DeferredPromise<string> | undefined;
        if (pinPromise) {
          const pin = await pinPromise;
          await client.sendCommand("controller.validate_dsk_and_enter_pin", {
            pin,
          });
        }
      };

      const cleanup = () => {
        client.off("grant security classes", grantSecurityClasses);
        client.off("validate dsk and enter pin", validateDsk);
        client.off("node added", onNodeAdded);
        currentInclusionCleanup = undefined;
      };

      const onNodeAdded = () => {
        cleanup();
      };

      // Note: We do NOT clean up on "inclusion stopped" because that event fires
      // after the initial NWI phase but BEFORE S2 negotiation completes.
      // The S2 events (grant security classes, validate dsk) come after "inclusion stopped".

      client.on("grant security classes", grantSecurityClasses);
      client.on("validate dsk and enter pin", validateDsk);
      client.on("node added", onNodeAdded);

      // Store cleanup function at module level
      currentInclusionCleanup = cleanup;

      // Determine inclusion strategy based on forceS0 flag
      const strategy = message.forceS0
        ? InclusionStrategy.Security_S0
        : InclusionStrategy.Default;

      for (let attempt = 1; attempt <= 5; attempt++) {
        try {
          const result = await client.sendCommand("controller.begin_inclusion", {
            options: {
              strategy,
            },
          });

          if ((result as { success: boolean }).success !== false) break;
        } catch (error) {
          console.error(`Inclusion attempt ${attempt} failed:`, error);
        }

        // Backoff in case another in-/exclusion process is still busy
        if (attempt < 5) {
          await wait(1000 * attempt);
        } else {
          throw new Error("Failed to start inclusion after 5 attempts");
        }
      }

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
