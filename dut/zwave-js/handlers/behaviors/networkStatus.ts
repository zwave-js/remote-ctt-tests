import { wait } from "alcalzone-shared/async";
import { NodeStatus } from "zwave-js";
import { registerHandler } from "../../prompt-handlers.ts";

registerHandler(/.*/, {
  async onPrompt(ctx) {
    if (ctx.message?.type !== "CHECK_NETWORK_STATUS") return;

    const { check, nodeId } = ctx.message;

    if (check === "RESET_AND_LEFT") {
      // It can take a while for the node to be removed from the controller's node list, so poll for it.
      for (let attempt = 1; attempt <= 5; attempt++) {
        if (!ctx.driver.controller.nodes.has(nodeId)) {
          return "Yes";
        }
        await wait(1000 * attempt);
      }
      return "No";
    }

    if (check === "INCLUDED") {
      return ctx.driver.controller.nodes.has(nodeId) ? "Yes" : "No";
    }

    if (check === "NOT_INCLUDED") {
      return ctx.driver.controller.nodes.has(nodeId) ? "No" : "Yes";
    }

    if (check === "FAILED") {
      // Wait up to 1 minute for the node to be marked as dead.
      // Polling is simpler than handling events and works just as well.
      for (let attempt = 0; attempt < 60; attempt++) {
        if (
          ctx.driver.controller.nodes.get(nodeId)?.status === NodeStatus.Dead
        ) {
          return "Yes";
        }
        await wait(1000);
      }
      return "No";
    }
  },
});
