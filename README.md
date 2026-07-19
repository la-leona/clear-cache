# Analysis of `clear-browser-and-windows-cache.ps1`

This document provides a detailed analysis of the `clear-browser-and-windows-cache.ps1` PowerShell script, outlining its purpose, features, parameters, and operational details.

## 1. Overview

The `clear-browser-and-windows-cache.ps1` script is a comprehensive PowerShell utility designed to clean various temporary files, logs, and browser caches on a Windows system. It targets both user-specific and system-wide junk files, offering a range of options for customization and control over the cleanup process. The script prioritizes safety by allowing previews and requiring confirmation for deletion, and it includes advanced features like Windows Update cache cleanup and component store maintenance.

## 2. Key Features

*   **Broad Cleanup Scope**: Targets Windows temporary files, logs, Explorer caches (thumbnails/icons), and caches for popular browsers (Firefox, Chrome, Edge, Brave, Opera, Vivaldi).
*   **Customizable Age Filtering**: Allows deletion of files older than a specified number of days.
*   **Preview Mode (`-Preview`)**: Enables users to see what would be deleted without actually performing any deletions, enhancing safety.
*   **Forced Execution (`-Force`)**: Skips the confirmation prompt for automated or unattended cleanup.
*   **Browser Closure (`-CloseBrowsers`)**: Automatically closes supported browser processes to ensure maximum cache cleanup.
*   **Windows Update Cache Cleanup (`-IncludeWindowsUpdateCache`)**: Cleans Windows Update download and log caches (requires Administrator privileges).
*   **Recycle Bin Emptying (`-EmptyRecycleBin`)**: Empties the Recycle Bin.
*   **DISM Component Store Cleanup (`-CleanupComponentStore`)**: Runs `DISM /Online /Cleanup-Image /StartComponentCleanup` to free up space used by Windows components (requires Administrator privileges).
*   **Windows Disk Cleanup Integration (`-RunDiskCleanup`)**: Executes `cleanmgr /sagerun:100` for a configured Disk Cleanup (requires prior configuration with `cleanmgr /sageset:100`).
*   **Explorer Cache Rebuild (`-RebuildExplorerCache`)**: Restarts Explorer and rebuilds thumbnail/icon cache databases.
*   **Delivery Optimization Cache Cleanup (`-ClearDeliveryOptimizationCache`)**: Clears the Windows Delivery Optimization cache.
*   **Safety Mechanisms**: Includes path validation to prevent accidental deletion of critical system or user files.
*   **Detailed Output**: Provides a summary of files to be deleted, including counts and sizes, and logs warnings for skipped items.

## 3. Parameters

The script supports the following parameters to control its behavior:

| Parameter | Description |
|---|---|
| `-OlderThanDays <N>` | Specifies that only files older than `N` days should be deleted. Default is `0`, meaning all eligible cache/temp files are targeted regardless of age. |
| `-Preview` | If specified, the script will only show a summary of what *would* be deleted and will not perform any actual file deletions. This is highly recommended for initial runs. |
| `-Force` | Bypasses the interactive confirmation prompt before deletion. Use with caution. |
| `-CloseBrowsers` | Attempts to stop running processes for Firefox, Chrome, Edge, Brave, Opera, and Vivaldi before cleaning their caches. This ensures that locked cache files can be deleted. |
| `-IncludeWindowsUpdateCache` | Includes the Windows Update download and log caches in the cleanup process. This option works best when the script is run with Administrator privileges. |
| `-EmptyRecycleBin` | Empties the Recycle Bin after the cache cleanup is complete. |
| `-CleanupComponentStore` | Executes the `DISM /Online /Cleanup-Image /StartComponentCleanup` command, which can free up significant space by cleaning up superseded Windows component files. Requires Administrator privileges. |
| `-RunDiskCleanup` | Runs the Windows Disk Cleanup utility using the `/sagerun:100` switch. This requires that a Disk Cleanup profile has been previously configured and saved using `cleanmgr /sageset:100`. |
| `-RebuildExplorerCache` | Temporarily restarts Windows Explorer and deletes its thumbnail and icon cache databases, forcing them to be rebuilt. This can resolve issues with incorrect or corrupted thumbnails. |
| `-ClearDeliveryOptimizationCache` | Clears the cache used by Windows Delivery Optimization, which stores update files downloaded from other PCs or Microsoft servers. Requires Administrator privileges for best results. |

## 4. Cleanup Targets

The script identifies and targets various locations for cleanup, categorized as follows:

*   **Windows System Files** (requires Administrator for some paths):
    *   `%WINDIR%\Temp` (Windows Temporary Files)
    *   `%WINDIR%\Logs` (Windows Logs)
    *   `%WINDIR%\debug` (Windows Debug Logs)
    *   `%WINDIR%\System32\LogFiles` (System Log Files)
    *   `%ProgramData%\USOShared\Logs\System` (USO Logs)
    *   `%WINDIR%\SoftwareDistribution\Download` (Windows Update Downloads - with `-IncludeWindowsUpdateCache`)
    *   `%WINDIR%\SoftwareDistribution\DataStore\Logs` (Windows Update Logs - with `-IncludeWindowsUpdateCache`)
