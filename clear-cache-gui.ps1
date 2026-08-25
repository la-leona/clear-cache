<#
.SYNOPSIS
    WPF front-end for clear-browser-and-windows-cache-v6.ps1.

.DESCRIPTION
    Pick the cleanup options with check boxes, preview what would be deleted, then run.
    The script itself is not modified: this GUI just builds the arguments, launches v6 in a
    child process and streams its output into the window.

    Defaults match clear-all.ps1 (browser cache, Windows Update cache, deep caches, recycle
    bin, DISM + /ResetBase, Delivery Optimization, user traces, elevated).

    Notes
      - The GUI always passes -Force to the child process, because a hidden console cannot
        answer the "Proceed with cleanup? (Y/N)" prompt. The confirmation is done by the GUI
        instead.
      - -Elevate is NOT passed to the child: v6 would relaunch itself in a new window and the
        output could not be captured. The GUI relaunches ITSELF elevated instead.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File C:\opt\bin\clear-cache-gui.ps1
#>

[CmdletBinding()]
param()

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml
Add-Type -AssemblyName System.Windows.Forms   # for the save-file dialog

$ErrorActionPreference = 'Stop'

$script:TargetScript = Join-Path $PSScriptRoot 'clear-browser-and-windows-cache-v6.ps1'
$script:Proc         = $null
$script:OutReader    = $null
$script:ErrReader    = $null
$script:OutFile      = $null
$script:ErrFile      = $null
$script:Timer        = $null

# Output pane state.
#   OpenBar     - a dism.exe progress bar drawn at the end of the pane; the next bar replaces
#                 it, so the bar appears to update in place instead of piling up. dism emits
#                 every redraw as "<CR>[==  10.0%  ] <CR><LF>", i.e. a COMPLETE line, so bars
#                 have to be recognised by pattern, not just by collapsing bare CRs.
#   OpenLen     - characters of OpenBar currently rendered (stripped before each update).
#   PartialText - text received without its newline yet. Buffered and NOT rendered, so a chunk
#                 boundary in the middle of a line cannot freeze a bar into the pane.
$script:OpenBar     = ''
$script:OpenLen     = 0
$script:PartialText = ''
$script:ProgressPattern = '^\[[=\s]*\d+(\.\d+)?%[=\s]*\]\s*$'

# Portable settings: keep them next to the script so the whole folder can be copied or
# backed up as one unit. If that folder is not writable (read-only media, restricted ACL,
# non-elevated run), fall back to the user profile. Load prefers the portable file, so an
# existing profile copy is migrated automatically on the next save.
$script:SettingsPathScript  = Join-Path $PSScriptRoot 'clear-cache-gui.settings.json'
$script:SettingsPathAppData = Join-Path (Join-Path $env:APPDATA 'clear-cache-gui') 'settings.json'

# Parents must come before their dependent option, so loading restores the child state
# after the parent's Checked handler has run.
$script:OptionBoxes = @('chkWU', 'chkDeep', 'chkDO', 'chkTraces', 'chkRecycle',
                        'chkBrowser', 'chkForceKill', 'chkComponent', 'chkResetBase',
                        'chkRebuild', 'chkDisk', 'chkQuiet', 'chkElevate')

# Window theme choices. 'None' keeps the classic look and is the default; it is also the
# fallback whenever a saved value is missing or unrecognised.
$script:ThemeChoices = @('None', 'Dark', 'Light', 'System')

