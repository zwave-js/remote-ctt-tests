import { CommandClasses } from "@zwave-js/core";
import { MeterCCValues, type ZWaveNode } from "zwave-js";
import { registerHandler } from "../../prompt-handlers.ts";

// Find a meter value by unit using the node's defined values and metadata
function findMeterValueByUnit(
  node: ZWaveNode,
  unit: string
): number | undefined {
  const meterValues = node
    .getDefinedValueIDs()
    .filter((v) => v.commandClass === CommandClasses.Meter);

  for (const valueId of meterValues) {
    const metadata = node.getValueMetadata(valueId);
    if (
      "unit" in metadata &&
      metadata.unit?.toLowerCase() === unit.toLowerCase()
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

    // Handle: Please trigger 'Reset Meter' for the emulated device on the DUT's UI!
    if (/trigger\s+'?Reset Meter'?/i.test(ctx.logText)) {
      await node.setValue(MeterCCValues.resetAll.id, true);
      return true;
    }
  },

  async onPrompt(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Handle: Please compare the DUTs UI to following values - are they displayed correctly?
    // '1.23' kWh
    // '123.4' W
    // '231.1' V
    // '43.21' kVarh
    if (/compare the DUTs UI to following values/i.test(ctx.promptText)) {
      // Extract all 'value' unit pairs
      const valuePattern = /'([\d.]+)'\s+(\w+)/g;
      let match;
      const pairs: Array<{ value: number; unit: string }> = [];

      while ((match = valuePattern.exec(ctx.promptText)) !== null) {
        pairs.push({
          value: parseFloat(match[1]!),
          unit: match[2]!,
        });
      }

      // Verify each value
      for (const { value: expected, unit } of pairs) {
        const actual = findMeterValueByUnit(node, unit);
        if (actual !== expected) {
          return "No";
        }
      }

      return "Yes";
    }

    // Handle: Confirm that 'kWh' scale is set to 43.21 in the DUTs UI!
    const scaleMatch =
      /confirm that '(?<unit>\w+)' scale is set to (?<value>[\d.]+)/i.exec(
        ctx.promptText
      );
    if (scaleMatch?.groups) {
      const unit = scaleMatch.groups.unit!;
      const expected = parseFloat(scaleMatch.groups.value!);

      const actual = findMeterValueByUnit(node, unit);
      return actual === expected ? "Yes" : "No";
    }

    // Handle: Wait a moment and confirm that all accumulating meter scales (kWh and kVarh) have been reset in DUT's UI!
    const resetMatch =
      /confirm that all accumulating meter scales \((?<units>[^)]+)\) have been reset/i.exec(
        ctx.promptText
      );
    if (resetMatch?.groups) {
      const units = resetMatch.groups.units!.split(/\s+and\s+|\s*,\s*/);

      for (const unit of units) {
        const actual = findMeterValueByUnit(node, unit.trim());
        if (actual !== 0) {
          return "No";
        }
      }
      return "Yes";
    }
  },
});
