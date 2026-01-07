import { WindowCoveringCCValues, Duration } from "zwave-js";
import { registerHandler } from "../../prompt-handlers.ts";
import { wait } from "alcalzone-shared/async";
import type {
  SendCommandMessage,
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

registerHandler("CCR_WindowCoveringCC_Rev02", {
  async onLog(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Handle SEND_COMMAND for Window Covering SET
    if (
      ctx.message?.type === "SEND_COMMAND" &&
      ctx.message.commandClass === "Window Covering" &&
      ctx.message.action === "SET"
    ) {
      const msg = ctx.message as SendCommandMessage & {
        paramId: number;
        value: number;
        duration?: DurationValue;
      };

      const transitionDuration =
        msg.duration !== undefined ? toDuration(msg.duration) : undefined;

      node.setValue(WindowCoveringCCValues.targetValue(msg.paramId).id, msg.value, {
        transitionDuration,
      });

      return true;
    }
  },

  async onPrompt(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Handle START_STOP_LEVEL_CHANGE for Window Covering
    if (
      ctx.message?.type === "START_STOP_LEVEL_CHANGE" &&
      ctx.message.commandClass === "Window Covering"
    ) {
      const msg = ctx.message as StartStopLevelChangeMessage & {
        paramId: number;
        direction: "up" | "down";
      };

      const duration = msg.duration ? toDuration(msg.duration) : undefined;

      setTimeout(async () => {
        await node.commandClasses["Window Covering"].startLevelChange(
          msg.paramId,
          msg.direction,
          duration
        );

        await wait(1000);

        await node.commandClasses["Window Covering"].stopLevelChange(msg.paramId);
      }, 250);

      return "Ok";
    }

    // Handle VERIFY_STATE for Window Covering current value
    if (
      ctx.message?.type === "VERIFY_STATE" &&
      ctx.message.commandClass === "Window Covering"
    ) {
      const msg = ctx.message as VerifyStateMessage;
      // property is in format "param_X" where X is the param ID
      const paramMatch = /param_(\d+)/.exec(msg.property || "");
      if (paramMatch) {
        const param = parseInt(paramMatch[1]!);
        const expectedLevel =
          typeof msg.expected === "number"
            ? msg.expected
            : parseInt(String(msg.expected));
        const actual = node.getValue(
          WindowCoveringCCValues.currentValue(param).id
        );

        return actual === expectedLevel ? "Yes" : "No";
      }
    }
  },
});
