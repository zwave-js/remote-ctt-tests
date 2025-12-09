import {
  BinarySwitchCC,
  BinarySwitchCCValues,
  MultilevelSwitchCCValues,
} from "zwave-js";
import { registerHandler } from "../../prompt-handlers.ts";

const boolFalseValues = new Set(["off", "0x00"]);
const boolTrueValues = new Set(["on", "0xff", "0xFF"]);

registerHandler(/.*/, {
  onPrompt: async (ctx) => {
    if (
      ctx.promptText.includes("confirm") &&
      ctx.promptText.includes("last known state")
    ) {
      const match =
        /last known state of (?<cc>[\w\s]+) is '(?<expected>.*?)'(?: \((?<alt>.*?)\))?/i.exec(
          ctx.promptText
        ) ??
        /last known state of (?<cc>[\w\s]+) is Z-Wave value = (?<expected>\d+)/i.exec(
          ctx.promptText
        );
      if (match?.groups) {
        const node = ctx.includedNodes.at(-1);
        if (!node) return;

        const ccName = match.groups["cc"];
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
            const actual = node.getValue(BinarySwitchCCValues.currentValue.id);
            return actual === expectedBool ? "Yes" : "No";
          }
          case "Multilevel Switch": {
            const actual = node.getValue(
              MultilevelSwitchCCValues.currentValue.id
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
