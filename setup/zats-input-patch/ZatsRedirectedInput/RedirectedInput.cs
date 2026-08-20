using System;
using System.Collections.Generic;
using System.Threading;

namespace ZatsRedirectedInput;

public static class RedirectedInput
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
        if (!Console.IsInputRedirected) return;
        lock (SyncRoot)
        {
            skipEnabled = true;
        }
    }

    public static void DisableSkip()
    {
        if (!Console.IsInputRedirected) return;
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

    public static int Read()
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