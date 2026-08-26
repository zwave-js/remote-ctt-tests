/**
 * Handler for sending simple commands
 *
 * Handles SEND_COMMAND messages for various command classes via WebSocket.
 */

import {
  BasicCCValues,
  BinarySwitchCCValues,
  Duration,
  MultilevelSwitchCCValues,
  SubsystemType,
} from "zwave-js";
import { CommandClasses } from "@zwave-js/core";
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
    const { client } = ctx;

    switch (msg.commandClass) {
      case "Basic": {
        if (msg.action === "SET") {
          const targetValue =
            msg.targetValue === "any"
              ? Math.round(Math.random() * 99)
              : msg.targetValue;
          await client.sendCommand("node.set_value", {
            nodeId: node.id,
            valueId: BasicCCValues.targetValue.endpoint(endpoint),
            value: targetValue,
          });
          return true;
        }
        break;
      }

      case "Binary Switch": {
        if (msg.action === "SET") {
          const targetValue =
            msg.targetValue === "any" ? Math.random() > 0.5 : msg.targetValue;
          await client.sendCommand("endpoint.invoke_cc_api", {
            nodeId: node.id,
            endpoint,
            commandClass: CommandClasses["Binary Switch"],
            methodName: "set",
            args: [targetValue],
          });
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
            await client.sendCommand("endpoint.invoke_cc_api", {
              nodeId: node.id,
              endpoint,
              commandClass: CommandClasses["Multilevel Switch"],
              methodName: "set",
              args: [targetValue, duration],
            });
          } else {
            await client.sendCommand("node.set_value", {
              nodeId: node.id,
              valueId: MultilevelSwitchCCValues.targetValue.endpoint(endpoint),
              value: targetValue,
            });
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
          await client.sendCommand("endpoint.invoke_cc_api", {
            nodeId: node.id,
            endpoint,
            commandClass: CommandClasses["Barrier Operator"],
            methodName: "set",
            args: [targetValue],
          });
          return true;
        }

        if (msg.action === "SET_EVENT_SIGNALING") {
          const subsystem =
            msg.subsystem === "Audible"
              ? SubsystemType.Audible
              : SubsystemType.Visual;
          await client.sendCommand("endpoint.invoke_cc_api", {
            nodeId: node.id,
            endpoint,
            commandClass: CommandClasses["Barrier Operator"],
            methodName: "setEventSignaling",
            args: [subsystem, msg.value],
          });
          return true;
        }
        break;
      }

      case "any": {
        // "Send any S2 command" - just send a Basic SET with random value
        if (msg.action === "any") {
          await client.sendCommand("endpoint.invoke_cc_api", {
            nodeId: node.id,
            endpoint: 0,
            commandClass: CommandClasses.Basic,
            methodName: "set",
            args: [Math.round(Math.random() * 99)],
          });
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

    const { client } = ctx;

    // For "any" commands (like "send any S2 command"), send and respond Ok
    if (msg.commandClass === "any" && msg.action === "any") {
      setTimeout(async () => {
        await client.sendCommand("endpoint.invoke_cc_api", {
          nodeId: node.id,
          endpoint: 0,
          commandClass: CommandClasses.Basic,
          methodName: "set",
          args: [Math.round(Math.random() * 99)],
        });
      }, 100);
      return "Ok";
    }

    return undefined;
  },
});
