import { UserIDStatus, KeypadMode } from "zwave-js";
import { registerHandler } from "../../prompt-handlers.ts";
import type { SendCommandMessage } from "../../../../src/ctt-message-types.ts";

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
          // @ts-expect-error This API has pretty conditional types
          await node.commandClasses["User Code"].set(userId, statusEnum, code);
          return true;
        }
      }

      if (msg.action === "CLEAR") {
        const { userId } = msg as { userId: number };
        await node.commandClasses["User Code"].clear(userId);
        return true;
      }

      if (msg.action === "SET_KEYPAD_MODE") {
        const { mode } = msg as { mode: string };
        const modeEnum = keypadModeNameToEnum[mode.toLowerCase()];
        if (modeEnum !== undefined) {
          await node.commandClasses["User Code"].setKeypadMode(modeEnum);
          return true;
        }
      }

      if (msg.action === "SET_ADMIN_CODE") {
        const { code } = msg as { code: string };
        await node.commandClasses["User Code"].setAdminCode(code);
        return true;
      }

      if (msg.action === "DISABLE_ADMIN_CODE") {
        await node.commandClasses["User Code"].setAdminCode("");
        return true;
      }
    }
  },
});
