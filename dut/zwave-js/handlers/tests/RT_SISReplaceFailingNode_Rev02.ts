import { ZWaveErrorCodes } from "@zwave-js/core";
import {
  InclusionState,
  InclusionStrategy,
  type ZWaveController,
  type ZWaveNode,
} from "zwave-js";
import {
  registerHandler,
  type PromptContext,
} from "../../prompt-handlers.ts";
import { scheduleDelayedCommand } from "../delayedCommands.ts";
import { isNodeStillRespondingError } from "../behaviors/nodeReset.ts";
import {
  grantS2SecurityClasses,
  resetS2InteractionObservations,
  waitForInclusionIdle,
  waitForS2Pin,
} from "../behaviors/addMode.ts";

const REPLACEMENT_DELAY_MS = 100;
const REPLACEMENT_START_TIMEOUT_MS = 45_000;
const REPLACEMENT_COMPLETION_TIMEOUT_MS = 120_000;
const REPLACEMENT_RUNNING = "replace failed node running";

function withTimeout<T>(
  promise: Promise<T>,
  timeoutMs: number,
  message: string
): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error(message)), timeoutMs);
    promise.then(
      (value) => {
        clearTimeout(timeout);
        resolve(value);
      },
      (error: unknown) => {
        clearTimeout(timeout);
        reject(error);
      }
    );
  });
}

async function waitForReplacementNode(
  nodeId: number,
  controller: ZWaveController
): Promise<void> {
  let onNodeAdded!: (node: ZWaveNode) => void;
  const added = new Promise<void>((resolve) => {
    onNodeAdded = (node) => {
      if (node.id === nodeId) resolve();
    };
    controller.on("node added", onNodeAdded);
  });
  try {
    await withTimeout(
      added,
      REPLACEMENT_COMPLETION_TIMEOUT_MS,
      `Replacement node ${nodeId} was not added within ${REPLACEMENT_COMPLETION_TIMEOUT_MS} ms`
    );
  } finally {
    controller.off("node added", onNodeAdded);
  }
}

async function replaceFailedNode(
  nodeId: number,
  ctx: PromptContext
): Promise<void> {
  if (!ctx.driver.controller.nodes.has(nodeId)) {
    throw new Error(`Cannot replace unknown node ${nodeId}`);
  }

  resetS2InteractionObservations(ctx.state);
  const started = await withTimeout(
    ctx.driver.controller.replaceFailedNode(nodeId, {
      strategy: InclusionStrategy.Security_S2,
      userCallbacks: {
        abort() {},
        async grantSecurityClasses(requested) {
          return grantS2SecurityClasses(ctx.state, requested);
        },
        async validateDSKAndEnterPIN() {
          return waitForS2Pin(ctx.state);
        },
      },
    }),
    REPLACEMENT_START_TIMEOUT_MS,
    `Replacement of node ${nodeId} did not start within ${REPLACEMENT_START_TIMEOUT_MS} ms`
  );
  if (!started) {
    throw new Error(`Controller was busy when replacing node ${nodeId}`);
  }

  await waitForReplacementNode(nodeId, ctx.driver.controller);
  console.log(`Replacement of failed node ${nodeId} completed`);
}

async function cancelReplacement(
  nodeId: number,
  ctx: PromptContext
): Promise<void> {
  const { controller } = ctx.driver;
  if (controller.inclusionState === InclusionState.Including) {
    await controller.stopInclusion();
  }

  await ctx.driver.scheduler.removeTasks(
    (task) =>
      task.tag?.id === "replace-failed-node" && task.tag.nodeId === nodeId
  );

  if (controller.inclusionState !== InclusionState.Idle) {
    await ctx.driver.softReset();
  }

  await waitForInclusionIdle(ctx.driver);
}

async function runReplacement(
  nodeId: number,
  ctx: PromptContext
): Promise<void> {
  try {
    await replaceFailedNode(nodeId, ctx);
  } catch (error) {
    try {
      await cancelReplacement(nodeId, ctx);
    } catch (cancellationError) {
      throw new Error(`Failed to cancel replacement of node ${nodeId}`, {
        cause: cancellationError,
      });
    }

    if (
      isNodeStillRespondingError(
        error,
        ZWaveErrorCodes.ReplaceFailedNode_Failed
      )
    ) {
      console.log(
        `Replacement of responding node ${nodeId} was rejected as expected`
      );
      return;
    }
    console.error(`Failed to replace node ${nodeId}:`, error);
  }
}

registerHandler("RT_SISReplaceFailingNode_Rev02", {
  async onPrompt(ctx) {
    if (ctx.message.type !== "REPLACE_FAILED_NODE") return;

    if (ctx.state.get(REPLACEMENT_RUNNING)) {
      throw new Error("A failed-node replacement is already running");
    }
    ctx.state.set(REPLACEMENT_RUNNING, true);

    const nodeId = ctx.message.nodeId;
    scheduleDelayedCommand(ctx.state, REPLACEMENT_DELAY_MS, async () => {
      await runReplacement(nodeId, ctx);
      // A failed cancellation leaves the controller in an unknown state, so the guard
      // must stay set to keep a second replacement from starting
      ctx.state.delete(REPLACEMENT_RUNNING);
    });

    return "Ok";
  },
});
