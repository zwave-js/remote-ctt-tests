import { SoundSwitchCCValues, ToneId } from "zwave-js";
import { CommandClasses } from "@zwave-js/core";
import { registerHandler } from "../../prompt-handlers.ts";
import type { SendCommandMessage } from "../../../../src/ctt-message-types.ts";
import type { NodeProxy } from "../../zwave-client.ts";

function getToneIdByName(
  node: NodeProxy,
  toneName: string
): number | undefined {
  const metadata = node.getValueMetadata(SoundSwitchCCValues.toneId.id);
  if (!metadata || !("states" in metadata) || !(metadata as { states?: Record<string, string> }).states)
    return undefined;

  for (const [id, label] of Object.entries((metadata as { states: Record<string, string> }).states)) {
    if (label.toLowerCase().startsWith(toneName.toLowerCase())) {
      return parseInt(id);
    }
  }
}

registerHandler("CCR_SoundSwitchCC_Rev02", {
  async onLog(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    const { client } = ctx;

    // Handle SEND_COMMAND for Sound Switch
    if (
      ctx.message?.type === "SEND_COMMAND" &&
      ctx.message.commandClass === "Sound Switch"
    ) {
      const msg = ctx.message as SendCommandMessage;

      switch (msg.action) {
        case "SET_TONE": {
          const tone = (msg as { tone: string }).tone;
          const toneId = getToneIdByName(node, tone);
          if (toneId !== undefined) {
            await client.sendCommand("endpoint.invoke_cc_api", {
              nodeId: node.id,
              endpoint: 0,
              commandClass: CommandClasses["Sound Switch"],
              methodName: "setConfiguration",
              args: [toneId, 0xff],
            });
            return true;
          }
          break;
        }

        case "SET_VOLUME": {
          const volume = (msg as { volume: number }).volume;
          await client.sendCommand("endpoint.invoke_cc_api", {
            nodeId: node.id,
            endpoint: 0,
            commandClass: CommandClasses["Sound Switch"],
            methodName: "setConfiguration",
            args: [0, volume],
          });
          return true;
        }

        case "MUTE": {
          await client.sendCommand("endpoint.invoke_cc_api", {
            nodeId: node.id,
            endpoint: 0,
            commandClass: CommandClasses["Sound Switch"],
            methodName: "setConfiguration",
            args: [0, 0],
          });
          return true;
        }

        case "PLAY": {
          const tone = (msg as { tone: string }).tone;
          const toneId = getToneIdByName(node, tone);
          if (toneId !== undefined) {
            await client.sendCommand("endpoint.invoke_cc_api", {
              nodeId: node.id,
              endpoint: 0,
              commandClass: CommandClasses["Sound Switch"],
              methodName: "play",
              args: [toneId],
            });
            return true;
          }
          break;
        }

        case "STOP": {
          await client.sendCommand("endpoint.invoke_cc_api", {
            nodeId: node.id,
            endpoint: 0,
            commandClass: CommandClasses["Sound Switch"],
            methodName: "stopPlaying",
            args: [],
          });
          return true;
        }

        case "PLAY_DEFAULT": {
          await client.sendCommand("endpoint.invoke_cc_api", {
            nodeId: node.id,
            endpoint: 0,
            commandClass: CommandClasses["Sound Switch"],
            methodName: "play",
            args: [ToneId.Default],
          });
          return true;
        }
      }
    }
  },
});
