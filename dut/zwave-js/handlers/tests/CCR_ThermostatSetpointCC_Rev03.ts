import { ThermostatSetpointCCValues, ThermostatSetpointType } from "zwave-js";
import { wait } from "alcalzone-shared/async";
import { registerHandler } from "../../prompt-handlers.ts";

// CTT uses Z-Wave JS names without spaces (e.g., "FullPower" instead of "Full Power")
const setpointTypeToEnum: Record<string, ThermostatSetpointType> = {
  Heating: ThermostatSetpointType["Heating"],
  Cooling: ThermostatSetpointType["Cooling"],
  Furnace: ThermostatSetpointType["Furnace"],
  DryAir: ThermostatSetpointType["Dry Air"],
  MoistAir: ThermostatSetpointType["Moist Air"],
  AutoChangeover: ThermostatSetpointType["Auto Changeover"],
  EnergySaveHeating: ThermostatSetpointType["Energy Save Heating"],
  EnergySaveCooling: ThermostatSetpointType["Energy Save Cooling"],
  AwayHeating: ThermostatSetpointType["Away Heating"],
  AwayCooling: ThermostatSetpointType["Away Cooling"],
  FullPower: ThermostatSetpointType["Full Power"],
};

const LAST_SETPOINT_TYPE = "lastSetpointType";
const LAST_SETPOINT_VALUE = "lastSetpointValue";

registerHandler("CCR_ThermostatSetpointCC_Rev03", {
  async onLog(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Handle: * THERMOSTAT_SETPOINT_SET for Setpoint Type 'Cooling' with value=22 °C
    const setMatch =
      /THERMOSTAT_SETPOINT_SET.+Type '(?<type>\w+)'.+value=(?<value>[\d.]+)/i.exec(
        ctx.logText
      ) ??
      /Setpoint for type '(?<type>\w+)' to (?<value>[\d.]+)/i.exec(ctx.logText);

    if (setMatch?.groups) {
      const setpointType = setpointTypeToEnum[setMatch.groups.type!];
      const value = parseFloat(setMatch.groups.value!);

      if (setpointType !== undefined) {
        await node.setValue(
          ThermostatSetpointCCValues.setpoint(setpointType).id,
          value
        );
        return true;
      }
    }
  },

  async onPrompt(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Handle: Has the Setpoint been set successfully? (with typos)
    if (/setpoint.+set succ?essfully/i.test(ctx.promptText)) {
      await wait(1000);

      const setpointType = ctx.state.get(LAST_SETPOINT_TYPE) as
        | ThermostatSetpointType
        | undefined;
      const expected = ctx.state.get(LAST_SETPOINT_VALUE) as number | undefined;

      if (setpointType === undefined || expected === undefined) {
        return "No";
      }

      const actual = node.getValue(
        ThermostatSetpointCCValues.setpoint(setpointType).id
      );

      return actual === expected ? "Yes" : "No";
    }
  },
});
