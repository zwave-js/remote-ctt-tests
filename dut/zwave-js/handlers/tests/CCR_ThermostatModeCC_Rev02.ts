import { ThermostatMode, ThermostatModeCCValues } from "zwave-js";
import { Bytes } from "@zwave-js/shared";
import { registerHandler } from "../../prompt-handlers.ts";

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

    // Handle: THERMOSTAT_MODE_SET to mode = 'HEAT'
    // Handle: THERMOSTAT_MODE_SET to mode = 'MANUFACTURER_SPECIFIC' with manufacturer specific data = [0x01, 0x02, 0x03]
    const modeMatch =
      /THERMOSTAT_MODE_SET to mode = '(?<mode>[^']+)'(?:\s+with manufacturer specific data = \[(?<data>[^\]]+)\])?/i.exec(
        ctx.logText
      );

    if (modeMatch?.groups?.mode) {
      const mode = modeNameToEnum[modeMatch.groups.mode];

      if (mode === undefined) return;

      if (mode === ThermostatMode["Manufacturer specific"]) {
        // Parse manufacturer data: "0x01, 0x02, 0x03" -> Uint8Array
        const dataStr = modeMatch.groups.data;
        if (dataStr) {
          const bytes = dataStr.split(",").map((s) => parseInt(s.trim(), 16));
          await node.commandClasses["Thermostat Mode"].set(
            mode,
            Bytes.from(bytes)
          );
        }
      } else {
        await node.commandClasses["Thermostat Mode"].set(mode);
      }
      return true;
    }
  },

  async onPrompt(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Handle: Confirm that last known mode of thermostat is 'OFF' (0x00) in the DUT UI!
    const modeCheckMatch =
      /last known mode of thermostat is '[^']+' \((?<value>0x[0-9a-fA-F]+)\)/i.exec(
        ctx.promptText
      );

    if (modeCheckMatch?.groups?.value) {
      const expected = parseInt(modeCheckMatch.groups.value, 16);
      const actual = node.getValue(ThermostatModeCCValues.thermostatMode.id);

      return actual === expected ? "Yes" : "No";
    }
  },
});
