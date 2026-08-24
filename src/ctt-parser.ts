// CTT Parser - Converts raw CTT logs and prompts into structured DUT messages

import type {
  DUTMessage,
  SendCommandMessage,
  S2PinCodeMessage,
  VerifyStateMessage,
  VerifyNotificationMessage,
  VerifySceneMessage,
  DUTCapabilityQueryMessage,
  CheckDUTMetadataMessage,
  CCCapabilityQueryMessage,
  ActivateNetworkModeMessage,
  OpenUIMessage,
  WaitForInterviewMessage,
  WaitForInclusionIdleMessage,
  WaitForCommandIdleMessage,
  WaitForNodeRemovalMessage,
  CheckNetworkStatusMessage,
  CheckSecurityClassMessage,
  CheckS2GrantRequestMessage,
  CheckS2PinRequestMessage,
  StartStopLevelChangeMessage,
  CheckEndpointCapabilityMessage,
  TrySetConfigParameterMessage,
  ShouldDisregardRecommendationMessage,
  TriggerReInterviewMessage,
  QueryUserCodesMessage,
  VerifyIndicatorIdentifyMessage,
  ManageProvisioningMessage,
  ReplaceFailedNodeMessage,
  ProvisioningSecurityClass,
  OrchestratorState,
  DUTCapabilityId,
  DurationValue,
} from "./ctt-message-types.ts";
import type { CttExecutionMode } from "./runner-ipc.ts";

// =============================================================================
// Parse Result Types
// =============================================================================

export type LogParseResult =
  | { action: "send_to_dut"; message: DUTMessage }
  | { action: "modify_context"; stateUpdate: Partial<OrchestratorState> }
  | { action: "none" };

export type PromptParseResult = (
  | { action: "send_to_dut"; message: DUTMessage; answer?: string }
  | { action: "auto_answer"; answer: string }
  | { action: "none" }
) & { stateUpdate?: Partial<OrchestratorState> };

export function nodeAddedStateUpdate(
  state: OrchestratorState,
  nodeId: number
): Partial<OrchestratorState> {
  const context = state.readinessContext;
  return {
    lastAddedNodeId: nodeId,
    readinessContext:
      context?.operation === "NODE_REMOVAL"
        ? context
        : { operation: "INCLUSION", addedNodeId: nodeId },
  };
}

export function nodeRemovedStateUpdate(
  state: OrchestratorState,
  nodeId: number
): Partial<OrchestratorState> {
  const context = state.readinessContext;
  let readinessContext = context;
  if (context?.operation === "INCLUSION") {
    // A node added and removed again during the same inclusion leaves nothing to interview
    if (context.addedNodeId === nodeId) {
      readinessContext = { operation: "INCLUSION" };
    }
  } else if (context?.operation !== "DUT_READY") {
    readinessContext = { operation: "NODE_REMOVAL", removedNodeId: nodeId };
  }
  return { lastRemovedNodeId: nodeId, readinessContext };
}

// Only the branch that sends nothing has to clear readinessContext, because
// dispatching a wait message already clears it
function nodeRemovalWait(nodeId: number | undefined): PromptParseResult {
  if (nodeId === undefined) {
    return { action: "none", stateUpdate: { readinessContext: undefined } };
  }
  const message: WaitForNodeRemovalMessage = {
    type: "WAIT_FOR_NODE_REMOVAL",
    responseOptions: ["Ok"],
    nodeId,
  };
  return { action: "send_to_dut", message };
}

export interface CttTestInstance {
  testName: string;
  executionMode: CttExecutionMode;
}

// =============================================================================
// Log Parsing
// =============================================================================

export function parseLog(
  logText: string,
  _state: OrchestratorState
): LogParseResult {
  // S2 PIN Code detection
  const pinMatch = /PIN( Code)?: (?<pin>\d{5})/i.exec(logText);
  if (pinMatch?.groups?.pin) {
    const message: S2PinCodeMessage = {
      type: "S2_PIN_CODE",
      pin: pinMatch.groups.pin,
    };
    return { action: "send_to_dut", message };
  }

  // Detect context for later prompts
  // Force S0 flag detection
  if (
    /handles commands from a supporting node with S0 security level/i.test(
      logText
    ) ||
    /S0 bootstrapping, highest scheme:\s*S0/i.test(logText) ||
    /--- Test \d+: S0 Bootstrapping ---/i.test(logText)
  ) {
    return { action: "modify_context", stateUpdate: { forceS0: true } };
  }
  if (/Wait until the DUT has finished interviewing/i.test(logText)) {
    return {
      action: "modify_context",
      stateUpdate: { waitForInterviewPrompt: true },
    };
  }
  if (/Please add .+DSK.+Node Provisioning List/i.test(logText)) {
    return {
      action: "modify_context",
      stateUpdate: { provisioningAction: "ADD" },
    };
  }
  if (/Please remove .+DSK.+Node Provisioning List/i.test(logText)) {
    return {
      action: "modify_context",
      stateUpdate: { provisioningAction: "REMOVE" },
    };
  }

  // Verify UI state detection (for later prompt answer)
  if (
    /Verify that the DUT offers a UI.+see the parameter numbers/i.test(logText)
  ) {
    return {
      action: "modify_context",
      stateUpdate: {
        verifyUIContext: { commandClass: "Configuration", nodeId: 0 },
      },
    };
  }

  // Recommendation disregard context detection
  const recommendMatch =
    /INDICATOR_REPORT.+RECOMMENDED.+does not advertise.+AGI Command List Report/is.exec(
      logText
    );
  if (recommendMatch) {
    return {
      action: "modify_context",
      stateUpdate: { recommendationContext: logText },
    };
  }

  // SEND_COMMAND patterns
  const sendCommand = parseLogSendCommand(logText);
  if (sendCommand) {
    return { action: "send_to_dut", message: sendCommand };
  }

  return { action: "none" };
}

