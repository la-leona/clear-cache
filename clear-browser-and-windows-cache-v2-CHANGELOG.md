# Changelog - clear-browser-and-windows-cache-v2.ps1

이전 버전(`clear-browser-and-windows-cache.ps1` / `-v1`) 대비 v2 변경 이력입니다.
`TODO.txt` 의 7개 항목과, 스크린샷("Windows System Cache") 에 보이던 파일들을 청소하도록 반영했습니다.

## 2026-07-24 (v2)

### 새 기능 (Features)

- **(TODO 1) 오타 파라미터 "Did you mean?" 제안**
  - `-Froce` 처럼 잘못 입력하면 예전에는 PowerShell 바인딩 오류로 스크립트가 시작조차
    안 됐음. 이제 `[Parameter(ValueFromRemainingArguments = $true)] $UnknownArgs` 로
    미인식 인자를 받아, Levenshtein 거리 기반으로 가장 가까운 파라미터를 추천하고 종료.
  - 출력 예시:
    ```
    Unknown parameter : -Froce

    Did you mean?
      -Force
    ```
  - 참고: `-DeepWindowsCach` 같은 유효한 축약형은 PowerShell 접두어 매칭으로 정상 바인딩됨.

- **(TODO 2) 충돌 / 무의미한 옵션 조합 경고**
  - 실행 전에 `WARNING` 블록으로 안내:
    - `-Preview -Force` : Force 는 Preview 중엔 효과 없음
    - `-CloseBrowsers -ForceCloseBrowsers` : ForceCloseBrowsers 가 우선
    - `-Preview` + close 옵션 : Preview 모드에선 브라우저를 닫지 않음
    - 브라우저 실행 중인데 close 옵션 없음 : `-CloseBrowsers` 권장

- **(TODO 5) `-DeepWindowsCache` 옵션 추가 (스크린샷 대상 청소)**
  - 아래 딥 캐시를 함께 정리. 스크린샷의 "Windows System Cache" 항목을 커버:
    - **CryptnetUrlCache** : User / SystemProfile / LocalService / NetworkService 4개 프로필
    - **D3DSCache (DirectX Shader Cache)**
    - **WER (Windows Error Reporting)** : ReportQueue / ReportArchive / Temp (User + System)
  - `-DeepWindowsCache` 지정 시 `-IncludeWindowsUpdateCache` 와
    `-ClearDeliveryOptimizationCache` 도 자동 활성화(Windows Update 캐시 +
    Delivery Optimization 캐시까지 정리).

- **(TODO 7) `-ForceCloseBrowsers` 옵션 추가 / `-CloseBrowsers` 세분화**
  - `-CloseBrowsers` : 정상 종료를 먼저 시도하고, 남은 프로세스만 강제 종료(기본 방식).
  - `-ForceCloseBrowsers` : 처음부터 즉시 강제 종료. `-CloseBrowsers` 보다 우선.

### 개선 (Improvements)

- **(TODO 3) `Show-Usage` 메타데이터 테이블화**
  - `$ParameterInfo` 배열(Name / Type / Description)을 단일 소스로 삼아, 사용법 출력과
    오타 제안이 같은 목록을 공유. 활성 파라미터는 `*` + 노란색으로 표시.

- **(TODO 4) Delivery Optimization 캐시 정리 강화**
  - 정식 cmdlet `Delete-DeliveryOptimizationCache` 우선 사용(위치/ACL/서비스 잠금 처리)은
    유지. cmdlet 이 없을 때의 폴백을 강화:
    - `DoSvc`, `BITS`, `UsoSvc`, `WaaSMedicSvc` 를 중지 후 삭제, 완료 후 재시작.
    - 못 지운 파일은 사유와 함께 목록 출력 — `Access denied` / `Locked by DoSvc` /
      `Locked (in use)`. 예:
      ```
      Deleted : 12
      Skipped : 8

      Skipped files
        content.bin (Locked by DoSvc)
        content.bin (Access denied)
      ```

- **(TODO 6) 브라우저 종료를 graceful 우선으로 변경**
  - 기존 `Stop-Process -Force` (+ `Start-Sleep 2`) 대신:
    1. `CloseMainWindow()` 로 정상 종료 요청
    2. 최대 10초 동안 실제 종료 여부를 폴링
    3. 그래도 살아 있으면 `Stop-Process -Force`
  - 브라우저별 상태 출력:
    ```
    Closing browsers...
      Chrome     Graceful shutdown... OK
      Edge       Graceful shutdown... OK
      Firefox    Graceful shutdown... Timeout
      Firefox    Force kill... OK
    ```

### 유지된 이전 수정 (Carried over from v1)

- `-OlderThanDays` 사용 시 오래된 폴더의 `-Recurse` 삭제로 최신 파일까지 지워지던 버그 수정
  (파일 단위로만 나이 필터 적용, 이후 빈 폴더만 정리).
- Delivery Optimization 캐시를 공식 cmdlet 으로 정리(경로 불일치/ACL 문제 해소).
- 드라이브 루트 삭제 방지 가드, 잠긴 파일 skip 처리, 삭제 전 요약 + 확인 프롬프트.

### 검증 (Verification)

- 구문 파싱: `Parser::ParseFile` -> PARSE OK
- `-Froce` / `-Forse` : `-Force` 추천 확인
- `-Preview -Force` : 충돌 경고 정상 출력
- `-DeepWindowsCache -Preview` : CryptnetUrlCache 4개 프로필 + D3DSCache 목록 표시,
  Delivery Optimization cleanup = True, 파라미터 테이블 정렬 정상
- 실제 삭제(브라우저 graceful 종료, DO cmdlet 대량 삭제)는 파괴적이라 Preview/구문/로직
  수준까지만 검증.

## 참고: 파라미터 요약

| Name | Type | 설명 |
|---|---|---|
| `-OlderThanDays` | Integer | N일보다 오래된 파일만 삭제 |
| `-Preview` | Switch | 요약만 표시, 삭제 안 함 |
| `-Force` | Switch | 확인 프롬프트 생략 |
| `-CloseBrowsers` | Switch | 정상 종료 우선, 남은 것만 강제 종료 |
| `-ForceCloseBrowsers` | Switch | 즉시 강제 종료 |
| `-IncludeWindowsUpdateCache` | Switch | Windows Update 다운로드/로그 캐시 포함 |
| `-DeepWindowsCache` | Switch | Cryptnet / D3DSCache / WER / WU / DO 캐시까지 정리 |
| `-EmptyRecycleBin` | Switch | 휴지통 비우기 |
| `-CleanupComponentStore` | Switch | DISM 구성 요소 저장소 정리 |
| `-RunDiskCleanup` | Switch | cleanmgr /sagerun:100 실행 |
| `-RebuildExplorerCache` | Switch | 탐색기 재시작 + 썸네일/아이콘 캐시 재생성 |
| `-ClearDeliveryOptimizationCache` | Switch | Delivery Optimization 캐시 정리 |
