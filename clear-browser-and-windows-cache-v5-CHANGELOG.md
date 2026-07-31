# Changelog - clear-browser-and-windows-cache-v5.ps1

`clear-browser-and-windows-cache-v4.ps1` 대비 v5 변경 이력과, 참고용으로 v4 이력을 함께
담았습니다.

## 2026-07-31 (v5)

### 새 기능 (Features)

- **`-ResetBase` : DISM 구성 요소 저장소 정리에 `/ResetBase` 추가(옵트인)**
  - 기존(v4): `-CleanupComponentStore` 는 항상
    `dism.exe /Online /Cleanup-Image /StartComponentCleanup` 만 실행. 이 경우 최근 업데이트에
    대한 30일 유예가 유지되어 대체된(superseded) 컴포넌트가 일부 남음.
  - 변경(v5): `-ResetBase` 를 함께 주면 `/ResetBase` 가 붙어 **대체된 컴포넌트를 전부 제거**.
    WinSxS 가 실제로 줄어들어 보통 수 GB 를 추가 확보.
  - **대가(중요)**: `/ResetBase` 이후에는 **설치된 Windows 업데이트를 제거(롤백)할 수 없음.**
    "업데이트 제거" 목록이 비워지고, 문제 있는 업데이트를 되돌릴 수 없게 됨. 정리 시간도
    훨씬 오래 걸림(수십 분 가능).
  - 되돌릴 수 없는 성격이라 **기본값이 아닌 옵트인 스위치**로 설계
    (`-ClearBrowserCache`, `-ClearUserTraces` 와 같은 방침).
  - `-CleanupComponentStore` 없이 단독으로 주면 아무 효과 없음(경고로 안내).

### 안내 / 경고 (Warnings)

- **조합 경고 2건 추가**
  - `-ResetBase` 를 `-CleanupComponentStore` 없이 사용:
    ```
    - -ResetBase is ignored without -CleanupComponentStore.
      -> Add -CleanupComponentStore to run the DISM cleanup with /ResetBase.
    ```
  - 실제 실행(Preview 아님) 시 확인 프롬프트 전에 영구성 경고:
    ```
    - /ResetBase makes installed Windows updates permanent (they can no longer be uninstalled).
      -> Drop -ResetBase to keep the ability to roll back updates.
    ```
- **요약의 "Additional actions"** 문구 분기:
  `- Run DISM component store cleanup with /ResetBase (installed updates become permanent).`
- **DISM 실행 직전** 재확인 경고 + 소요 시간 안내:
  `Using /ResetBase: installed Windows updates can no longer be uninstalled.`
  `Cleaning Windows Component Store (DISM /ResetBase, this can take a while)...`
- **Preview 출력**에 `Component Store /ResetBase: True/False` 줄 추가.

### 구현 세부 (v4 -> v5)

- `param()`: `[switch]$ResetBase` 추가(`-CleanupComponentStore` 바로 뒤).
- `$ParameterInfo` 에 `-ResetBase` 항목 추가 → 사용법 표와 오타 추천에 자동 반영.
- 주석 기반 도움말에 `.PARAMETER ResetBase` 추가(득실 및 단독 사용 시 무효 명시).
- DISM 호출을 문자열 고정에서 **배열 + splatting** 으로 변경:
  ```powershell
  $dismArgs = @('/Online', '/Cleanup-Image', '/StartComponentCleanup')
  if ($ResetBase) { $dismArgs += '/ResetBase'; Write-Warning '...' }
  & dism.exe @dismArgs
  ```
- Show-Usage 예시에 `-CleanupComponentStore -ResetBase` 1줄 추가.
- 도움말/예시의 파일명을 v5 로, 경로를 실제 위치인 `C:\opt\bin` 으로 정정
  (v4 문서에는 `C:\opt\ps1` 로 남아 있었음).

### 유지된 기능 (Carried over)

- v4: DO 캐시 크기를 요약에 반영, `-LogPath`, free space before/after, `-Quiet` + 종료 코드,
  `-Elevate`, `-ClearUserTraces`
- v3: 브라우저 캐시 옵트인(`-ClearBrowserCache`) / `-ForceCloseBrowsers`
- v2: 오타 "Did you mean?", 조합 경고, 메타데이터 사용법 표, DO cmdlet 우선 + 폴백,
  `-DeepWindowsCache`
- 공통: 브라우저 graceful 종료, `-OlderThanDays` 파일 단위 나이 필터, 드라이브 루트 가드.

### 검증 (Verification)

- 구문 파싱: `Parser::ParseFile` -> PARSE OK
- `-ResetBase -Preview` (CleanupComponentStore 없음): "ignored without" 경고 출력,
  `Component Store /ResetBase: True` / `Component Store cleanup: False` 확인.
- `-CleanupComponentStore -ResetBase -Preview`: Additional actions 에
  `/ResetBase (installed updates become permanent)` 표기 확인.
