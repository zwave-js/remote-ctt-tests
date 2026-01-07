import { MultilevelSwitchCCValues, Duration } from "zwave-js";
import { CommandClasses } from "@zwave-js/core";
import { registerHandler } from "../../prompt-handlers.ts";
import { wait } from "alcalzone-shared/async";
import type {
  StartStopLevelChangeMessage,
  VerifyStateMessage,
  DurationValue,
} from "../../../../src/ctt-message-types.ts";

// Helper to convert DurationValue to zwave-js Duration
function toDuration(duration: DurationValue): Duration {
  if (duration === "default") {
    return Duration.default();
  }
  return new Duration(duration.value, duration.unit);
}

registerHandler("CCR_MultilevelSwitchCC_Rev02", {
  async onPrompt(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    const { client } = ctx;

    // Handle START_STOP_LEVEL_CHANGE for Multilevel Switch
    if (
      ctx.message?.type === "START_STOP_LEVEL_CHANGE" &&
      ctx.message.commandClass === "Multilevel Switch"
    ) {
      const msg = ctx.message as StartStopLevelChangeMessage;
      const startLevel = msg.startLevel;
      const duration = msg.duration ? toDuration(msg.duration) : undefined;
      const direction = (msg as { direction: "up" | "down" }).direction;

      setTimeout(async () => {
        await client.sendCommand("endpoint.invoke_cc_api", {
          nodeId: node.id,
          endpoint: 0,
          commandClass: CommandClasses["Multilevel Switch"],
          methodName: "startLevelChange",
          args: [
            startLevel == undefined
              ? {
                  direction,
                  ignoreStartLevel: true,
                  duration,
                }
              : {
                  direction,
                  startLevel,
                  ignoreStartLevel: false,
                  duration,
                },
          ],
        });

        await wait(1000);

        await client.sendCommand("endpoint.invoke_cc_api", {
          nodeId: node.id,
          endpoint: 0,
          commandClass: CommandClasses["Multilevel Switch"],
          methodName: "stopLevelChange",
          args: [],
        });
      }, 250);

      return "Ok";
    }

    // Handle VERIFY_STATE for current level
    if (
      ctx.message?.type === "VERIFY_STATE" &&
      ctx.message.commandClass === "Multilevel Switch"
    ) {
      const msg = ctx.message as VerifyStateMessage;
      const expectedLevel =
        typeof msg.expected === "number"
          ? msg.expected
          : parseInt(String(msg.expected));
      const actual = node.getValue(MultilevelSwitchCCValues.currentValue.id);
      return actual === expectedLevel ? "Yes" : "No";
    }
  },
});
