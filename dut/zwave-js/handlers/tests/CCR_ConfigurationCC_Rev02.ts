import { ConfigurationCCValues } from "zwave-js";
import { ConfigValueFormat } from "@zwave-js/core";
import { registerHandler } from "../../prompt-handlers.ts";
import type { SendCommandMessage } from "../../../../src/ctt-message-types.ts";

registerHandler("CCR_ConfigurationCC_Rev02", {
  async onLog(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Handle SEND_COMMAND for Configuration CC
    if (
      ctx.message?.type === "SEND_COMMAND" &&
      ctx.message.commandClass === "Configuration"
    ) {
      const msg = ctx.message as SendCommandMessage;
      if (msg.action === "SET") {
        const { param, value, size } = msg as {
          param: number;
          value: number;
          size?: 1 | 2 | 4;
        };
        if (size !== undefined) {
          await node.commandClasses.Configuration.set({
            parameter: param,
            value,
            valueSize: size,
            valueFormat: ConfigValueFormat.SignedInteger,
          });
        } else {
          await node.setValue(
            ConfigurationCCValues.paramInformation(param).id,
            value
          );
        }
        return true;
      }
      if (msg.action === "RESET") {
        const { param } = msg as { param: number };
        await node.commandClasses.Configuration.reset(param);
        return true;
      }
      if (msg.action === "RESET_ALL") {
        await node.commandClasses.Configuration.resetAll();
        return true;
      }
    }
  },

  async onPrompt(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Handle TRY_SET_CONFIG_PARAMETER
    if (ctx.message?.type === "TRY_SET_CONFIG_PARAMETER") {
      const writeable = node.getValueMetadata(
        ConfigurationCCValues.paramInformation(ctx.message.paramNumber).id
      ).writeable;
      return writeable ? "Yes" : "No";
    }
  },
});
