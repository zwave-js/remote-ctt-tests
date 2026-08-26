import { ThermostatMode, ThermostatModeCCValues } from "zwave-js";
import { CommandClasses } from "@zwave-js/core";
import { registerHandler } from "../../prompt-handlers.ts";
import type { SendCommandMessage, VerifyStateMessage } from "../../../../src/ctt-message-types.ts";

// Convert number array to hex string for WebSocket transport
function toHexString(data: number[]): string {
  return data.map((b) => b.toString(16).padStart(2, "0")).join("");
}

// Map UPPER_CASE mode names from logs to ThermostatMode enum values
const modeNameToEnum: Record<string, ThermostatMode> = {
  OFF: ThermostatMode["Off"],
  HEAT: ThermostatMode["Heat"],
  COOL: ThermostatMode["Cool"],
  AUTO: ThermostatMode["Auto"],
  AUXILIARY: ThermostatMode["Auxiliary"],
  RESUME: ThermostatMode["Resume (on)"],
  FAN: ThermostatMode["Fan"],
  FURNACE: ThermostatMode["Furnace"],
  DRY: ThermostatMode["Dry"],
  MOIST: ThermostatMode["Moist"],
  AUTO_CHANGEOVER: ThermostatMode["Auto changeover"],
  ENERGY_HEAT: ThermostatMode["Energy heat"],
  ENERGY_COOL: ThermostatMode["Energy cool"],
  AWAY: ThermostatMode["Away"],
  FULL_POWER: ThermostatMode["Full power"],
  MANUFACTURER_SPECIFIC: ThermostatMode["Manufacturer specific"],
};

registerHandler("CCR_ThermostatModeCC_Rev02", {
  async onLog(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    const { client } = ctx;

    // Handle SEND_COMMAND for Thermostat Mode SET
    if (
      ctx.message?.type === "SEND_COMMAND" &&
      ctx.message.commandClass === "Thermostat Mode"
    ) {
      const msg = ctx.message as SendCommandMessage;
      if (msg.action === "SET") {
        const { mode, manufacturerData } = msg as {
          mode: string;
          manufacturerData?: number[];
        };
        const modeEnum = modeNameToEnum[mode];

        if (modeEnum === undefined) return;

        if (modeEnum === ThermostatMode["Manufacturer specific"]) {
          if (manufacturerData !== undefined) {
            await client.sendCommand("endpoint.invoke_cc_api", {
              nodeId: node.id,
              endpoint: 0,
              commandClass: CommandClasses["Thermostat Mode"],
              methodName: "set",
              // Convert to hex string for WebSocket transport (server accepts string | Uint8Array)
              args: [modeEnum, toHexString(manufacturerData)],
            });
          }
          // Skip if manufacturer specific without data
        } else {
          await client.sendCommand("endpoint.invoke_cc_api", {
            nodeId: node.id,
            endpoint: 0,
            commandClass: CommandClasses["Thermostat Mode"],
            methodName: "set",
            args: [modeEnum],
          });
        }
        return true;
      }
    }
  },

  async onPrompt(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Handle VERIFY_STATE for thermostat mode
    if (
      ctx.message?.type === "VERIFY_STATE" &&
      ctx.message.commandClass === "Thermostat Mode"
    ) {
      const msg = ctx.message as VerifyStateMessage;
      const expected =
        typeof msg.expected === "number"
          ? msg.expected
          : parseInt(String(msg.expected), 16);
      const actual = node.getValue(ThermostatModeCCValues.thermostatMode.id);

      return actual === expected ? "Yes" : "No";
    }
  },
});
