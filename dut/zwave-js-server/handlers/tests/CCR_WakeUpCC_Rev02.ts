import { registerHandler } from "../../prompt-handlers.ts";

registerHandler("CCR_WakeUpCC_Rev02", {
  onPrompt: async (ctx) => {
    // Handle CC_CAPABILITY_QUERY for Wake Up CC supervision
    if (
      ctx.message?.type === "CC_CAPABILITY_QUERY" &&
      ctx.message.commandClass === "Wake Up" &&
      ctx.message.capabilityId === "USES_SUPERVISION"
    ) {
      // Z-Wave JS uses Supervision for Wake Up Interval Set if supported
      return "Yes";
    }

    return undefined;
  },
});
