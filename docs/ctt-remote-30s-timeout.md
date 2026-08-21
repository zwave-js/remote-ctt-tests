# CTT Remote mode — 30 s client timeout on already-satisfied "wait for event" boxes

**Symptom.** `ctt-remote.log` fills with `[ERR] Client timeout of 30000 milliseconds has expired,
throwing TimeoutException`. Test runs take much longer than in the GUI, since many steps now take a flat 30s.

**The bug.** Some steps show a `Skip`-type message box reading *"trigger X … waiting for the
following events: `<a Z-Wave …_SET command>`"*. These resolve when CTT **receives the awaited
Z-Wave frame** — there is no button to press, the step is completed by the frame. CTT *does* receive
it within milliseconds and logs `OK <EVENT> received.`, **but it never closes the box.** It waits
the full 30 s for a client response that is never coming, then throws the timeout, before continuing with the next step.

While a box is open, CTT also sends nothing else to the client — all later messages batch up and
arrive only after the box is answered or the 30 s timeout fires. So each unresolved box costs a flat
30 s and delays the next step.

Example log (CTT = `ctt-remote.log`; DUT = Z-Wave JS log):

```
CTT  11:50:00.466  show Skip box: "Please trigger 'Open Barrier Operator' …
                                   waiting for: * BARRIER_OPERATOR_SET target='0xFF'"
DUT  11:50:00.467  sends BarrierOperatorCCSet, target = 255      ← the awaited frame
CTT  11:50:00.470  OK BARRIER_OPERATOR_SET received.             ← step satisfied
CTT  11:50:30.466  [ERR] Client timeout of 30000 milliseconds … ← 30 s later, box still open
```

## How to reproduce

Run a test with a "trigger + wait for event" step — `CCR_BarrierOperatorCC_Rev03` (two such boxes,
fastest) or `CCR_MultilevelSwitchCC_Rev02` (one per level-set step, so 30 s repeatedly):

```json
{"jsonrpc":"2.0","id":1,"method":"runTestCases","params":{"testCaseRequestDTO":{
  "testCaseNames":["CCR_BarrierOperatorCC_Rev03"],
  "groups":[],"results":[],"endPointIds":[],"ZWaveExecutionModes":[]}}}
```

CTT 4.0.3 does not consume the response to its outbound `testCaseMsgBox` request. Acknowledge that
request, then submit the selected button through the CTT JSON-RPC method `testCaseMsgBoxResult`.
`Ok` boxes use `"Ok"` and `YesNo` boxes use `"Yes"` or `"No"`. CTT 4.0.4 changes this contract:
it consumes the direct `testCaseMsgBox` response and removes `testCaseMsgBoxResult`.

The `Skip` "wait for event" boxes have no button to send. The DUT just emits the frame, and that's
where it hangs.

Some tests actually fail when submitting `Skip`, so there is no workaround either.

## A second case: slow client confirmation (inclusion / interview)

If a box needs a client answer but that answer waits on a step longer than 30 s, the timeout aborts a
passing test. In `CSR_LifelineMandatoryReports_Rev03`, inclusion + interview takes ~80 s, so the
"click OK when done" confirmation can't be sent in time:

```
CTT  13:10:54  show Ok box: "Click 'OK' as soon as the Inclusion process has finished on the DUT side!"
CTT  13:11:24  [ERR] Client timeout of 30000 milliseconds …   ← +30 s, interview still running; no verdict
```

The interview succeeds — the test would pass if CTT waited. The "5 min test sequence" budget covers
waiting for *events*, not the box answer.

## CTT 4.0.3: cancelled Skip readers consume later answers

CTT 4.0.3 avoids the 30-second stall by acknowledging `testCaseMsgBox` immediately and accepting
answers through `testCaseMsgBoxResult`. Its ZATS `MessageBoxImpl` introduces another Linux issue.
Each `Skip` box starts `Console.In.ReadAsync(..., cancellationToken)` while stdin is redirected.
`DisableSkip()` cancels that token and waits up to two seconds, but the underlying console read can
remain queued after the task reports cancellation.

Each leaked reader consumes one character intended for a later prompt. This sequence reproduces it:

```text
13:21:52.958  »SKIP:SHOW«
13:21:52.962  awaited event received
13:21:54.964  »SKIP:SHOW«
13:21:54.968  awaited event received
13:21:57.470  »YES-NO:SHOW«
13:21:57.473  »SKIP:DISABLE«       first Y was consumed by a cancelled Skip reader
13:29:48.018  »SKIP:DISABLE«       second Y was consumed by the other Skip reader
13:29:56.028  Yes                  third Y reached the Yes/No reader
```

The RPC call succeeds and ZATS remains alive, but the Yes/No prompt blocks because its reader never
receives the answer. Further RPC calls cannot help after CTT clears the confirmation callback.

The temporary `/proc` workaround proved the cause and has been removed. The packaged CTT 4.0.3
binaries now include `ZatsRedirectedInput.dll`. It owns one permanent redirected stdin reader and
dispatches input to cancellable Skip waits or confirmation prompts. A hash-aware patch utility
rewrites only the affected `ZatsServices.dll` methods and refuses unknown CTT versions.

`CCR_BarrierOperatorCC_Rev03` passed with the patched binaries on 2026-08-20. Six satisfied Skip
readers stopped within milliseconds. Both following Yes/No prompts accepted the first normal RPC
answer.

CTT 4.0.4 restores the previous `CancelIoEx(GetStdHandle(STD_INPUT_HANDLE))` implementation. That
cancels the queued console read on Windows, but it imports `kernel32.dll` and is not Linux-compatible.
A Linux-safe fix needs one stdin reader for all prompt types, or cancellation that waits until the
single redirected read has actually terminated before another prompt starts reading.
