// CTT Message Types - Structured messages between orchestrator and DUT
// All messages are actionable without further parsing

// =============================================================================
// Base Message Structure
// =============================================================================

export interface DUTMessageBase {
  type: string;
  // If undefined, no response is required (fire and forget)
  // If defined, DUT must respond with one of these options
  responseOptions?: string[];
}

// =============================================================================
// SEND_COMMAND - DUT should send a Z-Wave command
// =============================================================================

interface SendCommandBase {
  type: "SEND_COMMAND";
  // responseOptions: undefined - fire and forget
  endpoint?: number;
  encapsulation?: ("S0" | "S2")[];
}

// Configuration CC
interface SendCommand_ConfigurationSet {
  commandClass: "Configuration";
  action: "SET";
  param: number;
  size?: 1 | 2 | 4;
  value: number;
}

interface SendCommand_ConfigurationReset {
  commandClass: "Configuration";
  action: "RESET";
  param: number;
}

interface SendCommand_ConfigurationResetAll {
  commandClass: "Configuration";
  action: "RESET_ALL";
}

// Door Lock CC
interface SendCommand_DoorLockSetMode {
  commandClass: "Door Lock";
  action: "SET_MODE";
  mode: string;
}

interface SendCommand_DoorLockSetConfig {
  commandClass: "Door Lock";
  action: "SET_CONFIG";
  operationType: "Constant" | "Timed";
  insideHandles: [boolean, boolean, boolean, boolean];
  outsideHandles: [boolean, boolean, boolean, boolean];
  lockTimeout?: number;
  autoRelockTime?: number;
  holdAndReleaseTime?: number;
  blockToBlock?: boolean;
  twistAssist?: boolean;
}

// User Code CC
interface SendCommand_UserCodeSet {
  commandClass: "User Code";
  action: "SET";
  userId: number;
  status: string;
  code: string;
}

interface SendCommand_UserCodeAdd {
  commandClass: "User Code";
  action: "ADD";
  userId: number;
  status: string;
  code: string;
}

interface SendCommand_UserCodeClear {
  commandClass: "User Code";
  action: "CLEAR";
  userId: number;
}

interface SendCommand_UserCodeSetKeypadMode {
  commandClass: "User Code";
  action: "SET_KEYPAD_MODE";
  mode: string;
}

interface SendCommand_UserCodeSetAdminCode {
  commandClass: "User Code";
  action: "SET_ADMIN_CODE";
  code: string;
}

interface SendCommand_UserCodeDisableAdminCode {
  commandClass: "User Code";
  action: "DISABLE_ADMIN_CODE";
}

// Basic CC
interface SendCommand_BasicSet {
  commandClass: "Basic";
  action: "SET";
  targetValue: number | "any";
}

// Binary Switch CC
interface SendCommand_BinarySwitchSet {
  commandClass: "Binary Switch";
  action: "SET";
  targetValue: boolean | "any";
}

// Duration type used by multiple CCs
export type DurationValue =
  | "default"
  | { value: number; unit: "seconds" | "minutes" };

// Multilevel Switch CC
interface SendCommand_MultilevelSwitchSet {
  commandClass: "Multilevel Switch";
  action: "SET";
  targetValue: number | "any";
  duration?: DurationValue;
}

// Barrier Operator CC
interface SendCommand_BarrierOperatorSet {
  commandClass: "Barrier Operator";
  action: "SET";
  targetValue: number | "Open" | "Close";
}

interface SendCommand_BarrierOperatorSetEventSignaling {
  commandClass: "Barrier Operator";
  action: "SET_EVENT_SIGNALING";
  subsystem: "Audible" | "Visual";
  value: number;
}

// Notification CC
interface SendCommand_NotificationGet {
  commandClass: "Notification";
  action: "GET";
  notificationType: number;
}

// Meter CC
interface SendCommand_MeterResetAll {
  commandClass: "Meter";
  action: "RESET_ALL";
}

// Indicator CC
interface SendCommand_IndicatorIdentify {
  commandClass: "Indicator";
  action: "IDENTIFY";
}

// Thermostat Mode CC
interface SendCommand_ThermostatModeSet {
  commandClass: "Thermostat Mode";
  action: "SET";
  mode: string;
  manufacturerData?: number[];
}

// Thermostat Setback CC
interface SendCommand_ThermostatSetbackSet {
  commandClass: "Thermostat Setback";
  action: "SET";
  setbackType: string;
  stateKelvin: number;
}

// Thermostat Setpoint CC
interface SendCommand_ThermostatSetpointSet {
  commandClass: "Thermostat Setpoint";
  action: "SET";
  setpointType: string;
  value: number;
}

