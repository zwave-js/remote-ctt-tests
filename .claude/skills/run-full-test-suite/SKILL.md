---
name: run-full-test-suite
description: Runs the full Z-Wave CTT certification suite against the DUT one test at a time, restoring network state between tests, triaging every failure between zwave-js/harness/CTT/wrong-assertion, and reporting a --discover-like pass/skip/fail summary. Use when asked to run the whole test suite, see how far we get in certification testing, work through failing tests, or produce a pass/fail/skip report for the CTT suite.
---

# Run the Full CTT Test Suite

## Overview

Discover every CTT test case, run each one against the zwave-js DUT, and for
every failure decide whether the bug is in zwave-js, the harness, CTT itself,
or the test case's own assertion. Fix what's fixable, document what isn't, and
end with a summary in the same shape as `--discover`: every test with a
pass/skip/fail verdict and, for failures, why.

## When to use

Trigger on requests like "run the full test suite", "see how far we get in
CTT", "go through all the certification tests", "figure out why test X fails
and fix it", or "give me a pass/fail report for the CTT suite".

## Serial execution — never parallelize test runs

Only one test can run at a time: the emulated Z-Wave stack binaries, the CTT
process, and the DUT all hold exclusive ports (5000-5004, 4711-4713, 4905) and
share one on-disk network state. Run tests one after another with
`npm run start -- --test=<name>`, never with concurrent `npm run start`
invocations, and never split test execution across parallel subagents. This
constraint applies only to test execution — research and investigation can and
should run in parallel subagents (see below).

## Step-by-step workflow

1. **Discover tests.** Run `npm run start -- --discover` to list every test
   case with its category and group. Keep this list as the master checklist.
2. **Restore network state before each test.** Run
   [`setup/unpack-network-state-archive.ts`](../../../setup/unpack-network-state-archive.ts)
   to reset the emulated devices' and DUT's storage to the known-good network
   before every single test run, not just once at the start. This avoids
   failures caused by state corruption or drift left over from a previous
   test.
3. **Run the test.** `npm run start -- --test=<name> --verbose`. Record
   pass/fail and, for CTT, note the log folder it just created under
   [`ctt/project/Log/<timestamp>/`](../../../ctt/project/Log).
4. **On failure, triage before touching anything** (see Failure triage below).
5. **After a harness fix, rerun the same test** to confirm the fix, then
   continue down the checklist.
6. **Retain CTT logs for any test that exposed a zwave-js, CTT, or
   wrong-assertion bug.** These are the logs needed for later bug reports —
   don't delete them, and note the log folder path next to the documented
   bug.
7. **Repeat until every discovered test has a verdict**, then produce the
   final summary (see Final summary format below).

## Classification rules (by CTT group)

- **Automatic** — should pass as-is. A failure here is a real bug (zwave-js,
  harness, CTT, or the test itself), not a missing prompt handler. Triage it.
- **Interactive** and **Inclusion** — need the harness to answer CTT prompts
  correctly. A failure often means a prompt or log pattern isn't handled yet,
  not that the underlying functionality is wrong. Check
  [`dut/zwave-js/prompt-handlers.ts`](../../../dut/zwave-js/prompt-handlers.ts)
  and the test-specific handler in
  [`dut/zwave-js/handlers/tests/`](../../../dut/zwave-js/handlers/tests) (see
  the `implement-test-handler` skill for writing new handlers), fix or add the
  handler, then rerun. Some of these tests check what a UI would show the
  user; headless zwave-js can't confirm that, so instead verify that
  zwave-js emits the events the UI would need (check the driver logs /
  event stream) and treat that as the pass condition.
- **Manual** — out of scope for now. Skip these and record them as skipped
  with reason "manual test, outside automation scope", don't investigate.
- **Script** — try them the same way as Automatic/Interactive. A failure here
  is lower priority: note it and move on instead of deep-diving, since these
  aren't required to pass.

## Failure triage: zwave-js vs harness vs CTT vs wrong test

Work through these in order for every Automatic/Interactive/Inclusion/Script
failure:

1. **Is it a zwave-js bug?** Compare the DUT's actual command-class behavior
   against the spec in
   [`/home/dominic/repositories/AWG/source`](/home/dominic/repositories/AWG/source)
   (the raw Z-Wave specification text). If zwave-js does something the spec
   forbids or omits something the spec requires, that's a zwave-js bug.
   Document it briefly (what it does, what the spec says instead) so it can be
   fixed later. Do not attempt to fix zwave-js itself as part of this run.
