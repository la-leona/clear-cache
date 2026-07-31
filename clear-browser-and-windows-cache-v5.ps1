<#
.SYNOPSIS
    Clears Windows temporary files plus Firefox and common browser caches.

.DESCRIPTION
    Combines the Windows junk sweep and browser cache cleanup flow:
      1. Finds Windows temp/log targets.
      2. Finds Firefox profile caches.
      3. Finds common Chromium-based browser caches: Edge, Chrome, Brave, Opera, Vivaldi.
      4. Optionally cleans deep Windows system caches (CryptnetUrlCache, D3DSCache, WER, ...).
      5. Shows a count/size summary first.
      6. Deletes after confirmation unless -Force is used.

    Browser caches are only cleared when -ClearBrowserCache is given (browsers are closed
    first). Add -ForceCloseBrowsers to force-close instead of a graceful shutdown.
    Run as Administrator to clean C:\Windows targets.

.PARAMETER OlderThanDays
    Only delete files older than N days. Default 0 = all cache/temp files.

.PARAMETER Preview
    Show the summary only. No files are deleted.

.PARAMETER Force
    Skip the confirmation prompt.

.PARAMETER ClearBrowserCache
    Also clear browser caches (Firefox/Chrome/Edge/Brave/Opera/Vivaldi). Browsers are
    closed first: a graceful shutdown request, then force-kill only the processes that do
    not exit in time. Without this switch, browser caches are left untouched.

.PARAMETER ForceCloseBrowsers
    When closing browsers, force-kill them immediately (no graceful shutdown). Combine with
    -ClearBrowserCache to force-close browsers and then clear their caches.

.PARAMETER IncludeWindowsUpdateCache
    Include Windows Update download/log cache. Requires Administrator for best results.

.PARAMETER DeepWindowsCache
    Also clean deep Windows system caches: CryptnetUrlCache, D3DSCache / DirectX Shader
    Cache, Windows Error Reporting (WER), Windows Update cache, and Delivery Optimization.

.PARAMETER EmptyRecycleBin
    Empty the Recycle Bin after cache cleanup.

.PARAMETER CleanupComponentStore
    Run DISM /StartComponentCleanup after file cleanup. Requires Administrator.

.PARAMETER ResetBase
    Add /ResetBase to the component store cleanup, removing ALL superseded component
    versions instead of keeping the usual 30-day grace period. Reclaims noticeably more
    space, but installed Windows updates can then no longer be uninstalled (rolled back),
    and the cleanup takes much longer. Only has an effect with -CleanupComponentStore.

.PARAMETER RunDiskCleanup
    Run cleanmgr /sagerun:100 after file cleanup. Configure it first with cleanmgr /sageset:100.

.PARAMETER RebuildExplorerCache
    Restart Explorer and delete Explorer thumbnail/icon cache databases after confirmation.

.PARAMETER ClearDeliveryOptimizationCache
    Clear Windows Delivery Optimization cache after confirmation. Requires Administrator for best results.

.PARAMETER ClearUserTraces
    Also clear user-activity traces that are not pure caches: the Explorer thumbnail/icon
    cache, recent-item shortcuts, and jump lists. Off by default so a normal run does not
    reset your "recent files" list or thumbnails.

.PARAMETER LogPath
    Append a full transcript of this run (summary, per-item results, skipped files) to the
    given file. The parent folder is created if needed.

.PARAMETER Quiet
    Suppress the parameter table and per-item progress lines. The summary, warnings and the
    final result are still shown. Useful for scheduled/automated runs.

.PARAMETER Elevate
    If not already elevated, relaunch the script as Administrator (UAC prompt) with the same
    arguments. The elevated run opens in a new window.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File C:\opt\bin\clear-browser-and-windows-cache-v5.ps1 -Preview

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File C:\opt\bin\clear-browser-and-windows-cache-v5.ps1 -Force -ClearBrowserCache

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File C:\opt\bin\clear-browser-and-windows-cache-v5.ps1 -DeepWindowsCache -Preview
#>

[CmdletBinding()]
param(
    [int]$OlderThanDays = 0,
    [switch]$Preview,
    [switch]$Force,
    [switch]$ClearBrowserCache,
    [switch]$ForceCloseBrowsers,
    [switch]$IncludeWindowsUpdateCache,
    [switch]$DeepWindowsCache,
    [switch]$EmptyRecycleBin,
    [switch]$CleanupComponentStore,
    [switch]$ResetBase,
    [switch]$RunDiskCleanup,
    [switch]$RebuildExplorerCache,
    [switch]$ClearDeliveryOptimizationCache,
    [switch]$ClearUserTraces,
    [string]$LogPath,
    [switch]$Quiet,
    [switch]$Elevate,
    # Captures anything that did not bind to a real parameter (e.g. a typo like -Froce),
    # so the script can suggest the intended parameter instead of failing to bind.
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$UnknownArgs
)

$ErrorActionPreference = 'Stop'
$cutoff = if ($OlderThanDays -gt 0) { (Get-Date).AddDays(-$OlderThanDays) } else { $null }
$targets = [System.Collections.Generic.List[object]]::new()
$ScriptParameters = $PSBoundParameters