*   **User Temporary Files**:
    *   `%TEMP%` (User Temporary Files)
    *   `%LOCALAPPDATA%\Microsoft\Windows\Explorer` (Explorer Thumbnail/Icon Cache - `thumbcache_*.db`, `iconcache_*.db`)
    *   `%HOME%\AppData\Roaming\Microsoft\Windows\Recent` (Recent Item Shortcuts - `.lnk` files)
    *   `%WINDIR%\ServiceProfiles\LocalService\AppData\Local\FontCache` (Font Cache)
*   **Browser Caches**:
    *   **Firefox**: Caches within each profile (e.g., `cache2`, `startupCache`, `thumbnails`).
    *   **Chromium-based Browsers** (Chrome, Edge, Brave, Vivaldi): General cache, code cache (JS/WASM), GPU cache, shader cache, media cache, service worker caches within each user profile.
    *   **Opera**: Similar cache types as Chromium browsers, located in its specific user data paths.

**Important Note**: The script explicitly avoids deleting user documents, downloads, browser passwords, bookmarks, history, cookies, autofill data, extensions, Windows event logs, restore points, registry, or Prefetch files.

## 5. Safety Measures

*   **Path Validation**: The `Resolve-SafeDirectory` function ensures that only valid and non-root paths are targeted, preventing accidental deletion of entire drives or critical system directories.
*   **`Test-IsAdministrator`**: Checks for administrator privileges and warns the user if certain operations (like system-wide cleanup) cannot be performed without them.
*   **`SupportsShouldProcess`**: The script is designed to work with PowerShell's `-WhatIf` and `-Confirm` parameters, allowing users to preview actions or confirm each deletion.
*   **Confirmation Prompt**: By default, the script asks for user confirmation before proceeding with actual deletions (unless `-Force` is used).
*   **Service Management**: For Windows Update cache cleanup, it temporarily stops and restarts relevant services (`bits`, `wuauserv`) to ensure files can be accessed and deleted safely.
*   **Explorer Restart**: For Explorer cache rebuilding, it gracefully stops and restarts the Explorer process.

## 6. Usage Examples

Here are some common ways to use the script:

*   **Preview cleanup actions (highly recommended for first-time use):**
    ```powershell
    .\clear-browser-and-windows-cache.ps1 -Preview
    ```
*   **Perform a default cleanup, closing browsers and confirming deletion:**
    ```powershell
    .\clear-browser-and-windows-cache.ps1 -CloseBrowsers
    ```
*   **Clean all temporary files (regardless of age), including Windows Update cache, without confirmation:**
    ```powershell
    .\clear-browser-and-windows-cache.ps1 -OlderThanDays 0 -IncludeWindowsUpdateCache -Force
    ```
*   **Run a full system cleanup, including DISM, Disk Cleanup, and Recycle Bin, with browser closure:**
    ```powershell
    .\clear-browser-and-windows-cache.ps1 -CloseBrowsers -EmptyRecycleBin -CleanupComponentStore -RunDiskCleanup -RebuildExplorerCache -ClearDeliveryOptimizationCache -Force
    ```
    *(Note: `-RunDiskCleanup` requires prior configuration with `cleanmgr /sageset:100`)*

## 7. Comparison with `Windows-SafeCleanup.ps1` (Previous Script)

The `clear-browser-and-windows-cache.ps1` script is significantly more comprehensive and robust than the `Windows-SafeCleanup.ps1` script I previously provided. Key differences include:

*   **Modularity and Extensibility**: This script uses a more structured approach with functions like `Add-CleanupTarget`, `Add-WindowsTargets`, `Add-FirefoxTargets`, `Add-ChromiumProfileTargets`, and `Add-OperaTargets`, making it easier to understand, maintain, and extend.
*   **Broader Browser Support**: Includes Vivaldi in addition to Chrome, Edge, Brave, Firefox, and Opera.
*   **Advanced Windows Cleanup Options**: Integrates directly with `DISM` for component store cleanup, `cleanmgr` for Disk Cleanup, and includes options for Windows Update and Delivery Optimization caches. These were not present in the simpler `Windows-SafeCleanup.ps1`.
*   **Detailed Logging and Output**: Provides more structured output and a clearer summary of deleted, skipped, and freed items.
*   **Enhanced Safety**: While both scripts have safety features, this script's `Resolve-SafeDirectory` function is more explicit in preventing root directory deletions and handling invalid paths.
*   **Parameter Richness**: Offers a much wider array of parameters for fine-grained control over the cleanup process.

In essence, `clear-browser-and-windows-cache.ps1` is a more professional-grade and feature-rich cleanup solution, suitable for users who need extensive control and deeper system maintenance capabilities.
