import { BasicCCValues, BinarySwitchCCValues, Duration, MultilevelSwitchCCValues, SubsystemType } from "zwave-js";
import { registerHandler } from "../../prompt-handlers.ts";

// Handler for SET commands with a value and duration
registerHandler(/.*/, {
  onLog: async (ctx) => {
    // Each of those commands is sent as a single log line:
    const match =
      /\* (?<cmd>[A-Z_]+)(?: (to|on) end ?point (?<endpoint>\d+))?:.+Value\s+=\s+(?<targetValue>\d+).+Duration\s+=\s+(?<duration>\d+ )?(?<unit>\w+)/i.exec(
        ctx.logText
      );
    if (!match?.groups) return;

    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    if (!match.groups["targetValue"] || !match.groups["unit"]) {
      return;
    }

    const endpoint = match.groups["endpoint"]
      ? parseInt(match.groups["endpoint"])
      : 0;
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
        node
          .getEndpoint(endpoint)
          ?.commandClasses["Multilevel Switch"].set(targetValue, duration);
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

    let match =
      /\* (?<cmd>[A-Z_]+)(?: (to|on) end ?point (?<endpoint>\d+))?: \* Z-Wave Value = (?<targetValue>(0x)?[a-fA-F0-9]+)/i.exec(
        ctx.logText
      ) ??
      /\* (?<cmd>[A-Z_]+)(?: (to|on) end ?point (?<endpoint>\d+))? with value='(?<targetValue>(0x)?[a-fA-F0-9]+)/.exec(
        ctx.logText
      ) ??
      /\* (?<cmd>[A-Z_]+)(?: (to|on) end ?point (?<endpoint>\d+))?.+value = (?<targetValue>(0x)?[a-fA-F0-9]+)/i.exec(
        ctx.logText
      );

    if (match?.groups?.["cmd"] && match.groups["targetValue"]) {
      const endpoint = match.groups["endpoint"]
        ? parseInt(match.groups["endpoint"])
        : 0;
      const targetValue = parseInt(match.groups["targetValue"]!);
      const ep = node.getEndpoint(endpoint);

      switch (match.groups["cmd"]) {
        case "BARRIER_OPERATOR_SET":
          ep?.commandClasses["Barrier Operator"].set(targetValue);
          return true;

        case "BARRIER_OPERATOR_EVENT_SIGNAL_SET":
          if (ctx.logText.includes("AudibleNotification")) {
            ep?.commandClasses["Barrier Operator"].setEventSignaling(
              SubsystemType.Audible,
              targetValue
            );
            return true;
          }

          if (ctx.logText.includes("VisualNotification")) {
            ep?.commandClasses["Barrier Operator"].setEventSignaling(
              SubsystemType.Visual,
              targetValue
            );
            return true;
          }
          break;

        case "BASIC_SET": {
          node.setValue(BasicCCValues.targetValue.endpoint(endpoint), targetValue);
          return true;
        }

        case "SWITCH_BINARY_SET": {
          node.setValue(
            BinarySwitchCCValues.targetValue.endpoint(endpoint),
            targetValue === 0xff
          );
          return true;
        }

        case "SWITCH_MULTILEVEL_SET": {
          node.setValue(
            MultilevelSwitchCCValues.targetValue.endpoint(endpoint),
            targetValue
          );
          return true;
        }
      }
    }

    // * SWITCH_BINARY_SET with any value
    match =
      /\* (?<cmd>[A-Z_]+)(?: (to|on) end ?point (?<endpoint>\d+))?.+any value/.exec(
        ctx.logText
      );
    if (match?.groups?.["cmd"]) {
      const endpoint = match.groups["endpoint"]
        ? parseInt(match.groups["endpoint"])
        : 0;
      const ep = node.getEndpoint(endpoint);

      switch (match.groups["cmd"]) {
        case "BASIC_SET": {
          const anyValue = Math.round(Math.random() * 99);
          node.setValue(BasicCCValues.targetValue.endpoint(endpoint), anyValue);
          return true;
        }

        case "SWITCH_BINARY_SET": {
          const anyValue = Math.random() > 0.5;
          ep?.commandClasses["Binary Switch"].set(anyValue);
          node.setValue(
            BinarySwitchCCValues.targetValue.endpoint(endpoint),
            anyValue
          );
          return true;
        }

        case "SWITCH_MULTILEVEL_SET": {
          const anyValue = Math.round(Math.random() * 99);
          node.setValue(
            MultilevelSwitchCCValues.targetValue.endpoint(endpoint),
            anyValue
          );
          return true;
        }
      }
    }

    // Let other prompts fall through to manual handling
    return undefined;
  },
});