# Single source of truth for the usage table (#3) and typo suggestions (#1).
$ParameterInfo = @(
    @{ Name = 'OlderThanDays'; Type = 'Integer'; Description = 'Delete only files older than N days.' }
    @{ Name = 'Preview'; Type = 'Switch'; Description = 'Show summary only; do not delete files.' }
    @{ Name = 'Force'; Type = 'Switch'; Description = 'Skip the confirmation prompt.' }
    @{ Name = 'ClearBrowserCache'; Type = 'Switch'; Description = 'Close browsers (graceful) and clear their caches.' }
    @{ Name = 'ForceCloseBrowsers'; Type = 'Switch'; Description = 'Force-kill browsers immediately (use with -ClearBrowserCache).' }
    @{ Name = 'IncludeWindowsUpdateCache'; Type = 'Switch'; Description = 'Include Windows Update download/log cache.' }
    @{ Name = 'DeepWindowsCache'; Type = 'Switch'; Description = 'Clean Cryptnet/D3DSCache/WER/WU/DO caches too.' }
    @{ Name = 'EmptyRecycleBin'; Type = 'Switch'; Description = 'Empty the Recycle Bin.' }
    @{ Name = 'CleanupComponentStore'; Type = 'Switch'; Description = 'Run DISM component store cleanup.' }
    @{ Name = 'ResetBase'; Type = 'Switch'; Description = 'DISM /ResetBase: more space, updates become permanent.' }
    @{ Name = 'RunDiskCleanup'; Type = 'Switch'; Description = 'Run cleanmgr /sagerun:100.' }
    @{ Name = 'RebuildExplorerCache'; Type = 'Switch'; Description = 'Restart Explorer and rebuild thumbnail/icon cache.' }
    @{ Name = 'ClearDeliveryOptimizationCache'; Type = 'Switch'; Description = 'Clear Delivery Optimization cache.' }
    @{ Name = 'ClearUserTraces'; Type = 'Switch'; Description = 'Clear thumbnail cache, recent items and jump lists.' }
    @{ Name = 'LogPath'; Type = 'String'; Description = 'Append a transcript of this run to a file.' }
    @{ Name = 'Quiet'; Type = 'Switch'; Description = 'Suppress usage table and per-item progress lines.' }
    @{ Name = 'Elevate'; Type = 'Switch'; Description = 'Relaunch as Administrator if not already elevated.' }
)

$script:TranscriptActive = $false

function Format-Size {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N2} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N2} KB' -f ($Bytes / 1KB)) }
    return "$Bytes B"
}

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Free bytes on the drive Windows is installed on (e.g. C:).
function Get-FreeSpaceBytes {
    try {
        $driveName = $env:SystemDrive.TrimEnd(':')
        $drive = Get-PSDrive -Name $driveName -ErrorAction Stop
        return [long]$drive.Free
    }
    catch {
        return 0L
    }
}

