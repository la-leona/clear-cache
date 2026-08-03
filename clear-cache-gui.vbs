' clear-cache-gui.vbs
' ---------------------------------------------------------------------------
' Launches clear-cache-gui.ps1 with NO console window.
'
' Why this file exists:
'   powershell.exe -WindowStyle Hidden does NOT hide the console when Windows
'   Terminal is the default console host: the terminal is a separate process and
'   ignores the requested window style. wscript.exe has no console of its own,
'   and Run(cmd, 0, False) starts PowerShell hidden, so nothing appears or
'   flashes at all.
'
' Usage:
'   Point the desktop shortcut at this file (or at:
'   wscript.exe "C:\opt\bin\clear-cache-gui.vbs").
'   Tick "Run as administrator" in the shortcut's Advanced properties to start
'   elevated - the GUI needs it for Windows / DISM / Delivery Optimization.
' ---------------------------------------------------------------------------
Option Explicit

Dim sh, fso, here, target, cmd
Set sh  = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

' Resolve the .ps1 next to this launcher, so the folder stays portable.
here   = fso.GetParentFolderName(WScript.ScriptFullName)
target = here & "\clear-cache-gui.ps1"

If Not fso.FileExists(target) Then
    MsgBox "GUI script not found:" & vbCrLf & target, 16, "Cache Cleaner"
    WScript.Quit 1
End If

cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & target & """"

' 0 = hidden window, False = do not wait for it to finish.
sh.Run cmd, 0, False
