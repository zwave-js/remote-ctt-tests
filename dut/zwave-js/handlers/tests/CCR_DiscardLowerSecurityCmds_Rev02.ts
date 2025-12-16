import { registerHandler } from "../../prompt-handlers.ts";
import { FORCE_S0 } from "../behaviors/addMode.ts";

registerHandler("CCR_DiscardLowerSecurityCmds_Rev02", {
  onLog: async (ctx) => {
    // Detect when CTT signals that the next inclusion should use S0 security
    if (
      /handles commands from a supporting node with S0 security level/i.test(
        ctx.logText
      )
    ) {
      console.log("[DiscardLowerSecurity] Next inclusion will be S0-only");
      ctx.state.set(FORCE_S0, true);
      return true;
    }
  },
});
