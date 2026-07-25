& "$PSScriptRoot\clear-browser-and-windows-cache-v4.ps1" `
    -OlderThanDays 0 `
    -ClearBrowserCache `
    -IncludeWindowsUpdateCache `
    -DeepWindowsCache `
    -EmptyRecycleBin `
    -CleanupComponentStore `
    -ClearDeliveryOptimizationCache `
    -ClearUserTraces

Read-Host "Press Enter to exit"





#===== Available parameters =====
#  Name                              Type     Description
#  -OlderThanDays                  Integer  Delete only files older than N days.
#  -Preview                        Switch   Show summary only; do not delete files.
#  -Force                          Switch   Skip the confirmation prompt.
#  -ClearBrowserCache              Switch   Close browsers (graceful) and clear their caches.
#  -ForceCloseBrowsers             Switch   Force-kill browsers immediately (use with -ClearBrowserCache).
#  -IncludeWindowsUpdateCache      Switch   Include Windows Update download/log cache.
#  -DeepWindowsCache               Switch   Clean Cryptnet/D3DSCache/WER/WU/DO caches too.
#  -EmptyRecycleBin                Switch   Empty the Recycle Bin.
#  -CleanupComponentStore          Switch   Run DISM component store cleanup.
#  -RunDiskCleanup                 Switch   Run cleanmgr /sagerun:100.
#  -RebuildExplorerCache           Switch   Restart Explorer and rebuild thumbnail/icon cache.
#  -ClearDeliveryOptimizationCache Switch   Clear Delivery Optimization cache.
#  -ClearUserTraces                Switch   Clear thumbnail cache, recent items and jump lists.
#  -LogPath                        String   Append a transcript of this run to a file.
#  -Quiet                          Switch   Suppress usage table and per-item progress lines.
#  -Elevate                        Switch   Relaunch as Administrator if not already elevated.