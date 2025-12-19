import {
  BasicCCValues,
  BinarySwitchCCValues,
  MultilevelSwitchCCValues,
} from "zwave-js";
import { registerHandler } from "../../prompt-handlers.ts";
import { getUIContext } from "./uiContext.ts";
import { wait } from "alcalzone-shared/async";

const boolFalseValues = new Set(["off", "0", "0x00"]);
const boolTrueValues = new Set(["on", "255", "0xff", "0xFF"]);

registerHandler(/.*/, {
  onPrompt: async (ctx) => {
    if (ctx.message?.type !== "VERIFY_STATE") return;

    const { commandClass: msgCC, endpoint: msgEndpoint = 0, expected, alternativeValue } = ctx.message;

    // First try to get node from UI context, then fall back to last included node
    const uiContext = getUIContext(ctx);
    const node = uiContext
      ? ctx.includedNodes.find((n) => n.id === uiContext.nodeId)
      : ctx.includedNodes.at(-1);

    if (!node) return;

    // Use UI context for command class and endpoint when message has "unknown"
    const commandClass = msgCC === "unknown" && uiContext ? uiContext.commandClass : msgCC;
    const endpoint = msgCC === "unknown" && uiContext?.endpoint !== undefined ? uiContext.endpoint : msgEndpoint;

    // Help with timing issues. Especially with S0, the CTT seems to ask
    // before the command is received and processed.
    await wait(100);

    // Build set of acceptable values
    const allExpected = new Set<string>();
    if (typeof expected === "string") {
      allExpected.add(expected.toLowerCase());
    } else if (typeof expected === "number") {
      allExpected.add(String(expected));
    }
    if (alternativeValue) {
      allExpected.add(alternativeValue.toLowerCase());
    }

    // Determine expected boolean value
    const expectedBool =
      allExpected.intersection(boolTrueValues).size > 0
        ? true
        : allExpected.intersection(boolFalseValues).size > 0
        ? false
        : undefined;

    // Parse expected number
    const expectedNum =
      typeof expected === "number"
        ? expected
        : typeof expected === "string"
        ? parseInt(expected)
        : NaN;

    switch (commandClass) {
      case "Basic": {
        // A report of 255 means 100%, which is mapped to 99 in Z-Wave JS
        let targetValue = expectedNum;
        if (targetValue === 255) targetValue = 99;
        const actual = node.getValue(BasicCCValues.currentValue.endpoint(endpoint));
        return actual === targetValue ? "Yes" : "No";
      }
      case "Binary Switch": {
        const actual = node.getValue(
          BinarySwitchCCValues.currentValue.endpoint(endpoint)
        );
        // For Binary Switch, compare with boolean or number > 0
        if (expectedBool !== undefined) {
          return actual === expectedBool ? "Yes" : "No";
        }
        return actual === (expectedNum > 0) ? "Yes" : "No";
      }
      case "Multilevel Switch": {
        const actual = node.getValue(
          MultilevelSwitchCCValues.currentValue.endpoint(endpoint)
        );
        return actual === expectedNum ? "Yes" : "No";
      }
    }

    // Let other CC types fall through to manual handling
    return undefined;
  },
});
