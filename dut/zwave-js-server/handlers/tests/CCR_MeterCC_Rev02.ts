import { CommandClasses } from "@zwave-js/core";
import { MeterCCValues } from "zwave-js";
import { registerHandler } from "../../prompt-handlers.ts";
import type { SendCommandMessage, VerifyStateMessage } from "../../../../src/ctt-message-types.ts";
import type { NodeProxy } from "../../zwave-client.ts";

// Find a meter value by unit using the node's defined values and metadata
async function findMeterValueByUnit(
  node: NodeProxy,
  unit: string
): Promise<number | undefined> {
  const allValues = await node.getDefinedValueIDs();
  const meterValues = allValues.filter(
    (v) => v.commandClass === CommandClasses.Meter
  );

  for (const valueId of meterValues) {
    const metadata = node.getValueMetadata(valueId);
    if (
      "unit" in metadata &&
      (metadata as { unit?: string }).unit?.toLowerCase() === unit.toLowerCase()
    ) {
      return node.getValue(valueId) as number | undefined;
    }
  }
  return undefined;
}

registerHandler("CCR_MeterCC_Rev02", {
  async onLog(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Handle SEND_COMMAND for Meter RESET_ALL
    if (
      ctx.message?.type === "SEND_COMMAND" &&
      ctx.message.commandClass === "Meter"
    ) {
      const msg = ctx.message as SendCommandMessage;
      if (msg.action === "RESET_ALL") {
        await node.setValue(MeterCCValues.resetAll.id, true);
        return true;
      }
    }
  },

  async onPrompt(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Handle VERIFY_STATE for Meter values
    if (
      ctx.message?.type === "VERIFY_STATE" &&
      ctx.message.commandClass === "Meter"
    ) {
      const msg = ctx.message as VerifyStateMessage;

      // Handle array of {value, unit} pairs
      if (Array.isArray(msg.expected)) {
        for (const { value: expected, unit } of msg.expected as Array<{
          value: number;
          unit: string;
        }>) {
          const actual = await findMeterValueByUnit(node, unit);
          if (actual !== expected) {
            return "No";
          }
        }
        return "Yes";
      }
    }
  },
});