function Test-IsAdministrator {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-HostExe {
    $exe = (Get-Process -Id $PID).Path
    if (-not $exe) { $exe = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" }
    return $exe
}

# ----------------------------------------------------------------------------- XAML
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Windows / Browser Cache Cleaner (v6)"
        Width="900" Height="760" WindowStartupLocation="CenterScreen">
  <Grid Margin="10">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- targets -->
    <GroupBox Grid.Row="0" Header="Cleanup targets" Padding="8">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <StackPanel Grid.Column="0">
          <TextBlock Text="Windows temp / logs / font cache (always cleaned)"
                     Foreground="Gray" Margin="0,0,0,6"/>
          <CheckBox x:Name="chkWU"        Content="Windows Update cache (-IncludeWindowsUpdateCache)" Margin="0,3"/>
          <CheckBox x:Name="chkDeep"      Content="Deep system caches: Cryptnet / D3DSCache / WER (-DeepWindowsCache)" Margin="0,3"/>
          <CheckBox x:Name="chkDO"        Content="Delivery Optimization cache (-ClearDeliveryOptimizationCache)" Margin="0,3"/>
          <CheckBox x:Name="chkTraces"    Content="User traces: thumbnails / recent / jump lists (-ClearUserTraces)" Margin="0,3"/>
          <CheckBox x:Name="chkRecycle"   Content="Empty Recycle Bin (-EmptyRecycleBin)" Margin="0,3"/>
        </StackPanel>
        <StackPanel Grid.Column="1">
          <CheckBox x:Name="chkBrowser"   Content="Browser caches, closes browsers first (-ClearBrowserCache)" Margin="0,3"/>
          <CheckBox x:Name="chkForceKill" Content="Force-kill browsers immediately (-ForceCloseBrowsers)" Margin="18,3,0,3"/>
          <CheckBox x:Name="chkComponent" Content="DISM component store cleanup (-CleanupComponentStore)" Margin="0,3"/>
          <CheckBox x:Name="chkResetBase" Content="/ResetBase - updates can no longer be uninstalled (-ResetBase)"
                    Foreground="#B00000" Margin="18,3,0,3"/>
          <CheckBox x:Name="chkRebuild"   Content="Restart Explorer, rebuild icon cache (-RebuildExplorerCache)" Margin="0,3"/>
          <CheckBox x:Name="chkDisk"      Content="Windows Disk Cleanup, cleanmgr (-RunDiskCleanup)" Margin="0,3"/>
        </StackPanel>
      </Grid>
    </GroupBox>

    <!-- options -->
    <GroupBox Grid.Row="1" Header="Options" Padding="8" Margin="0,8,0,0">
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="*"/>
          <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Grid.Row="0" Grid.Column="0" Text="Only files older than" VerticalAlignment="Center"/>
        <TextBox   Grid.Row="0" Grid.Column="1" x:Name="txtDays" Text="0" Width="50" Margin="6,0"
                   VerticalAlignment="Center" TextAlignment="Right"/>
        <TextBlock Grid.Row="0" Grid.Column="2" Text="day(s)   (0 = all)" VerticalAlignment="Center"/>
        <CheckBox  Grid.Row="0" Grid.Column="3" x:Name="chkElevate" Content="Run as Administrator"
                   Margin="24,0,0,0" VerticalAlignment="Center"/>
        <!-- Quiet and Theme share this column so Theme sits directly right of the checkbox
             and the Browse button below keeps its own column. -->
        <StackPanel Grid.Row="0" Grid.Column="4" Orientation="Horizontal" VerticalAlignment="Center">
          <CheckBox  x:Name="chkQuiet" Content="Quiet (hide per-item lines)"
                     Margin="24,0,0,0" VerticalAlignment="Center"/>
          <TextBlock Text="Theme" Margin="24,0,6,0" VerticalAlignment="Center"/>
          <ComboBox  x:Name="cmbTheme" Width="84" VerticalAlignment="Center"/>
        </StackPanel>

        <TextBlock Grid.Row="1" Grid.Column="0" Text="Log file (optional)" VerticalAlignment="Center" Margin="0,8,0,0"/>
        <TextBox   Grid.Row="1" Grid.Column="1" Grid.ColumnSpan="4" x:Name="txtLog" Margin="6,8,6,0"
                   VerticalAlignment="Center"/>
        <Button    Grid.Row="1" Grid.Column="5" x:Name="btnBrowse" Content="Browse..." Width="90"
                   Margin="0,8,0,0"/>
      </Grid>
    </GroupBox>

    <!-- command preview -->
    <GroupBox Grid.Row="2" Header="Command that will run" Padding="6" Margin="0,8,0,0">
      <TextBox x:Name="txtCommand" IsReadOnly="True" TextWrapping="Wrap" BorderThickness="0"
               Background="Transparent" FontFamily="FiraCode Nanum, Consolas, Courier New"
               FontSize="12" MinHeight="34"/>
    </GroupBox>

    <!-- buttons -->
    <Grid Grid.Row="3" Margin="0,10,0,0">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <StackPanel Grid.Column="0" Orientation="Horizontal">
        <Button x:Name="btnPreview" Content="Preview (scan only)" Width="150" Height="32"/>
        <Button x:Name="btnRun"     Content="Run cleanup"         Width="130" Height="32" Margin="8,0,0,0"/>
        <Button x:Name="btnCancel"  Content="Cancel"              Width="100" Height="32" Margin="8,0,0,0" IsEnabled="False"/>
        <Button x:Name="btnClear"   Content="Clear output"        Width="110" Height="32" Margin="8,0,0,0"/>
        <Button x:Name="btnOpenLog" Content="Open log"            Width="100" Height="32" Margin="8,0,0,0"/>
        <Button x:Name="btnReset"   Content="Reset defaults"      Width="120" Height="32" Margin="8,0,0,0"/>
      </StackPanel>
      <Button Grid.Column="1" x:Name="btnExit" Content="Exit" Width="90" Height="32" Margin="16,0,0,0"/>
    </Grid>

    <!-- output -->
    <GroupBox Grid.Row="4" Header="Output" Padding="4" Margin="0,10,0,0">
      <TextBox x:Name="txtOutput" IsReadOnly="True" AcceptsReturn="True"
               VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto"
               FontFamily="FiraCode Nanum, Consolas, Courier New" FontSize="12"
               Background="#FF1E1E1E" Foreground="#FFDCDCDC" BorderThickness="1"/>
    </GroupBox>

    <!-- status -->
    <Grid Grid.Row="5" Margin="0,8,0,0">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <ProgressBar x:Name="prg" Grid.Column="0" Height="18" IsIndeterminate="False"/>
      <TextBlock   x:Name="lblStatus" Grid.Column="1" Margin="10,0,0,0" VerticalAlignment="Center" Text="Ready"/>
    </Grid>
  </Grid>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$win = [Windows.Markup.XamlReader]::Load($reader)

# Window theme, chosen in Options and remembered in the settings file. Window.ThemeMode only
# exists on modern .NET WPF (PowerShell 7), not on Windows PowerShell 5.1 / .NET Framework -
# and assigning a missing property is a terminating error here ($ErrorActionPreference =
# 'Stop'), which would kill the GUI silently when launched hidden. So probe for the property
# once here and treat the theme as unavailable when it is missing.
$script:ThemeSupported = ($null -ne $win.GetType().GetProperty('ThemeMode'))
if ($script:ThemeSupported) { $win.ThemeMode = 'None' }

# Title bar + taskbar icon, taken from clear-cache-gui.ico next to this script. A shortcut's
# icon only applies to the shortcut, so without this the window shows the powershell.exe icon.
# The 32x32 frame is preferred: Windows draws 32px in the taskbar and Alt+Tab and 16px in the
# title bar, so a 32px source stays crisp (clean 2:1 downscale) where a 128/256px frame looks
# soft.
$iconPath = Join-Path $PSScriptRoot 'clear-cache-gui.ico'
if (Test-Path -LiteralPath $iconPath) {
    try {
        $frames = ([System.Windows.Media.Imaging.BitmapDecoder]::Create(
                      (New-Object System.Uri $iconPath), 'None', 'OnLoad')).Frames
        $pick = $frames | Where-Object { $_.PixelWidth -eq 32 } | Select-Object -First 1
        if (-not $pick) {                       # nothing at 32: smallest frame above it
            $pick = $frames | Where-Object { $_.PixelWidth -gt 32 } |
                    Sort-Object PixelWidth | Select-Object -First 1
        }
        if (-not $pick) {                       # only smaller frames exist: take the largest
            $pick = $frames | Sort-Object PixelWidth -Descending | Select-Object -First 1
        }
        if ($pick) { $win.Icon = $pick }
    }
    catch { }   # a broken .ico must not stop the GUI
}

foreach ($n in @('chkWU','chkDeep','chkDO','chkTraces','chkRecycle','chkBrowser','chkForceKill',
                 'chkComponent','chkResetBase','chkRebuild','chkDisk','chkElevate','chkQuiet',
                 'txtDays','txtLog','btnBrowse','txtCommand','btnPreview','btnRun','btnCancel',
                 'btnClear','btnOpenLog','btnReset','btnExit','txtOutput','prg','lblStatus',
                 'cmbTheme')) {
    Set-Variable -Name $n -Value $win.FindName($n) -Scope Script
}

# Items are filled here rather than in XAML so SelectedItem is a plain string, which keeps
# saving and loading simple (a XAML-declared list would hand back ComboBoxItem objects).
$cmbTheme.ItemsSource = [string[]]$script:ThemeChoices
if (-not $script:ThemeSupported) {
    $cmbTheme.IsEnabled = $false
    $cmbTheme.ToolTip   = 'Needs PowerShell 7 (modern .NET WPF). This host has no Window.ThemeMode.'
}

# --------------------------------------------------------- defaults (match clear-all.ps1)
function Set-DefaultOptions {
    $chkBrowser.IsChecked   = $true    # -ClearBrowserCache
    $chkWU.IsChecked        = $true    # -IncludeWindowsUpdateCache
    $chkDeep.IsChecked      = $true    # -DeepWindowsCache
    $chkRecycle.IsChecked   = $true    # -EmptyRecycleBin
    $chkComponent.IsChecked = $true    # -CleanupComponentStore
    $chkResetBase.IsChecked = $true    # -ResetBase
    $chkDO.IsChecked        = $true    # -ClearDeliveryOptimizationCache
    $chkTraces.IsChecked    = $true    # -ClearUserTraces
    $chkElevate.IsChecked   = $true    # -Elevate (handled by relaunching this GUI)
    $txtDays.Text           = '0'      # -OlderThanDays 0
    # not used by clear-all.ps1: ForceCloseBrowsers, RebuildExplorerCache, RunDiskCleanup, Quiet
    $chkForceKill.IsChecked = $false
    $chkRebuild.IsChecked   = $false
    $chkDisk.IsChecked      = $false
    $chkQuiet.IsChecked     = $false
    $txtLog.Text            = ''
    $cmbTheme.SelectedItem  = 'None'   # GUI-only setting, not passed to the script
}

# Applies the chosen window theme. A no-op when this host's WPF has no ThemeMode property.
function Set-WindowTheme {
    param([string]$Theme)
    if (-not $script:ThemeSupported) { return }
    if ($script:ThemeChoices -notcontains $Theme) { $Theme = 'None' }
    try { $win.ThemeMode = $Theme }
    catch { Add-Output ("[theme] could not apply '{0}': {1}`r`n" -f $Theme, $_.Exception.Message) }
}

# Saves to the portable path first, then the profile path. Returns the path used, or $null.
function Save-GuiSettings {
    $data = [ordered]@{ version = 1 }
    foreach ($n in $script:OptionBoxes) {
        $data[$n] = [bool](Get-Variable -Name $n -Scope Script -ValueOnly).IsChecked
    }
    $data['olderThanDays'] = (Get-DaysValue)
    $data['logPath']       = ($txtLog.Text).Trim()
    $data['theme']         = if ($cmbTheme.SelectedItem) { [string]$cmbTheme.SelectedItem } else { 'None' }
    $json = $data | ConvertTo-Json

    foreach ($path in @($script:SettingsPathScript, $script:SettingsPathAppData)) {
        try {
            $dir = Split-Path -Path $path -Parent
            if ($dir -and -not (Test-Path -LiteralPath $dir)) {
                New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop | Out-Null
            }
            Set-Content -LiteralPath $path -Value $json -Encoding UTF8 -ErrorAction Stop
            return $path
        }
        catch {
            # Try the next location. Settings are a convenience; a failure must not break a run.
        }
    }

    Add-Output "[settings] could not save (script folder and APPDATA both failed)`r`n"
    return $null
}

# Loads from the portable path if present, else the profile path. Returns the path used,
# or $null when nothing usable was found.
function Import-GuiSettings {
    $path = @($script:SettingsPathScript, $script:SettingsPathAppData) |
            Where-Object { Test-Path -LiteralPath $_ } |
            Select-Object -First 1
    if (-not $path) { return $null }

    try {
        $s = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        Add-Output ("[settings] ignored unreadable file: {0}`r`n" -f $path)
        return $null
    }

    $props = $s.PSObject.Properties.Name
    foreach ($n in $script:OptionBoxes) {
        if ($props -contains $n) {
            (Get-Variable -Name $n -Scope Script -ValueOnly).IsChecked = [bool]$s.$n
        }
    }
    if ($props -contains 'olderThanDays') { $txtDays.Text = [string][int]$s.olderThanDays }
    if ($props -contains 'logPath')       { $txtLog.Text  = [string]$s.logPath }
    if ($props -contains 'theme') {
        # An unknown or hand-edited value falls back to 'None' rather than clearing the box.
        $t = [string]$s.theme
        $cmbTheme.SelectedItem = if ($script:ThemeChoices -contains $t) { $t } else { 'None' }
    }
    return $path
}

Set-DefaultOptions

# ----------------------------------------------------------------------------- helpers
# Appends child-process output. Progress bars are drawn in place: a new bar overwrites the
# previous one instead of adding a line, and the last bar is kept when normal output resumes.
function Add-Output {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return }

    # Take the open bar off the pane; it is re-rendered (or replaced) at the end.
    # NOTE: this must not be called $text - PowerShell variables are case-insensitive, so it
    # would overwrite the $Text parameter.
    $pane = $txtOutput.Text
    if ($script:OpenLen -gt 0 -and $pane.Length -ge $script:OpenLen) {
        $pane = $pane.Substring(0, $pane.Length - $script:OpenLen)
    }
    $bar = $script:OpenBar

    # Continue the buffered partial line, then work line by line.
    $data  = $script:PartialText + ($Text -replace "`r`n", "`n")
    $parts = $data -split "`n"
    $collapse = {                       # within one line, only text after the last CR survives
        param([string]$s)
        $i = $s.LastIndexOf("`r")
        if ($i -ge 0) { return $s.Substring($i + 1) }
        return $s
    }

    $lines = @()
    if ($parts.Count -gt 1) {
        $lines = $parts[0..($parts.Count - 2)] | ForEach-Object { & $collapse $_ }
    }
    $script:PartialText = & $collapse $parts[-1]     # keep buffered until its newline arrives

    foreach ($line in $lines) {
        if ($line -match $script:ProgressPattern) {
            $bar = $line                             # replaces the bar drawn before
        }
        else {
            if ($bar -ne '') { $pane += $bar + "`r`n"; $bar = '' }   # keep the last bar
            $pane += $line + "`r`n"
        }
    }

    $txtOutput.Text = $pane + $bar
    $script:OpenBar = $bar
    $script:OpenLen = $bar.Length
    $txtOutput.ScrollToEnd()
}

# Renders a line that never received its newline (e.g. the child exited mid-line).
function Flush-Output {
    if ($script:PartialText -ne '') { Add-Output "`n" }
}

function Get-DaysValue {
    $days = 0
    if (-not [int]::TryParse(($txtDays.Text).Trim(), [ref]$days)) { return 0 }
    if ($days -lt 0) { return 0 }
    return $days
}

# Builds the v6 argument list. -Force is always added for real runs (see .DESCRIPTION).
function Get-ScriptArgs {
    param([switch]$PreviewMode)

    $a = @()
    $days = Get-DaysValue
    if ($days -gt 0) { $a += @('-OlderThanDays', "$days") }

    if ($chkBrowser.IsChecked)   { $a += '-ClearBrowserCache' }
    if ($chkForceKill.IsChecked) { $a += '-ForceCloseBrowsers' }
    if ($chkWU.IsChecked)        { $a += '-IncludeWindowsUpdateCache' }
    if ($chkDeep.IsChecked)      { $a += '-DeepWindowsCache' }
    if ($chkTraces.IsChecked)    { $a += '-ClearUserTraces' }
    if ($chkRecycle.IsChecked)   { $a += '-EmptyRecycleBin' }
    if ($chkComponent.IsChecked) { $a += '-CleanupComponentStore' }
    if ($chkResetBase.IsChecked -and $chkComponent.IsChecked) { $a += '-ResetBase' }
    if ($chkDO.IsChecked)        { $a += '-ClearDeliveryOptimizationCache' }
    if ($chkRebuild.IsChecked)   { $a += '-RebuildExplorerCache' }
    if ($chkDisk.IsChecked)      { $a += '-RunDiskCleanup' }
    if ($chkQuiet.IsChecked)     { $a += '-Quiet' }

    $log = ($txtLog.Text).Trim()
    if ($log) { $a += @('-LogPath', $log) }

    # Preview never prompts, so -Force would only trigger the "no effect" warning.
    if ($PreviewMode) { $a += '-Preview' } else { $a += '-Force' }
    return $a
}

function Update-CommandPreview {
    $a = Get-ScriptArgs
    $shown = $a | ForEach-Object { if ($_ -match '\s') { "`"$_`"" } else { $_ } }
    $txtCommand.Text = ('.\{0} {1}' -f (Split-Path $script:TargetScript -Leaf), ($shown -join ' '))
}

function Set-Running {
    param([bool]$Running)
    foreach ($c in @($btnPreview, $btnRun, $btnBrowse, $btnClear, $btnReset)) { $c.IsEnabled = -not $Running }
    $btnCancel.IsEnabled  = $Running
    $prg.IsIndeterminate  = $Running
}

# Relaunch this GUI elevated. Returns $true when a new elevated instance was started.
# Goes through the wscript launcher (.js preferred, .vbs kept as a fallback): wscript.exe has
# no console of its own, whereas -WindowStyle Hidden does NOT hide the console when Windows
# Terminal is the default host. Only if no launcher is present do we relaunch PowerShell
# directly, which may briefly show a terminal window.
function Invoke-GuiElevation {
    try {
        foreach ($launcher in @('clear-cache-gui.js', 'clear-cache-gui.vbs')) {
            $path = Join-Path $PSScriptRoot $launcher
            if (Test-Path -LiteralPath $path) {
                Start-Process -FilePath 'wscript.exe' -Verb RunAs -ArgumentList "`"$path`""
                return $true
            }
        }
        Start-Process -FilePath (Get-HostExe) -Verb RunAs -ArgumentList @(
            '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden',
            '-File', "`"$PSCommandPath`"")
        return $true
    }
    catch {
        [System.Windows.MessageBox]::Show(
            "Elevation was cancelled or failed:`n$($_.Exception.Message)",
            'Cache Cleaner', 'OK', 'Warning') | Out-Null
        return $false
    }
}

