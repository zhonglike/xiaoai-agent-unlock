using Mono.Cecil;
using Mono.Cecil.Cil;

if (args.Length < 2)
{
    Console.WriteLine("usage: Patcher <input.dll> <output.dll> [--wakeup]");
    return 1;
}

string input = args[0];
string output = args[1];
bool patchWakeup = args.Contains("--wakeup");

var asm = AssemblyDefinition.ReadAssembly(input, new ReaderParameters { ReadWrite = false });
var module = asm.MainModule;

int patched = 0;

foreach (var type in AllTypes(module))
{
    foreach (var m in type.Methods)
    {
        if (m.FullName == "System.Void XiaoaiAgent.App::CheckSignatureAndPCType()")
        {
            Console.WriteLine($"[*] found {m.FullName}");
            Nop(m);
            patched++;
        }
        else if (m.FullName == "System.Void XiaoaiAgent.Services.UI.Interface.InfoCheckerService::OnFail()")
        {
            Console.WriteLine($"[*] found {m.FullName}");
            Nop(m);
            patched++;
        }
        else if (patchWakeup && m.FullName == "System.Boolean XiaoaiAgent.Helper.LocalSettingsHelper::get_IsInSupportWhiteList()")
        {
            Console.WriteLine($"[*] found {m.FullName} -> return true");
            ReturnTrue(m);
            patched++;
        }
    }
}

asm.Write(output);
Console.WriteLine($"[+] patched {patched} method(s) -> {output}");
return patched > 0 ? 0 : 2;

static IEnumerable<TypeDefinition> AllTypes(ModuleDefinition module)
{
    var stack = new Stack<TypeDefinition>(module.Types);
    while (stack.Count > 0)
    {
        var t = stack.Pop();
        yield return t;
        foreach (var n in t.NestedTypes) stack.Push(n);
    }
}

static void Nop(MethodDefinition m)
{
    var body = m.Body;
    body.ExceptionHandlers.Clear();
    body.Variables.Clear();
    body.InitLocals = false;
    body.Instructions.Clear();
    var il = body.GetILProcessor();
    il.Append(il.Create(OpCodes.Ret));
}

static void ReturnTrue(MethodDefinition m)
{
    var body = m.Body;
    body.ExceptionHandlers.Clear();
    body.Variables.Clear();
    body.InitLocals = false;
    body.Instructions.Clear();
    var il = body.GetILProcessor();
    il.Append(il.Create(OpCodes.Ldc_I4_1));
    il.Append(il.Create(OpCodes.Ret));
}
