# Testing results

## CTT uses a different settings directory

Remote CTT reads `~/.ctt4/settings.json`, but its warning and documentation specify
`~/.ctt-4/settings.json`. Settings placed there are ignored.

**Workaround:** Put settings in `~/.ctt4/settings.json`.

## ZATS searches the filesystem for Commander

With no Commander path, ZATS recursively searches Linux filesystems for `commander.exe`. An unhandled
permission error at `/sys/kernel/tracing` aborts the test.

**Workaround:** For virtual tests, set `SimplicityCommanderPath` to `/usr/bin/true`.

## CTT and ZATS detect different Commander executables

CTT detects `commander-cli`, while ZATS searches for `commander.exe` and `commander`. CTT also does
not pass ZATS's `-cap` argument.

**Workaround:** Set `SimplicityCommanderPath` explicitly. Virtual tests can use `/usr/bin/true`.

## The `ctt/bin/ZWaveCTT` shebang is not the first line

The vendor-supplied `ctt/bin/ZWaveCTT` shell script has its shebang on line 3. The shell therefore
runs it with `sh`, which fails with `Bad substitution`.

**Workaround:** Move `#!/bin/bash` to line 1.

## Pending Skip readers swallow message box results

CTT 4.0.3's ZATS `MessageBoxImpl` introduces another Linux issue.
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

**Previous workaround:** The harness counted shown `Skip` boxes and wrote repeated answers through
the ZATS stdin pipe. This proved the cause but depended on Linux `/proc` process layout.

**Binary patch:** `ZatsRedirectedInput.dll` provides one permanent stdin reader. The patch utility
rewrites `ZatsServices.dll` so redirected Skip tasks wait on its cancellable queue and confirmation
prompts read from its confirmation queue. Interactive console input remains unchanged. The utility
accepts only the known CTT 4.0.3 assembly hashes, so a later CTT release cannot be patched by mistake.

The patched `CCR_BarrierOperatorCC_Rev03` run passed on 2026-08-20. All six satisfied Skip readers
stopped within milliseconds. Both following Yes/No prompts accepted the first normal
`testCaseMsgBoxResult("Yes")` answer.

The vendor fix should use the same permanent-reader design:

```text
Console.In -> single reader loop -> current prompt handler
```

- The reader loop owns `Console.In` for the process lifetime.
- `ShowSkip` registers a cancellable handler for `S`.
- `DisableSkip` unregisters that handler. It never cancels the underlying read.
- Confirmation prompts replace the active handler and await its result.
- Input received without an active handler is discarded.
- Handler replacement must be synchronized.

`Console.In.ReadAsync(..., cancellationToken)` cannot reliably cancel an underlying redirected pipe read on Linux. Canceling its task and starting another read leaves competing consumers. Waiting longer does not fix that race.

A minimal shape would be:

```csharp
while (true)
{
    var key = await Console.In.ReadAsync(buffer);
    dispatcher.Deliver(buffer[0]);
}
```

Each prompt owns a `TaskCompletionSource<T>`. Closing a prompt removes and cancels that completion source only. This preserves optional `S` input for Skip prompts without ever creating another pending console read.