import { CommandClasses } from "@zwave-js/core";
import { registerHandler } from "../../prompt-handlers.ts";
import {
  EntryControlEventTypes,
  type ZWaveNotificationCallbackArgs_EntryControlCC,
} from "zwave-js";
import type { SendCommandMessage } from "../../../../src/ctt-message-types.ts";

registerHandler("CCR_EntryControlCC_Rev03", {
  async onLog(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Handle SEND_COMMAND for Entry Control SET_CONFIG
    if (
      ctx.message.type === "SEND_COMMAND" &&
      ctx.message.commandClass === "Entry Control" &&
      ctx.message.action === "SET_CONFIG"
    ) {
      const msg = ctx.message as SendCommandMessage & {
        keyCacheSize: number;
        keyCacheTimeout: number;
      };

      await node.commandClasses["Entry Control"].setConfiguration(
        msg.keyCacheSize,
        msg.keyCacheTimeout
      );
      return true;
    }
  },

  async onPrompt(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Handle VERIFY_NOTIFICATION for Entry Control
    if (
      ctx.message.type === "VERIFY_NOTIFICATION" &&
      ctx.message.commandClass === "Entry Control"
    ) {
      const { eventType, eventData } = ctx.message;

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
