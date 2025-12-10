import { UserIDStatus, KeypadMode } from "zwave-js";
import { registerHandler } from "../../prompt-handlers.ts";

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

    // Set User ID 'X' ... to User ID Status 'Y' with User Code 'Z'
    const setMatch =
      /Set User ID '(?<userId>\d+)'.*User ID Status '(?<status>[^']+)'.*User Code '(?<code>[^']+)'/i.exec(
        ctx.logText
      );
    if (setMatch?.groups) {
      const userId = parseInt(setMatch.groups.userId!);
      const status = statusNameToEnum[setMatch.groups.status!.toLowerCase()];
      const code = setMatch.groups.code;
      if (status !== undefined) {
        // @ts-expect-error This API has pretty conditional types
        await node.commandClasses["User Code"].set(userId, status, code);
        return true;
      }
    }

    // Add a new User Code (first available User ID is 'X')
    const addMatch =
      /Add a new User Code.*first available User ID is '(?<userId>\d+)'.*User ID Status '(?<status>[^']+)'.*User Code '(?<code>[^']+)'/i.exec(
        ctx.logText
      );
    if (addMatch?.groups) {
      const userId = parseInt(addMatch.groups.userId!);
      const status = statusNameToEnum[addMatch.groups.status!.toLowerCase()];
      const code = addMatch.groups.code;
      if (status !== undefined) {
        // @ts-expect-error This API has pretty conditional types
        await node.commandClasses["User Code"].set(userId, status, code);
        return true;
      }
    }

    // Erase User ID 'X'
    const eraseMatch = /Erase User ID '(?<userId>\d+)'/i.exec(ctx.logText);
    if (eraseMatch?.groups) {
      const userId = parseInt(eraseMatch.groups.userId!);
      await node.commandClasses["User Code"].clear(userId);
      return true;
    }

    // Set Keypad mode to 'X'
    const keypadMatch = /Set Keypad mode to '(?<mode>\w+)'/i.exec(ctx.logText);
    if (keypadMatch?.groups) {
      const mode = keypadModeNameToEnum[keypadMatch.groups.mode!.toLowerCase()];
      if (mode !== undefined) {
        await node.commandClasses["User Code"].setKeypadMode(mode);
        return true;
      }
    }

    // Set Admin Code to 'X'
    const adminMatch = /Set Admin Code to '(?<code>[^']+)'/i.exec(ctx.logText);
    if (adminMatch?.groups) {
      await node.commandClasses["User Code"].setAdminCode(adminMatch.groups.code!);
      return true;
    }

    // Disable Admin Code
    if (/Disable Admin Code/i.test(ctx.logText)) {
      await node.commandClasses["User Code"].setAdminCode("");
      return true;
    }
  },
});
