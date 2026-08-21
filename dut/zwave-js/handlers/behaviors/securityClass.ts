import { SecurityClass } from "@zwave-js/core";
import { registerHandler } from "../../prompt-handlers.ts";
import type { SecurityClassCheck } from "../../../../src/ctt-message-types.ts";

const concreteSecurityClasses: Partial<
  Record<SecurityClassCheck, SecurityClass>
> = {
  INSECURE: SecurityClass.None,
  S0: SecurityClass.S0_Legacy,
  S2_UNAUTHENTICATED: SecurityClass.S2_Unauthenticated,
  S2_AUTHENTICATED: SecurityClass.S2_Authenticated,
  S2_ACCESS_CONTROL: SecurityClass.S2_AccessControl,
};

registerHandler(/.*/, {
  async onPrompt(ctx) {
    if (ctx.message?.type !== "CHECK_SECURITY_CLASS") return;

    const node = ctx.driver.controller.nodes.get(ctx.message.nodeId);
    if (!node) return "No";

    const actual = node.getHighestSecurityClass();
    if (ctx.message.securityClass === "S2") {
      return actual !== undefined &&
        actual >= SecurityClass.S2_Unauthenticated &&
        actual <= SecurityClass.S2_AccessControl
        ? "Yes"
        : "No";
    }

    return actual === concreteSecurityClasses[ctx.message.securityClass]
      ? "Yes"
      : "No";
  },
});
