import { ConfigurationCCValues } from "zwave-js";
import { ConfigValueFormat } from "@zwave-js/core";
import { registerHandler } from "../../prompt-handlers.ts";

const LAST_VERIFY_QUESTION = "lastVerifyQuestion";

registerHandler("CCR_ConfigurationCC_Rev02", {
  async onLog(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    ctx.state.set(LAST_VERIFY_QUESTION, false);

    const explicitSizeMatch =
      /set the parameter.+number (?<param>\d+) and Size = (?<size>\d+) to value (?<value>-?\d+)/i.exec(
        ctx.logText
      );
    if (explicitSizeMatch?.groups) {
      const param = parseInt(explicitSizeMatch.groups.param!);
      const size = parseInt(explicitSizeMatch.groups.size!) as 1 | 2 | 4;
      const value = parseInt(explicitSizeMatch.groups.value!);
      await node.commandClasses.Configuration.set({
        parameter: param,
        value,
        valueSize: size,
        valueFormat: ConfigValueFormat.SignedInteger,
      });
      return true;
    }

    const autoSizeMatch =
      /set the parameter.+number (?<param>\d+).+to value (?<value>-?\d+)/i.exec(
        ctx.logText
      );
    if (autoSizeMatch?.groups) {
      const param = parseInt(autoSizeMatch.groups.param!);
      const value = parseInt(autoSizeMatch.groups.value!);
      await node.setValue(
        ConfigurationCCValues.paramInformation(param).id,
        value
      );
      return true;
    }

    // Single parameter reset
    const resetMatch =
      /trigger 'Configuration Parameter Reset'.+parameter number = (?<param>\d+)/i.exec(
        ctx.logText
      );
    if (resetMatch?.groups) {
      const param = parseInt(resetMatch.groups.param!);
      await node.commandClasses.Configuration.reset(param);
      return true;
    }

    // All parameter reset
    if (/trigger 'All Configuration Parameter Reset'/i.test(ctx.logText)) {
      await node.commandClasses.Configuration.resetAll();
      return true;
    }

    // Verify UI question - store in state
    if (
      /Verify that the DUT offers a UI.+see the parameter numbers/i.test(
        ctx.logText
      )
    ) {
      ctx.state.set(LAST_VERIFY_QUESTION, true);
      return true;
    }
  },

  async onPrompt(ctx) {
    const node = ctx.includedNodes.at(-1);
    if (!node) return;

    // Parameter numbers requirement
    if (
      /does the DUT meet the requirement for parameter numbers/i.test(
        ctx.promptText
      )
    ) {
      return "Yes";
    }

    // Check if writable
    const writableMatch =
      /try to set the parameter.+number (?<param>\d+).+Is it possible to set the parameter value/i.exec(
        ctx.promptText
      );
    if (writableMatch?.groups) {
      const param = parseInt(writableMatch.groups.param!);
      const writeable = node.getValueMetadata(
        ConfigurationCCValues.paramInformation(param).id
      ).writeable;
      return writeable ? "Yes" : "No";
    }

    // UI verification follow-up
    if (
      /does the DUT meet the requirement described above/i.test(ctx.promptText)
    ) {
      if (ctx.state.get(LAST_VERIFY_QUESTION)) {
        ctx.state.delete(LAST_VERIFY_QUESTION);
        return "Yes";
      }
    }
  },
});
