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
    // Match the endpoint control confirmation prompt
    // e.g. "Please refer to the DUT's UI and confirm if control of:
    //        * Binary Switch     on End Point 1
    //        * Meter             on End Point 2
    //        --- End Point 4 does not exist! ---
    //        * Multilevel Switch on End Point 7
    //      is provided!"
    if (!/confirm if control of:/i.test(ctx.promptText)) return;
    if (!/on end ?point/i.test(ctx.promptText)) return;
    if (!/is provided/i.test(ctx.promptText)) return;

    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    const valueIDs = node.getDefinedValueIDs();

    // Parse each "* <CC name> on End Point <N>" line
    const pattern = /\*\s+(?<cc>[\w\s]+?)\s+on End Point (?<ep>\d+)/gi;
    let match;

    while ((match = pattern.exec(ctx.promptText))?.groups) {
      const ccName = match.groups.cc!.trim();
      const endpoint = parseInt(match.groups.ep!);
      const ccId = ccNameToCC[ccName];

      if (ccId === undefined) {
        console.log(`Unknown CC name: ${ccName}`);
        return "No";
      }

      // Check if this CC exists on the specified endpoint
      const hasCC = valueIDs.some(
        (v) => v.commandClass === ccId && v.endpoint === endpoint
      );

      if (!hasCC) {
        console.log(`CC ${ccName} not found on endpoint ${endpoint}`);
        return "No";
      }
    }

    return "Yes";
  },
});
