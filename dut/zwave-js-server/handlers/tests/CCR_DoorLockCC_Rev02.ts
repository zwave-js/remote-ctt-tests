import {
  DoorLockCCValues,
  DoorLockMode,
  DoorLockOperationType,
  getEnumMemberName,
  type DoorLockCCConfigurationSetOptions,
} from "zwave-js";
import { CommandClasses } from "@zwave-js/core";
import { registerHandler } from "../../prompt-handlers.ts";
import type { SendCommandMessage, VerifyStateMessage } from "../../../../src/ctt-message-types.ts";

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

    const { client } = ctx;

    // Handle SEND_COMMAND for Door Lock CC
    if (
      ctx.message?.type === "SEND_COMMAND" &&
      ctx.message.commandClass === "Door Lock"
    ) {
      const msg = ctx.message as SendCommandMessage;

      if (msg.action === "SET_MODE") {
        const { mode } = msg as { mode: string };
        const modeName = mode.toLowerCase();
        const modeEnum = modeNameToEnum[modeName];
        if (modeEnum !== undefined) {
          await node.setValue(DoorLockCCValues.targetMode.id, modeEnum);
          return true;
        }
      }

      if (msg.action === "SET_CONFIG") {
        const {
          operationType,
          insideHandles,
          outsideHandles,
          lockTimeout,
          autoRelockTime,
          holdAndReleaseTime,
          blockToBlock,
          twistAssist,
        } = msg as {
          operationType: "Constant" | "Timed";
          insideHandles: [boolean, boolean, boolean, boolean];
          outsideHandles: [boolean, boolean, boolean, boolean];
          lockTimeout?: number;
          autoRelockTime?: number;
          holdAndReleaseTime?: number;
          blockToBlock?: boolean;
          twistAssist?: boolean;
        };

        const config: DoorLockCCConfigurationSetOptions = {
          ...(operationType === "Timed"
            ? {
                operationType: DoorLockOperationType.Timed,
                lockTimeoutConfiguration: lockTimeout ?? 0,
              }
            : {
                operationType: DoorLockOperationType.Constant,
              }),
          insideHandlesCanOpenDoorConfiguration: insideHandles,
          outsideHandlesCanOpenDoorConfiguration: outsideHandles,
        };

        if (autoRelockTime !== undefined) {
          config.autoRelockTime = autoRelockTime;
        }

        if (holdAndReleaseTime !== undefined) {
          config.holdAndReleaseTime = holdAndReleaseTime;
        }

        if (blockToBlock !== undefined) {
          config.blockToBlock = blockToBlock;
        }

        if (twistAssist !== undefined) {
          config.twistAssist = twistAssist;
        }

        await client.sendCommand("endpoint.invoke_cc_api", {
          nodeId: node.id,
          endpoint: 0,
          commandClass: CommandClasses["Door Lock"],
          methodName: "setConfiguration",
          args: [config],
        });
        return true;
      }
    }
  },

  async onPrompt(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Handle VERIFY_STATE for current mode
    if (
      ctx.message?.type === "VERIFY_STATE" &&
      ctx.message.commandClass === "Door Lock"
    ) {
      const msg = ctx.message as VerifyStateMessage;
      const expected = String(msg.expected).toLowerCase();
      const actual = getEnumMemberName(
        DoorLockMode,
        node.getValue(DoorLockCCValues.currentMode.id) ?? -1
      ).toLowerCase();

      return actual === expected ? "Yes" : "No";
    }
  },
});