// Sound Switch CC
interface SendCommand_SoundSwitchSetTone {
  commandClass: "Sound Switch";
  action: "SET_TONE";
  tone: string;
}

interface SendCommand_SoundSwitchSetVolume {
  commandClass: "Sound Switch";
  action: "SET_VOLUME";
  volume: number;
}

interface SendCommand_SoundSwitchMute {
  commandClass: "Sound Switch";
  action: "MUTE";
}

interface SendCommand_SoundSwitchPlay {
  commandClass: "Sound Switch";
  action: "PLAY";
  tone: string;
}

interface SendCommand_SoundSwitchStop {
  commandClass: "Sound Switch";
  action: "STOP";
}

interface SendCommand_SoundSwitchPlayDefault {
  commandClass: "Sound Switch";
  action: "PLAY_DEFAULT";
}

// Window Covering CC
interface SendCommand_WindowCoveringSet {
  commandClass: "Window Covering";
  action: "SET";
  paramId: number;
  value: number;
  duration?: DurationValue;
}

// Entry Control CC
interface SendCommand_EntryControlSetConfig {
  commandClass: "Entry Control";
  action: "SET_CONFIG";
  keyCacheSize: number;
  keyCacheTimeout: number;
}

// Color Switch CC
interface SendCommand_ColorSwitchSet {
  commandClass: "Color Switch";
  action: "SET";
  colorId: number;
  value: number;
}

// Any command (for generic "send any S2 command" prompts)
interface SendCommand_Any {
  commandClass: "any";
  action: "any";
}

export type SendCommandMessage = SendCommandBase &
  (
    | SendCommand_ConfigurationSet
    | SendCommand_ConfigurationReset
    | SendCommand_ConfigurationResetAll
    | SendCommand_DoorLockSetMode
    | SendCommand_DoorLockSetConfig
    | SendCommand_UserCodeSet
    | SendCommand_UserCodeAdd
    | SendCommand_UserCodeClear
    | SendCommand_UserCodeSetKeypadMode
    | SendCommand_UserCodeSetAdminCode
    | SendCommand_UserCodeDisableAdminCode
    | SendCommand_BasicSet
    | SendCommand_BinarySwitchSet
    | SendCommand_MultilevelSwitchSet
    | SendCommand_BarrierOperatorSet
    | SendCommand_BarrierOperatorSetEventSignaling
    | SendCommand_NotificationGet
    | SendCommand_MeterResetAll
    | SendCommand_IndicatorIdentify
    | SendCommand_ThermostatModeSet
    | SendCommand_ThermostatSetbackSet
    | SendCommand_ThermostatSetpointSet
    | SendCommand_SoundSwitchSetTone
    | SendCommand_SoundSwitchSetVolume
    | SendCommand_SoundSwitchMute
    | SendCommand_SoundSwitchPlay
    | SendCommand_SoundSwitchStop
    | SendCommand_SoundSwitchPlayDefault
    | SendCommand_WindowCoveringSet
    | SendCommand_EntryControlSetConfig
    | SendCommand_ColorSwitchSet
    | SendCommand_Any
  );

// =============================================================================
// S2_PIN_CODE - PIN code extracted from log
// =============================================================================

export interface S2PinCodeMessage {
  type: "S2_PIN_CODE";
  // responseOptions: undefined - fire and forget, DUT uses this for inclusion
  pin: string; // 5-digit PIN
}

// =============================================================================
// VERIFY_STATE - Confirm a CC value matches expected
// =============================================================================

export interface VerifyStateMessage {
  type: "VERIFY_STATE";
  responseOptions: ["Yes", "No"];
  commandClass: string;
  endpoint?: number;
  property?: string;
  expected: string | number | Array<{ value: number; unit: string }>;
  alternativeValue?: string;
}

// =============================================================================
// VERIFY_NOTIFICATION - Confirm notification was received
// =============================================================================

interface VerifyNotificationBase {
  type: "VERIFY_NOTIFICATION";
  responseOptions: ["Yes", "No"];
}

interface VerifyNotification_Notification {
  commandClass: "Notification";
  notificationType: number;
  event: number | "idle";
}

interface VerifyNotification_EntryControl {
  commandClass: "Entry Control";
  eventType: string;
  eventData?: string;
}

interface VerifyNotification_Battery {
  commandClass: "Battery";
}

export type VerifyNotificationMessage = VerifyNotificationBase &
  (
    | VerifyNotification_Notification
    | VerifyNotification_EntryControl
    | VerifyNotification_Battery
  );

// =============================================================================
// VERIFY_SCENE - Confirm scene event was received
// =============================================================================

export interface VerifySceneMessage {
  type: "VERIFY_SCENE";
  responseOptions: ["Yes", "No"];
  sceneId: number;
  expectedKeyState: string;
}

