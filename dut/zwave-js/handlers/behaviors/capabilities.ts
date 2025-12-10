import { registerHandler, type PromptResponse } from "../../prompt-handlers.ts";

const questions: { pattern: RegExp; answer: PromptResponse }[] = [
  { pattern: /allows the end user to establish association/i, answer: "No" },
  { pattern: /(capable|able) to display the last known state/i, answer: "Yes" },
  {
    pattern: /(DUT's UI|current state|visualization|visualisation).+is visible/i,
    answer: "Ok",
  },
  { pattern: /icon type.+match the actual device/i, answer: "Yes" },
  {
    pattern: /Does the DUT use the identify command for any other purpose/i,
    answer: "No",
  },
  { pattern: /able to send a Start\/Stop Level Change/i, answer: "Yes" },
  {
    pattern: /allow to set a dimming 'Duration' for 'Setting the Level'/i,
    answer: "Yes",
  },
  {
    pattern:
      /allow to set a ('Start Level'|dimming 'Duration') for '(Start|Stop) Level Change'/i,
    answer: "Yes",
  },
  {
    pattern:
      /activate and deactivate the '(audible|visual) notification' subsystem/i,
    answer: "Yes",
  },
  {
    pattern: /Does the DUT control.+COMMAND_CLASS_BASIC.+version 1/i,
    answer: "Yes",
  },
  {
    pattern: /Does the DUT control.+COMMAND_CLASS_INDICATOR.+version 3/i,
    answer: "Yes",
  },
  {
    pattern: /Does the DUT control.+COMMAND_CLASS_VERSION.+version 2/i,
    answer: "Yes",
  },
  {
    pattern: /Does the DUT control.+COMMAND_CLASS_WAKE_UP.+version 2/i,
    answer: "Yes",
  },
  { pattern: /provide a QR Code scanning capability/i, answer: "Yes" },
  { pattern: /can be reset to factory settings/i, answer: "Yes" },
  { pattern: /Does the DUT support Learn Mode/i, answer: "No" },
  { pattern: /Is the Learn Mode accessible/i, answer: "No" },
  { pattern: /lock or unlock the Anti-Theft feature/i, answer: "No" },
  { pattern: /offering a possibility to remove the failed/i, answer: "Yes" },

  // Command Class Control
  {
    pattern: /control any further Command Classes which are not listed/i,
    answer: "No",
  },
  {
    pattern: /Are all of them correctly documented as controlled/i,
    answer: "Yes",
  },

  // Door Lock
  {
    pattern: /configure the door handles of a v[14] supporting end node/i,
    answer: "Yes",
  },

  // Configuration CC
  {
    pattern: /allow to reset one particular configuration parameter/i,
    answer: "Yes",
  },

  // Notification CC
  {
    pattern:
      /allow to create rules or commands based on received notifications/i,
    answer: "Yes",
  },

  // User Code CC
  { pattern: /able to (modify|erase|add).+User Code/i, answer: "Yes" },
  { pattern: /able to set the Keypad Mode/i, answer: "Yes" },
  { pattern: /able to (set|disable).+Admin Code/i, answer: "Yes" },

  // Entry Control CC
  { pattern: /able to configure the keypad/i, answer: "Yes" },

  // Generic
  { pattern: /Retry\?/i, answer: "No" },
  { pattern: /partial control behavior documented/i, answer: "No" },
];

registerHandler(/.*/, {
  onPrompt: async (ctx) => {
    for (const q of questions) {
      if (q.pattern.test(ctx.promptText)) {
        return q.answer;
      }
    }

    // Let other prompts fall through to manual handling
    return undefined;
  },
});
