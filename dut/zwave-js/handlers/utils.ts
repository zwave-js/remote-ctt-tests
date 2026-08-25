import {
  Duration,
  type ZWaveNode,
  type ZWaveNodeValueAddedArgs,
  type ZWaveNodeValueUpdatedArgs,
} from "zwave-js";
import { valueIdToString, type ValueID } from "@zwave-js/core";

export function parseDurationFromLog(
  unit: string,
  value?: string
): Duration | undefined {
  if (unit === "instantly") {
    return new Duration(0, "seconds");
  } else if (unit.includes("default") || unit.includes("factory")) {
    return Duration.default();
  }

  if (!value) return;
  const valueNum = parseInt(value);
  if (isNaN(valueNum)) return;

  return unit === "seconds"
    ? new Duration(valueNum, "seconds")
    : new Duration(valueNum, "minutes");
}

// Six seconds exceeds zwave-js's five-second supervised-Set refresh delay
const VALUE_UPDATE_TIMEOUT_MS = 6_000;

export function waitForValueUpdate(
  node: ZWaveNode,
  valueId: ValueID
): Promise<void> {
  return new Promise((resolve) => {
    const target = valueIdToString(valueId);

    const settle = () => {
      node.off("value added", handleValueChange);
      node.off("value updated", handleValueChange);
      clearTimeout(timeout);
      resolve();
    };

    const handleValueChange = (
      eventNode: ZWaveNode,
      args: ZWaveNodeValueAddedArgs | ZWaveNodeValueUpdatedArgs
    ) => {
      if (eventNode.id !== node.id || valueIdToString(args) !== target) return;
      settle();
    };

    node.on("value added", handleValueChange);
    node.on("value updated", handleValueChange);
    const timeout = setTimeout(settle, VALUE_UPDATE_TIMEOUT_MS);
  });
}
