import { Duration } from "zwave-js";

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
