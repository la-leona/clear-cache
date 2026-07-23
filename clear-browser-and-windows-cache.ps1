<#
.SYNOPSIS
    Clears Windows temporary files plus Firefox and common browser caches.

.DESCRIPTION
    Combines the Windows junk sweep and Firefox cache cleanup flow:
      1. Finds Windows temp/log targets.
      2. Finds Firefox profile caches.
      3. Finds common Chromium-based browser caches: Edge, Chrome, Brave, Opera, Vivaldi.
      4. Shows a count/size summary first.
      5. Deletes after confirmation unless -Force is used.

    Close browsers first for the best result, or use -CloseBrowsers.
    Run as Administrator to clean C:\Windows targets.

.PARAMETER OlderThanDays
    Only delete files older than N days. Default 0 = all cache/temp files.

.PARAMETER Preview
    Show the summary only. No files are deleted.

.PARAMETER Force
    Skip the confirmation prompt.

.PARAMETER CloseBrowsers
    Stop supported browser processes before deleting cache files.

.PARAMETER IncludeWindowsUpdateCache
    Include Windows Update download/log cache. Requires Administrator for best results.

.PARAMETER EmptyRecycleBin
    Empty the Recycle Bin after cache cleanup.

.PARAMETER CleanupComponentStore
    Run DISM /StartComponentCleanup after file cleanup. Requires Administrator.

.PARAMETER RunDiskCleanup
    Run cleanmgr /sagerun:100 after file cleanup. Configure it first with cleanmgr /sageset:100.

.PARAMETER RebuildExplorerCache
    Restart Explorer and delete Explorer thumbnail/icon cache databases after confirmation.

.PARAMETER ClearDeliveryOptimizationCache
    Clear Windows Delivery Optimization cache after confirmation. Requires Administrator for best results.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File C:\opt\bin\clear-browser-and-windows-cache.ps1 -Preview

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File C:\opt\bin\clear-browser-and-windows-cache.ps1 -Force -CloseBrowsers
#>

[CmdletBinding()]
param(
    [int]$OlderThanDays = 0,
    [switch]$Preview,
    [switch]$Force,
    [switch]$CloseBrowsers,
    [switch]$IncludeWindowsUpdateCache,
    [switch]$EmptyRecycleBin,
    [switch]$CleanupComponentStore,
    [switch]$RunDiskCleanup,
    [switch]$RebuildExplorerCache,
    [switch]$ClearDeliveryOptimizationCache
)

$ErrorActionPreference = 'Stop'
$cutoff = if ($OlderThanDays -gt 0) { (Get-Date).AddDays(-$OlderThanDays) } else { $null }
$targets = [System.Collections.Generic.List[object]]::new()
$ScriptParameters = $PSBoundParameters

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

