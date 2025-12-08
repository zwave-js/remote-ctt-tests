import { SubsystemType } from "zwave-js";
import { registerHandler } from "../../prompt-handlers.ts";

registerHandler(/.*/, {
  onLog: async (ctx) => {
    // Each of those sommands is sent as a single log line:
    const match =
      /\* (?<cmd>[A-Z_]+) with value='(?<targetValue>(0x)?[a-fA-F0-9]+)/.exec(
        ctx.logText
      );
    if (!match?.groups) return;

    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    const targetValue = parseInt(match.groups["targetValue"]!);

    switch (match.groups["cmd"]) {
      case "BARRIER_OPERATOR_SET":
        node.commandClasses["Barrier Operator"].set(targetValue);
        return;

      case "BARRIER_OPERATOR_EVENT_SIGNAL_SET":
        if (ctx.logText.includes("AudibleNotification")) {
          node.commandClasses["Barrier Operator"].setEventSignaling(
            SubsystemType.Audible,
            targetValue
          );
          return;
        }

        if (ctx.logText.includes("VisualNotification")) {
          node.commandClasses["Barrier Operator"].setEventSignaling(
            SubsystemType.Visual,
            targetValue
          );
          return;
        }
        break;

      case "BASIC_SET": {
        node.commandClasses.Basic.set(targetValue);
        return;
      }

      case "SWITCH_BINARY_SET": {
        node.commandClasses["Binary Switch"].set(targetValue === 0xff);
        return;
      }

      case "SWITCH_MULTILEVEL_SET": {
        node.commandClasses["Multilevel Switch"].set(targetValue);
        return;
      }
    }

    // Let other prompts fall through to manual handling
    return undefined;
  },
});
