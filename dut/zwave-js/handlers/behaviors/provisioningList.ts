import { Protocols, SecurityClass } from "@zwave-js/core";
import { ProvisioningEntryStatus } from "zwave-js";
import { registerHandler } from "../../prompt-handlers.ts";
import type { ProvisioningSecurityClass } from "../../../../src/ctt-message-types.ts";

const securityClassMap: Record<ProvisioningSecurityClass, SecurityClass> = {
  S2_AccessControl: SecurityClass.S2_AccessControl,
  S2_Authenticated: SecurityClass.S2_Authenticated,
  S2_Unauthenticated: SecurityClass.S2_Unauthenticated,
};

registerHandler(/.*/, {
  async onPrompt(ctx) {
    if (ctx.message?.type !== "MANAGE_PROVISIONING") return;

    if (ctx.message.action === "ADD") {
      const isLongRange = ctx.message.protocol === "LONG_RANGE";
      ctx.driver.controller.provisionSmartStartNode({
        dsk: ctx.message.dsk,
        protocol: isLongRange ? Protocols.ZWaveLongRange : Protocols.ZWave,
        securityClasses: isLongRange
          ? [
              SecurityClass.S2_AccessControl,
              SecurityClass.S2_Authenticated,
            ]
          : [
              SecurityClass.S2_AccessControl,
              SecurityClass.S2_Authenticated,
              SecurityClass.S2_Unauthenticated,
            ],
      });
      ctx.notifications.provisioningEntryAdded(ctx.message.dsk);
    } else if (ctx.message.action === "REMOVE") {
      ctx.driver.controller.unprovisionSmartStartNode(ctx.message.dsk);
      ctx.notifications.provisioningEntryRemoved(ctx.message.dsk);
    } else if (ctx.message.action === "REMOVE_ALL") {
      for (const entry of ctx.driver.controller.getProvisioningEntries()) {
        ctx.driver.controller.unprovisionSmartStartNode(entry.dsk);
        ctx.notifications.provisioningEntryRemoved(entry.dsk);
      }
    } else if (ctx.message.action === "SET_KEYS") {
      const entry = ctx.driver.controller.getProvisioningEntry(ctx.message.dsk);
      if (!entry) {
        throw new Error(
          `SmartStart provisioning entry ${ctx.message.dsk} does not exist`
        );
      }
      ctx.driver.controller.provisionSmartStartNode({
        ...entry,
        securityClasses: ctx.message.securityClasses.map(
          (securityClass) => securityClassMap[securityClass]
        ),
      });
    } else if (ctx.message.action === "SET_STATUS") {
      const entry = ctx.driver.controller.getProvisioningEntry(ctx.message.dsk);
      if (!entry) {
        throw new Error(
          `SmartStart provisioning entry ${ctx.message.dsk} does not exist`
        );
      }
      ctx.driver.controller.provisionSmartStartNode({
        ...entry,
        status:
          ctx.message.status === "ACTIVE"
            ? ProvisioningEntryStatus.Active
            : ProvisioningEntryStatus.Inactive,
      });
    } else {
      const entry = ctx.driver.controller.getProvisioningEntry(ctx.message.dsk);
      if (ctx.message.action === "CHECK_PENDING") {
        return entry !== undefined && !("nodeId" in entry) ? "Yes" : "No";
      }
      if (ctx.message.action === "CHECK_INCLUDED") {
        return entry !== undefined && "nodeId" in entry ? "Yes" : "No";
      }
      if (ctx.message.action === "CHECK_ACTIVE") {
        return entry !== undefined &&
          entry.status !== ProvisioningEntryStatus.Inactive
          ? "Yes"
          : "No";
      }
      if (ctx.message.action === "CHECK_INACTIVE") {
        return entry?.status === ProvisioningEntryStatus.Inactive ? "Yes" : "No";
      }
      const exists = entry !== undefined;
      return exists === (ctx.message.action === "CHECK_EXISTS") ? "Yes" : "No";
    }

    return "Ok";
  },
});
