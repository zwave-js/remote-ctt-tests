import { CommandClasses } from "@zwave-js/core";
import { registerHandler } from "../../prompt-handlers.ts";
import {
  EntryControlEventTypes,
  type ZWaveNotificationCallbackArgs_EntryControlCC,
} from "zwave-js";

registerHandler("CCR_EntryControlCC_Rev03", {
  async onLog(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Handle: * ENTRY_CONTROL_CONFIGURATION_SET with KeyCacheSize = 16 and KeyCacheTimeout = 5
    const configSetMatch =
      /ENTRY_CONTROL_CONFIGURATION_SET.+KeyCacheSize\s*=\s*(?<size>\d+).+KeyCacheTimeout\s*=\s*(?<timeout>\d+)/i.exec(
        ctx.logText
      );

    if (configSetMatch?.groups) {
      const keyCacheSize = parseInt(configSetMatch.groups.size!, 10);
      const keyCacheTimeout = parseInt(configSetMatch.groups.timeout!, 10);

      await node.commandClasses["Entry Control"].setConfiguration(
        keyCacheSize,
        keyCacheTimeout
      );
      return true;
    }
  },

  async onPrompt(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Does the UI show a received Entry Control Notification event with Event Type 'Enter' and Event Data 'DummyEventData'?
    const notificationMatch =
      /UI show.+Entry Control Notification.+Event Type '(?<eventType>[^']+)'.+Event Data '(?<eventData>[^']+)'/i.exec(
        ctx.promptText
      );
    if (notificationMatch?.groups) {
      const eventType = notificationMatch.groups.eventType!;
      const eventData = notificationMatch.groups.eventData!;

      const events = ctx.nodeNotifications.find(
        (n) => n.ccId === CommandClasses["Entry Control"]
      );
      if (!events) return "No";

      const args = events.args as ZWaveNotificationCallbackArgs_EntryControlCC;
      if (
        args.eventType === (EntryControlEventTypes as any)[eventType] &&
        args.eventData === eventData
      ) {
        return "Yes";
      }

      return "No";
    }
  },
});
