# Proposed ZATS source fix

This is the source-level change to share with the CTT/ZATS developer. It does not depend on
Mono.Cecil or modified binaries.

## Cause

Each redirected Skip prompt starts `Console.In.ReadAsync(..., cancellationToken)`. Cancelling the
token can complete the task on Linux while the underlying pipe read remains pending. That reader can
then consume input intended for a later confirmation prompt.

## Shared redirected-input reader

Add this class to ZATS:

```csharp
using System;
using System.Collections.Generic;
using System.Threading;

namespace Zats.Services;

internal static class RedirectedInput
{
    private static readonly object SyncRoot = new object();
    private static readonly Queue<char> ConfirmationInput = new Queue<char>();
    private static readonly Queue<char> SkipInput = new Queue<char>();
    private static readonly AutoResetEvent ConfirmationAvailable = new AutoResetEvent(false);
    private static readonly AutoResetEvent SkipAvailable = new AutoResetEvent(false);
    private static bool skipEnabled;

    static RedirectedInput()
    {
        var reader = new Thread(ReadInput)
        {
            IsBackground = true,
            Name = "ZATS redirected input"
        };
        reader.Start();
    }

    public static void EnableSkip()
    {
        lock (SyncRoot)
        {
            skipEnabled = true;
        }
    }

    public static void DisableSkip()
    {
        lock (SyncRoot)
        {
            skipEnabled = false;
            SkipInput.Clear();
        }
    }

    public static bool WaitForSkip(CancellationToken cancellationToken, out char input)
    {
        while (true)
        {
            lock (SyncRoot)
            {
                if (SkipInput.Count > 0)
                {
                    input = SkipInput.Dequeue();
                    return true;
                }
            }

            var signaled = WaitHandle.WaitAny(
                new[] { SkipAvailable, cancellationToken.WaitHandle }
            );
            if (signaled == 1)
            {
                throw new OperationCanceledException(cancellationToken);
            }
        }
    }

    public static int ReadConfirmation()
    {
        while (true)
        {
            lock (SyncRoot)
            {
                if (ConfirmationInput.Count > 0)
                {
                    return ConfirmationInput.Dequeue();
                }
            }
            ConfirmationAvailable.WaitOne();
        }
    }

    private static void ReadInput()
    {
        while (true)
        {
            var value = Console.In.Read();
            if (value < 0) return;

            var input = (char)value;
            lock (SyncRoot)
            {
                if (skipEnabled && (input == 's' || input == 'S'))
                {
                    SkipInput.Enqueue(input);
                    SkipAvailable.Set();
                }
                else
                {
                    ConfirmationInput.Enqueue(input);
                    ConfirmationAvailable.Set();
                }
            }
        }
    }
}
```

The permanent reader is the only code that reads redirected `Console.In`. Cancelling a Skip prompt
only cancels its queue wait.

## MessageBoxImpl changes

Enable Skip routing when showing a redirected Skip prompt:

```csharp
public void ShowSkip(Action skipCallback)
{
    DisableSkip();
    if (Console.IsInputRedirected)
    {
        RedirectedInput.EnableSkip();
    }

    // Keep the existing interactive-input cleanup, callback, logging,
    // CancellationTokenSource, and Skip task setup here.
}
```

Replace the redirected Skip read:

```csharp
private static bool TryReadRedirectedSkipInput(CancellationToken cancellationToken, out char input)
{
    return RedirectedInput.WaitForSkip(cancellationToken, out input);
}
```

Disable Skip routing before cancelling the Skip task:

```csharp
public void DisableSkip()
{
    if (Console.IsInputRedirected)
    {
        RedirectedInput.DisableSkip();
    }

    // Keep the existing CancellationTokenSource cancellation, task wait,
    // disposal, and field cleanup here.
}
```

Use the shared reader for redirected confirmation prompts:

```csharp
private void ReadKey(out ConsoleKey keyValue, out ConsoleKeyInfo key)
{
    if (Console.IsInputRedirected)
    {
        keyValue = (ConsoleKey)(ushort)RedirectedInput.ReadConfirmation();
        key = new ConsoleKeyInfo(
            (char)(ushort)keyValue,
            keyValue,
            shift: false,
            alt: false,
            control: false
        );
        return;
    }

    // Keep the existing interactive Console.ReadKey implementation here.
}
```

## Regression test

Run `CCR_BarrierOperatorCC_Rev03`. It creates consecutive self-closing Skip prompts followed by
Yes/No prompts. The fixed implementation must meet these checks:

1. Each satisfied Skip prompt logs `SKIP:DISABLE` within milliseconds.
2. The following Yes/No prompt accepts its first input character.
3. The test completes without a 30-second client timeout.

The implementation above passed this test with CTT 4.0.3 on Linux.