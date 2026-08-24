import { CommandClasses } from "@zwave-js/core";
import type { CCVisibilityCommandClass } from "../../../../src/ctt-message-types.ts";
import { registerHandler } from "../../prompt-handlers.ts";

const ccNameToCC: Record<CCVisibilityCommandClass, CommandClasses> = {
  Battery: CommandClasses.Battery,
  "Binary Switch": CommandClasses["Binary Switch"],
  "Multilevel Sensor": CommandClasses["Multilevel Sensor"],
};

registerHandler(/.*/, {
  async onPrompt(ctx) {
    if (ctx.message.type !== "CHECK_CC_VISIBILITY") return;

    const node = ctx.driver.controller.nodes.get(ctx.message.nodeId);
    if (!node) return "No";

    const commandClasses = new Set(
      ctx.message.commandClasses.map((name) => ccNameToCC[name])
    );
    const visible = node
      .getDefinedValueIDs()
      .some((valueId) => commandClasses.has(valueId.commandClass));

    return visible === ctx.message.expectedVisible ? "Yes" : "No";
  },
});