function Write-ParameterLine {
    param(
        [string]$Name,
        [string]$Description
    )

    if ($script:ScriptParameters.ContainsKey($Name)) {
        Write-Host ("* {0,-30} {1}" -f "-$Name", $Description) `
            -ForegroundColor Yellow
    }
    else {
        Write-Host ("  {0,-30} {1}" -f "-$Name", $Description)
    }
}

function Show-Usage {
    Write-Host ''
    Write-Host '===== Available parameters =====' -ForegroundColor Cyan
    Write-ParameterLine "Preview" "Show summary only; do not delete files."
    Write-ParameterLine "Force" "Skip the confirmation prompt."
    Write-ParameterLine "CloseBrowsers" "Close Firefox/Chrome/Edge/Brave/Opera/Vivaldi before cleanup."
    Write-ParameterLine "OlderThanDays" "Delete only files older than N days."
    Write-ParameterLine "IncludeWindowsUpdateCache" "Include Windows Update download/log cache."
    Write-ParameterLine "EmptyRecycleBin" "Empty the Recycle Bin."
    Write-ParameterLine "CleanupComponentStore" "Run DISM component store cleanup."
    Write-ParameterLine "RunDiskCleanup" "Run cleanmgr /sagerun:100."
    Write-ParameterLine "RebuildExplorerCache" "Restart Explorer and rebuild thumbnail/icon cache."
    Write-ParameterLine "ClearDeliveryOptimizationCache" "Clear Delivery Optimization cache."
    Write-Host ''
    Write-Host 'Examples:' -ForegroundColor DarkGray
    Write-Host '  .\clear-browser-and-windows-cache.ps1 -Preview'
    Write-Host '  .\clear-browser-and-windows-cache.ps1 -Force -CloseBrowsers'
    Write-Host '  .\clear-browser-and-windows-cache.ps1 -OlderThanDays 30 -IncludeWindowsUpdateCache'
    Write-Host '  .\clear-browser-and-windows-cache.ps1 -RunDiskCleanup'
    Write-Host '  .\clear-browser-and-windows-cache.ps1 -RebuildExplorerCache -ClearDeliveryOptimizationCache'
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
    Add-CleanupTarget -Category 'Windows' -Name 'Explorer Thumbnail Cache' -Path "$HOME\AppData\Local\Microsoft\Windows\Explorer" -Include @('thumbcache_*.db', 'iconcache_*.db')
    Add-CleanupTarget -Category 'Windows' -Name 'Recent Item Shortcuts' -Path "$HOME\AppData\Roaming\Microsoft\Windows\Recent" -Include @('*.lnk')
    Add-CleanupTarget -Category 'Windows' -Name 'Font Cache' -Path "$env:WINDIR\ServiceProfiles\LocalService\AppData\Local\FontCache" -Include @('*.dat')

    if ($IncludeWindowsUpdateCache) {
        Add-CleanupTarget -Category 'Windows' -Name 'Windows Update Downloads' -Path "$env:WINDIR\SoftwareDistribution\Download"
        Add-CleanupTarget -Category 'Windows' -Name 'Windows Update Logs' -Path "$env:WINDIR\SoftwareDistribution\DataStore\Logs" -Include @('*.log', '*.etl')
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

function Stop-BrowserProcesses {
    $processNames = @('firefox', 'chrome', 'msedge', 'brave', 'opera', 'vivaldi')
    foreach ($processName in $processNames) {
        $procs = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if (-not $procs) { continue }

        Write-Host "Closing $processName ($($procs.Count) process(es))..." -ForegroundColor Yellow
        $procs | Stop-Process -Force -ErrorAction SilentlyContinue
    }

    Start-Sleep -Seconds 2
}

function Stop-WindowsUpdateServices {
    if (-not $IncludeWindowsUpdateCache) { return @() }
    if (-not (Test-IsAdministrator)) {
        Write-Warning "Windows Update cache cleanup works best as Administrator."
        return @()
    }

    $stopped = @()
    foreach ($serviceName in @('bits', 'wuauserv')) {
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

function Start-WindowsUpdateServices {
    param([string[]]$ServiceNames)

    foreach ($serviceName in $ServiceNames) {
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

function Invoke-DeliveryOptimizationCacheCleanup {
    if (-not (Test-IsAdministrator)) {
        Write-Warning 'Delivery Optimization cache cleanup works best as Administrator.'
    }

    # Preferred path: the supported DeliveryOptimization module cmdlet. It resolves the
    # real cache location (which is version/policy dependent and often NOT the legacy
    # NetworkService path), and clears files whose NetworkService/SYSTEM-owned ACLs make
    # a plain Remove-Item fail with access-denied. Manual deletion is only a fallback.
    if (Get-Command Delete-DeliveryOptimizationCache -ErrorAction SilentlyContinue) {
        if ($cutoff) {
            Write-Warning ("Delete-DeliveryOptimizationCache has no age filter; the -OlderThanDays {0} setting is ignored and the entire DO cache is cleared." -f $OlderThanDays)
        }

        Write-Host 'Clearing Delivery Optimization cache (Delete-DeliveryOptimizationCache)...' -ForegroundColor Cyan

        $before = Get-DoCacheSnapshot
        try {
            Delete-DeliveryOptimizationCache -Force -ErrorAction Stop
        }
        catch {
            Write-Warning "Delete-DeliveryOptimizationCache failed: $($_.Exception.Message)"
            return [pscustomobject]@{ Deleted = 0; Skipped = 0; Freed = 0L }
        }
        $after = Get-DoCacheSnapshot

        return [pscustomobject]@{
            Deleted = [Math]::Max(0, $before.Files - $after.Files)
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

    $stoppedService = $false
    try {
        $service = Get-Service -Name DoSvc -ErrorAction Stop
        if ($service.Status -ne 'Stopped') {
            Write-Host 'Stopping service: DoSvc' -ForegroundColor Yellow
            Stop-Service -Name DoSvc -Force -ErrorAction Stop
            $stoppedService = $true
        }
    }
    catch {
        Write-Warning "Could not stop service DoSvc: $($_.Exception.Message)"
    }

    Write-Host 'Clearing Delivery Optimization cache...' -ForegroundColor Cyan

    $deleted = 0
    $skipped = 0
    $freed = 0L

    # Files first, with the age filter applied per file (see Remove-TargetContents).
    Get-ChildItem -LiteralPath $cachePath -Recurse -Force -File -ErrorAction SilentlyContinue |
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

    # Then any directories left empty (deepest first).
    Get-ChildItem -LiteralPath $cachePath -Recurse -Force -Directory -ErrorAction SilentlyContinue |
        Sort-Object { $_.FullName.Length } -Descending |
        ForEach-Object {
            if (-not (Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue)) {
                try { Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop } catch { }
            }
        }

    if ($stoppedService) {
        try {
            Write-Host 'Starting service: DoSvc' -ForegroundColor Yellow
            Start-Service -Name DoSvc -ErrorAction Stop
        }
        catch {
            Write-Warning "Could not restart service DoSvc: $($_.Exception.Message)"
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

if (-not (Test-IsAdministrator)) {
    Write-Warning 'Not running as Administrator. Some Windows targets may be skipped or partially cleaned.'
}

Show-Usage

$runningBrowsers = Get-Process -Name firefox, chrome, msedge, brave, opera, vivaldi -ErrorAction SilentlyContinue
if ($runningBrowsers) {
    if ($CloseBrowsers) {
        Write-Warning 'One or more browsers are running. They will be closed only after you confirm cleanup.'
    }
    else {
        Write-Warning 'One or more browsers are running. Locked cache files will be skipped. Use -CloseBrowsers for a fuller clean.'
    }
}

Add-WindowsTargets
Add-BrowserTargets

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

Write-Host ('  {0}' -f ('-' * 76)) -ForegroundColor DarkGray
Write-Host ('  {0,-10} {1,8} files  {2,12}   TOTAL' -f '', $totalCount, (Format-Size $totalBytes)) -ForegroundColor Yellow
if ($RebuildExplorerCache -or $ClearDeliveryOptimizationCache -or $EmptyRecycleBin -or $CleanupComponentStore -or $RunDiskCleanup) {
    Write-Host ''
    Write-Host 'Additional actions after confirmation:' -ForegroundColor Cyan
    if ($RebuildExplorerCache) { Write-Host '  - Restart Explorer and rebuild thumbnail/icon cache.' }
    if ($ClearDeliveryOptimizationCache) { Write-Host '  - Clear Windows Delivery Optimization cache.' }
    if ($EmptyRecycleBin) { Write-Host '  - Empty Recycle Bin.' }
    if ($CleanupComponentStore) { Write-Host '  - Run DISM component store cleanup.' }
    if ($RunDiskCleanup) { Write-Host '  - Run Windows Disk Cleanup (cleanmgr /sagerun:100).' }
}
Write-Host ''

if ($totalCount -eq 0 -and -not $EmptyRecycleBin -and -not $CleanupComponentStore -and -not $RunDiskCleanup -and -not $RebuildExplorerCache -and -not $ClearDeliveryOptimizationCache) {
    Write-Host 'Nothing to delete.' -ForegroundColor Green
    return
}

if ($Preview) {
    Write-Host '[Preview] No files were deleted.' -ForegroundColor Magenta
    Write-Host "Recycle Bin cleanup: $EmptyRecycleBin"
    Write-Host "Component Store cleanup: $CleanupComponentStore"
    Write-Host "Disk Cleanup: $RunDiskCleanup"
    Write-Host "Explorer cache rebuild: $RebuildExplorerCache"
    Write-Host "Delivery Optimization cache cleanup: $ClearDeliveryOptimizationCache"
    return
}

if (-not $Force) {
    $answer = Read-Host 'Proceed with cleanup? (Y/N)'
    if ($answer -notmatch '^(y|yes)$') {
        Write-Host 'Cancelled.' -ForegroundColor Yellow
        return
    }
}

if ($CloseBrowsers) {
    Stop-BrowserProcesses
}

$stoppedServices = Stop-WindowsUpdateServices

$deletedTotal = 0
$skippedTotal = 0
$freedTotal = 0L

foreach ($target in $targets) {
    Write-Host "Cleaning: [$($target.Category)] $($target.Name)" -ForegroundColor Yellow
    $result = Remove-TargetContents -Target $target
    $deletedTotal += $result.Deleted
    $skippedTotal += $result.Skipped
    $freedTotal += $result.Freed
}

Start-WindowsUpdateServices -ServiceNames $stoppedServices

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
        Write-Host 'Cleaning Windows Component Store (DISM)...' -ForegroundColor Cyan
        & dism.exe /Online /Cleanup-Image /StartComponentCleanup
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

Write-Host ''
Write-Host '===== Cleanup Complete =====' -ForegroundColor Green
Write-Host ('  Deleted {0} files, freed {1}. Skipped {2} locked/in-use item(s).' -f $deletedTotal, (Format-Size $freedTotal), $skippedTotal) -ForegroundColor Green
