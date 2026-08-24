/**
 * Tracking for commands sent after a prompt is answered
 *
 * CTT arms its frame expectations only once the message box closes, so a
 * command triggered by a prompt has to be transmitted after the response.
 * `WAIT_FOR_COMMAND_IDLE` needs those sends to be awaitable, so every delayed
 * command registers here.
 */

import { wait } from "alcalzone-shared/async";

const OUTSTANDING_DELAYED_COMMANDS = "outstanding delayed commands";

/** Runs `command` after `delayMs` and registers it so `waitForDelayedCommands` can await it */
export function scheduleDelayedCommand(
  state: Map<string, unknown>,
  delayMs: number,
  command: () => Promise<void>
): void {
  let outstanding = state.get(OUTSTANDING_DELAYED_COMMANDS) as
    | Set<Promise<void>>
    | undefined;
  if (!outstanding) {
    outstanding = new Set();
    state.set(OUTSTANDING_DELAYED_COMMANDS, outstanding);
  }

  const completion = wait(delayMs).then(command);
  outstanding.add(completion);
  void completion.catch((error) => {
    console.error("Delayed command failed:", error);
  });
  void completion.then(
    () => outstanding.delete(completion),
    () => outstanding.delete(completion)
  );
}

export async function waitForDelayedCommands(
  state: Map<string, unknown>
): Promise<void> {
  const outstanding = state.get(OUTSTANDING_DELAYED_COMMANDS) as
    | Set<Promise<void>>
    | undefined;
  if (!outstanding?.size) return;
  // A failed command is already logged, and the wait only has to see it finish
  await Promise.allSettled(outstanding);
}
