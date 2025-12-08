import { registerHandler } from "../../prompt-handlers.ts";

const questions: { pattern: RegExp; answer: string }[] = [
  {
    pattern: /allows the end user to establish association/i,
    answer: "No",
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
