import { registerHandler } from "../../prompt-handlers.ts";

registerHandler("S2_BootstrTimeoutsIncludingNode_Rev01", {
  async onTestStart(ctx) {
    // The test delays both user-interaction callbacks by 200 seconds to exercise the TAI1 key-confirmation and TAI2 PIN-entry limits
    ctx.state.set("S2 interaction delay", 200_000);
  },
});
