import { WindowCoveringCCValues } from "zwave-js";
import { registerHandler } from "../../prompt-handlers.ts";
import { parseDurationFromLog } from "../utils.ts";
import { wait } from "alcalzone-shared/async";

registerHandler("CCR_WindowCoveringCC_Rev02", {
  async onLog(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // * WINDOW_COVERING_SET for Parameter 'OutRightPosition' (ID = 3)
    // with value = 50 (0x32), i. e. hardware level = '51%',
    // and duration = factory default (0xFF)
    const setMatch =
      /WINDOW_COVERING_SET.+\(ID = (?<param>\d+)\).+value = (?<value>\d+).+duration\s+=\s+(?<duration>\d+ )?(?<unit>\w+)/i.exec(
        ctx.logText
      );
    if (setMatch?.groups) {
      const param = parseInt(setMatch.groups.param!);
      const value = parseInt(setMatch.groups.value!);
      const duration = parseDurationFromLog(
        setMatch.groups.unit!,
        setMatch.groups.duration
      );

      node.setValue(WindowCoveringCCValues.targetValue(param).id, value, {
        transitionDuration: duration,
      });

      return true;
    }
  },

  async onPrompt(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    //  Verify level change for parameter 'OutBottomPosition' (13) with duration = factory default (0xFF)
    //     1.  Click 'OK' to start test sequence.
    //     2.  Start level change with Direction = 'DOWN' and wait a little moment. (CL:006A.01.31.03.1)
    //     3.  Stop level change. (CL:006A.01.31.04.1)
    if (
      ctx.promptText.includes("Click 'OK'") &&
      ctx.promptText.includes("Start level change") &&
      ctx.promptText.includes("Stop level change")
    ) {
      const directionMatch = /Direction\s+=\s+'(?<direction>\w+)'/i.exec(
        ctx.promptText
      )?.groups?.direction;
      const paramMatch = /parameter '\w+' \((?<param>\d+)\)/i.exec(
        ctx.promptText
      )?.groups?.param;
      const durationMatch =
        /duration\s+=\s+(?<duration>\d+ )?(?<unit>\w+)/i.exec(
          ctx.promptText
        )?.groups;

      if (directionMatch && paramMatch) {
        const parameter = parseInt(paramMatch);
        const direction = directionMatch.toLowerCase() === "up" ? "up" : "down";
        const duration = durationMatch?.unit
          ? parseDurationFromLog(durationMatch.unit, durationMatch.duration)
          : undefined;

        setTimeout(async () => {
          await node.commandClasses["Window Covering"].startLevelChange(
            parameter,
            direction,
            duration
          );

          await wait(1000);

          await node.commandClasses["Window Covering"].stopLevelChange(
            parameter
          );
        }, 250);

        return "Ok";
      }
    }

    // Is the current level for Paramter = 'OutBottomPosition' (ID = 13) set to Z-Wave value = 0 (0x00), i. e. hardware level = 'closed', in the DUT's UI?
    const currentValueMatch =
      /current level.+\(ID = (?<param>\d+)\).+value = (?<level>\d+)/i.exec(
        ctx.promptText
      );
    if (currentValueMatch?.groups) {
      const param = parseInt(currentValueMatch.groups.param!);
      const expectedLevel = parseInt(currentValueMatch.groups.level!);
      const actual = node.getValue(
        WindowCoveringCCValues.currentValue(param).id
      );

      return actual === expectedLevel ? "Yes" : "No";
    }
  },
});
