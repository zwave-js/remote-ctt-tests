import { SetbackType } from "zwave-js";
import { registerHandler } from "../../prompt-handlers.ts";
import type { SendCommandMessage } from "../../../../src/ctt-message-types.ts";

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

    // Handle SEND_COMMAND for Thermostat Setback SET
    if (
      ctx.message?.type === "SEND_COMMAND" &&
      ctx.message.commandClass === "Thermostat Setback" &&
      ctx.message.action === "SET"
    ) {
      const msg = ctx.message as SendCommandMessage & {
        setbackType: string;
        stateKelvin: number;
      };

      const setbackType = setbackTypeToEnum[msg.setbackType];
      if (setbackType !== undefined) {
        await node.commandClasses["Thermostat Setback"].set(
          setbackType,
          msg.stateKelvin
        );
        return true;
      }
    }
  },
});