# #5 Relaunch the script elevated, preserving the original arguments (minus -Elevate).
function Invoke-SelfElevation {
    $hostExe = (Get-Process -Id $PID).Path
    if (-not $hostExe) { $hostExe = 'powershell.exe' }

    $argString = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    foreach ($kv in $script:ScriptParameters.GetEnumerator()) {
        if ($kv.Key -in @('Elevate', 'UnknownArgs')) { continue }
        $val = $kv.Value
        if ($val -is [switch]) {
            if ($val.IsPresent) { $argString += " -$($kv.Key)" }
        }
        else {
            $argString += " -$($kv.Key) `"$val`""
        }
    }

    Start-Process -FilePath $hostExe -Verb RunAs -ArgumentList $argString
}

# Central exit point: stops the transcript (if any) and returns an exit code so scheduled
# runs can detect the outcome. 0=ok, 1=cancelled, 2=bad arguments.
function Complete-Run {
    param([int]$Code = 0)

    if ($script:TranscriptActive) {
        try { Stop-Transcript | Out-Null } catch { }
        $script:TranscriptActive = $false
    }
    exit $Code
}

function Get-LevenshteinDistance {
    param([string]$A, [string]$B)

    $A = $A.ToLowerInvariant()
    $B = $B.ToLowerInvariant()
    $n = $A.Length
    $m = $B.Length
    if ($n -eq 0) { return $m }
    if ($m -eq 0) { return $n }

    $d = New-Object 'int[,]' ($n + 1), ($m + 1)
    for ($i = 0; $i -le $n; $i++) { $d[$i, 0] = $i }
    for ($j = 0; $j -le $m; $j++) { $d[0, $j] = $j }

    for ($i = 1; $i -le $n; $i++) {
        for ($j = 1; $j -le $m; $j++) {
            $cost = if ($A[$i - 1] -eq $B[$j - 1]) { 0 } else { 1 }
            $del = $d[($i - 1), $j] + 1
            $ins = $d[$i, ($j - 1)] + 1
            $sub = $d[($i - 1), ($j - 1)] + $cost
            $d[$i, $j] = [Math]::Min([Math]::Min($del, $ins), $sub)
        }
    }
    return $d[$n, $m]
}

# #1 Unknown-parameter detection with "Did you mean?" suggestions.
function Test-UnknownArguments {
    if (-not $UnknownArgs -or $UnknownArgs.Count -eq 0) { return $false }

    $known = $ParameterInfo.Name
    $problem = $false

    foreach ($token in $UnknownArgs) {
        $problem = $true
        $bare = $token.TrimStart('-', '/')

        Write-Host ''
        Write-Host ("Unknown parameter : {0}" -f $token) -ForegroundColor Red

        if ($bare) {
            $suggestions = $known |
                ForEach-Object { [pscustomobject]@{ Name = $_; Distance = (Get-LevenshteinDistance $bare $_) } } |
                Where-Object { $_.Distance -le 3 -or $_.Name.ToLowerInvariant().StartsWith($bare.ToLowerInvariant()) } |
                Sort-Object Distance, Name |
                Select-Object -First 3

            if ($suggestions) {
                Write-Host ''
                Write-Host 'Did you mean?' -ForegroundColor Yellow
                foreach ($s in $suggestions) { Write-Host ("  -{0}" -f $s.Name) -ForegroundColor Yellow }
            }
        }
    }

    if ($problem) {
        Write-Host ''
        Write-Host 'Run without arguments to see all available parameters.' -ForegroundColor DarkGray
    }
    return $problem
}

function Show-Usage {
    Write-Host ''
    Write-Host '===== Available parameters =====' -ForegroundColor Cyan
    Write-Host ('  {0,-34}{1,-9}{2}' -f 'Name', 'Type', 'Description') -ForegroundColor DarkGray
    foreach ($p in $ParameterInfo) {
        $active = $script:ScriptParameters.ContainsKey($p.Name)
        $marker = if ($active) { '*' } else { ' ' }
        $line = ('{0} {1,-32}{2,-9}{3}' -f $marker, "-$($p.Name)", $p.Type, $p.Description)
        if ($active) { Write-Host $line -ForegroundColor Yellow } else { Write-Host $line }
    }
    Write-Host ''
    Write-Host 'Examples:' -ForegroundColor DarkGray
    Write-Host '  .\clear-browser-and-windows-cache-v5.ps1 -Preview'
    Write-Host '  .\clear-browser-and-windows-cache-v5.ps1 -ClearBrowserCache'
    Write-Host '  .\clear-browser-and-windows-cache-v5.ps1 -ClearBrowserCache -ForceCloseBrowsers'
    Write-Host '  .\clear-browser-and-windows-cache-v5.ps1 -OlderThanDays 30 -IncludeWindowsUpdateCache'
    Write-Host '  .\clear-browser-and-windows-cache-v5.ps1 -DeepWindowsCache -Preview'
    Write-Host '  .\clear-browser-and-windows-cache-v5.ps1 -RebuildExplorerCache -ClearDeliveryOptimizationCache'
    Write-Host '  .\clear-browser-and-windows-cache-v5.ps1 -CleanupComponentStore -ResetBase'
    Write-Host '  .\clear-browser-and-windows-cache-v5.ps1 -Elevate -DeepWindowsCache -Force -Quiet -LogPath C:\logs\clean.log'
}

# #2 Warn about conflicting or meaningless option combinations.
function Show-CombinationWarnings {
    $notes = [System.Collections.Generic.List[string[]]]::new()

    if ($Preview -and $Force) {
        $notes.Add(@('Force has no effect while Preview is enabled.', 'Remove -Preview to perform actual cleanup.'))
    }
    if ($ForceCloseBrowsers -and -not $ClearBrowserCache) {
        $notes.Add(@('Browsers will be force-closed, but browser caches will NOT be cleared.', 'Add -ClearBrowserCache to also clear browser caches.'))
    }
    if ($Preview -and ($ClearBrowserCache -or $ForceCloseBrowsers)) {
        $notes.Add(@('Browsers are not closed in Preview mode.', 'Remove -Preview to actually close browsers and clear their caches.'))
    }
    if ($ResetBase -and -not $CleanupComponentStore) {
        $notes.Add(@('-ResetBase is ignored without -CleanupComponentStore.', 'Add -CleanupComponentStore to run the DISM cleanup with /ResetBase.'))
    }
    if ($ResetBase -and $CleanupComponentStore -and -not $Preview) {
        $notes.Add(@('/ResetBase makes installed Windows updates permanent (they can no longer be uninstalled).', 'Drop -ResetBase to keep the ability to roll back updates.'))
    }

    if ($notes.Count -eq 0) { return }

    Write-Host ''
    Write-Host 'WARNING' -ForegroundColor Yellow
    Write-Host '-------' -ForegroundColor Yellow
    foreach ($note in $notes) {
        Write-Host ''
        Write-Host ("- {0}" -f $note[0]) -ForegroundColor Yellow
        Write-Host ("  -> {0}" -f $note[1]) -ForegroundColor DarkGray
    }
}

function Resolve-SafeDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }

    try {
        $fullPath = [System.IO.Path]::GetFullPath($Path)
    }
    catch {
        Write-Warning "Invalid path skipped: $Path"
        return $null
    }

    $root = [System.IO.Path]::GetPathRoot($fullPath)
    if ($fullPath.TrimEnd('\') -eq $root.TrimEnd('\')) {
        Write-Warning "Drive root skipped: $fullPath"
        return $null
    }

    try {
        $exists = Test-Path -LiteralPath $fullPath -PathType Container -ErrorAction Stop
    }
    catch {
        Write-Warning "Cannot access path skipped: $fullPath"
        return $null
    }

    if (-not $exists) {
        return $null
    }

    return $fullPath
}

function Get-TargetStats {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string[]]$Include = @('*')
    )

    $files = Get-ChildItem -LiteralPath $Path -Include $Include -Recurse -Force -File -ErrorAction SilentlyContinue |
        Where-Object { -not $cutoff -or $_.LastWriteTime -lt $cutoff }

    $bytes = ($files | Measure-Object -Property Length -Sum).Sum
    if (-not $bytes) { $bytes = 0 }

    return [pscustomobject]@{
        Count = $files.Count
        Bytes = [long]$bytes
    }
}

function Add-CleanupTarget {
    param(
        [Parameter(Mandatory = $true)][string]$Category,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Path,
        [string[]]$Include = @('*')
    )

    $safePath = Resolve-SafeDirectory -Path $Path
    if (-not $safePath) { return }

    $stats = Get-TargetStats -Path $safePath -Include $Include
    $script:targets.Add([pscustomobject]@{
            Category = $Category
            Name     = $Name
            Path     = $safePath
            Include  = $Include
            Count    = $stats.Count
            Bytes    = $stats.Bytes
        })
}

function Add-WindowsTargets {
    Add-CleanupTarget -Category 'Windows' -Name 'Windows Temp' -Path "$env:WINDIR\Temp"
    Add-CleanupTarget -Category 'Windows' -Name 'User Temp' -Path $env:TEMP
    Add-CleanupTarget -Category 'Windows' -Name 'Windows Logs' -Path "$env:WINDIR\Logs" -Include @('*.log', '*.etl', '*.txt', '*.cab')
    Add-CleanupTarget -Category 'Windows' -Name 'Windows Debug Logs' -Path "$env:WINDIR\debug" -Include @('*.log', '*.txt', '*.dmp')
    Add-CleanupTarget -Category 'Windows' -Name 'System Log Files' -Path "$env:WINDIR\System32\LogFiles" -Include @('*.log', '*.etl', '*.txt')
    Add-CleanupTarget -Category 'Windows' -Name 'USO Logs' -Path "$env:ProgramData\USOShared\Logs\System" -Include @('*.etl', '*.log')
    Add-CleanupTarget -Category 'Windows' -Name 'Font Cache' -Path "$env:WINDIR\ServiceProfiles\LocalService\AppData\Local\FontCache" -Include @('*.dat')

    if ($IncludeWindowsUpdateCache) {
        Add-CleanupTarget -Category 'Windows' -Name 'Windows Update Downloads' -Path "$env:WINDIR\SoftwareDistribution\Download"
        Add-CleanupTarget -Category 'Windows' -Name 'Windows Update Logs' -Path "$env:WINDIR\SoftwareDistribution\DataStore\Logs" -Include @('*.log', '*.etl')
    }
}

# User traces / UX-affecting items. These are not pure caches: clearing them resets the
# thumbnail cache and wipes the "recent files" / jump lists. Opt-in via -ClearUserTraces.
function Add-UserTraceTargets {
    Add-CleanupTarget -Category 'UserTraces' -Name 'Explorer Thumbnail Cache' -Path "$HOME\AppData\Local\Microsoft\Windows\Explorer" -Include @('thumbcache_*.db', 'iconcache_*.db')
    Add-CleanupTarget -Category 'UserTraces' -Name 'Recent Item Shortcuts' -Path "$HOME\AppData\Roaming\Microsoft\Windows\Recent" -Include @('*.lnk')
    Add-CleanupTarget -Category 'UserTraces' -Name 'Jump List (Automatic)' -Path "$HOME\AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations" -Include @('*.automaticDestinations-ms')
    Add-CleanupTarget -Category 'UserTraces' -Name 'Jump List (Custom)' -Path "$HOME\AppData\Roaming\Microsoft\Windows\Recent\CustomDestinations" -Include @('*.customDestinations-ms')
}

# #5 Deep Windows system caches. Covers the "Windows System Cache" items:
# CryptnetUrlCache (across user/system/service profiles), D3DSCache / DirectX Shader
# Cache, and Windows Error Reporting. Windows Update + Delivery Optimization are enabled
# by promoting their flags in the main flow.
function Add-DeepWindowsTargets {
    $cryptnet = @(
        @{ Name = 'CryptnetUrlCache / User'; Path = "$HOME\AppData\LocalLow\Microsoft\CryptnetUrlCache" }
        @{ Name = 'CryptnetUrlCache / SystemProfile'; Path = "$env:WINDIR\System32\config\systemprofile\AppData\LocalLow\Microsoft\CryptnetUrlCache" }
        @{ Name = 'CryptnetUrlCache / LocalService'; Path = "$env:WINDIR\ServiceProfiles\LocalService\AppData\LocalLow\Microsoft\CryptnetUrlCache" }
        @{ Name = 'CryptnetUrlCache / NetworkService'; Path = "$env:WINDIR\ServiceProfiles\NetworkService\AppData\LocalLow\Microsoft\CryptnetUrlCache" }
    )
    foreach ($c in $cryptnet) {
        Add-CleanupTarget -Category 'DeepCache' -Name $c.Name -Path $c.Path
    }

    Add-CleanupTarget -Category 'DeepCache' -Name 'D3DSCache (DirectX Shader Cache)' -Path "$env:LOCALAPPDATA\D3DSCache"

    $wer = @(
        @{ Name = 'WER / ReportQueue (User)'; Path = "$HOME\AppData\Local\Microsoft\Windows\WER\ReportQueue" }
        @{ Name = 'WER / ReportArchive (User)'; Path = "$HOME\AppData\Local\Microsoft\Windows\WER\ReportArchive" }
        @{ Name = 'WER / ReportQueue (System)'; Path = "$env:ProgramData\Microsoft\Windows\WER\ReportQueue" }
        @{ Name = 'WER / ReportArchive (System)'; Path = "$env:ProgramData\Microsoft\Windows\WER\ReportArchive" }
        @{ Name = 'WER / Temp (System)'; Path = "$env:ProgramData\Microsoft\Windows\WER\Temp" }
    )
    foreach ($w in $wer) {
        Add-CleanupTarget -Category 'DeepCache' -Name $w.Name -Path $w.Path
    }
}

function Add-FirefoxTargets {
    $profilesRoot = Join-Path $env:LOCALAPPDATA 'Mozilla\Firefox\Profiles'
    $cacheNames = @('cache2', 'startupCache', 'thumbnails', 'jumpListCache')

    if (-not (Test-Path -LiteralPath $profilesRoot -PathType Container)) { return }

    foreach ($profile in Get-ChildItem -LiteralPath $profilesRoot -Directory -ErrorAction SilentlyContinue) {
        foreach ($cacheName in $cacheNames) {
            Add-CleanupTarget -Category 'Firefox' -Name "$($profile.Name) / $cacheName" -Path (Join-Path $profile.FullName $cacheName)
        }
    }
}

function Add-ChromiumProfileTargets {
    param(
        [Parameter(Mandatory = $true)][string]$Browser,
        [Parameter(Mandatory = $true)][string]$UserDataPath
    )

    if (-not (Test-Path -LiteralPath $UserDataPath -PathType Container)) { return }

    $profileDirs = Get-ChildItem -LiteralPath $UserDataPath -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq 'Default' -or $_.Name -eq 'Guest Profile' -or $_.Name -match '^Profile \d+$' }

    foreach ($profile in $profileDirs) {
        $profileName = $profile.Name
        $relativeTargets = @(
            'Cache\Cache_Data',
            'Code Cache\js',
            'Code Cache\wasm',
            'GPUCache',
            'GrShaderCache',
            'ShaderCache',
            'Media Cache',
            'Service Worker\CacheStorage',
            'Service Worker\ScriptCache'
        )

        foreach ($relativePath in $relativeTargets) {
            Add-CleanupTarget -Category $Browser -Name "$profileName / $relativePath" -Path (Join-Path $profile.FullName $relativePath)
        }
    }
}

function Add-OperaTargets {
    $roots = @(
        (Join-Path $env:LOCALAPPDATA 'Opera Software\Opera Stable'),
        (Join-Path $env:APPDATA 'Opera Software\Opera Stable')
    ) | Select-Object -Unique

    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }

        $relativeTargets = @(
            'Default\Cache\Cache_Data',
            'Default\Code Cache\js',
            'Default\Code Cache\wasm',
            'Default\GPUCache',
            'Default\Service Worker\CacheStorage',
            'Default\Service Worker\ScriptCache',
            'Cache\Cache_Data',
            'Code Cache\js',
            'GPUCache',
            'Service Worker\CacheStorage',
            'Service Worker\ScriptCache'
        )

        foreach ($relativePath in $relativeTargets) {
            Add-CleanupTarget -Category 'Opera' -Name $relativePath -Path (Join-Path $root $relativePath)
        }
    }
}

function Add-BrowserTargets {
    Add-FirefoxTargets
    Add-ChromiumProfileTargets -Browser 'Chrome' -UserDataPath (Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data')
    Add-ChromiumProfileTargets -Browser 'Edge' -UserDataPath (Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data')
    Add-ChromiumProfileTargets -Browser 'Brave' -UserDataPath (Join-Path $env:LOCALAPPDATA 'BraveSoftware\Brave-Browser\User Data')
    Add-ChromiumProfileTargets -Browser 'Vivaldi' -UserDataPath (Join-Path $env:LOCALAPPDATA 'Vivaldi\User Data')
    Add-OperaTargets
}

# Friendly display name -> process name.
$script:BrowserProcessMap = [ordered]@{
    Chrome  = 'chrome'
    Edge    = 'msedge'
    Firefox = 'firefox'
    Brave   = 'brave'
    Opera   = 'opera'
    Vivaldi = 'vivaldi'
}

# #6/#7 Close browsers. Default is graceful (CloseMainWindow, wait, then force the
# leftovers). -ForceCloseBrowsers kills immediately.
function Stop-BrowserProcesses {
    param([switch]$ForceOnly)

    Write-Host ''
    Write-Host 'Closing browsers...' -ForegroundColor Cyan

    $anyRunning = $false

    foreach ($display in $script:BrowserProcessMap.Keys) {
        $procName = $script:BrowserProcessMap[$display]
        $procs = Get-Process -Name $procName -ErrorAction SilentlyContinue
        if (-not $procs) { continue }
        $anyRunning = $true

        if ($ForceOnly) {
            $procs | Stop-Process -Force -ErrorAction SilentlyContinue
            $result = if (Get-Process -Name $procName -ErrorAction SilentlyContinue) { 'FAILED' } else { 'OK' }
            Write-Host ('  {0,-10} Force kill... {1}' -f $display, $result)
            continue
        }

        # Step 1: graceful shutdown request.
        foreach ($p in $procs) {
            try { $null = $p.CloseMainWindow() } catch { }
        }

        $timeout = 10
        while ($timeout -gt 0 -and (Get-Process -Name $procName -ErrorAction SilentlyContinue)) {
            Start-Sleep -Seconds 1
            $timeout--
        }

        if (-not (Get-Process -Name $procName -ErrorAction SilentlyContinue)) {
            Write-Host ('  {0,-10} Graceful shutdown... OK' -f $display)
            continue
        }

        # Step 2: force-kill whatever survived.
        Write-Host ('  {0,-10} Graceful shutdown... Timeout' -f $display) -ForegroundColor Yellow
        Get-Process -Name $procName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        $result = if (Get-Process -Name $procName -ErrorAction SilentlyContinue) { 'FAILED' } else { 'OK' }
        Write-Host ('  {0,-10} Force kill... {1}' -f $display, $result)
    }

    if (-not $anyRunning) {
        Write-Host '  (no supported browsers were running)' -ForegroundColor DarkGray
    }
}

function Stop-ServiceSet {
    param([string[]]$Names)

    $stopped = @()
    foreach ($serviceName in $Names) {
        try {
            $service = Get-Service -Name $serviceName -ErrorAction Stop
            if ($service.Status -ne 'Stopped') {
                Write-Host "Stopping service: $serviceName" -ForegroundColor Yellow
                Stop-Service -Name $serviceName -Force -ErrorAction Stop
                $stopped += $serviceName
            }
        }
        catch {
            Write-Warning "Could not stop service $serviceName`: $($_.Exception.Message)"
        }
    }
    return $stopped
}

