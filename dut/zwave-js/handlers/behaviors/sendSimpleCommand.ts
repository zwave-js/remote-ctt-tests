import { BasicCCValues, BinarySwitchCCValues, Duration, MultilevelSwitchCCValues, SubsystemType } from "zwave-js";
import { registerHandler } from "../../prompt-handlers.ts";

// Handler for SET commands with a value and duration
registerHandler(/.*/, {
  onLog: async (ctx) => {
    // Each of those sommands is sent as a single log line:
    const match =
      /\* (?<cmd>[A-Z_]+):.+Value\s+=\s+(?<targetValue>\d+).+Duration\s+=\s+(?<duration>\d+ )?(?<unit>\w+)/i.exec(
        ctx.logText
      );
    if (!match?.groups) return;

    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    if (!match.groups["targetValue"] || !match.groups["unit"]) {
      return;
    }

    const targetValue = parseInt(match.groups["targetValue"]!);
    const durationRaw = parseInt(match.groups["duration"]!);
    const unit = match.groups["unit"]!;
    let duration =
      unit === "instantly"
        ? new Duration(0, "seconds")
        : unit.includes("default") || unit.includes("factory")
        ? Duration.default()
        : unit === "seconds"
        ? new Duration(durationRaw, "seconds")
        : new Duration(durationRaw, "minutes");

    switch (match.groups["cmd"]) {
      case "SWITCH_MULTILEVEL_SET": {
        node.commandClasses["Multilevel Switch"].set(targetValue, duration);
        return true;
      }
    }

    // Let other prompts fall through to manual handling
    return undefined;
  },
});

// Handler for SET commands with a specific value.
// Must come after the ones with a duration so those get parsed correctly
registerHandler(/.*/, {
  onLog: async (ctx) => {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Each of those sommands is sent as a single log line:
    let match =
      /\* (?<cmd>[A-Z_]+) with value='(?<targetValue>(0x)?[a-fA-F0-9]+)/.exec(
        ctx.logText
      ) ??
      /\* (?<cmd>[A-Z_]+).+value = (?<targetValue>(0x)?[a-fA-F0-9]+)/i.exec(
        ctx.logText
      );

    if (match?.groups?.["cmd"] && match.groups["targetValue"]) {
      const targetValue = parseInt(match.groups["targetValue"]!);

      switch (match.groups["cmd"]) {
        case "BARRIER_OPERATOR_SET":
          node.commandClasses["Barrier Operator"].set(targetValue);
          return true;

        case "BARRIER_OPERATOR_EVENT_SIGNAL_SET":
          if (ctx.logText.includes("AudibleNotification")) {
            node.commandClasses["Barrier Operator"].setEventSignaling(
              SubsystemType.Audible,
              targetValue
            );
            return true;
          }

          if (ctx.logText.includes("VisualNotification")) {
            node.commandClasses["Barrier Operator"].setEventSignaling(
              SubsystemType.Visual,
              targetValue
            );
            return true;
          }
          break;

        case "BASIC_SET": {
          node.setValue(BasicCCValues.targetValue.id, targetValue);
          return true;
        }

        case "SWITCH_BINARY_SET": {
          node.setValue(BinarySwitchCCValues.targetValue.id, targetValue === 0xff);
          return true;
        }

        case "SWITCH_MULTILEVEL_SET": {
          node.setValue(MultilevelSwitchCCValues.targetValue.id, targetValue);
          return true;
        }
      }
    }

    // * SWITCH_BINARY_SET with any value
    match = /\* (?<cmd>[A-Z_]+).+any value/.exec(ctx.logText);
    if (match?.groups?.["cmd"]) {
      switch (match.groups["cmd"]) {
        case "BASIC_SET": {
          const anyValue = Math.round(Math.random() * 99);
          node.setValue(BasicCCValues.targetValue.id, anyValue);
          return true;
        }

        case "SWITCH_BINARY_SET": {
          const anyValue = Math.random() > 0.5;
          node.commandClasses["Binary Switch"].set(anyValue);
          node.setValue(BinarySwitchCCValues.targetValue.id, anyValue);
          return true;
        }

        case "SWITCH_MULTILEVEL_SET": {
          const anyValue = Math.round(Math.random() * 99);
          node.setValue(MultilevelSwitchCCValues.targetValue.id, anyValue);
          return true;
        }
      }
    }

    // Let other prompts fall through to manual handling
    return undefined;
  },
});
