import { CommandClasses } from "@zwave-js/core";
import { registerHandler } from "../../prompt-handlers.ts";

// Map CTT CC names to CommandClasses enum values
const ccNameToCC: Record<string, CommandClasses> = {
  "Binary Switch": CommandClasses["Binary Switch"],
  "Multilevel Switch": CommandClasses["Multilevel Switch"],
  Meter: CommandClasses.Meter,
};

registerHandler(/.*/, {
  async onPrompt(ctx) {
    if (ctx.message?.type !== "CHECK_ENDPOINT_CAPABILITY") return;

    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    const valueIDs = node.getDefinedValueIDs();

    // Check each endpoint/CC pair from the structured message
    for (const { commandClass, endpoint } of ctx.message.endpoints) {
      const ccId = ccNameToCC[commandClass];

      if (ccId === undefined) {
        console.log(`Unknown CC name: ${commandClass}`);
        return "No";
      }

      // Check if this CC exists on the specified endpoint
      const hasCC = valueIDs.some(
        (v) => v.commandClass === ccId && v.endpoint === endpoint
      );

      if (!hasCC) {
        console.log(`CC ${commandClass} not found on endpoint ${endpoint}`);
        return "No";
      }
    }

    return "Yes";
  },
});
