import { registerHandler } from "../../prompt-handlers.ts";

registerHandler(/^S0_/, {
  async onTestStart(ctx) {
    // zwave-js declines S0 with the default strategy unless the application opts in
    ctx.state.set("force S0 inclusion", true);
  },
});
