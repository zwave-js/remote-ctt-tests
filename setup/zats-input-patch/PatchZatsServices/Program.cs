using System.Security.Cryptography;
using System.Text.Json.Nodes;
using Mono.Cecil;
using Mono.Cecil.Cil;
using ZatsRedirectedInput;

const string TestConsoleHash = "47b501744ec0b48e5ad8842de6e107f31af8102122e4322209c02e62f75c2dc2";
const string ZatsTestsHash = "84d3816909d3a904d0ab38a4eeee77cf3aa5d06ee8e20cacfdffe7daae59b567";
const string PatchedTestConsoleHash = "f6e45bfc02f56de8301af258235fcb90724a78ab8a7ad883160bba0d1b5c1e36";
const string PatchedZatsTestsHash = "baa6effb5d05dd32bc2bfd95d9b5225f9b436b6bbb31e531653c3734953b4ae2";

if (args.Length == 0)
{
    Console.Error.WriteLine("Usage: PatchZatsServices <ZatsServices.dll> [...]");
    return 2;
}

foreach (var assemblyPath in args)
{
    var originalHash = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(assemblyPath))).ToLowerInvariant();
    if (originalHash == PatchedTestConsoleHash || originalHash == PatchedZatsTestsHash)
    {
        InstallHelper(assemblyPath);
        Console.WriteLine($"Already patched {assemblyPath}");
        continue;
    }
    if (originalHash != TestConsoleHash && originalHash != ZatsTestsHash)
    {
        Console.Error.WriteLine($"Refusing to patch unknown ZatsServices.dll: {originalHash}");
        return 1;
    }

    using var assembly = AssemblyDefinition.ReadAssembly(assemblyPath, new ReaderParameters
    {
        InMemory = true,
        ReadWrite = false
    });
    var module = assembly.MainModule;
    var messageBox = module.GetType("Zats.Services.MessageBoxImpl")
        ?? throw new InvalidOperationException("Zats.Services.MessageBoxImpl was not found");

    var enableSkip = module.ImportReference(
        typeof(RedirectedInput).GetMethod(nameof(RedirectedInput.EnableSkip))!
    );
    var disableSkip = module.ImportReference(
        typeof(RedirectedInput).GetMethod(nameof(RedirectedInput.DisableSkip))!
    );
    var waitForSkip = module.ImportReference(
        typeof(RedirectedInput).GetMethod(nameof(RedirectedInput.WaitForSkip))!
    );
    var read = module.ImportReference(
        typeof(RedirectedInput).GetMethod(nameof(RedirectedInput.Read))!
    );

    var showSkip = FindMethod(messageBox, "ShowSkip", 1);
    var showSkipIl = showSkip.Body.GetILProcessor();
    var disableSkipCall = showSkip.Body.Instructions.First(instruction =>
        instruction.OpCode == OpCodes.Call &&
        instruction.Operand is MethodReference method &&
        method.Name == "DisableSkip"
    );
    showSkipIl.InsertAfter(disableSkipCall, showSkipIl.Create(OpCodes.Call, enableSkip));

    var disableSkipMethod = FindMethod(messageBox, "DisableSkip", 0);
    disableSkipMethod.Body.GetILProcessor().InsertBefore(
        disableSkipMethod.Body.Instructions[0],
        Instruction.Create(OpCodes.Call, disableSkip)
    );

    var redirectedSkip = FindMethod(messageBox, "TryReadRedirectedSkipInput", 2);
    redirectedSkip.Body.ExceptionHandlers.Clear();
    redirectedSkip.Body.Variables.Clear();
    redirectedSkip.Body.Instructions.Clear();
    var redirectedSkipIl = redirectedSkip.Body.GetILProcessor();
    redirectedSkipIl.Append(redirectedSkipIl.Create(OpCodes.Ldarg_0));
    redirectedSkipIl.Append(redirectedSkipIl.Create(OpCodes.Ldarg_1));
    redirectedSkipIl.Append(redirectedSkipIl.Create(OpCodes.Call, waitForSkip));
    redirectedSkipIl.Append(redirectedSkipIl.Create(OpCodes.Ret));

    var readKey = FindMethod(messageBox, "ReadKey", 2);
    var consoleRead = readKey.Body.Instructions.First(instruction =>
        instruction.OpCode == OpCodes.Callvirt &&
        instruction.Operand is MethodReference method &&
        method.DeclaringType.FullName == "System.IO.TextReader" &&
        method.Name == "Read"
    );
    var consoleIn = consoleRead.Previous;
    if (consoleIn?.Operand is not MethodReference consoleInMethod ||
        consoleInMethod.DeclaringType.FullName != "System.Console" ||
        consoleInMethod.Name != "get_In")
    {
        throw new InvalidOperationException("Expected Console.In before TextReader.Read");
    }
    consoleIn.OpCode = OpCodes.Nop;
    consoleIn.Operand = null;
    consoleRead.OpCode = OpCodes.Call;
    consoleRead.Operand = read;

    var temporaryPath = assemblyPath + ".patched";
    assembly.Write(temporaryPath);
    File.Move(temporaryPath, assemblyPath, true);
    InstallHelper(assemblyPath);
    Console.WriteLine($"Patched {assemblyPath}");
}

return 0;

static MethodDefinition FindMethod(TypeDefinition type, string name, int parameterCount)
{
    return type.Methods.Single(method =>
        method.Name == name && method.Parameters.Count == parameterCount
    );
}

static void InstallHelper(string assemblyPath)
{
    var assemblyDirectory = Path.GetDirectoryName(Path.GetFullPath(assemblyPath))!;
    var helperPath = Path.Combine(assemblyDirectory, "ZatsRedirectedInput.dll");
    File.Copy(typeof(RedirectedInput).Assembly.Location, helperPath, true);

    var depsPath = Path.Combine(assemblyDirectory, "ZatsTestConsole.deps.json");
    if (!File.Exists(depsPath)) return;

    var root = JsonNode.Parse(File.ReadAllText(depsPath))!.AsObject();
    var runtimeTarget = root["runtimeTarget"]!["name"]!.GetValue<string>();
    var target = root["targets"]![runtimeTarget]!.AsObject();
    target["ZatsServices/1.0.0"]!["dependencies"]!["ZatsRedirectedInput"] = "1.0.0";
    target["ZatsRedirectedInput/1.0.0"] = new JsonObject
    {
        ["runtime"] = new JsonObject
        {
            ["ZatsRedirectedInput.dll"] = new JsonObject
            {
                ["fileVersion"] = "1.0.0.0"
            }
        }
    };
    root["libraries"]!["ZatsRedirectedInput/1.0.0"] = new JsonObject
    {
        ["type"] = "project",
        ["serviceable"] = false,
        ["sha512"] = ""
    };
    File.WriteAllText(depsPath, root.ToJsonString(new() { WriteIndented = true }) + Environment.NewLine);
}