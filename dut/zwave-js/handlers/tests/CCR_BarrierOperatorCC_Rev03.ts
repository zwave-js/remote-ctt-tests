import { SubsystemType } from "zwave-js";
import { registerHandler } from "../../prompt-handlers.ts";

registerHandler("CCR_BarrierOperatorCC_Rev03", {
  async onPrompt(ctx) {
    if (
      /activate and deactivate the '(audible|visual) notification' subsystem/i.test(
        ctx.promptText
      )
    ) {
      return "Yes";
    }
  },
});
