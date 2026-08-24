import {
  isZWaveError,
  ZWaveErrorCodes,
} from "@zwave-js/core";
import { registerHandler } from "../../prompt-handlers.ts";

// The controller pings a node before removing or replacing it, so a node that answers cancels the operation
export function isNodeStillRespondingError(
  error: unknown,
  code: ZWaveErrorCodes
): boolean {
  return (
    isZWaveError(error) &&
    error.code === code &&
    error.message.includes("responded to a ping")
  );
}

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
          !isNodeStillRespondingError(
            error,
            ZWaveErrorCodes.RemoveFailedNode_Failed
          )
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