function Confirm-Elevation {
    if (-not $chkElevate.IsChecked) { return $true }
    if (Test-IsAdministrator) { return $true }

    $r = [System.Windows.MessageBox]::Show(
        "Administrator rights are required for Windows / DISM / Delivery Optimization targets." +
        "`n`nRestart this window as Administrator?" +
        "`n`n  Yes  - restart elevated (this window closes)" +
        "`n  No   - continue without elevation (some targets are skipped)",
        'Cache Cleaner', 'YesNoCancel', 'Question')

    switch ($r) {
        'Yes'    { if (Invoke-GuiElevation) { $win.Close() }; return $false }
        'No'     { return $true }
        default  { return $false }
    }
}

# ----------------------------------------------------------------------------- run / poll
function Stop-Polling {
    if ($script:Timer) { $script:Timer.Stop(); $script:Timer = $null }
    foreach ($r in @($script:OutReader, $script:ErrReader)) {
        if ($r) { try { $r.Dispose() } catch { } }
    }
    $script:OutReader = $null
    $script:ErrReader = $null
    foreach ($f in @($script:OutFile, $script:ErrFile)) {
        if ($f -and (Test-Path -LiteralPath $f)) { try { Remove-Item $f -Force } catch { } }
    }
}

function Open-StreamReader {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try {
        $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open,
              [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        return New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8, $true)
    }
    catch { return $null }
}