- `-CleanupComponentStore -ResetBase` (비 Preview, 프롬프트에서 취소): 확인 전 영구성 경고
  출력, 취소 시 exit code 1 확인.
- splatting 인자 구성 독립 검증:
  `ResetBase=False -> /Online /Cleanup-Image /StartComponentCleanup`,
  `True -> ... /ResetBase`.
- 실제 DISM 실행은 파괴적(업데이트 롤백 영구 불가)이고 수십 분 소요되어 트리거하지 않고
  인자 구성/경고/분기 수준까지 검증.

### 참고: 새 파라미터

| Name | Type | 설명 |
|---|---|---|
| `-ResetBase` | Switch | DISM 정리에 `/ResetBase` 추가. 공간 더 확보, 단 업데이트 롤백 불가(옵트인) |

> 주의: `/ResetBase` 는 **되돌릴 수 없습니다.** 업데이트 롤백 가능성을 유지하려면 이 옵션을
> 쓰지 마세요. 디스크 공간이 급할 때만 의도적으로 사용하는 것을 권장합니다.

---

# (참고) v4 이력

`clear-browser-and-windows-cache-v3.ps1` 대비 v4 변경 이력입니다.
v4는 정확성/감사/자동화 편의 기능을 추가했습니다.

## 2026-07-25 (v4)

### 새 기능 (Features)

- **(1) 요약(summary)에 Delivery Optimization 캐시 크기 반영**
  - 이전: DO 캐시는 파일 스캔이 아니라 cmdlet 으로 지우기 때문에 삭제 전 요약 표에서
    빠져, `-DeepWindowsCache` 실행 시 "TOTAL"이 실제보다 작게 표시됐음.
  - 변경: `Get-DeliveryOptimizationPerfSnap` 로 DO 캐시 크기를 조회해 요약에 별도 행으로
    표시하고 TOTAL 에 합산.
    ```
      DO             9 files       6.14 GB   Delivery Optimization (cleared via cmdlet)
    ```
  - DO 캐시가 비어 있으면(0) 행을 표시하지 않음.

- **(2) `-LogPath` : 실행 로그(감사 기록)**
  - `Start-Transcript -Append` 기반으로 이번 실행의 전체 출력(요약, 항목별 결과, skip 파일과
    사유, 최종 결과)을 지정 파일에 기록. 부모 폴더가 없으면 생성.
  - 중앙 종료 함수 `Complete-Run` 에서 `Stop-Transcript` 로 안전하게 닫음.

- **(3) 실행 전후 디스크 여유 공간 표시**
  - 시스템 드라이브의 free space 를 시작 시점에 기록하고, 완료 시 before/after/reclaimed 출력.
    ```
      C: free space: 40.20 GB -> 46.70 GB (reclaimed 6.50 GB)
    ```

- **(4) `-Quiet` + 종료 코드(exit code)**
  - `-Quiet` : 파라미터 표와 항목별 진행 로그를 숨김. 요약/경고/최종 결과는 유지.
  - 종료 코드: `0` 정상/Preview/지울 것 없음, `1` 사용자 취소, `2` 잘못된 파라미터.
  - 최상위 `return` 을 `Complete-Run <code>` 로 대체해 exit code 를 실제로 반환.

- **(5) `-Elevate` : 관리자 자동 재실행**
  - 비관리자면 `Start-Process -Verb RunAs` 로 동일 인자를 붙여 관리자로 재실행(UAC).
  - 재실행 인자에서 `-Elevate` 와 미인식 인자는 제외, 공백 포함 값은 따옴표 처리.
  - UAC 취소/실패 시 경고 후 비관리자로 계속. 이미 관리자면 안내만 출력.

- **(6) `-ClearUserTraces` : 사용 흔적 정리(옵트인)**
  - Explorer 썸네일/아이콘 캐시, 최근 항목 바로가기, 점프 목록을 기본 실행에서 제외하고
    이 옵션으로만 정리(v3 에서는 항상 삭제됐음).

### 구현 세부 (v3 -> v4)

- `param()`: `-LogPath [string]`, `-Quiet [switch]`, `-Elevate [switch]` 추가.
- 새 헬퍼: `Get-FreeSpaceBytes`, `Invoke-SelfElevation`, `Complete-Run`,
  스크립트 스코프 상태 `$script:TranscriptActive`.
- main flow: 오타 거부(exit 2) -> Elevate -> 트랜스크립트 -> DeepWindowsCache 승격 ->
  관리자 경고 -> free space 기록 -> Show-Usage -> 조합 경고 -> 요약(+DO 행) ->
  Preview/확인 -> 정리 -> free space 출력 -> `Complete-Run 0`.

> v4 동작 변경: v3 에서 기본으로 지우던 **Explorer 썸네일 캐시**와 **최근 항목 바로가기**는
> `-ClearUserTraces` 를 줄 때만 지워집니다.
> v3 동작 변경: 브라우저 캐시 삭제가 항상 -> `-ClearBrowserCache` 옵트인.
