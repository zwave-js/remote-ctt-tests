import { SoundSwitchCCValues, ToneId, type ZWaveNode } from "zwave-js";
import { registerHandler } from "../../prompt-handlers.ts";

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

    // Set default tone to 'Tone X'
    const defaultToneMatch = /Set default tone to '(?<tone>[^']+)'/i.exec(
      ctx.logText
    );
    if (defaultToneMatch?.groups?.tone) {
      const toneId = getToneIdByName(node, defaultToneMatch.groups.tone);
      if (toneId !== undefined) {
        await node.commandClasses["Sound Switch"].setConfiguration(
          toneId,
          0xff
        );
        return true;
      }
    }

    // Please set volume to X!
    const volumeMatch = /set volume to (?<volume>\d+)/i.exec(ctx.logText);
    if (volumeMatch?.groups?.volume) {
      const volume = parseInt(volumeMatch.groups.volume);
      await node.commandClasses["Sound Switch"].setConfiguration(0, volume);
      return true;
    }

    // Please mute Volume (set to 0)!
    if (/mute volume/i.test(ctx.logText)) {
      await node.commandClasses["Sound Switch"].setConfiguration(0, 0);
      return true;
    }

    // Please play tone 'Tone X'!
    const playToneMatch = /play tone '(?<tone>[^']+)'/i.exec(ctx.logText);
    if (playToneMatch?.groups?.tone) {
      const toneId = getToneIdByName(node, playToneMatch.groups.tone);
      if (toneId !== undefined) {
        await node.commandClasses["Sound Switch"].play(toneId);
        return true;
      }
    }

    // Please stop all tones being currently played!
    if (/stop all tones/i.test(ctx.logText)) {
      await node.commandClasses["Sound Switch"].stopPlaying();
      return true;
    }

    // Please play default tone!
    if (/play default tone/i.test(ctx.logText)) {
      await node.commandClasses["Sound Switch"].play(ToneId.Default);
      return true;
    }
  },
});