function Start-Cleanup {
    param([switch]$PreviewMode)

    if (-not (Test-Path -LiteralPath $script:TargetScript)) {
        [System.Windows.MessageBox]::Show("Target script not found:`n$($script:TargetScript)",
            'Cache Cleaner', 'OK', 'Error') | Out-Null
        return
    }
    if ($script:Proc -and -not $script:Proc.HasExited) { return }
    if (-not (Confirm-Elevation)) { return }

    $userArgs = Get-ScriptArgs -PreviewMode:$PreviewMode

    if (-not $PreviewMode) {
        $lines = @('Start cleanup with the selected options?', '')
        if ($chkBrowser.IsChecked -or $chkForceKill.IsChecked) {
            $lines += '- Browsers will be CLOSED. Unsaved tabs may be lost.'
        }
        if ($chkResetBase.IsChecked -and $chkComponent.IsChecked) {
            $lines += '- /ResetBase: installed Windows updates can NO LONGER be uninstalled.'
            $lines += '  This is irreversible and DISM may take tens of minutes.'
        }
        if ($chkRecycle.IsChecked) { $lines += '- The Recycle Bin will be emptied (all drives).' }
        if ($chkRebuild.IsChecked) { $lines += '- Explorer will be restarted.' }
        $lines += ''
        $lines += 'Deleted files cannot be recovered.'

        $r = [System.Windows.MessageBox]::Show(($lines -join "`n"), 'Confirm cleanup',
             'OKCancel', 'Warning')
        if ($r -ne 'OK') { return }
    }

    # Persist the choices now, so they survive even if the window is killed mid-run.
    Save-GuiSettings

    Stop-Polling
    $script:OutFile = [System.IO.Path]::GetTempFileName()
    $script:ErrFile = [System.IO.Path]::GetTempFileName()

    $spArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$($script:TargetScript)`"")
    $spArgs += $userArgs | ForEach-Object { if ($_ -match '\s') { "`"$_`"" } else { $_ } }

    Add-Output ("`r`n===== {0} =====`r`n" -f $(if ($PreviewMode) { 'PREVIEW' } else { 'CLEANUP' }))
    Add-Output ("> {0}`r`n`r`n" -f ($spArgs -join ' '))

    try {
        $script:Proc = Start-Process -FilePath (Get-HostExe) -ArgumentList $spArgs `
            -RedirectStandardOutput $script:OutFile -RedirectStandardError $script:ErrFile `
            -WindowStyle Hidden -PassThru
    }
    catch {
        Add-Output ("Failed to start: {0}`r`n" -f $_.Exception.Message)
        Stop-Polling
        return
    }

    Set-Running $true
    $lblStatus.Text = if ($PreviewMode) { 'Scanning...' } else { 'Cleaning...' }

    $script:Timer = New-Object System.Windows.Threading.DispatcherTimer
    $script:Timer.Interval = [TimeSpan]::FromMilliseconds(300)
    $script:Timer.Add_Tick({
        if (-not $script:OutReader) { $script:OutReader = Open-StreamReader $script:OutFile }
        if (-not $script:ErrReader) { $script:ErrReader = Open-StreamReader $script:ErrFile }
        if ($script:OutReader) { Add-Output $script:OutReader.ReadToEnd() }
        if ($script:ErrReader) { Add-Output $script:ErrReader.ReadToEnd() }

        if ($script:Proc -and $script:Proc.HasExited) {
            Start-Sleep -Milliseconds 120          # let the last buffered bytes land
            if ($script:OutReader) { Add-Output $script:OutReader.ReadToEnd() }
            if ($script:ErrReader) { Add-Output $script:ErrReader.ReadToEnd() }

            Flush-Output                            # render a last line that had no newline

            $code = $script:Proc.ExitCode
            $meaning = switch ($code) {
                0       { 'completed' }
                1       { 'cancelled at prompt' }
                2       { 'bad arguments' }
                default { 'exit code ' + $code }
            }
            Add-Output ("`r`n----- finished: {0} (exit {1}) -----`r`n" -f $meaning, $code)
            $lblStatus.Text = "Done ($meaning)"
            Set-Running $false
            $script:Proc = $null
            Stop-Polling
        }
    })
    $script:Timer.Start()
}