function parseLogSendCommand(logText: string): SendCommandMessage | null {
  // Configuration SET with explicit size
  const configSetExplicit =
    /set the parameter.+number (?<param>\d+) and Size = (?<size>\d+) to value (?<value>-?\d+)/i.exec(
      logText
    );
  if (configSetExplicit?.groups) {
    return {
      type: "SEND_COMMAND",
      commandClass: "Configuration",
      action: "SET",
      param: parseInt(configSetExplicit.groups.param!),
      size: parseInt(configSetExplicit.groups.size!) as 1 | 2 | 4,
      value: parseInt(configSetExplicit.groups.value!),
    };
  }

  // Configuration SET without explicit size
  const configSet =
    /set the parameter.+number (?<param>\d+).+to value (?<value>-?\d+)/i.exec(
      logText
    );
  if (configSet?.groups) {
    return {
      type: "SEND_COMMAND",
      commandClass: "Configuration",
      action: "SET",
      param: parseInt(configSet.groups.param!),
      value: parseInt(configSet.groups.value!),
    };
  }

  // Configuration RESET single
  const configReset =
    /trigger 'Configuration Parameter Reset'.+parameter number = (?<param>\d+)/i.exec(
      logText
    );
  if (configReset?.groups) {
    return {
      type: "SEND_COMMAND",
      commandClass: "Configuration",
      action: "RESET",
      param: parseInt(configReset.groups.param!),
    };
  }

  // Configuration RESET ALL
  if (/trigger 'All Configuration Parameter Reset'/i.test(logText)) {
    return {
      type: "SEND_COMMAND",
      commandClass: "Configuration",
      action: "RESET_ALL",
    };
  }

  // Door Lock SET_MODE
  const doorLockMode = /Set Door Lock Operation Mode (?<mode>\w+)/i.exec(
    logText
  );
  if (doorLockMode?.groups) {
    return {
      type: "SEND_COMMAND",
      commandClass: "Door Lock",
      action: "SET_MODE",
      mode: doorLockMode.groups.mode!,
    };
  }

  // Door Lock SET_CONFIG
  if (logText.includes("Set Door Lock Configuration:")) {
    return parseDoorLockConfig(logText);
  }

  // User Code SET
  const userCodeSet =
    /Set User ID '(?<userId>\d+)'.*User ID Status '(?<status>[^']+)'.*User Code '(?<code>[^']+)'/i.exec(
      logText
    );
  if (userCodeSet?.groups) {
    return {
      type: "SEND_COMMAND",
      commandClass: "User Code",
      action: "SET",
      userId: parseInt(userCodeSet.groups.userId!),
      status: userCodeSet.groups.status!,
      code: userCodeSet.groups.code!,
    };
  }

  // User Code ADD
  const userCodeAdd =
    /Add a new User Code.*first available User ID is '(?<userId>\d+)'.*User ID Status '(?<status>[^']+)'.*User Code '(?<code>[^']+)'/i.exec(
      logText
    );
  if (userCodeAdd?.groups) {
    return {
      type: "SEND_COMMAND",
      commandClass: "User Code",
      action: "ADD",
      userId: parseInt(userCodeAdd.groups.userId!),
      status: userCodeAdd.groups.status!,
      code: userCodeAdd.groups.code!,
    };
  }

  // User Code CLEAR
  const userCodeClear = /Erase User ID '(?<userId>\d+)'/i.exec(logText);
  if (userCodeClear?.groups) {
    return {
      type: "SEND_COMMAND",
      commandClass: "User Code",
      action: "CLEAR",
      userId: parseInt(userCodeClear.groups.userId!),
    };
  }

  // User Code SET_KEYPAD_MODE
  const keypadMode = /Set Keypad mode to '(?<mode>\w+)'/i.exec(logText);
  if (keypadMode?.groups) {
    return {
      type: "SEND_COMMAND",
      commandClass: "User Code",
      action: "SET_KEYPAD_MODE",
      mode: keypadMode.groups.mode!,
    };
  }

  // User Code SET_ADMIN_CODE
  const adminCode = /Set Admin Code to '(?<code>[^']+)'/i.exec(logText);
  if (adminCode?.groups) {
    return {
      type: "SEND_COMMAND",
      commandClass: "User Code",
      action: "SET_ADMIN_CODE",
      code: adminCode.groups.code!,
    };
  }

  // User Code DISABLE_ADMIN_CODE
  if (/Disable Admin Code/i.test(logText)) {
    return {
      type: "SEND_COMMAND",
      commandClass: "User Code",
      action: "DISABLE_ADMIN_CODE",
    };
  }

  // Generic SET command parser - handles multiple CCs with similar log formats
  // Try multiple patterns to extract command and value
  const setMatch =
    /\* (?<cmd>[A-Z_]+)(?: (?:to|on) end ?point (?<endpoint>\d+))?: \* Z-Wave Value = (?<targetValue>(0x)?[a-fA-F0-9]+)/i.exec(
      logText
    ) ??
    /\* (?<cmd>[A-Z_]+)(?: (?:to|on) end ?point (?<endpoint>\d+))? with (?:target )?value='(?<targetValue>(0x)?[a-fA-F0-9]+)/.exec(
      logText
    ) ??
    /\* (?<cmd>[A-Z_]+)(?: (?:to|on) end ?point (?<endpoint>\d+))?.+value\s*=\s*(?<targetValue>(0x)?[a-fA-F0-9]+)/i.exec(
      logText
    );

  if (setMatch?.groups?.cmd && setMatch.groups.targetValue) {
    const cmd = setMatch.groups.cmd.toUpperCase();
    const targetValue = parseInt(setMatch.groups.targetValue);
    const endpoint = setMatch.groups.endpoint
      ? parseInt(setMatch.groups.endpoint)
      : 0;

    switch (cmd) {
      case "BASIC_SET":
        return {
          type: "SEND_COMMAND",
          commandClass: "Basic",
          action: "SET",
          targetValue,
          endpoint,
        };

      case "SWITCH_BINARY_SET":
        return {
          type: "SEND_COMMAND",
          commandClass: "Binary Switch",
          action: "SET",
          targetValue: targetValue === 0xff,
          endpoint,
        };

      case "SWITCH_MULTILEVEL_SET": {
        // Parse duration with unit: "Duration = 10 seconds", "Duration = instantly", etc.
        const durationMatch =
          /Duration\s*=\s*(?<value>\d+\s+)?(?<unit>\w+)/i.exec(logText);
        let duration: DurationValue | undefined;
        if (durationMatch?.groups?.unit) {
          const unit = durationMatch.groups.unit.toLowerCase();
          const durationValue = durationMatch.groups.value
            ? parseInt(durationMatch.groups.value)
            : 0;
          if (unit === "instantly") {
            duration = { value: 0, unit: "seconds" };
          } else if (unit.includes("default") || unit.includes("factory")) {
            duration = "default";
          } else if (unit === "minutes") {
            duration = { value: durationValue, unit: "minutes" };
          } else {
            // seconds or other
            duration = { value: durationValue, unit: "seconds" };
          }
        }
        return {
          type: "SEND_COMMAND",
          commandClass: "Multilevel Switch",
          action: "SET",
          targetValue,
          duration,
          endpoint,
        };
      }

      case "BARRIER_OPERATOR_SET":
        return {
          type: "SEND_COMMAND",
          commandClass: "Barrier Operator",
          action: "SET",
          targetValue,
        };

      case "BARRIER_OPERATOR_EVENT_SIGNAL_SET": {
        const subsystemMatch = /(?<subsystem>Audible|Visual)/i.exec(logText);
        if (subsystemMatch?.groups?.subsystem) {
          return {
            type: "SEND_COMMAND",
            commandClass: "Barrier Operator",
            action: "SET_EVENT_SIGNALING",
            subsystem: subsystemMatch.groups.subsystem as "Audible" | "Visual",
            value: targetValue,
          };
        }
        break;
      }
    }
  }

  // Generic "any value" handler for multiple CCs
  const anyValueMatch =
    /\* (?<cmd>[A-Z_]+)(?: (?:to|on) end ?point (?<endpoint>\d+))?.+any value/i.exec(
      logText
    );
  if (anyValueMatch?.groups?.cmd) {
    const cmd = anyValueMatch.groups.cmd.toUpperCase();
    const endpoint = anyValueMatch.groups.endpoint
      ? parseInt(anyValueMatch.groups.endpoint)
      : 0;

    switch (cmd) {
      case "BASIC_SET":
        return {
          type: "SEND_COMMAND",
          commandClass: "Basic",
          action: "SET",
          targetValue: "any",
          endpoint,
        };
      case "SWITCH_BINARY_SET":
        return {
          type: "SEND_COMMAND",
          commandClass: "Binary Switch",
          action: "SET",
          targetValue: "any",
          endpoint,
        };
      case "SWITCH_MULTILEVEL_SET":
        return {
          type: "SEND_COMMAND",
          commandClass: "Multilevel Switch",
          action: "SET",
          targetValue: "any",
          endpoint,
        };
    }
  }

  // Binary Switch trigger any
  if (/trigger Binary Switch On or Off/i.test(logText)) {
    return {
      type: "SEND_COMMAND",
      commandClass: "Binary Switch",
      action: "SET",
      targetValue: "any",
    };
  }

  if (/trigger a Binary Switch Set OR a Basic Set/i.test(logText)) {
    return {
      type: "SEND_COMMAND",
      commandClass: "Binary Switch",
      action: "SET",
      targetValue: "any",
    };
  }

  // Multilevel Switch trigger any
  if (/trigger Multilevel Switch On or Off/i.test(logText)) {
    return {
      type: "SEND_COMMAND",
      commandClass: "Multilevel Switch",
      action: "SET",
      targetValue: "any",
      ...parseEndpoint(logText),
    };
  }

  // Notification GET
  const notificationGet =
    /\* ALARM_GET \(NOTIFICATION_GET\) for Alarm Type.+\((?<typeHex>0x[0-9a-fA-F]+)\)/i.exec(
      logText
    );
  if (notificationGet?.groups) {
    return {
      type: "SEND_COMMAND",
      commandClass: "Notification",
      action: "GET",
      notificationType: parseInt(notificationGet.groups.typeHex!, 16),
    };
  }

  // Meter RESET_ALL
  if (/trigger\s+'?Reset Meter'?/i.test(logText)) {
    return {
      type: "SEND_COMMAND",
      commandClass: "Meter",
      action: "RESET_ALL",
    };
  }

  // Indicator IDENTIFY
  if (/INDICATOR_SET to identify node/i.test(logText)) {
    return {
      type: "SEND_COMMAND",
      commandClass: "Indicator",
      action: "IDENTIFY",
    };
  }

  // Thermostat Mode SET
  const thermostatMode = /THERMOSTAT_MODE_SET to mode = '(?<mode>[^']+)'/i.exec(
    logText
  );
  if (thermostatMode?.groups) {
    // Parse manufacturer specific data array: [0x01, 0x02, 0x03]
    const manuMatch =
      /manufacturer\s+(?:specific\s+)?data\s*=\s*\[(?<data>[^\]]+)\]/i.exec(
        logText
      );
    let manufacturerData: number[] | undefined;
    if (manuMatch?.groups?.data) {
      manufacturerData = manuMatch.groups.data
        .split(",")
        .map((s) => parseInt(s.trim(), 16));
    }
    return {
      type: "SEND_COMMAND",
      commandClass: "Thermostat Mode",
      action: "SET",
      mode: thermostatMode.groups.mode!,
      manufacturerData,
    };
  }

  // Thermostat Setback SET
  const thermostatSetback =
    /THERMOSTAT_SETBACK_SET to Setback Type '(?<type>\w+)' with state=(?<state>-?\d+)/i.exec(
      logText
    );
  if (thermostatSetback?.groups) {
    return {
      type: "SEND_COMMAND",
      commandClass: "Thermostat Setback",
      action: "SET",
      setbackType: thermostatSetback.groups.type!,
      stateKelvin: parseInt(thermostatSetback.groups.state!),
    };
  }

  // Thermostat Setpoint SET
  const thermostatSetpoint =
    /THERMOSTAT_SETPOINT_SET.+Type '(?<type>\w+)'.+value=(?<value>[\d.]+)/i.exec(
      logText
    ) ?? /Setpoint for type '(?<type>\w+)' to (?<value>[\d.]+)/i.exec(logText);
  if (thermostatSetpoint?.groups) {
    return {
      type: "SEND_COMMAND",
      commandClass: "Thermostat Setpoint",
      action: "SET",
      setpointType: thermostatSetpoint.groups.type!,
      value: parseFloat(thermostatSetpoint.groups.value!),
    };
  }

  // Sound Switch SET_TONE
  const soundTone = /Set default tone to '(?<tone>[^']+)'/i.exec(logText);
  if (soundTone?.groups) {
    return {
      type: "SEND_COMMAND",
      commandClass: "Sound Switch",
      action: "SET_TONE",
      tone: soundTone.groups.tone!,
    };
  }

  // Sound Switch SET_VOLUME
  const soundVolume = /set volume to (?<volume>\d+)/i.exec(logText);
  if (soundVolume?.groups) {
    return {
      type: "SEND_COMMAND",
      commandClass: "Sound Switch",
      action: "SET_VOLUME",
      volume: parseInt(soundVolume.groups.volume!),
    };
  }

  // Sound Switch MUTE
  if (/mute volume/i.test(logText)) {
    return {
      type: "SEND_COMMAND",
      commandClass: "Sound Switch",
      action: "MUTE",
    };
  }

  // Sound Switch PLAY
  const soundPlay = /play tone '(?<tone>[^']+)'/i.exec(logText);
  if (soundPlay?.groups) {
    return {
      type: "SEND_COMMAND",
      commandClass: "Sound Switch",
      action: "PLAY",
      tone: soundPlay.groups.tone!,
    };
  }

  // Sound Switch STOP
  if (/stop all tones/i.test(logText)) {
    return {
      type: "SEND_COMMAND",
      commandClass: "Sound Switch",
      action: "STOP",
    };
  }

  // Sound Switch PLAY_DEFAULT
  if (/play default tone/i.test(logText)) {
    return {
      type: "SEND_COMMAND",
      commandClass: "Sound Switch",
      action: "PLAY_DEFAULT",
    };
  }

  // Window Covering SET
  const windowCovering =
    /WINDOW_COVERING_SET.+\(ID = (?<param>\d+)\).+value = (?<value>\d+)/i.exec(
      logText
    );
  if (windowCovering?.groups) {
    const durationMatch =
      /duration\s*=\s*(?<durationValue>\d+\s+)?(?<unit>\w+)/i.exec(logText);
    let duration: DurationValue | undefined;
    if (durationMatch?.groups?.unit) {
      const unit = durationMatch.groups.unit.toLowerCase();
      if (unit === "instantly") {
        duration = { value: 0, unit: "seconds" };
      } else if (unit.includes("default") || unit.includes("factory")) {
        duration = "default";
      } else if (durationMatch.groups.durationValue) {
        const durationValue = parseInt(durationMatch.groups.durationValue);
        duration =
          unit === "minutes"
            ? { value: durationValue, unit: "minutes" }
            : { value: durationValue, unit: "seconds" };
      }
    }
    return {
      type: "SEND_COMMAND",
      commandClass: "Window Covering",
      action: "SET",
      paramId: parseInt(windowCovering.groups.param!),
      value: parseInt(windowCovering.groups.value!),
      duration,
    };
  }

  // Entry Control SET_CONFIG
  const entryControl =
    /ENTRY_CONTROL_CONFIGURATION_SET.+KeyCacheSize\s*=\s*(?<size>\d+).+KeyCacheTimeout\s*=\s*(?<timeout>\d+)/i.exec(
      logText
    );
  if (entryControl?.groups) {
    return {
      type: "SEND_COMMAND",
      commandClass: "Entry Control",
      action: "SET_CONFIG",
      keyCacheSize: parseInt(entryControl.groups.size!),
      keyCacheTimeout: parseInt(entryControl.groups.timeout!),
    };
  }

  // Color Switch SET
  const colorSwitch =
    /SWITCH_COLOR_SET.+\(ID = (?<color>(0x)?[a-fA-F0-9]+)\).+value='(?<value>\d+)/i.exec(
      logText
    );
  if (colorSwitch?.groups) {
    return {
      type: "SEND_COMMAND",
      commandClass: "Color Switch",
      action: "SET",
      colorId: parseInt(colorSwitch.groups.color!),
      value: parseInt(colorSwitch.groups.value!),
    };
  }

  return null;
}

