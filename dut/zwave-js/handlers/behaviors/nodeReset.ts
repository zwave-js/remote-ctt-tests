import {
  isZWaveError,
  ZWaveErrorCodes,
} from "@zwave-js/core";
import { registerHandler } from "../../prompt-handlers.ts";

registerHandler(/.*/, {
  onPrompt: async (ctx) => {
    if (ctx.message?.type === "FACTORY_RESET") {
      const driverReady = new Promise<void>((resolve) => {
        ctx.driver.once("driver ready", resolve);
      });
      await ctx.driver.hardReset();
      await driverReady;
      ctx.includedNodes.length = 0;
      ctx.nodeNotifications.length = 0;
      ctx.valueNotifications.length = 0;
      return "Ok";
    }

    if (ctx.message?.type === "REMOVE_FAILED_NODE") {
      try {
        await ctx.driver.controller.removeFailedNode(ctx.message.nodeId);
      } catch (error) {
        if (
          !isZWaveError(error) ||
          error.code !== ZWaveErrorCodes.RemoveFailedNode_Failed ||
          !error.message.includes("responded to a ping")
        ) {
          throw error;
        }
      }
      return "Ok";
    }

    // Let other prompts fall through to manual handling
    return undefined;
  },
});
