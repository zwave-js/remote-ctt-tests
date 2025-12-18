import {
  registerHandler,
  type PromptContext,
  type PromptResponse,
} from "../../prompt-handlers.ts";

// State key for storing warning context
const DISREGARD_RECOMMENDATION_CONTEXT = "disregardRecommendationContext";

// Enum for different recommendation reasons - extend as needed
enum Recommendation {
  IndicatorReportInAGI = "IndicatorReportInAGI",
}

// Context stored in state
type DisregardRecommendationContext = {
  recommendation: Recommendation;
};

// Rules for how to respond based on reason - static response or function
type RuleResponse = PromptResponse | ((ctx: PromptContext) => PromptResponse);

const rules: Record<Recommendation, RuleResponse> = {
  [Recommendation.IndicatorReportInAGI]: "Yes",
};

registerHandler(/.*/, {
  onLog: async (ctx) => {
    let recContext: DisregardRecommendationContext | undefined;
    // Detect INDICATOR_REPORT not advertised in AGI Command List Report
    if (
      /INDICATOR_REPORT.+RECOMMENDED.+does not advertise.+AGI Command List Report/is.test(
        ctx.logText
      )
    ) {
      recContext = {
        recommendation: Recommendation.IndicatorReportInAGI,
      };
    }

    if (recContext) {
      ctx.state.set(DISREGARD_RECOMMENDATION_CONTEXT, recContext);
    }

    return undefined;
  },

  onPrompt: async (ctx) => {
    if (
      !/Is it intended to disregard the recommendation\?/i.test(ctx.promptText)
    ) {
      return undefined;
    }

    const context = ctx.state.get(DISREGARD_RECOMMENDATION_CONTEXT) as
      | DisregardRecommendationContext
      | undefined;
    if (!context) return undefined;

    ctx.state.delete(DISREGARD_RECOMMENDATION_CONTEXT);

    const rule = rules[context.recommendation];
    return typeof rule === "function" ? rule(ctx) : rule;
  },
});
