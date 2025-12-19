import {
  registerHandler,
  type PromptContext,
  type PromptResponse,
} from "../../prompt-handlers.ts";
import type {
  DUTCapabilityId,
  CCCapabilityQueryMessage,
} from "../../../../src/ctt-message-types.ts";

// DUT capability responses by capabilityId
const dutCapabilityResponses: Record<
  DUTCapabilityId,
  PromptResponse | ((ctx: PromptContext) => PromptResponse)
> = {
  ESTABLISH_ASSOCIATION: "No",
  DISPLAY_LAST_STATE: "Yes",
  QR_CODE: "Yes",
  LEARN_MODE: "No",
  LEARN_MODE_ACCESSIBLE: "No",
  FACTORY_RESET: "Yes",
  REMOVE_FAILED_NODE: "Yes",
  ICON_TYPE_MATCH: "Yes",
  IDENTIFY_OTHER_PURPOSE: "No",
  CONTROLS_UNLISTED_CCS: "No",
  ALL_DOCUMENTED_AS_CONTROLLED: "Yes",
  PARTIAL_CONTROL_DOCUMENTED: (ctx) => {
    // Entry Control CC is marked as partial control in the certification portal
    if (ctx.testName.includes("CCR_EntryControlCC")) {
      return "Yes";
    }
    return "No";
  },
  MAINS_POWERED: "Yes",
};

// CC capability responses by commandClass and capabilityId
type CCCapabilityKey = `${string}:${string}`;
const ccCapabilityResponses: Record<
  CCCapabilityKey,
  PromptResponse | ((msg: CCCapabilityQueryMessage) => PromptResponse)
> = {
  // Multilevel Switch capabilities
  "Multilevel Switch:START_STOP_LEVEL_CHANGE": "Yes",
  "Multilevel Switch:SET_DIMMING_DURATION": "Yes",
  "Multilevel Switch:SET_LEVEL_CHANGE_PARAMS": "Yes",

  // Barrier Operator capabilities
  "Barrier Operator:CONTROL_EVENT_SIGNALING": "Yes",

  // Anti-Theft capabilities
  "Anti-Theft:LOCK_UNLOCK": "No",

  // Door Lock capabilities
  "Door Lock:CONFIGURE_DOOR_HANDLES": "Yes",

  // Configuration capabilities
  "Configuration:RESET_SINGLE_PARAM": "Yes",

  // Notification capabilities
  "Notification:CREATE_RULES_FROM_NOTIFICATIONS": "Yes",
  "Notification:UPDATE_NOTIFICATION_LIST": "Yes",

  // User Code capabilities
  "User Code:MODIFY_USER_CODE": "Yes",
  "User Code:SET_KEYPAD_MODE": "Yes",
  "User Code:SET_ADMIN_CODE": "Yes",

  // Entry Control capabilities
  "Entry Control:CONFIGURE_KEYPAD": "Yes",
};

// CC version control - which CC versions we control
const controlledCCVersions: Record<string, number[]> = {
  Basic: [1, 2],
  Indicator: [1, 2, 3, 4],
  Version: [1, 2, 3],
  "Wake Up": [1, 2, 3],
};

registerHandler(/.*/, {
  onPrompt: async (ctx) => {
    if (ctx.message?.type === "DUT_CAPABILITY_QUERY") {
      const response = dutCapabilityResponses[ctx.message.capabilityId];
      if (response !== undefined) {
        return typeof response === "function" ? response(ctx) : response;
      }
    }

    if (ctx.message?.type === "CC_CAPABILITY_QUERY") {
      const { commandClass, capabilityId } = ctx.message;

      // Special handling for CONTROLS_CC with version
      if (capabilityId === "CONTROLS_CC" && "version" in ctx.message) {
        const versions = controlledCCVersions[commandClass];
        if (versions?.includes(ctx.message.version)) {
          return "Yes";
        }
        return "No";
      }

      // Look up standard capability response
      const key: CCCapabilityKey = `${commandClass}:${capabilityId}`;
      const response = ccCapabilityResponses[key];
      if (response !== undefined) {
        return typeof response === "function" ? response(ctx.message) : response;
      }
    }

    // Let other prompts fall through to manual handling
    return undefined;
  },
});
