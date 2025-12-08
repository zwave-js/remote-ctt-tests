/**
 * Handler Index
 *
 * Import all handler files here to register them.
 * Side-effect imports cause the handlers to self-register.
 */

// Test-specific handlers
import "./tests/CDR_ZWPv2IndicatorCCRequirements_Rev01.ts";
import "./tests/RT_PowerSupply_Rev02.ts";
import "./tests/CCR_BarrierOperatorCC_Rev03.ts";
import "./tests/CCR_BasicCC_Rev02.ts";

// Behavior handlers
import "./behaviors/capabilities.ts";
import "./behaviors/addMode.ts";
import "./behaviors/removeMode.ts";
import "./behaviors/interviewFinished.ts";
import "./behaviors/triggerReInterview.ts";
import "./behaviors/sendSimpleCommand.ts";
import "./behaviors/simplePrompts.ts";
