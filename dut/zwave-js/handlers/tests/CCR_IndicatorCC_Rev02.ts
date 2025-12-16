import { BasicCCValues, CommandClass, SubsystemType } from "zwave-js";
import { CommandClasses } from "@zwave-js/core";
import { registerHandler } from "../../prompt-handlers.ts";

registerHandler("CCR_IndicatorCC_Rev02", {
  async onLog(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    if (/INDICATOR_SET to identify node/i.test(ctx.logText)) {
      node.commandClasses.Indicator.identify();
      return true;
    }
  },
});
