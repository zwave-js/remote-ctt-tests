import {
  BinarySwitchCCValues,
  ColorSwitchCCValues,
  MultilevelSwitchCCValues,
} from "zwave-js";
import { registerHandler } from "../../prompt-handlers.ts";
import { wait } from "alcalzone-shared/async";
import type {
  SendCommandMessage,
  StartStopLevelChangeMessage,
  VerifyStateMessage,
} from "../../../../src/ctt-message-types.ts";

registerHandler("CCR_ColorSwitchCC_Rev02", {
  async onLog(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Handle SEND_COMMAND for Color Switch SET
    if (
      ctx.message?.type === "SEND_COMMAND" &&
      ctx.message.commandClass === "Color Switch" &&
      ctx.message.action === "SET"
    ) {
      const msg = ctx.message as SendCommandMessage & {
        colorId: number;
        value: number;
      };

      await node.setValue(
        ColorSwitchCCValues.targetColorChannel(msg.colorId).id,
        msg.value
      );
      return true;
    }

    // Handle SEND_COMMAND for Binary Switch SET (trigger any)
    if (
      ctx.message?.type === "SEND_COMMAND" &&
      ctx.message.commandClass === "Binary Switch" &&
      ctx.message.action === "SET"
    ) {
      node.setValue(BinarySwitchCCValues.targetValue.id, true);
      return true;
    }

    // Handle SEND_COMMAND for Multilevel Switch SET (trigger any)
    if (
      ctx.message?.type === "SEND_COMMAND" &&
      ctx.message.commandClass === "Multilevel Switch" &&
      ctx.message.action === "SET"
    ) {
      node.setValue(MultilevelSwitchCCValues.targetValue.id, 99);
      return true;
    }
  },

  async onPrompt(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Handle VERIFY_STATE for Color Switch current level
    if (
      ctx.message?.type === "VERIFY_STATE" &&
      ctx.message.commandClass === "Color Switch"
    ) {
      const msg = ctx.message as VerifyStateMessage;
      // property is in format "color_X" where X is the color component ID
      const colorMatch = /color_(\d+)/.exec(msg.property || "");
      if (colorMatch) {
        const colorComponent = parseInt(colorMatch[1]!);
        const expected =
          typeof msg.expected === "number"
            ? msg.expected
            : parseInt(String(msg.expected));
        const actual = node.getValue(
          ColorSwitchCCValues.currentColorChannel(colorComponent).id
        );
        return actual === expected ? "Yes" : "No";
      }
    }

    // Handle START_STOP_LEVEL_CHANGE for Color Switch
    if (
      ctx.message?.type === "START_STOP_LEVEL_CHANGE" &&
      ctx.message.commandClass === "Color Switch"
    ) {
      const msg = ctx.message as StartStopLevelChangeMessage & {
        colorId: number;
        direction: "up" | "down";
      };

      setTimeout(async () => {
        await node.commandClasses["Color Switch"].startLevelChange({
          colorComponent: msg.colorId,
          direction: msg.direction,
          ignoreStartLevel: true,
        });

        await wait(1000);

        await node.commandClasses["Color Switch"].stopLevelChange(msg.colorId);
      }, 250);

      return "Ok";
    }
  },
});
