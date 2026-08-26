import { CommandClasses } from "@zwave-js/core";
import { registerHandler } from "../../prompt-handlers.ts";

registerHandler("CCR_IndicatorCC_Rev02", {
  async onLog(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    const { client } = ctx;

    // Handle SEND_COMMAND for Indicator IDENTIFY
    if (
      ctx.message?.type === "SEND_COMMAND" &&
      ctx.message.commandClass === "Indicator" &&
      ctx.message.action === "IDENTIFY"
    ) {
      await client.sendCommand("endpoint.invoke_cc_api", {
        nodeId: node.id,
        endpoint: 0,
        commandClass: CommandClasses.Indicator,
        methodName: "identify",
        args: [],
      });
      return true;
    }
  },
});
