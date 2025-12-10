import {
  BinarySwitchCCValues,
  ColorComponent,
  ColorSwitchCCValues,
  MultilevelSwitchCCValues,
} from "zwave-js";
import { registerHandler } from "../../prompt-handlers.ts";
import { wait } from "alcalzone-shared/async";

const colorNameToComponent: Record<string, ColorComponent> = {
  "Warm White": ColorComponent["Warm White"],
  "Cold White": ColorComponent["Cold White"],
  Red: ColorComponent.Red,
  Green: ColorComponent.Green,
  Blue: ColorComponent.Blue,
  Amber: ColorComponent.Amber,
  Cyan: ColorComponent.Cyan,
  Purple: ColorComponent.Purple,
};

registerHandler("CCR_ColorSwitchCC_Rev02", {
  async onLog(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // * SWITCH_COLOR_SET for color component 'Green' (ID = 0x03) with value='255.
    const match =
      /SWITCH_COLOR_SET.+\(ID = (?<color>(0x)?[a-fA-F0-9]+)\).+value='(?<value>\d+)/i.exec(
        ctx.logText
      );
    if (match?.groups) {
      const colorComponent = parseInt(match.groups.color!);
      const value = parseInt(match.groups.value!);

      await node.setValue(
        ColorSwitchCCValues.targetColorChannel(colorComponent).id,
        value
      );
      return true;
    }

    // Please trigger Binary Switch On or Off for the emulated device in the DUT's UI!
    if (/trigger Binary Switch On or Off/i.test(ctx.logText)) {
      node.setValue(BinarySwitchCCValues.targetValue.id, true);
      return true;
    }

    // Please trigger Multilevel Switch On or Off
    if (/trigger Multilevel Switch On or Off/i.test(ctx.logText)) {
      node.setValue(MultilevelSwitchCCValues.targetValue.id, 99);
      return true;
    }
  },

  async onPrompt(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Is the current level of color component 'Blue' (ID = 4) set to 130 in the DUT's UI?
    const levelMatch =
      /current level.+\(ID = (?<color>(0x)?[a-fA-F0-9]+)\).+set to (?<value>\d+)/i.exec(
        ctx.promptText
      );
    if (levelMatch?.groups) {
      const colorComponent = parseInt(levelMatch.groups.color!);
      const expected = parseInt(levelMatch.groups.value!);
      const actual = node.getValue(
        ColorSwitchCCValues.currentColorChannel(colorComponent).id
      );
      return actual === expected ? "Yes" : "No";
    }

    // Testing level change for color component 'Red' (ID = 0x02)...Click 'OK' to start
    if (
      /level change for color component/i.test(ctx.promptText) &&
      /Click 'OK'/i.test(ctx.promptText)
    ) {
      const colorMatch = /\(ID = (?<color>(0x)?[a-fA-F0-9]+)\)/i.exec(ctx.promptText);
      if (!colorMatch?.groups) return;

      const colorComponent = parseInt(colorMatch.groups.color!);

      setTimeout(async () => {
        await node.commandClasses["Color Switch"].startLevelChange({
          colorComponent,
          direction: ctx.promptText.includes("increasing") ? "up" : "down",
          ignoreStartLevel: true,
        });

        await wait(1000);

        await node.commandClasses["Color Switch"].stopLevelChange(
          colorComponent
        );
      }, 250);

      return "Ok";
    }
  },
});
