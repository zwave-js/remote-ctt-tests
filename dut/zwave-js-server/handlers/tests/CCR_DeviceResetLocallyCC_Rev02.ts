import { registerHandler } from "../../prompt-handlers.ts";

registerHandler("CCR_DeviceResetLocallyCC_Rev02", {
  onPrompt: async (ctx) => {
    // Handle DUT_CAPABILITY_QUERY for MAINS_POWERED
    if (
      ctx.message?.type === "DUT_CAPABILITY_QUERY" &&
      ctx.message.capabilityId === "MAINS_POWERED"
    ) {
      return "Yes";
    }

    return undefined;
  },
});
