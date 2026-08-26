import { MultilevelSensorCCValues } from "zwave-js";
import { registerHandler } from "../../prompt-handlers.ts";
import type { VerifyStateMessage } from "../../../../src/ctt-message-types.ts";

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

    // Handle VERIFY_STATE for Multilevel Sensor
    if (
      ctx.message?.type === "VERIFY_STATE" &&
      ctx.message.commandClass === "Multilevel Sensor"
    ) {
      const msg = ctx.message as VerifyStateMessage;
      const sensorType = getSensorPropertyName(msg.property || "");
      const expectedValue =
        typeof msg.expected === "string"
          ? parseFloat(msg.expected)
          : typeof msg.expected === "number"
            ? msg.expected
            : 0;

      const actual = node.getValue(
        MultilevelSensorCCValues.value(sensorType).id
      );

      return actual === expectedValue ? "Yes" : "No";
    }
  },
});
