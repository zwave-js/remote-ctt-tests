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

    // FIXME: Migrate this to `simplePrompts.ts`
    if (
      (match = /confirm that the state \((?<value>\d+)/i.exec(ctx.promptText))
        ?.groups
    ) {
      let expectedValue = parseInt(match.groups.value!);
      const node = ctx.includedNodes.at(-1);
      if (!node) return;

      // A report of 255 means 100%, which is mapped to 99 in Z-Wave JS
      if (expectedValue === 255) expectedValue = 99;

      const actualValue = node.getValue(BasicCCValues.currentValue.id);
      console.log(`Basic CC current value: ${actualValue}`);
      return actualValue === expectedValue ? "Yes" : "No";
    }
  },
});
