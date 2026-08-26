import { CentralSceneCCValues, CentralSceneKeys } from "zwave-js";
import { CommandClasses } from "@zwave-js/core";
import { registerHandler } from "../../prompt-handlers.ts";
import type { VerifyStateMessage, VerifySceneMessage } from "../../../../src/ctt-message-types.ts";
import type { NodeProxy } from "../../zwave-client.ts";

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

// Module-level variable to track cleanup function (persists across test state clears)
let currentSceneCleanup: (() => void) | undefined;

registerHandler("CCR_CentralSceneCC_Rev03", {
  async onTestStart(ctx) {
    const { client, state } = ctx;

    // Clean up any leftover listener from previous test
    if (currentSceneCleanup) {
      currentSceneCleanup();
      currentSceneCleanup = undefined;
    }

    const sceneEvents = new Map<number, CentralSceneKeys>();
    state.set(SCENE_EVENTS, sceneEvents);

    const onValueNotification = (node: NodeProxy | undefined, args: {
      commandClass: number;
      property: string;
      propertyKey?: string | number;
      value: unknown;
    }) => {
      if (args.commandClass !== CommandClasses["Central Scene"]) return;
      if (CentralSceneCCValues.scene.is(args)) {
        // Property key is a zero-padded string
        const sceneId = parseInt(args.propertyKey as string);
        sceneEvents.set(sceneId, args.value as CentralSceneKeys);
      }
    };

    client.on("node value notification", onValueNotification);
    currentSceneCleanup = () => {
      client.off("node value notification", onValueNotification);
    };
  },

  async onPrompt(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Handle VERIFY_STATE for scene count
    if (
      ctx.message?.type === "VERIFY_STATE" &&
      ctx.message.commandClass === "Central Scene" &&
      ctx.message.property === "sceneCount"
    ) {
      const msg = ctx.message as VerifyStateMessage;
      const expectedNumScenes =
        typeof msg.expected === "number"
          ? msg.expected
          : parseInt(String(msg.expected));
      const actual = node.getValue(CentralSceneCCValues.sceneCount.id);
      return actual === expectedNumScenes ? "Yes" : "No";
    }

    // Handle VERIFY_SCENE
    if (ctx.message?.type === "VERIFY_SCENE") {
      const msg = ctx.message as VerifySceneMessage;
      const expected = keyMapping[msg.expectedKeyState]!;

      const sceneEvents = ctx.state.get(SCENE_EVENTS) as Map<
        number,
        CentralSceneKeys
      >;
      const actual = sceneEvents.get(msg.sceneId);

      console.log("expected value: ", CentralSceneKeys[expected]);
      console.log(
        "actual value: ",
        CentralSceneKeys[actual as CentralSceneKeys]
      );

      return actual === expected ? "Yes" : "No";
    }
  },
});
