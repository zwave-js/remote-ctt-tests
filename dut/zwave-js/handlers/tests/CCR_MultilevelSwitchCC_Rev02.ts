import { MultilevelSwitchCCValues } from "zwave-js";
import { registerHandler } from "../../prompt-handlers.ts";
import { parseDurationFromLog } from "../utils.ts";
import { wait } from "alcalzone-shared/async";

registerHandler("CCR_MultilevelSwitchCC_Rev02", {
  async onPrompt(ctx) {
    // Testing optional level change:
    //     * Direction   = up
    //     * Start Level = 5 (0x05), i. e. hardware level = 5%
    //     * Duration    = 20 seconds
    // -----------------------------------------------------------------------
    // 1.  Click 'OK' to start test sequence!
    // 2.  Start level change up (with increasing brightness) and wait a little moment.
    // 3.  Stop level change.

    if (
      ctx.promptText.includes("Click 'OK'") &&
      ctx.promptText.includes("Start level change") &&
      ctx.promptText.includes("Stop level change")
    ) {
      const directionMatch = /Direction\s+=\s+(?<direction>\w+)/i.exec(
        ctx.promptText
      )?.groups?.direction;
      const startLevelMatch = /Start Level\s+=\s+(?<startLevel>\d+)/i.exec(
        ctx.promptText
      )?.groups?.startLevel;
      const durationMatch =
        /Duration\s+=\s+(?<duration>\d+ )?(?<unit>\w+)/i.exec(
          ctx.promptText
        )?.groups;
      const node = ctx.includedNodes.at(-1);
      if (!node || !directionMatch) return;

      const startLevel = startLevelMatch
        ? parseInt(startLevelMatch)
        : undefined;
      const duration = durationMatch?.unit
        ? parseDurationFromLog(durationMatch.unit, durationMatch.duration)
        : undefined;
      const direction = directionMatch.toLowerCase() === "up" ? "up" : "down";

      setTimeout(async () => {
        await node.commandClasses["Multilevel Switch"].startLevelChange(
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
              }
        );

        await wait(1000);

        await node.commandClasses["Multilevel Switch"].stopLevelChange();
      }, 250);

      return "Ok";
    }

    //  Is the current level set to Z-Wave value = 13 (0x0D), i. e. hardware level = 13%, in the DUT's UI?
    const currentValueMatch =
      /current level set to.+value = (?<level>\d+)/i.exec(ctx.promptText);
    if (currentValueMatch?.groups) {
      const node = ctx.includedNodes.at(-1);
      if (!node) return;

      const expectedLevel = parseInt(currentValueMatch.groups.level!);
      const actual = node.getValue(MultilevelSwitchCCValues.currentValue.id);
      return actual === expectedLevel ? "Yes" : "No";
    }
  },
});
