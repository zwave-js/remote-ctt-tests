import { BinarySwitchCCValues, MultilevelSwitchCCValues } from "zwave-js";
import { registerHandler } from "../../prompt-handlers.ts";

const boolFalseValues = new Set(["off", "0", "0x00"]);
const boolTrueValues = new Set(["on", "255", "0xff", "0xFF"]);

registerHandler(/.*/, {
  onPrompt: async (ctx) => {
    // Handle "last known state" confirmation prompts (with optional endpoint)
    if (
      ctx.promptText.includes("confirm") &&
      ctx.promptText.includes("last known state")
    ) {
      const match =
        // Non-greedy if there are '
        /last known state of (?<cc>[\w\s]+?)(?: (on|to) end ?point (?<endpoint>\d+))? is (Z-Wave value = )?'(?<expected>.*?)'(?: \((?<alt>.+?)\))?/i.exec(
          ctx.promptText
        ) ??
        // Greedy without '
        /last known state of (?<cc>[\w\s]+?)(?: (on|to) end ?point (?<endpoint>\d+))? is (Z-Wave value = )?(?<expected>\d+)(?: \((?<alt>.+?)\))?/i.exec(
          ctx.promptText
        );
      if (match?.groups) {
        const node = ctx.includedNodes.at(-1);
        if (!node) return;

        const ccName = match.groups["cc"]?.trim();
        const endpoint = match.groups["endpoint"]
          ? parseInt(match.groups["endpoint"])
          : 0;
        const expected = match.groups["expected"]!;
        const alt = match.groups["alt"];
        const allExpected = new Set([expected]);
        if (alt != undefined) allExpected.add(alt);

        // Make it easier to compare boolean values
        const expectedBool =
          allExpected.intersection(boolTrueValues).size > 0
            ? true
            : allExpected.intersection(boolFalseValues).size > 0
            ? false
            : undefined;

        const expectedNum = parseInt(expected);

        switch (ccName) {
          case "Binary Switch": {
            const actual = node.getValue(
              BinarySwitchCCValues.currentValue.endpoint(endpoint)
            );
            return actual === expectedBool ? "Yes" : "No";
          }
          case "Multilevel Switch": {
            const actual = node.getValue(
              MultilevelSwitchCCValues.currentValue.endpoint(endpoint)
            );
            return actual === expectedNum ? "Yes" : "No";
          }
        }
      }
    }

    // Let other prompts fall through to manual handling
    return undefined;
  },
});