function Start-ServiceSet {
    param([string[]]$Names)

    foreach ($serviceName in $Names) {
        try {
            Write-Host "Starting service: $serviceName" -ForegroundColor Yellow
            Start-Service -Name $serviceName -ErrorAction Stop
        }
        catch {
            Write-Warning "Could not restart service $serviceName`: $($_.Exception.Message)"
        }
    }
}

function Invoke-ExplorerCacheRebuild {
    $explorerCachePath = Resolve-SafeDirectory -Path (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer')
    if (-not $explorerCachePath) {
        Write-Warning 'Explorer cache folder was not found or could not be accessed.'
        return [pscustomobject]@{ Deleted = 0; Skipped = 0; Freed = 0L }
    }

    Write-Host 'Restarting Explorer and rebuilding thumbnail/icon cache...' -ForegroundColor Cyan

    try {
        Get-Process -Name explorer -ErrorAction SilentlyContinue |
            Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
    catch {
        Write-Warning "Could not stop Explorer: $($_.Exception.Message)"
    }

    $deleted = 0
    $skipped = 0
    $freed = 0L
    $patterns = @('thumbcache_*.db', 'iconcache_*.db')

    foreach ($pattern in $patterns) {
        Get-ChildItem -LiteralPath $explorerCachePath -Filter $pattern -Force -File -ErrorAction SilentlyContinue |
            Sort-Object FullName -Unique |
            ForEach-Object {
                $len = $_.Length
                try {
                    Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop
                    $deleted++
                    $freed += $len
                }
                catch {
                    $skipped++
                }
            }
    }

    try {
        Start-Process explorer -ErrorAction Stop
    }
    catch {
        Write-Warning "Could not restart Explorer: $($_.Exception.Message)"
    }

    return [pscustomobject]@{
        Deleted = $deleted
        Skipped = $skipped
        Freed   = $freed
    }
}

function Get-DoCacheSnapshot {
    try {
        $snap = Get-DeliveryOptimizationPerfSnap -ErrorAction Stop -WarningAction SilentlyContinue
    }
    catch {
        return [pscustomobject]@{ Files = 0; Bytes = 0L }
    }

    $files = [int]($snap.Files | Select-Object -First 1)
    $bytes = [long]($snap.CacheSizeBytes | Select-Object -First 1)
    return [pscustomobject]@{ Files = $files; Bytes = $bytes }
}

# Classify why a delete failed, so the fallback can explain each skipped file (#4).
function Get-SkipReason {
    param($ErrorRecord, [bool]$DoServiceRunning)

    $ex = $ErrorRecord.Exception
    if ($ex -is [System.UnauthorizedAccessException]) { return 'Access denied' }
    if ($ex -is [System.IO.IOException]) {
        return $(if ($DoServiceRunning) { 'Locked by DoSvc' } else { 'Locked (in use)' })
    }
    return $ex.GetType().Name
}

function Invoke-DeliveryOptimizationCacheCleanup {
    if (-not (Test-IsAdministrator)) {
        Write-Warning 'Delivery Optimization cache cleanup works best as Administrator.'
    }

    Write-Host ''
    Write-Host 'Cleaning Delivery Optimization cache...' -ForegroundColor Cyan

    # Preferred path: the supported DeliveryOptimization module cmdlet. It resolves the
    # real cache location (which is version/policy dependent and often NOT the legacy
    # NetworkService path), and clears files whose NetworkService/SYSTEM-owned ACLs make
    # a plain Remove-Item fail with access-denied. Manual deletion is only a fallback.
    if (Get-Command Delete-DeliveryOptimizationCache -ErrorAction SilentlyContinue) {
        if ($cutoff) {
            Write-Warning ("Delete-DeliveryOptimizationCache has no age filter; the -OlderThanDays {0} setting is ignored and the entire DO cache is cleared." -f $OlderThanDays)
        }

        $before = Get-DoCacheSnapshot
        try {
            Delete-DeliveryOptimizationCache -Force -ErrorAction Stop
        }
        catch {
            Write-Warning "Delete-DeliveryOptimizationCache failed: $($_.Exception.Message)"
            return [pscustomobject]@{ Deleted = 0; Skipped = 0; Freed = 0L }
        }
        $after = Get-DoCacheSnapshot

        $deleted = [Math]::Max(0, $before.Files - $after.Files)
        Write-Host ("Deleted : {0}" -f $deleted)
        Write-Host 'Skipped : 0'
        return [pscustomobject]@{
            Deleted = $deleted
            Skipped = 0
            Freed   = [long][Math]::Max(0L, $before.Bytes - $after.Bytes)
        }
    }

    # --- Fallback: legacy manual file deletion (may be blocked by folder ACLs) ---
    Write-Warning 'Delete-DeliveryOptimizationCache cmdlet not available; falling back to manual file deletion.'

    $cachePath = Resolve-SafeDirectory -Path "$env:WINDIR\ServiceProfiles\NetworkService\AppData\Local\Microsoft\DeliveryOptimization\Cache"
    if (-not $cachePath) {
        Write-Warning 'Delivery Optimization cache folder was not found or could not be accessed.'
        return [pscustomobject]@{ Deleted = 0; Skipped = 0; Freed = 0L }
    }

    # Stop the services that keep handles on the DO cache. WaaSMedicSvc is protected and
    # often refuses to stop; that is fine, it is best-effort.
    $doServices = @('DoSvc', 'BITS', 'UsoSvc', 'WaaSMedicSvc')
    $stopped = Stop-ServiceSet -Names $doServices
    $doStillRunning = [bool](Get-Service -Name DoSvc -ErrorAction SilentlyContinue |
            Where-Object { $_.Status -ne 'Stopped' })

    $deleted = 0
    $skipped = 0
    $freed = 0L
    $skippedFiles = [System.Collections.Generic.List[object]]::new()

    Get-ChildItem -LiteralPath $cachePath -Recurse -Force -File -ErrorAction SilentlyContinue |
        Where-Object { -not $cutoff -or $_.LastWriteTime -lt $cutoff } |
        ForEach-Object {
            $file = $_
            $len = $file.Length
            try {
                Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                $deleted++
                $freed += $len
            }
            catch {
                $skipped++
                $skippedFiles.Add([pscustomobject]@{
                        Name   = $file.Name
                        Reason = (Get-SkipReason -ErrorRecord $_ -DoServiceRunning $doStillRunning)
                    })
            }
        }

    # Remove directories left empty (deepest first).
    Get-ChildItem -LiteralPath $cachePath -Recurse -Force -Directory -ErrorAction SilentlyContinue |
        Sort-Object { $_.FullName.Length } -Descending |
        ForEach-Object {
            if (-not (Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue)) {
                try { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop } catch { }
            }
        }

    Start-ServiceSet -Names $stopped

    Write-Host ("Deleted : {0}" -f $deleted)
    Write-Host ("Skipped : {0}" -f $skipped)

    if ($skippedFiles.Count -gt 0) {
        Write-Host ''
        Write-Host 'Skipped files' -ForegroundColor Yellow
        $shown = 0
        foreach ($sf in $skippedFiles) {
            if ($shown -ge 30) {
                Write-Host ("  ... and {0} more" -f ($skippedFiles.Count - $shown)) -ForegroundColor DarkGray
                break
            }
            Write-Host ("  {0} ({1})" -f $sf.Name, $sf.Reason)
            $shown++
        }
    }

    return [pscustomobject]@{
        Deleted = $deleted
        Skipped = $skipped
        Freed   = $freed
    }
}

function Remove-TargetContents {
    param([Parameter(Mandatory = $true)]$Target)

    $deleted = 0
    $skipped = 0
    $freed = 0L

    # Delete matching files only. The age filter is applied per file, never via a
    # parent directory's -Recurse (which would wipe newer files inside an old folder).
    Get-ChildItem -LiteralPath $Target.Path -Include $Target.Include -Recurse -Force -File -ErrorAction SilentlyContinue |
        Where-Object { -not $cutoff -or $_.LastWriteTime -lt $cutoff } |
        ForEach-Object {
            $len = $_.Length
            try {
                Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop
                $deleted++
                $freed += $len
            }
            catch {
                $skipped++
            }
        }

    # For wildcard-all targets, remove directories left empty (deepest first).
    # Non-empty directories are kept, so any file that survived the age filter stays.
    if ($Target.Include.Count -eq 1 -and $Target.Include[0] -eq '*') {
        Get-ChildItem -LiteralPath $Target.Path -Recurse -Force -Directory -ErrorAction SilentlyContinue |
            Sort-Object { $_.FullName.Length } -Descending |
            ForEach-Object {
                if (-not (Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue)) {
                    try { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop } catch { }
                }
            }
    }

    return [pscustomobject]@{
        Deleted = $deleted
        Skipped = $skipped
        Freed   = $freed
    }
}

# ------------------------------- main flow -------------------------------

# #1 Reject typos before doing anything else.
if (Test-UnknownArguments) {
    Complete-Run 2
}

# #5 If requested and not already elevated, relaunch as Administrator and hand off.
if ($Elevate -and -not (Test-IsAdministrator)) {
    Write-Host 'Relaunching as Administrator (output appears in the elevated window)...' -ForegroundColor Cyan
    try {
        Invoke-SelfElevation
        Complete-Run 0
    }
    catch {
        Write-Warning "Elevation was cancelled or failed: $($_.Exception.Message)"
        Write-Warning 'Continuing without Administrator rights.'
    }
}
elseif ($Elevate) {
    Write-Host 'Already running as Administrator; -Elevate not needed.' -ForegroundColor DarkGray
}

# #2 Start the audit transcript as early as possible so warnings are captured too.
if ($LogPath) {
    try {
        $logDir = Split-Path -Path $LogPath -Parent
        if ($logDir -and -not (Test-Path -LiteralPath $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        Start-Transcript -Path $LogPath -Append -ErrorAction Stop | Out-Null
        $script:TranscriptActive = $true
    }
    catch {
        Write-Warning "Could not start log transcript at '$LogPath': $($_.Exception.Message)"
    }
}

# #5 DeepWindowsCache promotes the Windows Update and Delivery Optimization flags so the
# existing target-building and post-cleanup steps pick them up.
if ($DeepWindowsCache) {
    $IncludeWindowsUpdateCache = $true
    $ClearDeliveryOptimizationCache = $true
}

if (-not (Test-IsAdministrator)) {
    Write-Warning 'Not running as Administrator. Some Windows targets may be skipped or partially cleaned.'
}

# #3 Record free space before doing anything.
$freeBefore = Get-FreeSpaceBytes

if (-not $Quiet) { Show-Usage }

# #2 Point out conflicting / meaningless option combinations.
Show-CombinationWarnings

Add-WindowsTargets
if ($DeepWindowsCache) { Add-DeepWindowsTargets }
# User traces (thumbnail cache, recent items, jump lists) are opt-in.
if ($ClearUserTraces) { Add-UserTraceTargets }
# Browser caches are only touched when -ClearBrowserCache is given.
if ($ClearBrowserCache) { Add-BrowserTargets }

$targets = $targets |
    Sort-Object Category, Name, Path -Unique |
    Where-Object { $_.Count -gt 0 }

Write-Host ''
Write-Host '===== Browser + Windows cache cleanup summary =====' -ForegroundColor Cyan
if ($cutoff) {
    Write-Host ("Filter: older than {0} day(s)" -f $OlderThanDays) -ForegroundColor DarkGray
}

$totalCount = 0
$totalBytes = 0L
foreach ($target in $targets) {
    Write-Host ('  {0,-10} {1,8} files  {2,12}   {3}' -f $target.Category, $target.Count, (Format-Size $target.Bytes), $target.Name)
    $totalCount += $target.Count
    $totalBytes += $target.Bytes
}

# #1 Delivery Optimization is cleared via cmdlet, not the file scan, so its size is missing
# from the table above. Query it and include it so the TOTAL is honest.
if ($ClearDeliveryOptimizationCache) {
    $doSummary = Get-DoCacheSnapshot
    if ($doSummary.Files -gt 0 -or $doSummary.Bytes -gt 0) {
        Write-Host ('  {0,-10} {1,8} files  {2,12}   {3}' -f 'DO', $doSummary.Files, (Format-Size $doSummary.Bytes), 'Delivery Optimization (cleared via cmdlet)')
        $totalCount += $doSummary.Files
        $totalBytes += $doSummary.Bytes
    }
}

Write-Host ('  {0}' -f ('-' * 76)) -ForegroundColor DarkGray
Write-Host ('  {0,-10} {1,8} files  {2,12}   TOTAL' -f '', $totalCount, (Format-Size $totalBytes)) -ForegroundColor Yellow
if ($RebuildExplorerCache -or $ClearDeliveryOptimizationCache -or $EmptyRecycleBin -or $CleanupComponentStore -or $RunDiskCleanup) {
    Write-Host ''
    Write-Host 'Additional actions after confirmation:' -ForegroundColor Cyan
    if ($RebuildExplorerCache) { Write-Host '  - Restart Explorer and rebuild thumbnail/icon cache.' }
    if ($ClearDeliveryOptimizationCache) { Write-Host '  - Clear Windows Delivery Optimization cache.' }
    if ($EmptyRecycleBin) { Write-Host '  - Empty Recycle Bin.' }
    if ($CleanupComponentStore) {
        if ($ResetBase) {
            Write-Host '  - Run DISM component store cleanup with /ResetBase (installed updates become permanent).'
        }
        else {
            Write-Host '  - Run DISM component store cleanup.'
        }
    }
    if ($RunDiskCleanup) { Write-Host '  - Run Windows Disk Cleanup (cleanmgr /sagerun:100).' }
}
Write-Host ''

if ($totalCount -eq 0 -and -not $EmptyRecycleBin -and -not $CleanupComponentStore -and -not $RunDiskCleanup -and -not $RebuildExplorerCache -and -not $ClearDeliveryOptimizationCache) {
    Write-Host 'Nothing to delete.' -ForegroundColor Green
    Complete-Run 0
}

if ($Preview) {
    Write-Host '[Preview] No files were deleted.' -ForegroundColor Magenta
    Write-Host "Recycle Bin cleanup: $EmptyRecycleBin"
    Write-Host "Component Store cleanup: $CleanupComponentStore"
    Write-Host "Component Store /ResetBase: $ResetBase"
    Write-Host "Disk Cleanup: $RunDiskCleanup"
    Write-Host "Explorer cache rebuild: $RebuildExplorerCache"
    Write-Host "Delivery Optimization cache cleanup: $ClearDeliveryOptimizationCache"
    Write-Host "Deep Windows cache cleanup: $DeepWindowsCache"
    Write-Host "Browser cache cleanup: $ClearBrowserCache"
    Write-Host "User traces cleanup: $ClearUserTraces"
    Complete-Run 0
}

if (-not $Force) {
    $answer = Read-Host 'Proceed with cleanup? (Y/N)'
    if ($answer -notmatch '^(y|yes)$') {
        Write-Host 'Cancelled.' -ForegroundColor Yellow
        Complete-Run 1
    }
}

if ($ForceCloseBrowsers) {
    Stop-BrowserProcesses -ForceOnly
}
elseif ($ClearBrowserCache) {
    Stop-BrowserProcesses
}

$stoppedServices = @()
if ($IncludeWindowsUpdateCache) {
    if (Test-IsAdministrator) {
        $stoppedServices = Stop-ServiceSet -Names @('bits', 'wuauserv')
    }
    else {
        Write-Warning 'Windows Update cache cleanup works best as Administrator.'
    }
}

$deletedTotal = 0
$skippedTotal = 0
$freedTotal = 0L

foreach ($target in $targets) {
    if (-not $Quiet) { Write-Host "Cleaning: [$($target.Category)] $($target.Name)" -ForegroundColor Yellow }
    $result = Remove-TargetContents -Target $target
    $deletedTotal += $result.Deleted
    $skippedTotal += $result.Skipped
    $freedTotal += $result.Freed
}

Start-ServiceSet -Names $stoppedServices

if ($ClearDeliveryOptimizationCache) {
    $result = Invoke-DeliveryOptimizationCacheCleanup
    $deletedTotal += $result.Deleted
    $skippedTotal += $result.Skipped
    $freedTotal += $result.Freed
}

if ($RebuildExplorerCache) {
    $result = Invoke-ExplorerCacheRebuild
    $deletedTotal += $result.Deleted
    $skippedTotal += $result.Skipped
    $freedTotal += $result.Freed
}

if ($EmptyRecycleBin) {
    try {
        Write-Host 'Emptying Recycle Bin...' -ForegroundColor Yellow
        Clear-RecycleBin -Confirm:$false -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to empty Recycle Bin: $($_.Exception.Message)"
    }
}

if ($CleanupComponentStore) {
    if (-not (Test-IsAdministrator)) {
        Write-Warning 'Component Store cleanup requires Administrator. Skipped.'
    }
    else {
        # /ResetBase drops ALL superseded components (no 30-day grace). It frees more space
        # but installed updates can no longer be uninstalled, so it stays opt-in.
        $dismArgs = @('/Online', '/Cleanup-Image', '/StartComponentCleanup')
        if ($ResetBase) {
            $dismArgs += '/ResetBase'
            Write-Warning 'Using /ResetBase: installed Windows updates can no longer be uninstalled.'
            Write-Host 'Cleaning Windows Component Store (DISM /ResetBase, this can take a while)...' -ForegroundColor Cyan
        }
        else {
            Write-Host 'Cleaning Windows Component Store (DISM)...' -ForegroundColor Cyan
        }

        & dism.exe @dismArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "DISM returned exit code $LASTEXITCODE."
        }
    }
}

if ($RunDiskCleanup) {
    try {
        Write-Host 'Running Windows Disk Cleanup (cleanmgr /sagerun:100)...' -ForegroundColor Cyan
        Write-Host 'Tip: configure this once with cleanmgr /sageset:100 if you have not already.' -ForegroundColor DarkGray
        Start-Process cleanmgr -ArgumentList '/sagerun:100' -Wait -NoNewWindow -ErrorAction Stop
    }
    catch {
        Write-Warning "Windows Disk Cleanup failed: $($_.Exception.Message)"
    }
}

# #3 Report disk free space before/after.
$freeAfter = Get-FreeSpaceBytes
$freeDelta = [long][Math]::Max(0L, $freeAfter - $freeBefore)

Write-Host ''
Write-Host '===== Cleanup Complete =====' -ForegroundColor Green
Write-Host ('  Deleted {0} files, freed {1}. Skipped {2} locked/in-use item(s).' -f $deletedTotal, (Format-Size $freedTotal), $skippedTotal) -ForegroundColor Green
Write-Host ('  {0} free space: {1} -> {2} (reclaimed {3})' -f $env:SystemDrive, (Format-Size $freeBefore), (Format-Size $freeAfter), (Format-Size $freeDelta)) -ForegroundColor Green

Complete-Run 0
