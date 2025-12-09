import { registerHandler, type PromptResponse } from "../../prompt-handlers.ts";

const questions: { pattern: RegExp; answer: PromptResponse }[] = [
  {
    pattern: /allows the end user to establish association/i,
    answer: "No",
  },
  {
    pattern: /capable to display the last known state/i,
    answer: "Yes",
  },
  {
    pattern: /(current state|visualization|visualisation).+is visible/i,
    answer: "Ok",
  },
  {
    pattern: /icon type.+match the actual device/i,
    answer: "Yes",
  },
  {
    pattern: /Does the DUT use the identify command for any other purpose/i,
    answer: "No",
  },
  {
    pattern: /able to send a Start\/Stop Level Change/i,
    answer: "Yes",
  },
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
