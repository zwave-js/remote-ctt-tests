import { BasicCCValues } from "zwave-js";
import { CommandClasses } from "@zwave-js/core";
import { registerHandler } from "../../prompt-handlers.ts";

registerHandler("CCR_BasicCC_Rev02", {
  async onPrompt(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Handle VERIFY_STATE for Basic CC
    if (
      ctx.message?.type === "VERIFY_STATE" &&
      (ctx.message.commandClass === "unknown" ||
        ctx.message.commandClass === "Basic")
    ) {
      let expectedValue =
        typeof ctx.message.expected === "number"
          ? ctx.message.expected
          : parseInt(String(ctx.message.expected));

      // A report of 255 means 100%, which is mapped to 99 in Z-Wave JS
      if (expectedValue === 255) expectedValue = 99;

      const actualValue = node.getValue(BasicCCValues.currentValue.id);
      console.log(`Basic CC current value: ${actualValue}`);
      return actualValue === expectedValue ? "Yes" : "No";
    }

    // Handle CC_CAPABILITY_QUERY for Basic CC
    if (
      ctx.message?.type === "CC_CAPABILITY_QUERY" &&
      ctx.message.commandClass === "Basic" &&
      ctx.message.capabilityId === "CONTROL_BASIC_CC"
    ) {
      // getDefinedValueIDs is async in zwave-js-server
      const valueIds = await node.getDefinedValueIDs();
      const hasBasicValues = valueIds.some(
        (v) => v.commandClass === CommandClasses.Basic
      );

      return hasBasicValues ? "Yes" : "No";
    }
  },
});
