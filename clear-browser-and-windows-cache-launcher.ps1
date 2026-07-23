& "$PSScriptRoot\clear-browser-and-windows-cache-v1.ps1" `
    -CloseBrowsers `
    -OlderThanDays 0 `
    -IncludeWindowsUpdateCache `
    -EmptyRecycleBin `
    -CleanupComponentStore `
    -ClearDeliveryOptimizationCache

#===== Available parameters =====
#-Preview                          Show summary only; do not delete files.'
#-Force                            Skip the confirmation prompt.'
#-CloseBrowsers                    Close Firefox/Chrome/Edge/Brave/Opera/Vivaldi before cleanup.'
#-OlderThanDays <N>                Delete only files older than N days. Default: 0 = all.'
#-IncludeWindowsUpdateCache        Include Windows Update download/log cache.'
#-EmptyRecycleBin                  Empty the Recycle Bin.'
#-CleanupComponentStore            Run DISM component store cleanup.'
#-RunDiskCleanup                   Run cleanmgr /sagerun:100. Configure first with cleanmgr /sageset:100.'
#-RebuildExplorerCache             Restart Explorer and delete thumbnail/icon cache DB files.'
#-ClearDeliveryOptimizationCache'  Clear Windows Delivery Optimization cache.'