function parseDoorLockConfig(logText: string): SendCommandMessage {
  const operationType = /Operation Type:\s+'(\w+)'/i.exec(logText)?.[1];
  const insideHandle1 = /Inside Handle 1:\s+'(\w+)'/i.exec(logText)?.[1];
  const insideHandle2 = /Inside Handle 2:\s+'(\w+)'/i.exec(logText)?.[1];
  const insideHandle3 = /Inside Handle 3:\s+'(\w+)'/i.exec(logText)?.[1];
  const insideHandle4 = /Inside Handle 4:\s+'(\w+)'/i.exec(logText)?.[1];
  const outsideHandle1 = /Outside Handle 1:\s+'(\w+)'/i.exec(logText)?.[1];
  const outsideHandle2 = /Outside Handle 2:\s+'(\w+)'/i.exec(logText)?.[1];
  const outsideHandle3 = /Outside Handle 3:\s+'(\w+)'/i.exec(logText)?.[1];
  const outsideHandle4 = /Outside Handle 4:\s+'(\w+)'/i.exec(logText)?.[1];
  const lockTimeout = /Lock Timeout:\s+(\d+)\s+seconds/i.exec(logText)?.[1];
  const autoRelockTime = /Auto-relock Time:\s+(\d+)\s+seconds/i.exec(
    logText
  )?.[1];
  const holdReleaseTime = /Hold&Release Time:\s+(\d+)\s+seconds/i.exec(
    logText
  )?.[1];
  const blockToBlock = /Block to Block:\s+'(\w+)'/i.exec(logText)?.[1];
  const twistAssist = /Twist Assist:\s+'(\w+)/i.exec(logText)?.[1];

  const isEnabled = (value: string | undefined) =>
    value?.toLowerCase() === "enabled";

  return {
    type: "SEND_COMMAND",
    commandClass: "Door Lock",
    action: "SET_CONFIG",
    operationType:
      operationType?.toLowerCase() === "timedoperation" ? "Timed" : "Constant",
    insideHandles: [
      isEnabled(insideHandle1),
      isEnabled(insideHandle2),
      isEnabled(insideHandle3),
      isEnabled(insideHandle4),
    ],
    outsideHandles: [
      isEnabled(outsideHandle1),
      isEnabled(outsideHandle2),
      isEnabled(outsideHandle3),
      isEnabled(outsideHandle4),
    ],
    lockTimeout: lockTimeout ? parseInt(lockTimeout) : undefined,
    autoRelockTime: autoRelockTime ? parseInt(autoRelockTime) : undefined,
    holdAndReleaseTime: holdReleaseTime ? parseInt(holdReleaseTime) : undefined,
    blockToBlock: blockToBlock ? isEnabled(blockToBlock) : undefined,
    twistAssist: twistAssist ? isEnabled(twistAssist) : undefined,
  };
}

function parseEndpoint(text: string): { endpoint?: number } {
  const match = /end ?point (?<ep>\d+)/i.exec(text);
  return match?.groups?.ep ? { endpoint: parseInt(match.groups.ep) } : {};
}

function parseProvisioningSecurityClass(
  value: string
): ProvisioningSecurityClass | undefined {
  switch (value.toLowerCase()) {
    case "s2_access":
    case "s2_accesscontrol":
      return "S2_AccessControl";
    case "s2_authenticated":
      return "S2_Authenticated";
    case "s2_unauthenticated":
      return "S2_Unauthenticated";
  }
}

// =============================================================================
// Prompt Parsing
// =============================================================================