// =============================================================================
// DUT_CAPABILITY_QUERY - Answer about generic DUT capabilities
// =============================================================================

export type DUTCapabilityId =
  | "ESTABLISH_ASSOCIATION"
  | "DISPLAY_LAST_STATE"
  | "QR_CODE"
  | "LEARN_MODE"
  | "LEARN_MODE_ACCESSIBLE"
  | "FACTORY_RESET"
  | "REMOVE_FAILED_NODE"
  | "ICON_TYPE_MATCH"
  | "IDENTIFY_OTHER_PURPOSE"
  | "PARTIAL_CONTROL_DOCUMENTED"
  | "CONTROLS_UNLISTED_CCS"
  | "ALL_DOCUMENTED_AS_CONTROLLED"
  | "MAINS_POWERED";

export interface DUTCapabilityQueryMessage {
  type: "DUT_CAPABILITY_QUERY";
  responseOptions: ["Yes", "No"];
  capabilityId: DUTCapabilityId;
}

// =============================================================================
// CC_CAPABILITY_QUERY - Answer about CC-specific DUT capabilities
// =============================================================================

interface CCCapabilityQueryBase {
  type: "CC_CAPABILITY_QUERY";
  responseOptions: ["Yes", "No"];
  commandClass: string;
}

// Controls a specific CC version
interface CCCapability_ControlsCC {
  capabilityId: "CONTROLS_CC";
  version: number;
}

// Multilevel Switch capabilities
interface CCCapability_StartStopLevelChange {
  capabilityId: "START_STOP_LEVEL_CHANGE";
}

interface CCCapability_SetDimmingDuration {
  capabilityId: "SET_DIMMING_DURATION";
}

interface CCCapability_SetLevelChangeParams {
  capabilityId: "SET_LEVEL_CHANGE_PARAMS";
}

// Barrier Operator capabilities
interface CCCapability_ControlEventSignaling {
  capabilityId: "CONTROL_EVENT_SIGNALING";
}

// Anti-Theft capabilities
interface CCCapability_LockUnlock {
  capabilityId: "LOCK_UNLOCK";
}

// Door Lock capabilities
interface CCCapability_ConfigureDoorHandles {
  capabilityId: "CONFIGURE_DOOR_HANDLES";
}

// Configuration capabilities
interface CCCapability_ResetSingleParam {
  capabilityId: "RESET_SINGLE_PARAM";
}

// Notification capabilities
interface CCCapability_CreateRulesFromNotifications {
  capabilityId: "CREATE_RULES_FROM_NOTIFICATIONS";
}

interface CCCapability_UpdateNotificationList {
  capabilityId: "UPDATE_NOTIFICATION_LIST";
}

// User Code capabilities
interface CCCapability_ModifyUserCode {
  capabilityId: "MODIFY_USER_CODE";
}

interface CCCapability_SetKeypadMode {
  capabilityId: "SET_KEYPAD_MODE";
}

interface CCCapability_SetAdminCode {
  capabilityId: "SET_ADMIN_CODE";
}

// Entry Control capabilities
interface CCCapability_ConfigureKeypad {
  capabilityId: "CONFIGURE_KEYPAD";
}

// Basic CC capabilities
interface CCCapability_ControlBasicCC {
  capabilityId: "CONTROL_BASIC_CC";
}

// Wake Up CC capabilities
interface CCCapability_UsesSupervision {
  capabilityId: "USES_SUPERVISION";
}

export type CCCapabilityQueryMessage = CCCapabilityQueryBase &
  (
    | CCCapability_ControlsCC
    | CCCapability_StartStopLevelChange
    | CCCapability_SetDimmingDuration
    | CCCapability_SetLevelChangeParams
    | CCCapability_ControlEventSignaling
    | CCCapability_LockUnlock
    | CCCapability_ConfigureDoorHandles
    | CCCapability_ResetSingleParam
    | CCCapability_CreateRulesFromNotifications
    | CCCapability_UpdateNotificationList
    | CCCapability_ModifyUserCode
    | CCCapability_SetKeypadMode
    | CCCapability_SetAdminCode
    | CCCapability_ConfigureKeypad
    | CCCapability_ControlBasicCC
    | CCCapability_UsesSupervision
  );

// =============================================================================
// ACTIVATE_NETWORK_MODE - Enter a network mode
// =============================================================================

export interface ActivateNetworkModeMessage {
  type: "ACTIVATE_NETWORK_MODE";
  responseOptions: ["Ok"];
  mode: "ADD" | "REMOVE" | "LEARN";
  forceS0?: boolean;
}

// =============================================================================
// OPEN_UI - Navigate to CC visualization / make UI visible
// =============================================================================

