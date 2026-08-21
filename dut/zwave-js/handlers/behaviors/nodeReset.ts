import { registerHandler } from "../../prompt-handlers.ts";

registerHandler(/.*/, {
  onPrompt: async (ctx) => {

    // Let other prompts fall through to manual handling
    return undefined;
  },
});
