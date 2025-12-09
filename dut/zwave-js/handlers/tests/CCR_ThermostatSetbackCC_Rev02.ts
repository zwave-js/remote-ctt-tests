import { SetbackType } from "zwave-js";
import { registerHandler } from "../../prompt-handlers.ts";

// Map setback type names from logs to SetbackType enum values
const setbackTypeToEnum: Record<string, SetbackType> = {
  None: SetbackType.None,
  TemporaryOverride: SetbackType.Temporary,
  PermanentOverride: SetbackType.Permanent,
};

registerHandler("CCR_ThermostatSetbackCC_Rev02", {
  async onLog(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Handle: * THERMOSTAT_SETBACK_SET to Setback Type 'PermanentOverride' with state=-4 Kelvin (0xD8)
    const match =
      /THERMOSTAT_SETBACK_SET to Setback Type '(?<type>\w+)' with state=(?<state>-?\d+) Kelvin/i.exec(
        ctx.logText
      );

    if (match?.groups) {
      const setbackType = setbackTypeToEnum[match.groups.type!];

      if (setbackType !== undefined) {
        await node.commandClasses["Thermostat Setback"].set(
          setbackType,
          parseInt(match.groups.state!)
        );
        return true;
      }
    }
  },
});
