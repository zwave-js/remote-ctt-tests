import { SoundSwitchCCValues, ToneId, type ZWaveNode } from "zwave-js";
import { registerHandler } from "../../prompt-handlers.ts";
import type { SendCommandMessage } from "../../../../src/ctt-message-types.ts";

function getToneIdByName(
  node: ZWaveNode,
  toneName: string
): number | undefined {
  const metadata = node.getValueMetadata(SoundSwitchCCValues.toneId.id);
  if (!metadata || !("states" in metadata) || !metadata.states)
    return undefined;

  for (const [id, label] of Object.entries(metadata.states)) {
    if (label.toLowerCase().startsWith(toneName.toLowerCase())) {
      return parseInt(id);
    }
  }
}

registerHandler("CCR_SoundSwitchCC_Rev02", {
  async onLog(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

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
            await node.commandClasses["Sound Switch"].setConfiguration(
              toneId,
              0xff
            );
            return true;
          }
          break;
        }

        case "SET_VOLUME": {
          const volume = (msg as { volume: number }).volume;
          await node.commandClasses["Sound Switch"].setConfiguration(0, volume);
          return true;
        }

        case "MUTE": {
          await node.commandClasses["Sound Switch"].setConfiguration(0, 0);
          return true;
        }

        case "PLAY": {
          const tone = (msg as { tone: string }).tone;
          const toneId = getToneIdByName(node, tone);
          if (toneId !== undefined) {
            await node.commandClasses["Sound Switch"].play(toneId);
            return true;
          }
          break;
        }

        case "STOP": {
          await node.commandClasses["Sound Switch"].stopPlaying();
          return true;
        }

        case "PLAY_DEFAULT": {
          await node.commandClasses["Sound Switch"].play(ToneId.Default);
          return true;
        }
      }
    }
  },
});
