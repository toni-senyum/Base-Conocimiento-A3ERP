' Lanza consolidar.ps1 sin ventana, espera a que termine y devuelve su codigo de salida.
Option Explicit
Dim sh, cmd, rc
Set sh = CreateObject("WScript.Shell")
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File ""C:\SENYUM\base-conocimiento\consolidacion\consolidar.ps1"""
rc = sh.Run(cmd, 0, True)
WScript.Quit rc
