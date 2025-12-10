import { type ZWaveNotificationCallbackArgs_NotificationCC } from "zwave-js";
import { CommandClasses } from "@zwave-js/core";
import { registerHandler } from "../../prompt-handlers.ts";

registerHandler("CCR_NotificationCC_Rev04", {
  async onLog(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Handle: ALARM_GET (NOTIFICATION_GET) for Alarm Type System (0x09)
    // This needs to be specific to not falsely trigger after the interview!
    const alarmMatch =
      /\* ALARM_GET \(NOTIFICATION_GET\) for Alarm Type.+\((?<typeHex>0x[0-9a-fA-F]+)\)/i.exec(
        ctx.logText
      );
    if (alarmMatch?.groups) {
      const notificationType = parseInt(alarmMatch.groups.typeHex!, 16);
      await node.commandClasses.Notification.get({ notificationType });
      return true;
    }
  },

  async onPrompt(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Handle: Does the DUT display the event 'OverheatDetected (0x02)' for the notification type 'HeatAlarm (0x04)'?
    const eventMatch =
      /display the event.+\((?<eventHex>0x[0-9a-fA-F]+)\).+notification type.+\((?<typeHex>0x[0-9a-fA-F]+)\)/i.exec(
        ctx.promptText
      );
    if (
      ctx.promptText.includes(
        "Does the DUT display the event 'OverheatDetected (0x02)'"
      )
    ) {
      debugger;
    }
    if (eventMatch?.groups) {
      const expectedType = parseInt(eventMatch.groups.typeHex!, 16);
      const expectedEvent = parseInt(eventMatch.groups.eventHex!, 16);

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

    // Handle: Does the state of notification type 'HeatAlarm (0x04)' return to 'idle'?
    const idleMatch =
      /state of notification type.+\((?<typeHex>0x[0-9a-fA-F]+)\).+return to 'idle'/i.exec(
        ctx.promptText
      );
    if (idleMatch?.groups) {
      const expectedType = parseInt(idleMatch.groups.typeHex!, 16);

      // Check for idle event (0x00) in notifications
      const idle = ctx.nodeNotifications.some((evt) => {
        if (evt.ccId !== CommandClasses.Notification) return false;
        const args = evt.args as ZWaveNotificationCallbackArgs_NotificationCC;
        return args.type === expectedType && args.event === 0x00;
      });

      if (idle) return "Yes";

      // Also check value IDs
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
          if (value === 0) {
            return "Yes";
          }
        }
      }

      return "No";
    }
  },
});
