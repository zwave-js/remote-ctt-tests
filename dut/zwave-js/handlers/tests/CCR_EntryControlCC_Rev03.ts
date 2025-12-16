import { registerHandler } from "../../prompt-handlers.ts";

registerHandler("CCR_EntryControlCC_Rev03", {
  async onLog(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Handle: * ENTRY_CONTROL_CONFIGURATION_SET with KeyCacheSize = 16 and KeyCacheTimeout = 5
    const match =
      /ENTRY_CONTROL_CONFIGURATION_SET.+KeyCacheSize\s*=\s*(?<size>\d+).+KeyCacheTimeout\s*=\s*(?<timeout>\d+)/i.exec(
        ctx.logText
      );

    if (match?.groups) {
      const keyCacheSize = parseInt(match.groups.size!, 10);
      const keyCacheTimeout = parseInt(match.groups.timeout!, 10);

      await node.commandClasses["Entry Control"].setConfiguration(
        keyCacheSize,
        keyCacheTimeout
      );
      return true;
    }
  },
});