# ----------------------------------------------------------------------------- events
foreach ($c in @($chkWU, $chkDeep, $chkDO, $chkTraces, $chkRecycle, $chkBrowser, $chkForceKill,
                 $chkComponent, $chkResetBase, $chkRebuild, $chkDisk, $chkQuiet)) {
    $c.Add_Checked({   Update-CommandPreview })
    $c.Add_Unchecked({ Update-CommandPreview })
}
$txtDays.Add_TextChanged({ Update-CommandPreview })
$txtLog.Add_TextChanged({ Update-CommandPreview })

# Theme is cosmetic and is not passed to the script, so it only repaints the window - the
# command preview stays untouched.
$cmbTheme.Add_SelectionChanged({ Set-WindowTheme ([string]$cmbTheme.SelectedItem) })

# /ResetBase only means something together with the DISM cleanup.
$syncResetBase = {
    $chkResetBase.IsEnabled = [bool]$chkComponent.IsChecked
    if (-not $chkComponent.IsChecked) { $chkResetBase.IsChecked = $false }
    Update-CommandPreview
}
$chkComponent.Add_Checked($syncResetBase)
$chkComponent.Add_Unchecked($syncResetBase)

# -ForceCloseBrowsers is only useful when browser caches are cleared.
$syncForceKill = {
    $chkForceKill.IsEnabled = [bool]$chkBrowser.IsChecked
    if (-not $chkBrowser.IsChecked) { $chkForceKill.IsChecked = $false }
    Update-CommandPreview
}
$chkBrowser.Add_Checked($syncForceKill)
$chkBrowser.Add_Unchecked($syncForceKill)

