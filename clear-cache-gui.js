// clear-cache-gui.js
// ---------------------------------------------------------------------------
// Launches clear-cache-gui.ps1 with NO console window.
//
// Why this file exists:
//   powershell.exe -WindowStyle Hidden does NOT hide the console when Windows
//   Terminal is the default console host: the terminal is a separate process and
//   ignores the requested window style. wscript.exe has no console of its own,
//   and Run(cmd, 0, False) starts the shell hidden, so nothing appears or
//   flashes at all.
//
// Which PowerShell:
//   PowerShell 7 (pwsh.exe) is preferred because newer WPF features such as
//   Window.ThemeMode only exist on modern .NET. Windows PowerShell 5.1
//   (powershell.exe, .NET Framework) is used as a fallback when pwsh is absent,
//   and the GUI guards those features so it still runs there.
//
// Usage:
//   Point the desktop shortcut at this file (or at:
//   cscript.exe "C:\opt\bin\clear-cache-gui.js" or
//   wscript.exe "C:\opt\bin\clear-cache-gui.js").
//   Tick "Run as administrator" in the shortcut's Advanced properties to start
//   elevated - the GUI needs it for Windows / DISM / Delivery Optimization.
// ---------------------------------------------------------------------------

(function() {
    'use strict';

    try {
        // Create WScript Shell and FileSystemObject
        var sh = new ActiveXObject("WScript.Shell");
        var fso = new ActiveXObject("Scripting.FileSystemObject");

        // Resolve the .ps1 next to this launcher, so the folder stays portable.
        var here = fso.GetParentFolderName(WScript.ScriptFullName);
        var target = here + "\\clear-cache-gui.ps1";

        // Check if the target file exists
        if (!fso.FileExists(target)) {
            var msg = "GUI script not found:\r\n" + target;
            sh.Popup(msg, 0, "Cache Cleaner", 16);
            WScript.Quit(1);
        }

        // Prefer PowerShell 7, fall back to Windows PowerShell 5.1.
        var programFiles = sh.ExpandEnvironmentStrings("%ProgramFiles%");
        var windir = sh.ExpandEnvironmentStrings("%WINDIR%");
        
        var exe = programFiles + "\\PowerShell\\7\\pwsh.exe";
        if (!fso.FileExists(exe)) {
            exe = windir + "\\System32\\WindowsPowerShell\\v1.0\\powershell.exe";
        }

        // Build the command line
        var cmd = '"' + exe + '" -NoProfile -ExecutionPolicy Bypass -File "' + target + '"';

        // 0 = hidden window, false = do not wait for it to finish.
        sh.Run(cmd, 0, false);

    } catch (e) {
        // Error handling
        var errorMsg = "An error occurred:\r\n" + e.message;
        var sh_error = new ActiveXObject("WScript.Shell");
        sh_error.Popup(errorMsg, 0, "Cache Cleaner - Error", 16);
        WScript.Quit(1);
    }
})();