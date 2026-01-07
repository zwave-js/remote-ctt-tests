import {
  BasicCCValues,
  BinarySwitchCCValues,
  Duration,
  MultilevelSwitchCCValues,
  SubsystemType,
} from "zwave-js";
import { registerHandler } from "../../prompt-handlers.ts";
import type {
  SendCommandMessage,
  DurationValue,
} from "../../../../src/ctt-message-types.ts";

// Helper to convert DurationValue to zwave-js Duration
function toDuration(duration: DurationValue): Duration {
  if (duration === "default") {
    return Duration.default();
  }
  return new Duration(duration.value, duration.unit);
}

// Handler for SEND_COMMAND messages (from logs - fire and forget)
registerHandler(/.*/, {
  onLog: async (ctx) => {
    if (ctx.message?.type !== "SEND_COMMAND") return;

    const msg = ctx.message as SendCommandMessage;
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    const endpoint = msg.endpoint ?? 0;
    const ep = node.getEndpoint(endpoint);

    switch (msg.commandClass) {
      case "Basic": {
        if (msg.action === "SET") {
          const targetValue =
            msg.targetValue === "any"
              ? Math.round(Math.random() * 99)
              : msg.targetValue;
          node.setValue(BasicCCValues.targetValue.endpoint(endpoint), targetValue);
          return true;
        }
        break;
      }

      case "Binary Switch": {
        if (msg.action === "SET") {
          const targetValue =
            msg.targetValue === "any" ? Math.random() > 0.5 : msg.targetValue;
          ep?.commandClasses["Binary Switch"].set(targetValue);
          node.setValue(
            BinarySwitchCCValues.targetValue.endpoint(endpoint),
            targetValue
          );
          return true;
        }
        break;
      }

      case "Multilevel Switch": {
        if (msg.action === "SET") {
          const targetValue =
            msg.targetValue === "any"
              ? Math.round(Math.random() * 99)
              : msg.targetValue;

          // Handle duration if specified
          if (msg.duration !== undefined) {
            const duration = toDuration(msg.duration);
            ep?.commandClasses["Multilevel Switch"].set(targetValue, duration);
          } else {
            node.setValue(
              MultilevelSwitchCCValues.targetValue.endpoint(endpoint),
              targetValue
            );
          }
          return true;
        }
        break;
      }

      case "Barrier Operator": {
        if (msg.action === "SET") {
          const targetValue =
            msg.targetValue === "Open"
              ? 0xff
              : msg.targetValue === "Close"
              ? 0x00
              : msg.targetValue;
          ep?.commandClasses["Barrier Operator"].set(targetValue);
          return true;
        }

        if (msg.action === "SET_EVENT_SIGNALING") {
          const subsystem =
            msg.subsystem === "Audible"
              ? SubsystemType.Audible
              : SubsystemType.Visual;
          ep?.commandClasses["Barrier Operator"].setEventSignaling(
            subsystem,
            msg.value
          );
          return true;
        }
        break;
      }

      case "any": {
        // "Send any S2 command" - just send a Basic SET with random value
        if (msg.action === "any") {
          node.commandClasses.Basic.set(Math.round(Math.random() * 99));
          return true;
        }
        break;
      }
    }

    // Let other command types fall through
    return undefined;
  },

  // Also handle SEND_COMMAND messages from prompts (some require response after sending)
  onPrompt: async (ctx) => {
    if (ctx.message?.type !== "SEND_COMMAND") return;

    const msg = ctx.message as SendCommandMessage;
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // For "any" commands (like "send any S2 command"), send and respond Ok
    if (msg.commandClass === "any" && msg.action === "any") {
      setTimeout(() => {
        node.commandClasses.Basic.set(Math.round(Math.random() * 99));
      }, 100);
      return "Ok";
    }

    return undefined;
  },
});
