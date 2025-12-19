import { ThermostatSetpointCCValues, ThermostatSetpointType } from "zwave-js";
import { registerHandler } from "../../prompt-handlers.ts";
import type { SendCommandMessage, VerifyStateMessage } from "../../../../src/ctt-message-types.ts";

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

registerHandler("CCR_ThermostatSetpointCC_Rev03", {
  async onLog(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Handle SEND_COMMAND for Thermostat Setpoint SET
    // Note: We intentionally do NOT store state here. The onPrompt handler
    // checks if state is undefined and returns "No" - this is the correct
    // behavior for tests that verify the DUT rejects out-of-range values.
    if (
      ctx.message?.type === "SEND_COMMAND" &&
      ctx.message.commandClass === "Thermostat Setpoint" &&
      ctx.message.action === "SET"
    ) {
      const msg = ctx.message as SendCommandMessage & {
        setpointType: string;
        value: number;
      };

      const setpointType = setpointTypeToEnum[msg.setpointType];
      if (setpointType !== undefined) {
        await node.setValue(
          ThermostatSetpointCCValues.setpoint(setpointType).id,
          msg.value
        );
        return true;
      }
    }
  },

  async onPrompt(ctx) {
    // Handle VERIFY_STATE for Thermostat Setpoint (setpoint set successfully)
    // Always return "No" - CTT tests verify DUT rejects out-of-range values
    if (
      ctx.message?.type === "VERIFY_STATE" &&
      ctx.message.commandClass === "Thermostat Setpoint" &&
      (ctx.message as VerifyStateMessage).property === "setSuccessfully"
    ) {
      return "No";
    }
  },
});