$btnBrowse.Add_Click({
    $dlg = New-Object System.Windows.Forms.SaveFileDialog
    $dlg.Filter = 'Log files (*.log)|*.log|All files (*.*)|*.*'
    $dlg.FileName = 'clean.log'
    $dlg.OverwritePrompt = $false      # v6 appends
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtLog.Text = $dlg.FileName
    }
})

$btnPreview.Add_Click({ Start-Cleanup -PreviewMode })
$btnRun.Add_Click({     Start-Cleanup })

$btnCancel.Add_Click({
    if ($script:Proc -and -not $script:Proc.HasExited) {
        if ($chkComponent.IsChecked) {
            $r = [System.Windows.MessageBox]::Show(
                "A DISM cleanup may be running. Stopping it midway is not recommended." +
                "`n`nStop anyway?", 'Cancel', 'YesNo', 'Warning')
            if ($r -ne 'Yes') { return }
        }
        # /T kills the whole tree (dism.exe / cleanmgr are children of the child process).
        & taskkill.exe /PID $script:Proc.Id /T /F | Out-Null
        Add-Output "`r`n[cancelled by user]`r`n"
        $lblStatus.Text = 'Cancelled'
    }
})

$btnClear.Add_Click({
    $txtOutput.Clear()
    $script:OpenBar     = ''      # forget the bar being drawn in place
    $script:OpenLen     = 0
    $script:PartialText = ''
})

