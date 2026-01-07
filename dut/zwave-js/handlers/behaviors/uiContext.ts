import { registerHandler } from "../../prompt-handlers.ts";
import type { OpenUIMessage } from "../../../../src/ctt-message-types.ts";

export const UI_CONTEXT = "ui_context";

export interface UIContext {
  commandClass: string;
  nodeId: number;
  endpoint?: number;
}

export function getUIContext(ctx: {
  state: Map<string, unknown>;
}): UIContext | undefined {
  return ctx.state.get(UI_CONTEXT) as UIContext | undefined;
}

/**
 * Set UI context from an OPEN_UI message.
 */
export function setUIContextFromMessage(
  message: OpenUIMessage,
  state: Map<string, unknown>
): void {
  if (message.commandClass && message.nodeId) {
    state.set(UI_CONTEXT, {
      commandClass: message.commandClass,
      nodeId: message.nodeId,
    } satisfies UIContext);
  }
}

// Handler for OPEN_UI messages - captures context and responds Ok
registerHandler(/.*/, {
  onPrompt: async (ctx) => {
    if (ctx.message?.type === "OPEN_UI") {
      setUIContextFromMessage(ctx.message, ctx.state);
      return "Ok";
    }
    return undefined;
  },
});
