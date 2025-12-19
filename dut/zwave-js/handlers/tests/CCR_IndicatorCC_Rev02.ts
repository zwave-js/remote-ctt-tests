import { registerHandler } from "../../prompt-handlers.ts";

registerHandler("CCR_IndicatorCC_Rev02", {
  async onLog(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Handle SEND_COMMAND for Indicator IDENTIFY
    if (
      ctx.message?.type === "SEND_COMMAND" &&
      ctx.message.commandClass === "Indicator" &&
      ctx.message.action === "IDENTIFY"
    ) {
      node.commandClasses.Indicator.identify();
      return true;
    }
  },
});
