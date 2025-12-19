import {
  BatteryCCValues,
  type ZWaveNotificationCallbackArgs_BatteryCC,
} from "zwave-js";
import { CommandClasses } from "@zwave-js/core";
import { registerHandler } from "../../prompt-handlers.ts";
import type { VerifyStateMessage, VerifyNotificationMessage } from "../../../../src/ctt-message-types.ts";

registerHandler("CCR_BatteryCC_Rev02", {
  async onPrompt(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Handle VERIFY_STATE for battery level
    if (
      ctx.message?.type === "VERIFY_STATE" &&
      ctx.message.commandClass === "Battery"
    ) {
      const msg = ctx.message as VerifyStateMessage;
      const expectedLevel =
        typeof msg.expected === "number"
          ? msg.expected
          : parseInt(String(msg.expected));
      const actual = node.getValue(BatteryCCValues.level.id);
      return actual === expectedLevel ? "Yes" : "No";
    }

    // Handle VERIFY_NOTIFICATION for battery low
    if (
      ctx.message?.type === "VERIFY_NOTIFICATION" &&
      ctx.message.commandClass === "Battery"
    ) {
      const receivedEvent = ctx.nodeNotifications.some((evt) => {
        return (
          evt.ccId === CommandClasses.Battery &&
          (evt.args as ZWaveNotificationCallbackArgs_BatteryCC).eventType ===
            "battery low"
        );
      });
      return receivedEvent ? "Yes" : "No";
    }
  },
});
