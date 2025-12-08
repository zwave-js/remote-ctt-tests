import { BasicCCValues, CommandClass, SubsystemType } from "zwave-js";
import { CommandClasses } from "@zwave-js/core";
import { registerHandler } from "../../prompt-handlers.ts";

registerHandler("CCR_BasicCC_Rev02", {
  async onPrompt(ctx) {
    if (
      /control the device using the Basic Command Class/i.test(ctx.promptText)
    ) {
      const node = ctx.includedNodes.at(-1);
      if (!node) return;

      const hasBasicValues = node
        .getDefinedValueIDs()
        .some((v) => v.commandClass === CommandClasses.Basic);

      return hasBasicValues ? "Yes" : "No";
    }

    let match: RegExpExecArray | null;

    if (
      (match = /confirm that the state \((?<value>\d+)/i.exec(ctx.promptText))
    ) {
      const expectedValue = parseInt(match.groups!.value);
      const node = ctx.includedNodes.at(-1);
      if (!node) return;

      const actualValue = node.getValue(BasicCCValues.currentValue.id);
      console.log(`Basic CC current value: ${actualValue}`);
      return actualValue === expectedValue ? "Yes" : "No";
    }
  },

  async onLog(ctx) {
    const match = /trigger 'Basic Set to (?<targetValue>\d+)/i;
    const result = match.exec(ctx.logText);
    if (result?.groups) {
      const targetValue = parseInt(result.groups["targetValue"]);
      const node = ctx.includedNodes.at(-1);
      if (!node) return;

      node.commandClasses.Basic.set(targetValue);
    }
  },
});
