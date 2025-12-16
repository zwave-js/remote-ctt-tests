/**
 * CTT Output Parser
 *
 * Handles parsing of CTT-specific output formats including:
 * - Color codes: {color:darkgray}text{color}
 * - User prompts: »YES-NO:SHOW«
 */

import c from "ansi-colors";

// Type for ansi-colors style functions
type StyleFunction = (text: string) => string;

// Map CTT color names to ansi-colors functions
const CTT_COLOR_MAP: Record<string, StyleFunction> = {
  // Standard colors
  black: c.black,
  red: c.red,
  green: c.green,
  yellow: c.yellow,
  blue: c.blue,
  magenta: c.magenta,
  cyan: c.cyan,
  white: c.white,
  gray: c.gray,
  grey: c.grey,

  // Dark variants (use dim versions)
  darkred: c.red,
  darkgreen: c.green,
  darkyellow: c.yellow,
  darkblue: c.blue,
  darkmagenta: c.magenta,
  darkcyan: c.cyan,
  darkgray: c.gray,
  darkgrey: c.grey,

  // Bright variants
  brightred: c.redBright,
  brightgreen: c.greenBright,
  brightyellow: c.yellowBright,
  brightblue: c.blueBright,
  brightmagenta: c.magentaBright,
  brightcyan: c.cyanBright,
  brightwhite: c.whiteBright,

  // Additional common colors
  orange: c.yellow, // Use yellow as fallback
  purple: c.magenta, // Use magenta as fallback
  pink: c.magentaBright,
};

/**
 * Convert CTT color format to ANSI escape codes using ansi-colors
 *
 * Input: "{color:darkgray}13:30:34.680 {color}{color:darkyellow}---{color}"
 * Output: properly colored string with ANSI codes
 */
export function convertCttColorsToAnsi(text: string): string {
  // Split text into segments based on color tags
  const segments: Array<{ text: string; color?: string }> = [];
  let currentColor: string | undefined;
  let lastIndex = 0;

  const colorPattern = /\{color(?::([^}]+))?\}/gi;
  let match: RegExpExecArray | null;

  while ((match = colorPattern.exec(text)) !== null) {
    // Add text before this tag
    if (match.index > lastIndex) {
      segments.push({
        text: text.slice(lastIndex, match.index),
        color: currentColor,
      });
    }

    // Update current color
    const colorName = match[1];
    currentColor = colorName ? colorName.toLowerCase().trim() : undefined;
    lastIndex = match.index + match[0].length;
  }

  // Add remaining text
  if (lastIndex < text.length) {
    segments.push({
      text: text.slice(lastIndex),
      color: currentColor,
    });
  }

  // Build output with colors
  return segments
    .map((segment) => {
      if (!segment.color) {
        return segment.text;
      }

      const colorFn = CTT_COLOR_MAP[segment.color];
      if (colorFn) {
        return colorFn(segment.text);
      }

      // Unknown color - return text without color
      return segment.text;
    })
    .join("");
}

/**
 * Strip all CTT color codes from text (for plain output)
 */
export function stripCttColors(text: string): string {
  return text.replace(/\{color(?::[^}]+)?\}/gi, "");
}

/**
 * Prompt types that CTT can send
 */
export type PromptType = "YES_NO" | "BUTTON_LIST" | "UNKNOWN";

export interface CttPrompt {
  type: PromptType;
  rawText: string;
  buttons: string[];
}

/**
 * Parse CTT prompt format
 *
 * Examples:
 * - "»YES-NO:SHOW«" -> { type: "YES_NO", buttons: ["YES", "NO"] }
 * - "»BUTTON1-BUTTON2-BUTTON3:SHOW«" -> { type: "BUTTON_LIST", buttons: ["BUTTON1", "BUTTON2", "BUTTON3"] }
 */
export function parseCttPrompt(text: string): CttPrompt | null {
  // Pattern: »BUTTON1-BUTTON2:ACTION«
  const promptPattern = /»([^:]+):([^«]+)«/;
  const match = text.match(promptPattern);

  if (!match) {
    return null;
  }

  const buttonsPart = match[1];
  const buttons = buttonsPart.split("-").map((b) => b.trim());

  // Determine prompt type
  let type: PromptType = "UNKNOWN";
  if (
    buttons.length === 2 &&
    buttons[0].toUpperCase() === "YES" &&
    buttons[1].toUpperCase() === "NO"
  ) {
    type = "YES_NO";
  } else if (buttons.length >= 2) {
    type = "BUTTON_LIST";
  }

  return {
    type,
    rawText: match[0],
    buttons,
  };
}

/**
 * Check if a line contains a CTT prompt
 */
export function containsPrompt(text: string): boolean {
  return /»[^«]+«/.test(text);
}

/**
 * Format a prompt for CLI display
 */
export function formatPromptForCli(prompt: CttPrompt): string {
  if (prompt.type === "YES_NO") {
    return "Enter Y (Yes) or N (No): ";
  }

  // For button lists, show numbered options
  const options = prompt.buttons
    .map((btn, i) => `${i + 1}) ${btn}`)
    .join("  ");
  return `Choose an option [${options}]: `;
}

/**
 * Convert user input to CTT response.
 * Valid TestCaseConfirmation values per CTT-Remote documentation:
 * Ok, Cancel, Yes, No, Open, Skip
 */
export function parseUserResponse(
  input: string,
  prompt: CttPrompt
): string | null {
  const trimmed = input.trim().toUpperCase();

  if (prompt.type === "YES_NO") {
    if (trimmed === "Y" || trimmed === "YES") {
      return "Yes"; // CTT expects "Yes" not "YES"
    }
    if (trimmed === "N" || trimmed === "NO") {
      return "No"; // CTT expects "No" not "NO"
    }
    return null; // Invalid input
  }

  // For button lists, accept number or button name
  const num = parseInt(trimmed, 10);
  if (!isNaN(num) && num >= 1 && num <= prompt.buttons.length) {
    return prompt.buttons[num - 1];
  }

  // Check if input matches a button name
  const matchingButton = prompt.buttons.find(
    (btn) => btn.toUpperCase() === trimmed
  );
  if (matchingButton) {
    return matchingButton;
  }

  return null; // Invalid input
}