export function parsePrompt(
  promptText: string,
  state: OrchestratorState,
  testInstance: CttTestInstance = {
    testName: "",
    executionMode: "Classic",
  }
): PromptParseResult {
  const { testName } = testInstance;
  // Orchestrator-only auto-answers
  // CTT's blank Ok box still contains separator formatting
  if (state.waitForInterviewPrompt && !/[a-z]/i.test(promptText)) {
    return {
      action: "send_to_dut",
      message: {
        type: "WAIT_FOR_INTERVIEW",
        responseOptions: ["Ok"],
      },
    };
  }
  if (/Prepare the DUT to send any.+command/i.test(promptText)) {
    return { action: "auto_answer", answer: "Ok" };
  }
  if (/Include.+into the DUT network/i.test(promptText)) {
    return {
      action: "auto_answer",
      answer: "Ok",
      stateUpdate: { readinessContext: { operation: "INCLUSION" } },
    };
  }
  if (/^\s*Ready for Inclusion\?\s*$/i.test(promptText)) {
    const message: WaitForInclusionIdleMessage = {
      type: "WAIT_FOR_INCLUSION_IDLE",
      responseOptions: ["Ok"],
    };
    return { action: "send_to_dut", message };
  }
  // `Make sure the DUT has been reset` confirms the preceding prompt's factory reset in
  // CDR_WhenNodeReset_Rev01, so acknowledge it without triggering a second reset
  if (
    /Make sure the DUT is SIS|Make sure the DUT has been reset before continuing/i.test(
      promptText
    )
  ) {
    return {
      action: "auto_answer",
      answer: "Ok",
      stateUpdate: { readinessContext: { operation: "DUT_READY" } },
    };
  }
  if (/Ready for exclusion\?/i.test(promptText)) {
    return {
      action: "auto_answer",
      answer: "Ok",
      stateUpdate: { readinessContext: { operation: "NODE_REMOVAL" } },
    };
  }
  if (
    /wait for the DUT not sending (?:any commands|commands anymore)/i.test(
      promptText
    )
  ) {
    const message: WaitForCommandIdleMessage = {
      type: "WAIT_FOR_COMMAND_IDLE",
      responseOptions: ["Ok"],
    };
    return { action: "send_to_dut", message };
  }
  if (
    testName.includes("S2_WarningHighestKeyNotGranted") &&
    /Does the DUT present a warning message informing the user that the\s*CTT Controller has NOT been included with the highest security\?/is.test(
      promptText
    )
  ) {
    const message: CheckS2GrantRequestMessage = {
      type: "CHECK_S2_GRANT_REQUEST",
      responseOptions: ["Yes", "No"],
      check: "NOT_HIGHEST_SECURITY_WARNING",
    };
    return { action: "send_to_dut", message };
  }
  if (
    testName.includes("S2_WarningHighestKeyNotGranted") &&
    /Does the DUT present a warning message informing the user that the CTT Controller\s*has NOT been granted ANY security key\?/is.test(
      promptText
    )
  ) {
    const message: CheckS2GrantRequestMessage = {
      type: "CHECK_S2_GRANT_REQUEST",
      responseOptions: ["Yes", "No"],
      check: "NO_SECURITY_WARNING",
    };
    return { action: "send_to_dut", message };
  }
  if (
    testName.includes("S2_ConfirmForAuthenticated_Rev01") &&
    /Did the DUT present a dialog with the requested security classes\?/i.test(
      promptText
    )
  ) {
    const message: CheckS2GrantRequestMessage = {
      type: "CHECK_S2_GRANT_REQUEST",
      responseOptions: ["Yes", "No"],
      check: "REQUEST_OBSERVED",
    };
    return { action: "send_to_dut", message };
  }
  if (
    testName.includes("S2_ConfirmForAuthenticated_Rev01") &&
    /Did the DUT ask for confirmation before granting S2 Authenticated Class\?/i.test(
      promptText
    )
  ) {
    const message: CheckS2GrantRequestMessage = {
      type: "CHECK_S2_GRANT_REQUEST",
      responseOptions: ["Yes", "No"],
      check: "REQUESTED_S2_AUTHENTICATED",
    };
    return { action: "send_to_dut", message };
  }
  if (
    testName.includes("S2_SISMustHaveS2ClassInputAndDisplay_Rev01") &&
    /Did the DUT present a dialog for entering the PIN portion.+DSK.+show the rest/is.test(
      promptText
    )
  ) {
    const message: CheckS2PinRequestMessage = {
      type: "CHECK_S2_PIN_REQUEST",
      responseOptions: ["Yes", "No"],
    };
    return { action: "send_to_dut", message };
  }
  if (
    (testName.includes("S2_GrantedS2Classes_Rev01") ||
      testName.includes("S2_SISMustSupportAnyS2ClassCombination_Rev01")) &&
    /Have all keys been pre-selected\?|Have all Security Classes been preselected automatically/i.test(
      promptText
    )
  ) {
    const message: CheckS2GrantRequestMessage = {
      type: "CHECK_S2_GRANT_REQUEST",
      responseOptions: ["Yes", "No"],
      check: "ALL_REQUESTED_GRANTED",
    };
    return { action: "send_to_dut", message };
  }
  if (/Has the End Device \d+ been placed in a special section/i.test(promptText)) {
    return { action: "auto_answer", answer: "No" };
  }
  if (
    /Reset (?:the )?DUT(?:!| and)|perform a factory reset as stated|Please reset the DUT/i.test(
      promptText
    )
  ) {
    return {
      action: "send_to_dut",
      message: {
        type: "FACTORY_RESET",
        responseOptions: ["Ok"],
      },
      stateUpdate: { readinessContext: { operation: "DUT_READY" } },
    };
  }
  if (
    /Does the NIF of the DUT contain any Command Classes that are controlled but NOT supported/i.test(
      promptText
    )
  ) {
    return { action: "auto_answer", answer: "No" };
  }
  const manufacturerMetadataMatch =
    /Does (?<property>Manufacturer ID|Product Type ID|Product ID)\s*=\s*(?<expected>[0-9a-f]{2}\s+[0-9a-f]{2}) match the actual device/i.exec(
      promptText
    );
  if (manufacturerMetadataMatch?.groups) {
    const property = {
      "Manufacturer ID": "MANUFACTURER_ID",
      "Product Type ID": "PRODUCT_TYPE_ID",
      "Product ID": "PRODUCT_ID",
    }[manufacturerMetadataMatch.groups.property!] as
      | "MANUFACTURER_ID"
      | "PRODUCT_TYPE_ID"
      | "PRODUCT_ID";
    const message: CheckDUTMetadataMessage = {
      type: "CHECK_DUT_METADATA",
      responseOptions: ["Yes", "No"],
      property,
      expected: Number.parseInt(
        manufacturerMetadataMatch.groups.expected!.replace(/\s/g, ""),
        16
      ),
    };
    return { action: "send_to_dut", message };
  }
  const hardwareVersionMatch =
    /Does Hardware Version\s*=\s*(?<expected>0x[0-9a-f]+).+match the actual device/i.exec(
      promptText
    );
  if (hardwareVersionMatch?.groups) {
    const message: CheckDUTMetadataMessage = {
      type: "CHECK_DUT_METADATA",
      responseOptions: ["Yes", "No"],
      property: "HARDWARE_VERSION",
      expected: Number.parseInt(hardwareVersionMatch.groups.expected!, 16),
    };
    return { action: "send_to_dut", message };
  }
  const firmwareVersionMatch =
    /Does Firmware (?<firmwareIndex>\d+) (?<component>Version|Sub-?Version)\s*=\s*(?<expected>0x[0-9a-f]+).+match the actual device/i.exec(
      promptText
    );
  if (firmwareVersionMatch?.groups) {
    const message: CheckDUTMetadataMessage = {
      type: "CHECK_DUT_METADATA",
      responseOptions: ["Yes", "No"],
      property: "FIRMWARE_VERSION",
      firmwareIndex: Number.parseInt(
        firmwareVersionMatch.groups.firmwareIndex!,
        10
      ),
      component: firmwareVersionMatch.groups.component!
        .toLowerCase()
        .startsWith("sub")
        ? "SUB_VERSION"
        : "VERSION",
      expected: Number.parseInt(firmwareVersionMatch.groups.expected!, 16),
    };
    return { action: "send_to_dut", message };
  }
  if (/issue new bursts within less than 30 seconds/i.test(promptText)) {
    return { action: "auto_answer", answer: "No" };
  }
  if (/observe the dut.+does (?:it|the dut).+\?/i.test(promptText)) {
    return { action: "auto_answer", answer: "Yes" };
  }
  if (promptText.toLowerCase().includes("observe the dut")) {
    return { action: "auto_answer", answer: "Ok" };
  }
  if (/Retry\?/i.test(promptText)) {
    return { action: "auto_answer", answer: "No" };
  }
  if (/pause on requests that were answered incorrectly/i.test(promptText)) {
    return { action: "auto_answer", answer: "No" };
  }
  if (/Click 'OK' to start the Command Class response tests/i.test(promptText)) {
    return { action: "auto_answer", answer: "Ok" };
  }
  const longRangeProvisioningEntry =
    /configure the Bootstrapping Mode TLV to 'Z-Wave Long Range\s+SmartStart inclusion'.+DSK:\s*(?<dsk>(?:\d{5}-){7}\d{5})/is.exec(
      promptText
    );
  if (longRangeProvisioningEntry?.groups) {
    const message: ManageProvisioningMessage = {
      type: "MANAGE_PROVISIONING",
      responseOptions: ["Ok"],
      action: "ADD",
      protocol: "LONG_RANGE",
      dsk: longRangeProvisioningEntry.groups.dsk!,
    };
    return { action: "send_to_dut", message };
  }
  const addProvisioningEntry =
    /add (?:the following|this(?: modified)?) DSK to the DUT's Node Provisioning List:\s*(?<dsk>(?:\d{5}-){7}\d{5})/i.exec(
      promptText
    );
  if (addProvisioningEntry?.groups) {
    const message: ManageProvisioningMessage = {
      type: "MANAGE_PROVISIONING",
      responseOptions: ["Ok"],
      action: "ADD",
      dsk: addProvisioningEntry.groups.dsk!,
    };
    return { action: "send_to_dut", message };
  }
  const pendingEntryDsk =
    /(?<dsk>(?:\d{5}-){7}\d{5})/.exec(promptText);
  if (
    testName.includes("SSR_PendingNodeProvisioningListEntry") &&
    pendingEntryDsk?.groups &&
    state.provisioningAction
  ) {
    const message: ManageProvisioningMessage = {
      type: "MANAGE_PROVISIONING",
      responseOptions: ["Ok"],
      action: state.provisioningAction,
      dsk: pendingEntryDsk.groups.dsk!,
    };
    return { action: "send_to_dut", message };
  }
  const advancedJoiningKeys =
    /Advanced Joining: Please select (?<key>S2_[A-Za-z]+) and deselect all other security keys/i.exec(
      promptText
    );
  if (advancedJoiningKeys?.groups) {
    if (state.lastAddedProvisioningDsk === undefined) {
      return { action: "none" };
    }
    const securityClass = parseProvisioningSecurityClass(
      advancedJoiningKeys.groups.key!
    );
    if (securityClass) {
      const message: ManageProvisioningMessage = {
        type: "MANAGE_PROVISIONING",
        responseOptions: ["Ok"],
        action: "SET_KEYS",
        dsk: state.lastAddedProvisioningDsk,
        securityClasses: [securityClass],
      };
      return { action: "send_to_dut", message };
    }
  }
  if (/set the SmartStart Inclusion setting to 'ignored\/disabled'/i.test(promptText)) {
    if (state.lastAddedProvisioningDsk === undefined) {
      return { action: "none" };
    }
    const message: ManageProvisioningMessage = {
      type: "MANAGE_PROVISIONING",
      responseOptions: ["Ok"],
      action: "SET_STATUS",
      dsk: state.lastAddedProvisioningDsk,
      status: "INACTIVE",
    };
    return { action: "send_to_dut", message };
  }
  if (/entry shown as to be ignored when requesting SmartStart inclusion/i.test(promptText)) {
    if (state.lastAddedProvisioningDsk === undefined) {
      return { action: "none" };
    }
    const message: ManageProvisioningMessage = {
      type: "MANAGE_PROVISIONING",
      responseOptions: ["Yes", "No"],
      action: "CHECK_INACTIVE",
      dsk: state.lastAddedProvisioningDsk,
    };
    return { action: "send_to_dut", message };
  }
  if (/Has the entry been added to the Node Provisioning List/i.test(promptText)) {
    if (state.lastAddedProvisioningDsk === undefined) {
      return { action: "none" };
    }
    const message: ManageProvisioningMessage = {
      type: "MANAGE_PROVISIONING",
      responseOptions: ["Yes", "No"],
      action: "CHECK_EXISTS",
      dsk: state.lastAddedProvisioningDsk,
    };
    return { action: "send_to_dut", message };
  }
  if (/Is the node reported as not included \(pending\)/i.test(promptText)) {
    if (state.lastAddedProvisioningDsk === undefined) {
      return { action: "none" };
    }
    const message: ManageProvisioningMessage = {
      type: "MANAGE_PROVISIONING",
      responseOptions: ["Yes", "No"],
      action: "CHECK_PENDING",
      dsk: state.lastAddedProvisioningDsk,
    };
    return { action: "send_to_dut", message };
  }
  if (/Is the node reported as included/i.test(promptText)) {
    if (state.lastAddedProvisioningDsk === undefined) {
      return { action: "none" };
    }
    const message: ManageProvisioningMessage = {
      type: "MANAGE_PROVISIONING",
      responseOptions: ["Yes", "No"],
      action: "CHECK_INCLUDED",
      dsk: state.lastAddedProvisioningDsk,
    };
    return { action: "send_to_dut", message };
  }
  if (
    /Has the entry been removed from the Node Provisioning List|Is the entry removed from the DUT's Node Provisioning List/i.test(
      promptText
    )
  ) {
    if (state.lastRemovedProvisioningDsk === undefined) {
      return { action: "none" };
    }
    const message: ManageProvisioningMessage = {
      type: "MANAGE_PROVISIONING",
      responseOptions: ["Yes", "No"],
      action: "CHECK_ABSENT",
      dsk: state.lastRemovedProvisioningDsk,
    };
    return { action: "send_to_dut", message };
  }
  if (
    /remove (?:the DSK of the CTT End Device|this DSK|the entry|this entry) from the DUT's Node Provisioning List|remove the .+ from the Node Provisioning List and click 'OK'/i.test(
      promptText
    )
  ) {
    if (state.lastAddedProvisioningDsk === undefined) {
      return { action: "none" };
    }
    const message: ManageProvisioningMessage = {
      type: "MANAGE_PROVISIONING",
      responseOptions: ["Ok"],
      action: "REMOVE",
      dsk: state.lastAddedProvisioningDsk,
    };
    return { action: "send_to_dut", message };
  }
  if (/remove both entries from the Node Provisioning List/i.test(promptText)) {
    const message: ManageProvisioningMessage = {
      type: "MANAGE_PROVISIONING",
      responseOptions: ["Ok"],
      action: "REMOVE_ALL",
    };
    return { action: "send_to_dut", message };
  }
  // Configuration CC - parameter numbers requirement (always yes)
  if (
    /does the DUT meet the requirement for parameter numbers/i.test(promptText)
  ) {
    return { action: "auto_answer", answer: "Yes" };
  }
  // Configuration CC - verify UI follow-up (check context from previous log)
  if (/does the DUT meet the requirement described above/i.test(promptText)) {
    if (state.verifyUIContext?.commandClass === "Configuration") {
      return { action: "auto_answer", answer: "Yes" };
    }
  }

  // Send any S2 command (orchestrator clicks OK, then sends message to DUT)
  if (
    /Click 'OK' and (?:send any S2|use the DUT's UI to send any secure command)/i.test(
      promptText
    )
  ) {
    const message: SendCommandMessage = {
      type: "SEND_COMMAND",
      commandClass: "any",
      action: "any",
      encapsulation: ["S2"],
    };
    return { action: "send_to_dut", message };
  }
  const sendAnyToNode =
    /send any command to CTT End Device \(Node ID = (?<nodeId>\d+)\)/i.exec(
      promptText
    );
  if (sendAnyToNode?.groups) {
    const nodeId = parseInt(sendAnyToNode.groups.nodeId!);
    const message: SendCommandMessage = {
      type: "SEND_COMMAND",
      commandClass: "any",
      action: "any",
      nodeId,
    };
    return {
      action: "send_to_dut",
      message,
      stateUpdate: { failedNodeTargetId: nodeId },
    };
  }
  const sendBasicToNode =
    /send a Basic Set command (?:to CTT End Device \(Node ID = |from the DUT to Node ID )(?<nodeId>\d+)\)?/i.exec(
      promptText
    );
  if (sendBasicToNode?.groups) {
    const message: SendCommandMessage = {
      type: "SEND_COMMAND",
      commandClass: "Basic",
      action: "SET",
      targetValue: "any",
      nodeId: parseInt(sendBasicToNode.groups.nodeId!),
    };
    return { action: "send_to_dut", message };
  }

  // ACTIVATE_NETWORK_MODE
  if (/activate the add mode|set (?:the )?dut into add mode/i.test(promptText)) {
    const message: ActivateNetworkModeMessage = {
      type: "ACTIVATE_NETWORK_MODE",
      responseOptions: ["Ok"],
      mode: "ADD",
      forceS0: state.forceS0,
    };
    return {
      action: "send_to_dut",
      message,
      stateUpdate: { readinessContext: { operation: "INCLUSION" } },
    };
  }
  if (/stop add mode on dut/i.test(promptText)) {
    const message: ActivateNetworkModeMessage = {
      type: "ACTIVATE_NETWORK_MODE",
      responseOptions: ["Ok"],
      mode: "STOP_ADD",
    };
    return { action: "send_to_dut", message };
  }
  if (promptText.toLowerCase().includes("activate the remove mode")) {
    const message: ActivateNetworkModeMessage = {
      type: "ACTIVATE_NETWORK_MODE",
      responseOptions: ["Ok"],
      mode: "REMOVE",
    };
    return {
      action: "send_to_dut",
      message,
      stateUpdate: { readinessContext: { operation: "NODE_REMOVAL" } },
    };
  }

  if (
    /wait for the DUT to finish or abort the Inclusion process|wait until the Inclusion process has finished or abort it on DUT side|wait until the DUT is ready \(after having aborted S2 bootstrapping\)|wait until the DUT is ready to start inclusion/i.test(
      promptText
    )
  ) {
    const message: WaitForInclusionIdleMessage = {
      type: "WAIT_FOR_INCLUSION_IDLE",
      responseOptions: ["Ok"],
    };
    return { action: "send_to_dut", message };
  }

  if (/Exclusion process has been finished/i.test(promptText)) {
    const context = state.readinessContext;
    return nodeRemovalWait(
      context?.operation === "NODE_REMOVAL" ? context.removedNodeId : undefined
    );
  }

  if (
    /^(?:abort interview or )?(?:please )?wait until (?:the )?DUT is ready(?:!| and click 'OK'\.)$/i.test(
      promptText
    )
  ) {
    const context = state.readinessContext;
    if (!context) return { action: "none" };
    if (context.operation === "NODE_REMOVAL") {
      return nodeRemovalWait(context.removedNodeId);
    }
    // A node that survived the inclusion still has to finish its interview
    // Anything else only has to reach an idle controller
    const message: WaitForInterviewMessage | WaitForInclusionIdleMessage =
      context.operation === "INCLUSION" && context.addedNodeId !== undefined
        ? { type: "WAIT_FOR_INTERVIEW", responseOptions: ["Ok"] }
        : { type: "WAIT_FOR_INCLUSION_IDLE", responseOptions: ["Ok"] };
    return { action: "send_to_dut", message };
  }

  // WAIT_FOR_INTERVIEW
  if (
    /wait for (the )?(node )?interview to (be )?finish/i.test(promptText) ||
    /wait until (?:the )?Inclusion process is done/i.test(promptText) ||
    /inclusion (?:process )?(?:has )?finished/i.test(promptText) ||
    /inclusion.+finished.+click(?:ing)?.+OK/i.test(promptText) ||
    /inclusion and interview process has been finished/i.test(promptText) ||
    /Inclusion and interview passed/i.test(promptText)
  ) {
    // Also check for embedded UI context (e.g., "visit the Basic Command Class visualisation")
    const uiMatch =
      /visit the (?<cc>[\w\s]+) Command Class visuali[sz]ation for node (?<nodeId>\d+)/i.exec(
        promptText
      );
    const message: WaitForInterviewMessage = {
      type: "WAIT_FOR_INTERVIEW",
      responseOptions: ["Ok"],
      uiContext: uiMatch?.groups
        ? {
            commandClass: uiMatch.groups.cc!.trim(),
            nodeId: parseInt(uiMatch.groups.nodeId!),
          }
        : undefined,
    };
    return { action: "send_to_dut", message };
  }
  // OPEN_UI
  const visitMatch =
    /visit the (?<cc>[\w\s]+) Command Class visuali[sz]ation for node (?<nodeId>\d+)/i.exec(
      promptText
    );
  if (visitMatch?.groups) {
    const message: OpenUIMessage = {
      type: "OPEN_UI",
      responseOptions: ["Ok"],
      commandClass: visitMatch.groups.cc!.trim(),
      nodeId: parseInt(visitMatch.groups.nodeId!),
    };
    return { action: "send_to_dut", message };
  }
  // "UI for X Command Class is visible" pattern
  const uiForCCMatch = /UI for (?<cc>[\w\s/]+) Command Class is visible/i.exec(
    promptText
  );
  if (uiForCCMatch?.groups) {
    const message: OpenUIMessage = {
      type: "OPEN_UI",
      responseOptions: ["Ok"],
      commandClass: uiForCCMatch.groups.cc!.trim(),
    };
    return { action: "send_to_dut", message };
  }
  if (
    /(DUT's UI|current.+state|visuali[sz]ation).+is visible/i.test(
      promptText
    ) ||
    /navigate to '[^']+' on DUT's UI/i.test(promptText)
  ) {
    const message: OpenUIMessage = {
      type: "OPEN_UI",
      responseOptions: ["Ok"],
    };
    return { action: "send_to_dut", message };
  }

  // CHECK_NETWORK_STATUS
  const resetLeftMatch =
    /indicate.+node.+ID = (?<nodeId>\d+).+reset and left/i.exec(promptText);
  if (resetLeftMatch?.groups) {
    const message: CheckNetworkStatusMessage = {
      type: "CHECK_NETWORK_STATUS",
      responseOptions: ["Yes", "No"],
      check: "RESET_AND_LEFT",
      nodeId: parseInt(resetLeftMatch.groups.nodeId!),
    };
    return { action: "send_to_dut", message };
  }
  const removedMatch = /DUT removed this node.+ID = (?<nodeId>\d+).+list/i.exec(
    promptText
  );
  if (removedMatch?.groups) {
    const message: CheckNetworkStatusMessage = {
      type: "CHECK_NETWORK_STATUS",
      responseOptions: ["Yes", "No"],
      check: "NOT_INCLUDED",
      nodeId: parseInt(removedMatch.groups.nodeId!),
    };
    return { action: "send_to_dut", message };
  }
  if (/Is the CTT End Device removed from the DUT's device list/i.test(promptText)) {
    if (state.failedNodeTargetId === undefined) return { action: "none" };
    const message: CheckNetworkStatusMessage = {
      type: "CHECK_NETWORK_STATUS",
      responseOptions: ["Yes", "No"],
      check: "NOT_INCLUDED",
      nodeId: state.failedNodeTargetId,
    };
    return {
      action: "send_to_dut",
      message,
      stateUpdate: { failedNodeTargetId: undefined },
    };
  }
  const s0NodeRemoved =
    /Has the S0 Node \(Node ID = (?<nodeId>\d+)\) been removed from DUT’s device list/i.exec(
      promptText
    );
  if (s0NodeRemoved?.groups) {
    const message: CheckNetworkStatusMessage = {
      type: "CHECK_NETWORK_STATUS",
      responseOptions: ["Yes", "No"],
      check: "NOT_INCLUDED",
      nodeId: parseInt(s0NodeRemoved.groups.nodeId!),
    };
    return { action: "send_to_dut", message };
  }
  const s2NodeRemoved =
    /Has the S2 Node \(Node ID = (?<nodeId>\d+)\) been removed from DUT’s device list/i.exec(
      promptText
    );
  if (s2NodeRemoved?.groups) {
    const message: CheckNetworkStatusMessage = {
      type: "CHECK_NETWORK_STATUS",
      responseOptions: ["Yes", "No"],
      check: "NOT_INCLUDED",
      nodeId: parseInt(s2NodeRemoved.groups.nodeId!),
    };
    return { action: "send_to_dut", message };
  }
  const includedMatch =
    /Has the End Device (?<nodeId>\d+) been included.+NO request to start an exclusion/i.exec(
      promptText
    );
  if (includedMatch?.groups) {
    const message: CheckNetworkStatusMessage = {
      type: "CHECK_NETWORK_STATUS",
      responseOptions: ["Yes", "No"],
      check: "INCLUDED",
      nodeId: parseInt(includedMatch.groups.nodeId!),
    };
    return { action: "send_to_dut", message };
  }
  if (
    /Is (?:the )?CTT Controller (?:shown as )?(?:non-securely included|included non-securely)/i.test(
      promptText
    )
  ) {
    if (state.lastAddedNodeId === undefined) return { action: "none" };
    const message: CheckSecurityClassMessage = {
      type: "CHECK_SECURITY_CLASS",
      responseOptions: ["Yes", "No"],
      securityClass: "INSECURE",
      nodeId: state.lastAddedNodeId,
    };
    return { action: "send_to_dut", message };
  }
  if (/Is the CTT Controller listed as a non-secure device/i.test(promptText)) {
    if (state.lastAddedNodeId === undefined) return { action: "none" };
    const message: CheckSecurityClassMessage = {
      type: "CHECK_SECURITY_CLASS",
      responseOptions: ["Yes", "No"],
      securityClass: "INSECURE",
      nodeId: state.lastAddedNodeId,
    };
    return { action: "send_to_dut", message };
  }
  if (/intended to include the S0 Node non-securely only/i.test(promptText)) {
    const message: DUTCapabilityQueryMessage = {
      type: "DUT_CAPABILITY_QUERY",
      responseOptions: ["Yes", "No"],
      capabilityId:
        "INTENDED_INSECURE_INCLUSION_OF_S0_NODE_BY_INCLUSION_CONTROLLER",
    };
    return { action: "send_to_dut", message };
  }
  const s2NodeShown =
    /Is the S2 Node \(Node ID = (?<nodeId>\d+)\) shown.+as added with S2 security/is.exec(
      promptText
    );
  if (s2NodeShown?.groups) {
    const message: CheckSecurityClassMessage = {
      type: "CHECK_SECURITY_CLASS",
      responseOptions: ["Yes", "No"],
      securityClass: "S2",
      nodeId: parseInt(s2NodeShown.groups.nodeId!),
    };
    return { action: "send_to_dut", message };
  }
  const insecureS2NodeShown =
    /Is the S2 Node \(Node ID = (?<nodeId>\d+)\) shown.+as non-securely added/is.exec(
      promptText
    );
  if (insecureS2NodeShown?.groups) {
    const message: CheckSecurityClassMessage = {
      type: "CHECK_SECURITY_CLASS",
      responseOptions: ["Yes", "No"],
      securityClass: "INSECURE",
      nodeId: parseInt(insecureS2NodeShown.groups.nodeId!),
    };
    return { action: "send_to_dut", message };
  }
  if (/DUT UI shows the included device as 'non-secure'/i.test(promptText)) {
    if (state.lastAddedNodeId === undefined) return { action: "none" };
    const message: CheckSecurityClassMessage = {
      type: "CHECK_SECURITY_CLASS",
      responseOptions: ["Yes", "No"],
      securityClass: "INSECURE",
      nodeId: state.lastAddedNodeId,
    };
    return { action: "send_to_dut", message };
  }
  if (
    /listed as a device with S2_AUTHENTICATED as highest granted security scheme/i.test(
      promptText
    )
  ) {
    if (state.lastAddedNodeId === undefined) return { action: "none" };
    const message: CheckSecurityClassMessage = {
      type: "CHECK_SECURITY_CLASS",
      responseOptions: ["Yes", "No"],
      securityClass: "S2_AUTHENTICATED",
      nodeId: state.lastAddedNodeId,
    };
    return { action: "send_to_dut", message };
  }
  const shownNonSecure =
    /S0 Node \(Node ID = (?<nodeId>\d+)\).+non-securely added/i.exec(
      promptText
    );
  if (shownNonSecure?.groups) {
    const message: CheckSecurityClassMessage = {
      type: "CHECK_SECURITY_CLASS",
      responseOptions: ["Yes", "No"],
      securityClass: "INSECURE",
      nodeId: parseInt(shownNonSecure.groups.nodeId!),
    };
    return { action: "send_to_dut", message };
  }
  if (/Is the CTT End Device shown as failed device/i.test(promptText)) {
    if (state.failedNodeTargetId === undefined) return { action: "none" };
    const message: CheckNetworkStatusMessage = {
      type: "CHECK_NETWORK_STATUS",
      responseOptions: ["Yes", "No"],
      check: "FAILED",
      nodeId: state.failedNodeTargetId,
    };
    return { action: "send_to_dut", message };
  }
  if (/Is the CTT End Device shown in the DUT's device list/i.test(promptText)) {
    if (state.lastAddedNodeId === undefined) return { action: "none" };
    const message: CheckNetworkStatusMessage = {
      type: "CHECK_NETWORK_STATUS",
      responseOptions: ["Yes", "No"],
      check: "INCLUDED",
      nodeId: state.lastAddedNodeId,
    };
    return { action: "send_to_dut", message };
  }
  if (
    /Has the CTT End Device been removed from the DUT's device list/i.test(
      promptText
    )
  ) {
    if (state.lastRemovedNodeId === undefined) return { action: "none" };
    const message: CheckNetworkStatusMessage = {
      type: "CHECK_NETWORK_STATUS",
      responseOptions: ["Yes", "No"],
      check: "NOT_INCLUDED",
      nodeId: state.lastRemovedNodeId,
    };
    return { action: "send_to_dut", message };
  }
  if (
    /joining node has been granted the S0 key only|joining node has been included with S0 security|listed as an S0 device/i.test(
      promptText
    )
  ) {
    if (state.lastAddedNodeId === undefined) return { action: "none" };
    const message: CheckSecurityClassMessage = {
      type: "CHECK_SECURITY_CLASS",
      responseOptions: ["Yes", "No"],
      securityClass: "S0",
      nodeId: state.lastAddedNodeId,
    };
    return { action: "send_to_dut", message };
  }
  const removeFailedNode =
    /remove the failed CTT End Device \(Node ID = (?<nodeId>\d+)\)/i.exec(
      promptText
    );
  if (removeFailedNode?.groups) {
    const nodeId = parseInt(removeFailedNode.groups.nodeId!);
    return {
      action: "send_to_dut",
      message: {
        type: "REMOVE_FAILED_NODE",
        responseOptions: ["Ok"],
        nodeId,
      },
      stateUpdate: { failedNodeTargetId: nodeId },
    };
  }

  const replaceFailedNode =
    /use the DUT's UI to replace the failed CTT End Device \(Node ID = (?<nodeId>\d+)\)/i.exec(
      promptText
    );
  if (replaceFailedNode?.groups) {
    const message: ReplaceFailedNodeMessage = {
      type: "REPLACE_FAILED_NODE",
      responseOptions: ["Ok"],
      nodeId: parseInt(replaceFailedNode.groups.nodeId!),
    };
    return { action: "send_to_dut", message };
  }

  // VERIFY_STATE patterns
  const verifyState = parseVerifyState(promptText);
  if (verifyState) {
    return { action: "send_to_dut", message: verifyState };
  }

  // VERIFY_NOTIFICATION patterns
  const verifyNotification = parseVerifyNotification(promptText);
  if (verifyNotification) {
    return { action: "send_to_dut", message: verifyNotification };
  }

  // VERIFY_SCENE
  const sceneMatch =
    /has the scene.*?(?<sceneId>\d+).+to '(?<expected>.*?)'/i.exec(promptText);
  if (sceneMatch?.groups) {
    const message: VerifySceneMessage = {
      type: "VERIFY_SCENE",
      responseOptions: ["Yes", "No"],
      sceneId: parseInt(sceneMatch.groups.sceneId!),
      expectedKeyState: sceneMatch.groups.expected!,
    };
    return { action: "send_to_dut", message };
  }

  // DUT_CAPABILITY_QUERY
  const dutCapability = parseDUTCapabilityQuery(promptText);
  if (dutCapability) {
    return { action: "send_to_dut", message: dutCapability };
  }

  // CC_CAPABILITY_QUERY
  const ccCapability = parseCCCapabilityQuery(promptText);
  if (ccCapability) {
    return { action: "send_to_dut", message: ccCapability };
  }

  // START_STOP_LEVEL_CHANGE
  const levelChange = parseStartStopLevelChange(promptText);
  if (levelChange) {
    return { action: "send_to_dut", message: levelChange };
  }

  // CHECK_ENDPOINT_CAPABILITY
  if (promptText.includes("confirm if control of:")) {
    const endpointPattern = /\*\s+(?<cc>[\w\s]+?)\s+on End Point (?<ep>\d+)/gi;
    const endpoints: Array<{ commandClass: string; endpoint: number }> = [];
    let match;
    while ((match = endpointPattern.exec(promptText)) !== null) {
      endpoints.push({
        commandClass: match.groups!.cc!.trim(),
        endpoint: parseInt(match.groups!.ep!),
      });
    }
    if (endpoints.length > 0) {
      const message: CheckEndpointCapabilityMessage = {
        type: "CHECK_ENDPOINT_CAPABILITY",
        responseOptions: ["Yes", "No"],
        endpoints,
      };
      return { action: "send_to_dut", message };
    }
  }

  // TRY_SET_CONFIG_PARAMETER
  const trySetMatch =
    /try to set the parameter.+number (?<param>\d+).+Is it possible to set the parameter value/i.exec(
      promptText
    );
  if (trySetMatch?.groups) {
    const message: TrySetConfigParameterMessage = {
      type: "TRY_SET_CONFIG_PARAMETER",
      responseOptions: ["Yes", "No"],
      paramNumber: parseInt(trySetMatch.groups.param!),
    };
    return { action: "send_to_dut", message };
  }

  // SHOULD_DISREGARD_RECOMMENDATION
  if (/Is it intended to disregard the recommendation\?/i.test(promptText)) {
    const message: ShouldDisregardRecommendationMessage = {
      type: "SHOULD_DISREGARD_RECOMMENDATION",
      responseOptions: ["Yes", "No"],
      recommendationType: state.recommendationContext?.includes(
        "INDICATOR_REPORT"
      )
        ? "INDICATOR_REPORT_IN_AGI"
        : "UNKNOWN",
      context: state.recommendationContext,
    };
    return { action: "send_to_dut", message };
  }

  // TRIGGER_RE_INTERVIEW (prompt says "click OK and trigger...")
  const reInterviewMatch =
    /trigger a capability discovery for node (?<nodeId>\d+)/i.exec(promptText);
  if (reInterviewMatch?.groups) {
    const message: TriggerReInterviewMessage = {
      type: "TRIGGER_RE_INTERVIEW",
      nodeId: parseInt(reInterviewMatch.groups.nodeId!),
    };
    return { action: "send_to_dut", message, answer: "Ok" };
  }

  // QUERY_USER_CODES - Request specific user codes without full re-interview
  // Matches: "trigger an interview...without deleting user codes...User IDs = '1', '50' and '11111'"
  if (/trigger an interview.+without deleting user codes.+from User IDs/i.test(promptText)) {
    // Extract all user IDs from the prompt (e.g., '1', '50', '11111')
    const userIdPattern = /'(\d+)'/g;
    const userIds: number[] = [];
    let match;
    while ((match = userIdPattern.exec(promptText)) !== null) {
      userIds.push(parseInt(match[1]!));
    }
    if (userIds.length > 0) {
      const message: QueryUserCodesMessage = {
        type: "QUERY_USER_CODES",
        userIds,
      };
      return { action: "send_to_dut", message, answer: "Ok" };
    }
  }

  // VERIFY_INDICATOR_IDENTIFY
  if (/did .+ indicator .+ blink \w+ times/i.test(promptText)) {
    const message: VerifyIndicatorIdentifyMessage = {
      type: "VERIFY_INDICATOR_IDENTIFY",
      responseOptions: ["Yes", "No"],
    };
    return { action: "send_to_dut", message };
  }

  return { action: "none" };
}

