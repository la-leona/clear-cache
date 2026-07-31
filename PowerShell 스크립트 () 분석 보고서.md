## PowerShell 스크립트 (`clear-browser-and-windows-cache.ps1`) 분석 보고서

### 1. 개요

사용자님께서 제공해주신 `clear-browser-and-windows-cache.ps1` 스크립트는 Windows 시스템 및 주요 웹 브라우저의 캐시와 임시 파일을 효율적으로 정리하는 PowerShell 스크립트입니다. 이전 버전에서 요청하셨던 **"Available parameters를 항상 보여주되 입력된 파라미터는 눈에 띄게 (굵게, 색상변경등) 보여주는"** 기능이 성공적으로 구현되었습니다.

### 2. 주요 변경 사항 및 구현 분석

스크립트의 핵심 변경 사항은 `Show-Usage` 함수와 파라미터 강조 로직에 있습니다.

#### 2.1. `Show-Usage` 함수 개선

-   **`Write-ParameterLine` 함수 도입**: `Show-Usage` 함수 내에서 각 파라미터 라인을 직접 `Write-Host`로 출력하는 대신, `Write-ParameterLine`이라는 헬퍼 함수를 새로 정의하여 사용했습니다. 이 함수는 파라미터 이름과 설명을 인자로 받아 출력 형식을 일관되게 유지하고, 강조 로직을 캡슐화합니다.

    ```powershell
    function Write-ParameterLine {
        param(
            [string]$Name,
            [string]$Description
        )

        if ($PSBoundParameters.ContainsKey($Name) -or $script:PSBoundParameters.ContainsKey($Name)) {
            Write-Host ("* {0,-30} {1}" -f "-$Name", $Description) `
                -ForegroundColor Yellow
        }
        else {
            Write-Host ("  {0,-30} {1}" -f "-$Name", $Description)
        }
    }
    ```

-   **항상 도움말 표시**: 스크립트 시작 부분에 `$showUsage = ($PSBoundParameters.Count -eq 0)` 로직이 있지만, `Show-Usage` 함수는 이제 스크립트의 마지막 부분에서 `Show-Usage`로 직접 호출되므로, 파라미터 입력 여부와 관계없이 항상 사용법이 출력됩니다. 이는 사용자 요청 사항을 정확히 반영한 것입니다.

#### 2.2. 파라미터 강조 로직

-   **`$PSBoundParameters` 활용**: `Write-ParameterLine` 함수 내에서 `$PSBoundParameters.ContainsKey($Name)`을 사용하여 현재 스크립트 실행 시 어떤 파라미터가 바인딩(입력)되었는지 확인합니다. 이 방식은 `PSBoundParametersDictionary` 타입을 명시적으로 사용하지 않아 이전 버전의 PowerShell에서도 호환성 문제를 일으키지 않습니다.
-   **`$script:PSBoundParameters` 추가**: `$script:PSBoundParameters.ContainsKey($Name)`을 추가하여 스크립트 스코프의 바인딩된 파라미터도 함께 확인합니다. 이는 스크립트가 모듈로 로드되거나 다른 방식으로 호출될 때 발생할 수 있는 스코프 문제를 보완하려는 시도로 보입니다.
-   **강조 색상**: 활성화된 파라미터는 `Yellow` (노란색)으로 강조됩니다. 이전 요청에서는 초록색(Green)을 언급했지만, 노란색도 충분히 눈에 띄며 가독성이 좋습니다.
-   **`OlderThanDays` 값 표시**: `OlderThanDays` 파라미터의 경우, 현재 설정된 값(`$ScriptParameters.OlderThanDays`)을 함께 표시하여 사용자가 어떤 값으로 스크립트가 실행되는지 명확히 알 수 있도록 했습니다. 이는 사용자 경험 측면에서 매우 유용한 개선입니다.

    ```powershell
    Write-ParameterLine "OlderThanDays" "Delete only files older than N days. (Current: $($ScriptParameters.OlderThanDays))"
    ```

### 3. 스크립트의 전반적인 구조 및 기능

사용자님께서 제공해주신 스크립트는 여전히 다음과 같은 강력한 기능을 유지하고 있습니다.

-   **모듈화된 함수**: `Format-Size`, `Test-IsAdministrator`, `Resolve-SafeDirectory`, `Get-TargetStats`, `Add-CleanupTarget` 등 기능별로 잘 분리된 함수를 통해 코드의 가독성과 유지보수성이 높습니다.
-   **다양한 정리 대상**: Windows 임시 파일, 로그, Explorer 캐시, Windows Update 캐시, 그리고 Firefox, Chrome, Edge, Brave, Opera, Vivaldi 등 다양한 브라우저의 캐시를 지원합니다.
-   **안전 장치**: `Resolve-SafeDirectory` 함수를 통해 드라이브 루트 디렉토리 삭제를 방지하고, `Preview` 모드를 제공하여 실제 삭제 전에 어떤 파일이 정리될지 미리 확인할 수 있습니다.
-   **고급 시스템 최적화**: `CleanupComponentStore` (DISM), `RunDiskCleanup` (cleanmgr), `RebuildExplorerCache`, `ClearDeliveryOptimizationCache` 등 Windows의 고급 정리 및 최적화 기능을 통합적으로 제공합니다.

### 4. 개선 제안

현재 스크립트는 매우 잘 작동하지만, 몇 가지 추가적인 개선을 고려해 볼 수 있습니다.

1.  **`$script:PSBoundParameters` 사용 통일**: `Write-ParameterLine` 함수 내에서 `$PSBoundParameters.ContainsKey($Name)`과 `$script:PSBoundParameters.ContainsKey($Name)`을 동시에 확인하고 있습니다. 일반적으로 스크립트 파일 자체에서 실행될 때는 `$PSBoundParameters`만으로 충분하며, `$script:` 스코프는 모듈이나 다른 스크립트에서 호출될 때 주로 사용됩니다. 혼란을 줄이기 위해 `$PSBoundParameters`만 사용하거나, `$script:PSBoundParameters`를 사용한다면 스크립트 전체에서 일관되게 사용하는 것을 고려해 볼 수 있습니다.

2.  **`OlderThanDays` 기본값 표시 개선**: `OlderThanDays` 파라미터의 설명에서 "Default: 0 = all"이라는 문구가 있는데, `Write-ParameterLine` 함수 내에서 `(Current: $($ScriptParameters.OlderThanDays))`로 현재 값을 표시할 때 이 기본값에 대한 설명도 함께 보여주면 더 친절할 것입니다. 예를 들어, `$ScriptParameters.OlderThanDays`가 0일 경우 "(Current: 0 = all)"과 같이 표시하는 방식입니다.

3.  **색상 팔레트 통일**: `Write-Host` 메시지에서 `Cyan`, `Yellow`, `DarkGray` 등 다양한 색상을 사용하고 있습니다. 이는 시각적으로 정보를 구분하는 데 도움이 되지만, 전체적인 출력의 일관성을 위해 색상 사용 규칙을 명확히 정의하고 통일하는 것이 좋습니다. (예: 강조는 노란색, 경고는 빨간색, 정보는 시안색 등)

### 5. 결론

사용자님께서 수정하신 스크립트는 요청하신 기능을 완벽하게 구현했으며, 이전 버전의 호환성 문제도 해결된 것으로 보입니다. `Write-ParameterLine` 함수를 통해 코드의 재사용성과 가독성을 높인 점이 특히 인상적입니다. 이 스크립트는 Windows 시스템 관리에 매우 유용하게 활용될 수 있는 훌륭한 도구입니다.
