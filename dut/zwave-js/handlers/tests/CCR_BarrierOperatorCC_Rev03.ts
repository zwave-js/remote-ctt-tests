import { SubsystemType } from "zwave-js";
import { registerHandler, type PromptContext } from "../../prompt-handlers.ts";
import { TEST_STATE_LAST_NODE_ID } from "../shared/consts.ts";

registerHandler("CCR_BarrierOperatorCC_Rev03", {
  async onPrompt(ctx) {
    if (
      /activate and deactivate the '(audible|visual) notification' subsystem/i.test(
        ctx.promptText
      )
    ) {
      return "Yes";
    }
  },

  async onLog(ctx) {
    const match =
      /BARRIER_OPERATOR_(?<cmd>[\w_]+) with target value='(?<targetValue>(0x)?[a-fA-F0-9]+)'/i;
    const result = match.exec(ctx.logText);
    if (result?.groups) {
      const cmd = result.groups["cmd"];
      const targetValue = parseInt(result.groups["targetValue"]);
      const lastNodeId = ctx.state.get(TEST_STATE_LAST_NODE_ID) as number;
      const node = ctx.driver.controller.nodes.get(lastNodeId);
      if (!node) return;

      // Figure out which commands to send based on the log
      switch (cmd) {
        case "SET":
          node.commandClasses["Barrier Operator"].set(targetValue);
          return;

        case "EVENT_SIGNAL_SET":
          if (ctx.logText.includes("AudibleNotification")) {
            node.commandClasses["Barrier Operator"].setEventSignaling(
              SubsystemType.Audible,
              targetValue
            );
            return;
          }

          if (ctx.logText.includes("VisualNotification")) {
            node.commandClasses["Barrier Operator"].setEventSignaling(
              SubsystemType.Visual,
              targetValue
            );
            return;
          }

          break;
      }
    }
  },
});
