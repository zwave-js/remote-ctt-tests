import { registerHandler } from "../../prompt-handlers.ts";

registerHandler("S2_WarningHighestKeyNotGranted_Rev01", {
  async onTestStart(ctx) {
    // The test omits S2 Access to exercise the partial-grant and no-security warning outcomes
    ctx.state.set("exclude S2 Access", true);
  },
});
