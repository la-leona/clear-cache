<#
.SYNOPSIS
    Clears Firefox cache for all local profiles.

.DESCRIPTION
    Deletes the contents of each Firefox profile's cache folders:
      - cache2        (main disk cache)
      - startupCache  (startup/JS cache)
      - thumbnails    (page thumbnails)
      - jumpListCache (taskbar jump list)

    Profiles are discovered under %LOCALAPPDATA%\Mozilla\Firefox\Profiles.
    Shows a summary (count/size) first, asks Y/N, then deletes.
    Files locked by a running Firefox are skipped (close Firefox for a full clean).

.PARAMETER Preview
    Only show the summary and exit without deleting anything.

.PARAMETER Force
    Delete without the confirmation prompt (for automation).

.PARAMETER CloseFirefox
    Stop running Firefox processes first (so locked cache files can be removed).

.EXAMPLE
    .\Clear-FirefoxCache.ps1 -Preview

.EXAMPLE
    .\Clear-FirefoxCache.ps1 -CloseFirefox
#>
[CmdletBinding()]
param(
    [switch]$Preview,
    [switch]$Force,
    [switch]$CloseFirefox
)

$ErrorActionPreference = 'Stop'

function Format-Size {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N2} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N2} KB' -f ($Bytes / 1KB)) }
    return "$Bytes B"
}

$profilesRoot = Join-Path $env:LOCALAPPDATA 'Mozilla\Firefox\Profiles'
if (-not (Test-Path $profilesRoot)) {
    Write-Warning "No Firefox profiles found at: $profilesRoot"
    return
}

$cacheDirNames = @('cache2', 'startupCache', 'thumbnails', 'jumpListCache')

# Firefox running?
$ffProcs = Get-Process -Name firefox -ErrorAction SilentlyContinue
if ($ffProcs) {
    if ($CloseFirefox) {
        Write-Host "Closing Firefox ($($ffProcs.Count) process)..." -ForegroundColor Yellow
        $ffProcs | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    } else {
        Write-Warning "Firefox is running - locked cache files will be skipped. Close Firefox (or use -CloseFirefox) for a full clean."
    }
}

# Collect target folders across all profiles
$targets = [System.Collections.Generic.List[object]]::new()
foreach ($profile in Get-ChildItem -LiteralPath $profilesRoot -Directory -ErrorAction SilentlyContinue) {
    foreach ($name in $cacheDirNames) {
        $path = Join-Path $profile.FullName $name
        if (Test-Path $path) {
            $files = Get-ChildItem -LiteralPath $path -Recurse -Force -File -ErrorAction SilentlyContinue
            $bytes = ($files | Measure-Object -Property Length -Sum).Sum
            if (-not $bytes) { $bytes = 0 }
            $targets.Add([pscustomobject]@{
                Profile = $profile.Name
                Cache   = $name
                Path    = $path
                Count   = $files.Count
                Bytes   = [long]$bytes
            })
        }
    }
}

# Summary
Write-Host ""
Write-Host "===== Firefox cache summary =====" -ForegroundColor Cyan
$totalBytes = 0L; $totalCount = 0
foreach ($t in $targets) {
    Write-Host ("  {0,-22} {1,-14} {2,7} files  {3,10}" -f $t.Profile, $t.Cache, $t.Count, (Format-Size $t.Bytes))
    $totalBytes += $t.Bytes; $totalCount += $t.Count
}
Write-Host ("  {0}" -f ('-' * 62)) -ForegroundColor DarkGray
Write-Host ("  {0,-37} {1,7} files  {2,10}" -f "TOTAL", $totalCount, (Format-Size $totalBytes)) -ForegroundColor Yellow
Write-Host ""

if ($totalCount -eq 0) {
    Write-Host "Nothing to delete." -ForegroundColor Green
    return
}

if ($Preview) {
    Write-Host "[Preview] No files were deleted." -ForegroundColor Magenta
    return
}

# Confirm
if (-not $Force) {
    $ans = Read-Host "Clear the Firefox cache above? (Y/N)"
    if ($ans -notmatch '^(y|yes)$') { Write-Host "Cancelled." -ForegroundColor Yellow; return }
}

# Delete
$deleted = 0; $skipped = 0; $freed = 0L
foreach ($t in $targets) {
    if ($t.Count -eq 0) { continue }
    Write-Host "Clearing: $($t.Profile) / $($t.Cache)" -ForegroundColor Cyan
    Get-ChildItem -LiteralPath $t.Path -Recurse -Force -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending |
        ForEach-Object {
            $len = if ($_.PSIsContainer) { 0 } else { $_.Length }
            try {
                Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop
                if (-not $_.PSIsContainer) { $deleted++; $freed += $len }
            } catch { $skipped++ }  # locked (Firefox running) or in use
        }
}

Write-Host ""
Write-Host "===== Done =====" -ForegroundColor Green
Write-Host ("  Deleted {0} files, freed {1}." -f $deleted, (Format-Size $freed)) -ForegroundColor Green
if ($skipped -gt 0) {
    Write-Host ("  Skipped {0} (locked - close Firefox or use -CloseFirefox)." -f $skipped) -ForegroundColor DarkYellow
}
