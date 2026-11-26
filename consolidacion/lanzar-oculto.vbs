' Lanza consolidar.ps1 sin ventana, espera a que termine y devuelve su codigo de salida. Reenvia sus argumentos (p. ej. -AlIniciarSesion) a consolidar.ps1.
Option Explicit
Dim sh, cmd, rc, i
Set sh = CreateObject("WScript.Shell")
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File ""C:\SENYUM\base-conocimiento\consolidacion\consolidar.ps1"""
For i = 0 To WScript.Arguments.Count - 1
    cmd = cmd & " " & WScript.Arguments(i)
Next
rc = sh.Run(cmd, 0, True)
WScript.Quit rc
