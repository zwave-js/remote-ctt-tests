import { CentralSceneCCValues, CentralSceneKeys, CommandClass } from "zwave-js";
import { CommandClasses } from "@zwave-js/core";
import { registerHandler } from "../../prompt-handlers.ts";

const keyMapping: Record<string, CentralSceneKeys> = {
  "Key Pressed 1 time": CentralSceneKeys.KeyPressed,
  "Key Pressed 2 times": CentralSceneKeys.KeyPressed2x,
  "Key Pressed 3 times": CentralSceneKeys.KeyPressed3x,
  "Key Pressed 4 times": CentralSceneKeys.KeyPressed4x,
  "Key Pressed 5 times": CentralSceneKeys.KeyPressed5x,
  "held down": CentralSceneKeys.KeyHeldDown,
  released: CentralSceneKeys.KeyReleased,
};

const SCENE_EVENTS = "scene events";

registerHandler("CCR_CentralSceneCC_Rev03", {
  async onTestStart(ctx) {
    const sceneEvents = new Map<number, CentralSceneKeys>();
    ctx.state.set(SCENE_EVENTS, sceneEvents);

    ctx.driver.on("node value notification", (node, args) => {
      if (args.commandClass !== CommandClasses["Central Scene"]) return;
      if (CentralSceneCCValues.scene.is(args)) {
        // Property key is a zero-padded string
        const sceneId = parseInt(args.propertyKey as string);
        sceneEvents.set(sceneId, args.value as CentralSceneKeys);
      }
    });
  },

  async onPrompt(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    const numberOfScenesMatch =
      /the number of supported.+is (?<numScenes>\d+)/i.exec(ctx.promptText);
    if (numberOfScenesMatch?.groups) {
      const expectedNumScenes = parseInt(numberOfScenesMatch.groups.numScenes!);
      const actual = node.getValue(CentralSceneCCValues.sceneCount.id);
      return actual === expectedNumScenes ? "Yes" : "No";
    }

    const sceneChangedMatch =
      /has the scene.*?(?<sceneId>\d+).+to '(?<expected>.*?)'/i.exec(
        ctx.promptText
      );
    if (sceneChangedMatch?.groups) {
      const sceneId = parseInt(sceneChangedMatch.groups.sceneId!);
      const expectedRaw = sceneChangedMatch.groups.expected!;
      const expected = keyMapping[expectedRaw]!;

      const sceneEvents = ctx.state.get(SCENE_EVENTS) as Map<number, CentralSceneKeys>;
      const actual = sceneEvents.get(sceneId);

      console.log("expected value: ", CentralSceneKeys[expected]);
      console.log(
        "actual value: ",
        CentralSceneKeys[actual as CentralSceneKeys]
      );

      return actual === expected ? "Yes" : "No";
    }
  },
});
