import {
  BasicCCValues,
  BatteryCCValues,
  CommandClass,
  SubsystemType,
  type ZWaveNotificationCallbackArgs_BatteryCC,
} from "zwave-js";
import { CommandClasses } from "@zwave-js/core";
import { registerHandler } from "../../prompt-handlers.ts";

const REPLACE_BATTERY_EMITTED = "replace battery event emitted";

registerHandler("CCR_BatteryCC_Rev02", {
  async onPrompt(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    const batteryLevelMatch = /validate.+battery level of (?<level>\d+)%/i.exec(
      ctx.promptText
    );
    if (batteryLevelMatch?.groups) {
      const expectedLevel = parseInt(batteryLevelMatch.groups.level!);
      const actual = node.getValue(BatteryCCValues.level.id);
      return actual === expectedLevel ? "Yes" : "No";
    }

    if (
      ctx.promptText.includes("displays that the battery needs to be replaced")
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
