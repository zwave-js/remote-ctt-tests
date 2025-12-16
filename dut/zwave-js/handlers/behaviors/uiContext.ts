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
 * Try to capture UI context from the given prompt text.
 * Call this from handlers that respond to prompts containing UI context info.
 */
export function captureUIContext(
  promptText: string,
  state: Map<string, unknown>
): void {
  // Pattern: "visit the X Command Class visualisation for node Y"
  const match =
    /visit the (?<cc>[\w\s]+) Command Class visuali[sz]ation for node (?<nodeId>\d+)/i.exec(
      promptText
    );

  if (match?.groups) {
    state.set(UI_CONTEXT, {
      commandClass: match.groups.cc.trim(),
      nodeId: parseInt(match.groups.nodeId),
    } satisfies UIContext);
  }
}