2. **Is it a harness bug?** If the DUT behaved correctly but the harness
   answered a CTT prompt wrong, mis-parsed a log line, or didn't restore state
   correctly, fix the harness code (prompt handler, parser, or setup script)
   and rerun the test to confirm.
3. **Is it a CTT bug?** If CTT itself misbehaves (hangs, throws, reads its own
   settings wrong, races on Linux), investigate and, if possible, work around
   it. Document the bug and the workaround in
   [`docs/testing-results.md`](../../../docs/testing-results.md), following
   the existing entries as a template. Keep the CTT log folder from the
   failing run since it's needed for reporting the bug upstream.
4. **Is the test case itself wrong?** If the test's own assertion or expected
   value doesn't match the specification, verify against
   `/home/dominic/repositories/AWG/source` and, if that's inconclusive,
   decompile the test's DLL from
   [`ctt/bin/Zats/ZatsTests/<TestName>.dll`](../../../ctt/bin/Zats/ZatsTests)
   (e.g. with `ilspycmd`) to read what it actually checks. If the test is
   confirmed wrong, document it and keep the CTT log folder, same as for a CTT
   bug.

## Delegate research, keep execution serial

Use subagents to keep the main context clean, but only for research and
investigation, never for running tests:

- Delegate reading the AWG spec text, decompiling a test DLL, and comparing
  behavior against the spec to a subagent (e.g. an `explore` or
  `general-purpose` agent) — hand it the test name, the relevant log excerpt,
  and the CC/feature involved, and have it report back a verdict plus
  citations.
- Delegate writing up a documented bug entry (zwave-js bug note, or a
  `docs/testing-results.md` addition) to a subagent once the root cause is
  known.
- Do not delegate the actual `npm run start -- --test=...` invocation, the
  network-state restore, or rerunning a test after a harness fix — do those
  yourself, sequentially, since they share the same live devices/CTT/DUT
  processes and can't run concurrently.

## Final summary format (--discover-like)

Mirror the `--discover` layout: group by category, then list every test with
its verdict. For example:

```
[Binary Switch] (4 tests)
  CC_Binary_Switch_Set        EP0  Classic  Automatic   PASS
  CC_Binary_Switch_Get        EP0  Classic  Automatic   PASS
  CCR_DoorLockCC_Rev02        EP0  Classic  Interactive PASS (handler added)
  RT_CSCAssignsReturnRoute_Rev01 EP0 Classic Automatic  FAIL - zwave-js bug: <one line>

[Manual-only category] (2 tests)
  MD_SomeManualCheck_Rev01    EP0  Classic  Manual      SKIP - manual test, outside automation scope
```

Every test must land in exactly one bucket:

- **PASS** — ran and succeeded.
- **SKIP** — Manual tests (always), plus anything not reached this run; state
  why.
- **FAIL** — include the one-line reason and which triage bucket it fell into
  (zwave-js bug / harness bug, now fixed / CTT bug, workaround documented /
  wrong test, documented). Point to the retained CTT log folder for any
  zwave-js/CTT/wrong-test finding.

## Reference files

- [`setup/unpack-network-state-archive.ts`](../../../setup/unpack-network-state-archive.ts) — restores emulated-device and DUT storage to the known-good network state.
- [`src/start.ts`](../../../src/start.ts) — orchestrator; `--discover`, `--test=`, `--category=`, `--group=` flags.
- [`dut/zwave-js/prompt-handlers.ts`](../../../dut/zwave-js/prompt-handlers.ts) and [`dut/zwave-js/handlers/`](../../../dut/zwave-js/handlers) — CTT prompt/log handlers (see the `implement-test-handler` skill).
- [`docs/testing-results.md`](../../../docs/testing-results.md) — existing log of CTT/harness bugs and workarounds; add new findings here.
- [`ctt/project/Log/`](../../../ctt/project/Log) — per-run CTT logs, timestamped; retain the folder for any run that exposed a zwave-js/CTT/wrong-test bug.
- [`ctt/bin/Zats/ZatsTests/`](../../../ctt/bin/Zats/ZatsTests) — compiled test-case DLLs, decompile when a test's own assertion is in question.
- `/home/dominic/repositories/AWG/source` — raw Z-Wave specification text (reStructuredText) to verify expected behavior against.
