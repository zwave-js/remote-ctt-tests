import {
  DoorLockCCValues,
  DoorLockMode,
  DoorLockOperationType,
  getEnumMemberName,
  type DoorLockCCConfigurationSetOptions,
} from "zwave-js";
import { registerHandler } from "../../prompt-handlers.ts";

const modeNameToEnum: Record<string, DoorLockMode> = {
  unsecured: DoorLockMode.Unsecured,
  unsecuredwithtimeout: DoorLockMode.UnsecuredWithTimeout,
  insideunsecured: DoorLockMode.InsideUnsecured,
  insideunsecuredwithtimeout: DoorLockMode.InsideUnsecuredWithTimeout,
  outsideunsecured: DoorLockMode.OutsideUnsecured,
  outsideunsecuredwithtimeout: DoorLockMode.OutsideUnsecuredWithTimeout,
  secured: DoorLockMode.Secured,
};

registerHandler("CCR_DoorLockCC_Rev02", {
  async onLog(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Handle: Set Door Lock Operation Mode <mode>
    const modeMatch = /Set Door Lock Operation Mode (?<mode>\w+)/i.exec(
      ctx.logText
    );
    if (modeMatch?.groups?.mode) {
      const modeName = modeMatch.groups.mode.toLowerCase();
      const mode = modeNameToEnum[modeName];
      if (mode !== undefined) {
        node.setValue(DoorLockCCValues.targetMode.id, mode);
        return true;
      }
    }

    // Handle: Set Door Lock Configuration (multi-line)
    if (ctx.logText.includes("Set Door Lock Configuration:")) {
      const operationType = /Operation Type:\s+'(\w+)'/i.exec(ctx.logText)?.[1];
      const insideHandle1 = /Inside Handle 1:\s+'(\w+)'/i.exec(
        ctx.logText
      )?.[1];
      const insideHandle2 = /Inside Handle 2:\s+'(\w+)'/i.exec(
        ctx.logText
      )?.[1];
      const insideHandle3 = /Inside Handle 3:\s+'(\w+)'/i.exec(
        ctx.logText
      )?.[1];
      const insideHandle4 = /Inside Handle 4:\s+'(\w+)'/i.exec(
        ctx.logText
      )?.[1];
      const outsideHandle1 = /Outside Handle 1:\s+'(\w+)'/i.exec(
        ctx.logText
      )?.[1];
      const outsideHandle2 = /Outside Handle 2:\s+'(\w+)'/i.exec(
        ctx.logText
      )?.[1];
      const outsideHandle3 = /Outside Handle 3:\s+'(\w+)'/i.exec(
        ctx.logText
      )?.[1];
      const outsideHandle4 = /Outside Handle 4:\s+'(\w+)'/i.exec(
        ctx.logText
      )?.[1];
      const lockTimeout = /Lock Timeout:\s+(\d+)\s+seconds/i.exec(
        ctx.logText
      )?.[1];
      const autoRelockTime = /Auto-relock Time:\s+(\d+)\s+seconds/i.exec(
        ctx.logText
      )?.[1];
      const holdReleaseTime = /Hold&Release Time:\s+(\d+)\s+seconds/i.exec(
        ctx.logText
      )?.[1];
      const blockToBlock = /Block to Block:\s+'(\w+)'/i.exec(ctx.logText)?.[1];
      const twistAssist = /Twist Assist:\s+'(\w+)/i.exec(ctx.logText)?.[1];

      const isEnabled = (value: string | undefined) =>
        value?.toLowerCase() === "enabled";

      const lockTimeoutConfiguration = lockTimeout ? parseInt(lockTimeout) : 0;

      const config: DoorLockCCConfigurationSetOptions = {
        ...(operationType?.toLowerCase() === "timedoperation"
          ? {
              operationType: DoorLockOperationType.Timed,
              lockTimeoutConfiguration,
            }
          : {
              operationType: DoorLockOperationType.Constant,
            }),
        insideHandlesCanOpenDoorConfiguration: [
          isEnabled(insideHandle1),
          isEnabled(insideHandle2),
          isEnabled(insideHandle3),
          isEnabled(insideHandle4),
        ],
        outsideHandlesCanOpenDoorConfiguration: [
          isEnabled(outsideHandle1),
          isEnabled(outsideHandle2),
          isEnabled(outsideHandle3),
          isEnabled(outsideHandle4),
        ],
      };

      if (operationType?.toLowerCase() === "timedoperation" && lockTimeout) {
        (config as any).lockTimeoutConfiguration = parseInt(lockTimeout);
      }

      if (autoRelockTime) {
        config.autoRelockTime = parseInt(autoRelockTime);
      }

      if (holdReleaseTime) {
        config.holdAndReleaseTime = parseInt(holdReleaseTime);
      }

      if (blockToBlock) {
        config.blockToBlock = isEnabled(blockToBlock);
      }

      if (twistAssist) {
        config.twistAssist = isEnabled(twistAssist);
      }

      await node.commandClasses["Door Lock"].setConfiguration(config);
      return true;
    }
  },

  async onPrompt(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Handle: check if current mode is set to '<mode>'
    const modeCheckMatch = /current mode is set to '(?<mode>\w+)'/i.exec(
      ctx.promptText
    );
    if (modeCheckMatch?.groups?.mode) {
      const expected = modeCheckMatch.groups.mode.toLowerCase();
      const actual = getEnumMemberName(
        DoorLockMode,
        node.getValue(DoorLockCCValues.currentMode.id) ?? -1
      ).toLowerCase();

      return actual === expected ? "Yes" : "No";
    }
  },
});