$btnReset.Add_Click({
    $r = [System.Windows.MessageBox]::Show(
        "Reset all options to the clear-all.ps1 defaults?", 'Reset defaults', 'OKCancel', 'Question')
    if ($r -ne 'OK') { return }
    Set-DefaultOptions
    & $syncResetBase
    & $syncForceKill
    Update-CommandPreview
    $lblStatus.Text = 'Options reset to defaults'
})

# Exit runs the same path as the window's X button (saves settings, offers to stop a run).
$btnExit.Add_Click({ $win.Close() })

$btnOpenLog.Add_Click({
    $log = ($txtLog.Text).Trim()
    if (-not $log) {
        [System.Windows.MessageBox]::Show('No log file is set.', 'Cache Cleaner', 'OK', 'Information') | Out-Null
        return
    }
    if (-not (Test-Path -LiteralPath $log)) {
        [System.Windows.MessageBox]::Show("Log file does not exist yet:`n$log",
            'Cache Cleaner', 'OK', 'Information') | Out-Null
        return
    }
    Start-Process notepad.exe -ArgumentList "`"$log`""
})

$win.Add_Closing({
    if ($script:Proc -and -not $script:Proc.HasExited) {
        $r = [System.Windows.MessageBox]::Show(
            'A cleanup is still running. Stop it and close?', 'Cache Cleaner', 'YesNo', 'Warning')
        if ($r -ne 'Yes') { $_.Cancel = $true; return }
        try { & taskkill.exe /PID $script:Proc.Id /T /F | Out-Null } catch { }
    }
    Save-GuiSettings
    Stop-Polling
})

# ----------------------------------------------------------------------------- start
$loadedFrom = Import-GuiSettings
& $syncResetBase
& $syncForceKill
Set-WindowTheme ([string]$cmbTheme.SelectedItem)
Update-CommandPreview

if ($loadedFrom) {
    Add-Output ("[settings] restored from {0}`r`n" -f $loadedFrom)
    if ($loadedFrom -eq $script:SettingsPathAppData) {
        Add-Output ("[settings] will be saved next to the script from now on: {0}`r`n" -f $script:SettingsPathScript)
    }
}
else {
    Add-Output ("[settings] clear-all.ps1 defaults; will save to {0}`r`n" -f $script:SettingsPathScript)
}

if (Test-IsAdministrator) {
    $lblStatus.Text = 'Ready (Administrator)'
}
else {
    $lblStatus.Text = 'Ready (not elevated)'
    Add-Output "Not running as Administrator. Windows / DISM / Delivery Optimization targets may be skipped.`r`nUse the 'Run as Administrator' option to restart elevated.`r`n"
}

# The wscript launcher (clear-cache-gui.js) starts this process with a hidden window state
# (SW_HIDE) so no console appears. A side effect is that the shell skips creating a taskbar
# button for the first window - it only shows up once the window is moved. Toggling
# ShowInTaskbar after the window is up recreates the HWND, so the taskbar registers it at once.
$win.Add_Loaded({
        $win.ShowInTaskbar = $false
        $win.ShowInTaskbar = $true
    })

$win.ShowDialog() | Out-Null
