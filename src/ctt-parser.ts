// CTT Parser - Converts raw CTT logs and prompts into structured DUT messages

import type {
  DUTMessage,
  SendCommandMessage,
  S2PinCodeMessage,
  VerifyStateMessage,
  VerifyNotificationMessage,
  VerifySceneMessage,
  DUTCapabilityQueryMessage,
  CCCapabilityQueryMessage,
  ActivateNetworkModeMessage,
  OpenUIMessage,
  WaitForInterviewMessage,
  CheckNetworkStatusMessage,
  StartStopLevelChangeMessage,
  CheckEndpointCapabilityMessage,
  TrySetConfigParameterMessage,
  ShouldDisregardRecommendationMessage,
  TriggerReInterviewMessage,
  QueryUserCodesMessage,
  VerifyIndicatorIdentifyMessage,
  OrchestratorState,
  DUTCapabilityId,
  DurationValue,
} from "./ctt-message-types.ts";

// =============================================================================
// Parse Result Types
// =============================================================================

export type LogParseResult =
  | { action: "send_to_dut"; message: DUTMessage }
  | { action: "modify_context"; stateUpdate: Partial<OrchestratorState> }
  | { action: "none" };

export type PromptParseResult =
  | { action: "send_to_dut"; message: DUTMessage; answer?: string }
  | { action: "auto_answer"; answer: string }
  | { action: "none" };

// =============================================================================
// Log Parsing
// =============================================================================

export function parseLog(
  logText: string,
  state: OrchestratorState
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
    )
  ) {
    return { action: "modify_context", stateUpdate: { forceS0: true } };
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

// =============================================================================
// Prompt Parsing
// =============================================================================

export function parsePrompt(
  promptText: string,
  state: OrchestratorState
): PromptParseResult {
  // Orchestrator-only auto-answers
  if (/Prepare the DUT to send any.+command/i.test(promptText)) {
    return { action: "auto_answer", answer: "Ok" };
  }
  if (/Include.+into the DUT network/i.test(promptText)) {
    return { action: "auto_answer", answer: "Ok" };
  }
  if (promptText.toLowerCase().includes("observe the dut")) {
    return { action: "auto_answer", answer: "Ok" };
  }
  if (/Retry\?/i.test(promptText)) {
    return { action: "auto_answer", answer: "No" };
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
  if (/Click 'OK' and send any S2/i.test(promptText)) {
    const message: SendCommandMessage = {
      type: "SEND_COMMAND",
      commandClass: "any",
      action: "any",
      encapsulation: ["S2"],
    };
    return { action: "send_to_dut", message, answer: "Ok" };
  }

  // ACTIVATE_NETWORK_MODE
  if (promptText.toLowerCase().includes("activate the add mode")) {
    const message: ActivateNetworkModeMessage = {
      type: "ACTIVATE_NETWORK_MODE",
      responseOptions: ["Ok"],
      mode: "ADD",
      forceS0: state.forceS0,
    };
    return { action: "send_to_dut", message };
  }
  if (promptText.toLowerCase().includes("activate the remove mode")) {
    const message: ActivateNetworkModeMessage = {
      type: "ACTIVATE_NETWORK_MODE",
      responseOptions: ["Ok"],
      mode: "REMOVE",
    };
    return { action: "send_to_dut", message };
  }

  // WAIT_FOR_INTERVIEW
  if (
    /wait for (the )?(node )?interview to (be )?finish/i.test(promptText) ||
    /inclusion (process )?(has )?finish(ed)?/i.test(promptText) ||
    /inclusion.+finished.+click(ing)?.+OK/i.test(promptText) ||
    /Inclusion and interview passed/i.test(promptText) ||
    /wait.+dut is ready/i.test(promptText)
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
      check: "REMOVED_FROM_LIST",
      nodeId: parseInt(removedMatch.groups.nodeId!),
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
