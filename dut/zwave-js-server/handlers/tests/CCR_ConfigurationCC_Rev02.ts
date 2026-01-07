import { ConfigurationCCValues } from "zwave-js";
import { CommandClasses, ConfigValueFormat } from "@zwave-js/core";
import { registerHandler } from "../../prompt-handlers.ts";
import type { SendCommandMessage } from "../../../../src/ctt-message-types.ts";

registerHandler("CCR_ConfigurationCC_Rev02", {
  async onLog(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    const { client } = ctx;

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
          await client.sendCommand("endpoint.invoke_cc_api", {
            nodeId: node.id,
            endpoint: 0,
            commandClass: CommandClasses.Configuration,
            methodName: "set",
            args: [{
              parameter: param,
              value,
              valueSize: size,
              valueFormat: ConfigValueFormat.SignedInteger,
            }],
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
        await client.sendCommand("endpoint.invoke_cc_api", {
          nodeId: node.id,
          endpoint: 0,
          commandClass: CommandClasses.Configuration,
          methodName: "reset",
          args: [param],
        });
        return true;
      }
      if (msg.action === "RESET_ALL") {
        await client.sendCommand("endpoint.invoke_cc_api", {
          nodeId: node.id,
          endpoint: 0,
          commandClass: CommandClasses.Configuration,
          methodName: "resetAll",
          args: [],
        });
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
