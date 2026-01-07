import { type ZWaveNotificationCallbackArgs_NotificationCC } from "zwave-js";
import { CommandClasses } from "@zwave-js/core";
import { registerHandler } from "../../prompt-handlers.ts";
import type { SendCommandMessage } from "../../../../src/ctt-message-types.ts";

registerHandler("CCR_NotificationCC_Rev04", {
  async onLog(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Handle SEND_COMMAND for Notification GET
    if (
      ctx.message.type === "SEND_COMMAND" &&
      ctx.message.commandClass === "Notification"
    ) {
      const msg = ctx.message as SendCommandMessage;
      if (msg.action === "GET") {
        const { notificationType } = msg as { notificationType: number };
        await node.commandClasses.Notification.get({ notificationType });
        return true;
      }
    }
  },

  async onPrompt(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Handle VERIFY_NOTIFICATION
    if (
      ctx.message.type === "VERIFY_NOTIFICATION" &&
      ctx.message.commandClass === "Notification"
    ) {
      const { notificationType, event } = ctx.message;
      const expectedType = notificationType;
      const expectedEvent = event === "idle" ? 0x00 : (event as number);

      // Check received notifications first
      const found = ctx.nodeNotifications.some((evt) => {
        if (evt.ccId !== CommandClasses.Notification) return false;
        const args = evt.args as ZWaveNotificationCallbackArgs_NotificationCC;
        return args.type === expectedType && args.event === expectedEvent;
      });

      if (found) return "Yes";

      // If not found in notifications, check defined value IDs with ccSpecific
      const valueIds = node
        .getDefinedValueIDs()
        .filter((v) => v.commandClass === CommandClasses.Notification);
      for (const valueId of valueIds) {
        const metadata = node.getValueMetadata(valueId);
        if (
          "ccSpecific" in metadata &&
          (metadata.ccSpecific as { notificationType?: number })
            ?.notificationType === expectedType
        ) {
          const value = node.getValue(valueId);
          if (value === expectedEvent) {
            return "Yes";
          }
        }
      }

      return "No";
    }
  },
});
