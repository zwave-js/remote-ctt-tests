import { UserIDStatus, KeypadMode } from "zwave-js";
import { CommandClasses } from "@zwave-js/core";
import { registerHandler } from "../../prompt-handlers.ts";
import type {
  SendCommandMessage,
  QueryUserCodesMessage,
} from "../../../../src/ctt-message-types.ts";

const statusNameToEnum: Record<string, UserIDStatus> = {
  enabled: UserIDStatus.Enabled,
  "enabled / grant access": UserIDStatus.Enabled,
  disabled: UserIDStatus.Disabled,
  passagemode: UserIDStatus.PassageMode,
  occupied: UserIDStatus.Enabled, // V1 Occupied (0x01) = V2 Enabled (0x01)
  reserved: UserIDStatus.Disabled, // V1 Reserved (0x02) = V2 Disabled (0x02)
};

const keypadModeNameToEnum: Record<string, KeypadMode> = {
  normal: KeypadMode.Normal,
  vacation: KeypadMode.Vacation,
  privacy: KeypadMode.Privacy,
};

registerHandler("CCR_UserCodeCC_Rev04", {
  async onLog(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    const { client } = ctx;

    // Handle SEND_COMMAND for User Code CC
    if (
      ctx.message?.type === "SEND_COMMAND" &&
      ctx.message.commandClass === "User Code"
    ) {
      const msg = ctx.message as SendCommandMessage;

      if (msg.action === "SET" || msg.action === "ADD") {
        const { userId, status, code } = msg as {
          userId: number;
          status: string;
          code: string;
        };
        const statusEnum = statusNameToEnum[status.toLowerCase()];
        if (statusEnum !== undefined) {
          await client.sendCommand("endpoint.invoke_cc_api", {
            nodeId: node.id,
            endpoint: 0,
            commandClass: CommandClasses["User Code"],
            methodName: "set",
            args: [userId, statusEnum, code],
          });
          return true;
        }
      }

      if (msg.action === "CLEAR") {
        const { userId } = msg as { userId: number };
        await client.sendCommand("endpoint.invoke_cc_api", {
          nodeId: node.id,
          endpoint: 0,
          commandClass: CommandClasses["User Code"],
          methodName: "clear",
          args: [userId],
        });
        return true;
      }

      if (msg.action === "SET_KEYPAD_MODE") {
        const { mode } = msg as { mode: string };
        const modeEnum = keypadModeNameToEnum[mode.toLowerCase()];
        if (modeEnum !== undefined) {
          await client.sendCommand("endpoint.invoke_cc_api", {
            nodeId: node.id,
            endpoint: 0,
            commandClass: CommandClasses["User Code"],
            methodName: "setKeypadMode",
            args: [modeEnum],
          });
          return true;
        }
      }

      if (msg.action === "SET_ADMIN_CODE") {
        const { code } = msg as { code: string };
        await client.sendCommand("endpoint.invoke_cc_api", {
          nodeId: node.id,
          endpoint: 0,
          commandClass: CommandClasses["User Code"],
          methodName: "setAdminCode",
          args: [code],
        });
        return true;
      }

      if (msg.action === "DISABLE_ADMIN_CODE") {
        await client.sendCommand("endpoint.invoke_cc_api", {
          nodeId: node.id,
          endpoint: 0,
          commandClass: CommandClasses["User Code"],
          methodName: "setAdminCode",
          args: [""],
        });
        return true;
      }
    }

    // Handle QUERY_USER_CODES - query specific user codes without full re-interview
    if (ctx.message?.type === "QUERY_USER_CODES") {
      const msg = ctx.message as QueryUserCodesMessage;

      // Query each user ID in sequence
      for (const userId of msg.userIds) {
        await client.sendCommand("endpoint.invoke_cc_api", {
          nodeId: node.id,
          endpoint: 0,
          commandClass: CommandClasses["User Code"],
          methodName: "get",
          args: [userId],
        });
      }
      return true;
    }
  },
});
