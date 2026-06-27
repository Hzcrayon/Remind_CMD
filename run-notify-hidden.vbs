Option Explicit

Dim shell, fso, scriptDir, psPath, command, i, arg

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
psPath = fso.BuildPath(scriptDir, "notify.ps1")

command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -Sta -WindowStyle Hidden -File " & Quote(psPath)

For i = 0 To WScript.Arguments.Count - 1
    arg = WScript.Arguments.Item(i)
    command = command & " " & Quote(arg)
Next

shell.Run command, 0, False

Function Quote(value)
    Quote = Chr(34) & Replace(CStr(value), Chr(34), Chr(34) & Chr(34)) & Chr(34)
End Function
