<#
.SYNOPSIS
    Clears browsing history for Firefox, Opera, Chrome, Edge, Brave, and Vivaldi.
.DESCRIPTION
    Safely terminates browser background processes and deletes their history databases.
    Leaves bookmarks intact.
#>

# 1. Force close all browsers and background helpers to release file locks
Write-Host "Closing browsers and background processes..." -ForegroundColor Cyan

# $ProcessNames = @("firefox", "msedge", "chrome", "brave", "vivaldi")
$ProcessNames = @("msedge", "chrome", "brave", "vivaldi")
foreach ($Proc in $ProcessNames) {
    Stop-Process -Name $Proc -Force -ErrorAction SilentlyContinue
}
# Catch all Opera variants (Opera Stable, GX, Developer)
Get-Process | Where-Object {$_.Name -like "*opera*"} | Stop-Process -Force -ErrorAction SilentlyContinue

# Give the system 2 seconds to completely release file handles
Start-Sleep -Seconds 2

# 2. Define History file paths (Checks standard, Default, and secondary profiles)
$HistoryPaths = @(
    # Firefox (Roaming AppData)
    # "$env:APPDATA\Mozilla\Firefox\Profiles\*\places.sqlite",

    # Opera & Opera GX (Roaming AppData)
    "$env:APPDATA\Opera Software\Opera Stable\Default\History*",
    "$env:APPDATA\Opera Software\Opera Stable\History*",
    "$env:APPDATA\Opera Software\Opera GX Stable\Default\History*",
    "$env:APPDATA\Opera Software\Opera GX Stable\History*",

    # Microsoft Edge (Local AppData - Supports Default and Profile 1, 2, etc.)
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\History*",
    "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Profile *\History*",

    # Google Chrome (Local AppData)
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History*",
    "$env:LOCALAPPDATA\Google\Chrome\User Data\Profile *\History*",

    # Brave Browser (Local AppData)
    "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\History*",
    "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Profile *\History*",

    # Vivaldi Browser (Local AppData)
    "$env:LOCALAPPDATA\Vivaldi\User Data\Default\History*",
    "$env:LOCALAPPDATA\Vivaldi\User Data\Profile *\History*"
)

# 3. Iterate and safely delete history files
Write-Host "Purging history databases..." -ForegroundColor Yellow
$DeletedCount = 0

foreach ($Path in $HistoryPaths) {
    if (Test-Path $Path) {
        Remove-Item -Path $Path -Force -ErrorAction SilentlyContinue
        Write-Host "Cleared history at: $Path" -ForegroundColor Green
        $DeletedCount++
    }
}

if ($DeletedCount -eq 0) {
    Write-Host "No active history database files were found. They may already be clean!" -ForegroundColor DarkGray
} else {
    Write-Host "Cleanup completed successfully! Removed data from $DeletedCount location(s)." -ForegroundColor Green
}
