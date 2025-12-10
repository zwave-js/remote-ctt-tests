import { MultilevelSensorCCValues } from "zwave-js";
import { registerHandler } from "../../prompt-handlers.ts";

// Map CTT sensor names to zwave-js property names
const sensorTypeMap: Record<string, string> = {
  "carbon monoxide": "Carbon monoxide (CO) level",
};

function getSensorPropertyName(cttName: string): string {
  // Check explicit mapping first (case-insensitive)
  const mapped = sensorTypeMap[cttName.toLowerCase()];
  if (mapped) return mapped;

  // Otherwise assume CTT name matches zwave-js property name
  return cttName;
}

registerHandler("CCR_MultilevelSensorCC_Rev02", {
  async onPrompt(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Confirm that last known value of 'Air temperature' in °C in the DUTs UI is '23.45'!
    const match =
      /confirm that last known value of '(?<sensorType>[^']+)'.+is '(?<value>[^']+)'/i.exec(
        ctx.promptText
      );
    if (match?.groups) {
      const cttSensorType = match.groups.sensorType!;
      const expectedValue = parseFloat(match.groups.value!);

      const sensorType = getSensorPropertyName(cttSensorType);
      const actual = node.getValue(
        MultilevelSensorCCValues.value(sensorType).id
      );

      return actual === expectedValue ? "Yes" : "No";
    }
  },
});