function parseVerifyState(promptText: string): VerifyStateMessage | null {
  // Setpoint set successfully - check FIRST before lastKnownState which might also match
  if (/setpoint.+set succ?essfully/i.test(promptText)) {
    return {
      type: "VERIFY_STATE",
      responseOptions: ["Yes", "No"],
      commandClass: "Thermostat Setpoint",
      property: "setSuccessfully",
      expected: "true",
    };
  }

  // Last known state pattern - two variants: with quotes and without
  const lastKnownState =
    // Non-greedy with quotes around expected value
    /last known state of (?<cc>[\w\s]+?)(?: (?:on|to) end ?point (?<endpoint>\d+))? is (?:Z-Wave value = )?'(?<expected>.*?)'(?: \((?<alt>.+?)\))?/i.exec(
      promptText
    ) ??
    // Without quotes (e.g., "Z-Wave value = 0 (0x00)")
    /last known state of (?<cc>[\w\s]+?)(?: (?:on|to) end ?point (?<endpoint>\d+))? is (?:Z-Wave value = )?(?<expected>\d+)(?: \((?<alt>.+?)\))?/i.exec(
      promptText
    );
  if (lastKnownState?.groups) {
    return {
      type: "VERIFY_STATE",
      responseOptions: ["Yes", "No"],
      commandClass: lastKnownState.groups.cc!.trim(),
      endpoint: lastKnownState.groups.endpoint
        ? parseInt(lastKnownState.groups.endpoint)
        : undefined,
      expected: lastKnownState.groups.expected!,
      alternativeValue: lastKnownState.groups.alt,
    };
  }

  // Current State has been set to
  const currentState = /Current State has been set to (?<value>\d+)/i.exec(
    promptText
  );
  if (currentState?.groups) {
    return {
      type: "VERIFY_STATE",
      responseOptions: ["Yes", "No"],
      commandClass: "unknown", // Will use UI context
      expected: parseInt(currentState.groups.value!),
    };
  }

  // Current mode is set to
  const currentMode = /current mode is set to '(?<mode>\w+)'/i.exec(promptText);
  if (currentMode?.groups) {
    return {
      type: "VERIFY_STATE",
      responseOptions: ["Yes", "No"],
      commandClass: "Door Lock",
      property: "currentMode",
      expected: currentMode.groups.mode!,
    };
  }

  // Current level with param ID (Window Covering) - must come before generic pattern
  const levelWithParam =
    /current level.+\(ID = (?<param>\d+)\).+value = (?<level>\d+)/i.exec(
      promptText
    );
  if (levelWithParam?.groups) {
    return {
      type: "VERIFY_STATE",
      responseOptions: ["Yes", "No"],
      commandClass: "Window Covering",
      property: `param_${levelWithParam.groups.param}`,
      expected: parseInt(levelWithParam.groups.level!),
    };
  }

  // Current level value (generic - Multilevel Switch)
  const currentLevel = /current level.+value = (?<level>\d+)/i.exec(promptText);
  if (currentLevel?.groups) {
    return {
      type: "VERIFY_STATE",
      responseOptions: ["Yes", "No"],
      commandClass: "Multilevel Switch",
      property: "currentValue",
      expected: parseInt(currentLevel.groups.level!),
    };
  }

  // Current level of color component (Color Switch)
  const colorLevelMatch =
    /current level of color component.+\(ID = (?<color>(0x)?[a-fA-F0-9]+)\).+set to (?<level>\d+)/i.exec(
      promptText
    );
  if (colorLevelMatch?.groups) {
    return {
      type: "VERIFY_STATE",
      responseOptions: ["Yes", "No"],
      commandClass: "Color Switch",
      property: `color_${parseInt(colorLevelMatch.groups.color!)}`,
      expected: parseInt(colorLevelMatch.groups.level!),
    };
  }

  // Confirm that the state
  const confirmState = /confirm that the state \((?<value>\d+)/i.exec(
    promptText
  );
  if (confirmState?.groups) {
    return {
      type: "VERIFY_STATE",
      responseOptions: ["Yes", "No"],
      commandClass: "unknown",
      expected: parseInt(confirmState.groups.value!),
    };
  }

  // Validate battery level
  const batteryLevel = /validate.+battery level of (?<level>\d+)%/i.exec(
    promptText
  );
  if (batteryLevel?.groups) {
    return {
      type: "VERIFY_STATE",
      responseOptions: ["Yes", "No"],
      commandClass: "Battery",
      property: "level",
      expected: parseInt(batteryLevel.groups.level!),
    };
  }

  // Last known mode of thermostat
  const thermostatMode =
    /last known mode of thermostat is.+\((?<value>0x[0-9a-fA-F]+)\)/i.exec(
      promptText
    );
  if (thermostatMode?.groups) {
    return {
      type: "VERIFY_STATE",
      responseOptions: ["Yes", "No"],
      commandClass: "Thermostat Mode",
      property: "mode",
      expected: parseInt(thermostatMode.groups.value!, 16),
    };
  }

  // Compare DUT UI to following values (meter)
  if (/compare the DUTs UI to following values/i.test(promptText)) {
    const valuePattern = /'([\d.]+)'\s+(\w+)/g;
    const values: Array<{ value: number; unit: string }> = [];
    let match;
    while ((match = valuePattern.exec(promptText)) !== null) {
      values.push({
        value: parseFloat(match[1]!),
        unit: match[2]!,
      });
    }
    if (values.length > 0) {
      return {
        type: "VERIFY_STATE",
        responseOptions: ["Yes", "No"],
        commandClass: "Meter",
        expected: values,
      };
    }
  }

  // Confirm scale is set to
  const scaleMatch =
    /confirm that '(?<unit>\w+)' scale is set to (?<value>[\d.]+)/i.exec(
      promptText
    );
  if (scaleMatch?.groups) {
    return {
      type: "VERIFY_STATE",
      responseOptions: ["Yes", "No"],
      commandClass: "Meter",
      expected: [
        {
          value: parseFloat(scaleMatch.groups.value!),
          unit: scaleMatch.groups.unit!,
        },
      ],
    };
  }

  // Confirm accumulating meter scales reset
  const resetMatch =
    /confirm that all accumulating meter scales \((?<units>[^)]+)\) have been reset/i.exec(
      promptText
    );
  if (resetMatch?.groups) {
    const units = resetMatch.groups.units!.split(/\s+and\s+|\s*,\s*/);
    return {
      type: "VERIFY_STATE",
      responseOptions: ["Yes", "No"],
      commandClass: "Meter",
      expected: units.map((unit) => ({ value: 0, unit: unit.trim() })),
    };
  }

  // Confirm last known value of sensor
  const sensorMatch =
    /confirm that last known value of '(?<sensorType>[^']+)'.+is '(?<value>[^']+)'/i.exec(
      promptText
    );
  if (sensorMatch?.groups) {
    return {
      type: "VERIFY_STATE",
      responseOptions: ["Yes", "No"],
      commandClass: "Multilevel Sensor",
      property: sensorMatch.groups.sensorType!,
      expected: sensorMatch.groups.value!,
    };
  }

  // Number of supported scenes
  const scenesMatch = /the number of supported.+is (?<numScenes>\d+)/i.exec(
    promptText
  );
  if (scenesMatch?.groups) {
    return {
      type: "VERIFY_STATE",
      responseOptions: ["Yes", "No"],
      commandClass: "Central Scene",
      property: "sceneCount",
      expected: parseInt(scenesMatch.groups.numScenes!),
    };
  }

  return null;
}

function parseVerifyNotification(
  promptText: string
): VerifyNotificationMessage | null {
  // Display event for notification type
  const eventMatch =
    /display the event.+\((?<eventHex>0x[0-9a-fA-F]+)\).+notification type.+\((?<typeHex>0x[0-9a-fA-F]+)\)/i.exec(
      promptText
    );
  if (eventMatch?.groups) {
    return {
      type: "VERIFY_NOTIFICATION",
      responseOptions: ["Yes", "No"],
      commandClass: "Notification",
      notificationType: parseInt(eventMatch.groups.typeHex!, 16),
      event: parseInt(eventMatch.groups.eventHex!, 16),
    };
  }

  // State return to idle
  const idleMatch =
    /state of notification type.+\((?<typeHex>0x[0-9a-fA-F]+)\).+return to 'idle'/i.exec(
      promptText
    );
  if (idleMatch?.groups) {
    return {
      type: "VERIFY_NOTIFICATION",
      responseOptions: ["Yes", "No"],
      commandClass: "Notification",
      notificationType: parseInt(idleMatch.groups.typeHex!, 16),
      event: "idle",
    };
  }

  // Entry Control notification
  const entryControlMatch =
    /UI show.+Entry Control Notification.+Event Type '(?<eventType>[^']+)'.+Event Data '(?<eventData>[^']+)'/i.exec(
      promptText
    );
  if (entryControlMatch?.groups) {
    return {
      type: "VERIFY_NOTIFICATION",
      responseOptions: ["Yes", "No"],
      commandClass: "Entry Control",
      eventType: entryControlMatch.groups.eventType!,
      eventData: entryControlMatch.groups.eventData!,
    };
  }

  // Battery needs to be replaced
  if (/displays that the battery needs to be replaced/i.test(promptText)) {
    return {
      type: "VERIFY_NOTIFICATION",
      responseOptions: ["Yes", "No"],
      commandClass: "Battery",
    };
  }

  return null;
}

function parseDUTCapabilityQuery(
  promptText: string
): DUTCapabilityQueryMessage | null {
  const patterns: Array<[RegExp, DUTCapabilityId]> = [
    [/allows the end user to establish association/i, "ESTABLISH_ASSOCIATION"],
    [/(capable|able) to display the last.+state/i, "DISPLAY_LAST_STATE"],
    [/provide a QR Code scanning capability/i, "QR_CODE"],
    [/Does the DUT support Learn Mode/i, "LEARN_MODE"],
    [/Is the Learn Mode accessible/i, "LEARN_MODE_ACCESSIBLE"],
    [/can be reset to factory settings/i, "FACTORY_RESET"],
    [/offering a possibility to remove the failed/i, "REMOVE_FAILED_NODE"],
    [
      /Does the DUT support the 'Replace Failed Node' function/i,
      "REPLACE_FAILED_NODE",
    ],
    [/icon type.+match the actual device/i, "ICON_TYPE_MATCH"],
    [
      /Does the DUT use the identify command for any other purpose/i,
      "IDENTIFY_OTHER_PURPOSE",
    ],
    [/partial control behavior documented/i, "PARTIAL_CONTROL_DOCUMENTED"],
    [
      /control any further Command Classes which are not listed/i,
      "CONTROLS_UNLISTED_CCS",
    ],
    [
      /Are all of them correctly documented as controlled/i,
      "ALL_DOCUMENTED_AS_CONTROLLED",
    ],
    [/Is the DUT mains-powered/i, "MAINS_POWERED"],
    [
      /Is it possible to actively deselect the S2_ACCESS key in the DUT UI/i,
      "SELECT_GRANTED_SECURITY_CLASSES",
    ],
    [
      /^(?:Is it possible to deny or \(de-\)select what keys the DUT will grant to a non-Access node during S2 bootstrapping|Is the DUT able to confirm \(or adjust\) the requested keys before granting them to a joining node)\?$/i,
      "SELECT_GRANTED_SECURITY_CLASSES",
    ],
  ];

  for (const [pattern, capabilityId] of patterns) {
    if (pattern.test(promptText)) {
      return {
        type: "DUT_CAPABILITY_QUERY",
        responseOptions: ["Yes", "No"],
        capabilityId,
      };
    }
  }

  return null;
}

function parseCCCapabilityQuery(
  promptText: string
): CCCapabilityQueryMessage | null {
  // CONTROLS_CC with version
  const controlsCCMatch =
    /Does the DUT control.+COMMAND_CLASS_(?<cc>\w+).+version (?<ver>\d+)/i.exec(
      promptText
    );
  if (controlsCCMatch?.groups) {
    const ccName = controlsCCMatch.groups
      .cc!.replace(/_/g, " ")
      .toLowerCase()
      .split(" ")
      .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
      .join(" ");
    return {
      type: "CC_CAPABILITY_QUERY",
      responseOptions: ["Yes", "No"],
      commandClass: ccName,
      capabilityId: "CONTROLS_CC",
      version: parseInt(controlsCCMatch.groups.ver!),
    };
  }

  // Multilevel Switch capabilities
  if (/able to send a Start\/Stop Level Change/i.test(promptText)) {
    return {
      type: "CC_CAPABILITY_QUERY",
      responseOptions: ["Yes", "No"],
      commandClass: "Multilevel Switch",
      capabilityId: "START_STOP_LEVEL_CHANGE",
    };
  }
  if (
    /allow to set a dimming 'Duration' for 'Setting the Level'/i.test(
      promptText
    )
  ) {
    return {
      type: "CC_CAPABILITY_QUERY",
      responseOptions: ["Yes", "No"],
      commandClass: "Multilevel Switch",
      capabilityId: "SET_DIMMING_DURATION",
    };
  }
  if (
    /allow to set a ('Start Level'|dimming 'Duration') for '(Start|Stop) Level Change'/i.test(
      promptText
    )
  ) {
    return {
      type: "CC_CAPABILITY_QUERY",
      responseOptions: ["Yes", "No"],
      commandClass: "Multilevel Switch",
      capabilityId: "SET_LEVEL_CHANGE_PARAMS",
    };
  }

  // Barrier Operator capabilities
  if (
    /activate and deactivate the '(audible|visual) notification' subsystem/i.test(
      promptText
    )
  ) {
    return {
      type: "CC_CAPABILITY_QUERY",
      responseOptions: ["Yes", "No"],
      commandClass: "Barrier Operator",
      capabilityId: "CONTROL_EVENT_SIGNALING",
    };
  }

  // Anti-Theft capabilities
  if (/lock or unlock the Anti-Theft feature/i.test(promptText)) {
    return {
      type: "CC_CAPABILITY_QUERY",
      responseOptions: ["Yes", "No"],
      commandClass: "Anti-Theft",
      capabilityId: "LOCK_UNLOCK",
    };
  }

  // Door Lock capabilities
  if (
    /configure the door handles of a v[14] supporting end node/i.test(
      promptText
    )
  ) {
    return {
      type: "CC_CAPABILITY_QUERY",
      responseOptions: ["Yes", "No"],
      commandClass: "Door Lock",
      capabilityId: "CONFIGURE_DOOR_HANDLES",
    };
  }

  // Configuration capabilities
  if (
    /allow to reset one particular configuration parameter/i.test(promptText)
  ) {
    return {
      type: "CC_CAPABILITY_QUERY",
      responseOptions: ["Yes", "No"],
      commandClass: "Configuration",
      capabilityId: "RESET_SINGLE_PARAM",
    };
  }

  // Notification capabilities
  if (
    /allow to create rules or commands based on received notifications/i.test(
      promptText
    )
  ) {
    return {
      type: "CC_CAPABILITY_QUERY",
      responseOptions: ["Yes", "No"],
      commandClass: "Notification",
      capabilityId: "CREATE_RULES_FROM_NOTIFICATIONS",
    };
  }
  if (/capability to update its Notification list/i.test(promptText)) {
    return {
      type: "CC_CAPABILITY_QUERY",
      responseOptions: ["Yes", "No"],
      commandClass: "Notification",
      capabilityId: "UPDATE_NOTIFICATION_LIST",
    };
  }

  // User Code capabilities
  if (/able to (modify|erase|add).+User Code/i.test(promptText)) {
    return {
      type: "CC_CAPABILITY_QUERY",
      responseOptions: ["Yes", "No"],
      commandClass: "User Code",
      capabilityId: "MODIFY_USER_CODE",
    };
  }
  if (/able to set the Keypad Mode/i.test(promptText)) {
    return {
      type: "CC_CAPABILITY_QUERY",
      responseOptions: ["Yes", "No"],
      commandClass: "User Code",
      capabilityId: "SET_KEYPAD_MODE",
    };
  }
  if (/able to (set|disable).+Admin Code/i.test(promptText)) {
    return {
      type: "CC_CAPABILITY_QUERY",
      responseOptions: ["Yes", "No"],
      commandClass: "User Code",
      capabilityId: "SET_ADMIN_CODE",
    };
  }

  // Entry Control capabilities
  if (/able to configure the keypad/i.test(promptText)) {
    return {
      type: "CC_CAPABILITY_QUERY",
      responseOptions: ["Yes", "No"],
      commandClass: "Entry Control",
      capabilityId: "CONFIGURE_KEYPAD",
    };
  }

  // Basic CC capabilities
  if (/control the device using the Basic Command Class/i.test(promptText)) {
    return {
      type: "CC_CAPABILITY_QUERY",
      responseOptions: ["Yes", "No"],
      commandClass: "Basic",
      capabilityId: "CONTROL_BASIC_CC",
    };
  }

  // Wake Up CC capabilities
  if (
    /used Supervision encapsulation for sending the Wake Up Interval Set/i.test(
      promptText
    )
  ) {
    return {
      type: "CC_CAPABILITY_QUERY",
      responseOptions: ["Yes", "No"],
      commandClass: "Wake Up",
      capabilityId: "USES_SUPERVISION",
    };
  }

  return null;
}

function parseStartStopLevelChange(
  promptText: string
): StartStopLevelChangeMessage | null {
  // Must contain both start and stop
  if (
    !promptText.includes("Start level change") ||
    !promptText.includes("Stop level change")
  ) {
    return null;
  }

  const directionMatch = /Direction\s+=\s+'?(?<direction>up|down)'?/i.exec(
    promptText
  )?.groups?.direction;
  const startLevelMatch = /Start Level\s+=\s+(?<startLevel>\d+)/i.exec(
    promptText
  )?.groups?.startLevel;
  const durationMatch = /duration\s+=\s+(?<duration>\d+\s+)?(?<unit>\w+)/i.exec(
    promptText
  )?.groups;

  const startLevel = startLevelMatch
    ? parseInt(startLevelMatch)
    : undefined;

  let duration: DurationValue | undefined;
  if (durationMatch?.unit) {
    const unit = durationMatch.unit.toLowerCase();
    if (unit === "instantly") {
      duration = { value: 0, unit: "seconds" };
    } else if (unit.includes("default") || unit.includes("factory")) {
      duration = "default";
    } else if (durationMatch.duration) {
      const durationValue = parseInt(durationMatch.duration);
      duration =
        unit === "minutes"
          ? { value: durationValue, unit: "minutes" }
          : { value: durationValue, unit: "seconds" };
    }
  }

  // Check for Window Covering (has param ID)
  const paramMatch = /parameter '\w+' \((?<param>\d+)\)/i.exec(promptText);
  if (paramMatch?.groups) {
    const rawDirection = directionMatch?.toLowerCase();
    return {
      type: "START_STOP_LEVEL_CHANGE",
      responseOptions: ["Ok"],
      commandClass: "Window Covering",
      direction: (rawDirection === "up" ? "up" : "down") as "up" | "down",
      paramId: parseInt(paramMatch.groups.param!),
      startLevel,
      duration,
    };
  }

  // Check for Color Switch (has color ID)
  const colorMatch = /\(ID = (?<color>(0x)?[a-fA-F0-9]+)\)/i.exec(promptText);
  if (colorMatch?.groups) {
    return {
      type: "START_STOP_LEVEL_CHANGE",
      responseOptions: ["Ok"],
      commandClass: "Color Switch",
      direction: (directionMatch?.toLowerCase() || "up") as
        | "up"
        | "down",
      colorId: parseInt(colorMatch.groups.color!),
      startLevel,
      duration,
    };
  }

  // Default to Multilevel Switch
  return {
    type: "START_STOP_LEVEL_CHANGE",
    responseOptions: ["Ok"],
    commandClass: "Multilevel Switch",
    direction: (directionMatch?.toLowerCase() || "up") as
      | "up"
      | "down",
    startLevel,
    duration,
  };
}
