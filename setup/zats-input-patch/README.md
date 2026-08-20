# ZATS redirected input patch

Share [`PROPOSED_VENDOR_FIX.md`](PROPOSED_VENDOR_FIX.md) with the CTT/ZATS developer. It contains the
source-level implementation and regression test without the binary patching machinery.

CTT 4.0.3 starts one cancellable `Console.In.ReadAsync` call for every Skip prompt. On Linux the
cancelled pipe read can remain pending and consume a later confirmation.

`ZatsRedirectedInput.dll` owns one permanent redirected stdin reader. The patch utility changes
`MessageBoxImpl` so Skip tasks wait on a cancellable queue and confirmation prompts use a separate
queue. Interactive console input keeps the original implementation.

Apply the patch to an extracted CTT 4.0.3 archive with:

```sh
dotnet run --project setup/zats-input-patch/PatchZatsServices/PatchZatsServices.csproj -- \
  ctt/bin/Zats/ZatsTestConsole/ZatsServices.dll \
  ctt/bin/Zats/ZatsTests/ZatsServices.dll
```

The utility installs the helper assembly and updates `ZatsTestConsole.deps.json`. It accepts only the
known original or patched CTT 4.0.3 hashes. An unknown hash stops the operation so a later CTT release
is never modified without review.