export interface OpenUIMessage {
  type: "OPEN_UI";
  responseOptions: ["Ok"];
  commandClass?: string;
  nodeId?: number;
}

// =============================================================================
// WAIT_FOR_INTERVIEW - Wait for node interview to complete
// =============================================================================

export interface WaitForInterviewMessage {
  type: "WAIT_FOR_INTERVIEW";
  responseOptions: ["Ok"];
  uiContext?: {
    commandClass: string;
    nodeId: number;
  };
}

// =============================================================================
// CHECK_NETWORK_STATUS - Check node status
// =============================================================================

export interface CheckNetworkStatusMessage {
  type: "CHECK_NETWORK_STATUS";
  responseOptions: ["Yes", "No"];
  check: "RESET_AND_LEFT" | "REMOVED_FROM_LIST";
  nodeId: number;
}

// =============================================================================
// START_STOP_LEVEL_CHANGE - Interactive level change operation
// =============================================================================

interface StartStopLevelChangeBase {
  type: "START_STOP_LEVEL_CHANGE";
  responseOptions: ["Ok"];
  startLevel?: number;
  duration?: DurationValue;
}

interface StartStopLevelChange_MultilevelSwitch {
  commandClass: "Multilevel Switch";
  direction: "up" | "down";
}

interface StartStopLevelChange_WindowCovering {
  commandClass: "Window Covering";
  direction: "up" | "down";
  paramId: number;
}

interface StartStopLevelChange_ColorSwitch {
  commandClass: "Color Switch";
  direction: "up" | "down";
  colorId: number;
}

export type StartStopLevelChangeMessage = StartStopLevelChangeBase &
  (
    | StartStopLevelChange_MultilevelSwitch
    | StartStopLevelChange_WindowCovering
    | StartStopLevelChange_ColorSwitch
  );

// =============================================================================
// CHECK_ENDPOINT_CAPABILITY - Confirm control of CCs on endpoints
// =============================================================================

export interface CheckEndpointCapabilityMessage {
  type: "CHECK_ENDPOINT_CAPABILITY";
  responseOptions: ["Yes", "No"];
  endpoints: Array<{ commandClass: string; endpoint: number }>;
}

// =============================================================================
// TRY_SET_CONFIG_PARAMETER - Check if a config parameter can be set
// =============================================================================

export interface TrySetConfigParameterMessage {
  type: "TRY_SET_CONFIG_PARAMETER";
  responseOptions: ["Yes", "No"];
  paramNumber: number;
}

// =============================================================================
// SHOULD_DISREGARD_RECOMMENDATION - Answer about intentional disregard
// =============================================================================

export interface ShouldDisregardRecommendationMessage {
  type: "SHOULD_DISREGARD_RECOMMENDATION";
  responseOptions: ["Yes", "No"];
  recommendationType: "INDICATOR_REPORT_IN_AGI" | string;
  context?: string;
}

// =============================================================================
// TRIGGER_RE_INTERVIEW - Trigger capability discovery for a node
// =============================================================================

export interface TriggerReInterviewMessage {
  type: "TRIGGER_RE_INTERVIEW";
  nodeId: number;
}

// =============================================================================
// QUERY_USER_CODES - Query specific user codes without full re-interview
// =============================================================================

export interface QueryUserCodesMessage {
  type: "QUERY_USER_CODES";
  userIds: number[];
}

// =============================================================================
// VERIFY_INDICATOR_IDENTIFY - Check if identify event was received
// =============================================================================

export interface VerifyIndicatorIdentifyMessage {
  type: "VERIFY_INDICATOR_IDENTIFY";
  responseOptions: ["Yes", "No"];
}

// =============================================================================
// Union of all DUT message types
// =============================================================================

export type DUTMessage =
  | SendCommandMessage
  | S2PinCodeMessage
  | VerifyStateMessage
  | VerifyNotificationMessage
  | VerifySceneMessage
  | DUTCapabilityQueryMessage
  | CCCapabilityQueryMessage
  | ActivateNetworkModeMessage
  | OpenUIMessage
  | WaitForInterviewMessage
  | CheckNetworkStatusMessage
  | StartStopLevelChangeMessage
  | CheckEndpointCapabilityMessage
  | TrySetConfigParameterMessage
  | ShouldDisregardRecommendationMessage
  | TriggerReInterviewMessage
  | QueryUserCodesMessage
  | VerifyIndicatorIdentifyMessage;

// =============================================================================
// Orchestrator-only state (not sent to DUT)
// =============================================================================

export interface OrchestratorState {
  forceS0?: boolean;
  verifyUIContext?: {
    commandClass: string;
    nodeId: number;
  };
  recommendationContext?: string;
}
