# Changelog - clear-browser-and-windows-cache-v4.ps1

`clear-browser-and-windows-cache-v3.ps1` 대비 v4 변경 이력입니다.
v4는 정확성/감사/자동화 편의 기능 5가지를 추가했습니다(동작 변경 없음, 하위 호환).

## 2026-07-25 (v4)

### 새 기능 (Features)

- **(1) 요약(summary)에 Delivery Optimization 캐시 크기 반영**
  - 이전: DO 캐시는 파일 스캔이 아니라 cmdlet 으로 지우기 때문에 삭제 전 요약 표에서
    빠져, `-DeepWindowsCache` 실행 시 "TOTAL"이 실제보다 작게 표시됐음(예: 표엔 수백 MB,
    실제론 수 GB 삭제).
  - 변경: `-ClearDeliveryOptimizationCache`(또는 `-DeepWindowsCache`) 시
    `Get-DeliveryOptimizationPerfSnap` 로 DO 캐시 크기를 조회해 요약에 별도 행으로 표시하고
    TOTAL 에 합산.
    ```
      DO             9 files       6.14 GB   Delivery Optimization (cleared via cmdlet)
    ```
  - DO 캐시가 비어 있으면(0) 행을 표시하지 않음.

- **(2) `-LogPath` : 실행 로그(감사 기록)**
  - `Start-Transcript -Append` 기반으로 이번 실행의 전체 출력(요약, 항목별 결과, skip 파일과
    사유, 최종 결과)을 지정 파일에 기록. 부모 폴더가 없으면 생성.
  - 중앙 종료 함수 `Complete-Run` 에서 `Stop-Transcript` 로 안전하게 닫음(어느 경로로
    끝나도 로그가 정상 종료됨).

- **(3) 실행 전후 디스크 여유 공간 표시**
  - 시스템 드라이브(`$env:SystemDrive`)의 free space 를 시작 시점에 기록하고, 완료 시
    before/after/reclaimed 로 출력.
    ```
      C: free space: 40.20 GB -> 46.70 GB (reclaimed 6.50 GB)
    ```
  - 삭제 바이트 합계(freedTotal)와 별개로 실제 체감 확보량을 교차 확인 가능.

- **(4) `-Quiet` + 종료 코드(exit code)**
  - `-Quiet` : 파라미터 표(Show-Usage)와 항목별 진행 로그(`Cleaning: ...`)를 숨김.
    요약/경고/최종 결과는 유지. 스케줄러/자동화 로그를 깔끔하게.
  - 종료 코드 규약(스케줄러가 성공/실패 판별 가능):
    - `0` : 정상 완료 / Preview / 삭제할 것 없음
    - `1` : 사용자가 확인 프롬프트에서 취소
    - `2` : 잘못된 파라미터(오타)
  - 최상위 `return` 을 `Complete-Run <code>` 로 대체해 exit code 를 실제로 반환.

- **(5) `-Elevate` : 관리자 자동 재실행**
  - 관리자가 아니고 `-Elevate` 가 있으면 `Start-Process -Verb RunAs` 로 동일 인자를 붙여
    자신을 관리자로 재실행(UAC). 현재 호스트(powershell.exe/pwsh.exe)를 그대로 사용.
  - 재실행 인자에서 `-Elevate` 와 미인식 인자(UnknownArgs)는 제외(무한 재실행/오류 방지),
    공백이 포함된 값(예: `-LogPath`)은 따옴표 처리.
  - UAC 취소/실패 시에는 경고 후 비관리자 권한으로 계속 진행.
  - 참고: 상승된 실행은 새 창에서 동작하므로 출력은 그 창에 표시됨.

- **(6) `-ClearUserTraces` : 사용 흔적 정리(옵트인)**
  - 순수 캐시가 아니라 UX/사용 흔적에 해당하는 항목을 기본 실행에서 제외하고 이 옵션으로만
    정리하도록 분리:
    - Explorer 썸네일/아이콘 캐시(`thumbcache_*.db`, `iconcache_*.db`)
    - 최근 항목 바로가기(`Recent\*.lnk`)
    - 점프 목록(`Recent\AutomaticDestinations`, `Recent\CustomDestinations`)
  - 이전(v3)에는 썸네일 캐시와 최근 항목이 **항상** 삭제돼, 순수 캐시만 지우려던 사용자에겐
    "최근 파일 목록/썸네일이 초기화되는" 놀라움이 있었음. v4 기본 실행은 이들을 건드리지 않음.
  - 요약 표에서는 `UserTraces` 카테고리로 표시. (썸네일 db 는 Explorer 가 잠그고 있으면
    skip 되며, 완전한 재생성은 `-RebuildExplorerCache` 사용.)

### 구현 세부 (v3 -> v4)

- `param()`: `-LogPath [string]`, `-Quiet [switch]`, `-Elevate [switch]` 추가.
- `$ParameterInfo` 에 세 항목 추가(사용법 표 + 오타 제안에 자동 반영).
- 새 헬퍼: `Get-FreeSpaceBytes`, `Invoke-SelfElevation`, `Complete-Run`,
  스크립트 스코프 상태 `$script:TranscriptActive`.
- main flow 순서: 오타 거부(exit 2) -> Elevate 재실행 -> 트랜스크립트 시작 ->
  DeepWindowsCache 승격 -> 관리자 경고 -> free space 기록 -> (Quiet 아니면) Show-Usage
  -> 조합 경고 -> 대상 수집/요약(+DO 행) -> Preview/확인 -> 정리 -> free space 출력 ->
  `Complete-Run 0`.
- Show-Usage 예시에 자동화 예시 1줄 추가:
  `-Elevate -DeepWindowsCache -Force -Quiet -LogPath C:\logs\clean.log`

### 유지된 기능 (Carried over)

- 브라우저 캐시 옵트인(`-ClearBrowserCache`) / `-ForceCloseBrowsers` (v3)
- 오타 "Did you mean?", 조합 경고, 메타데이터 사용법 표 (v2)
- DO cmdlet 우선 + 폴백(다중 서비스 중지 + skip 사유), `-DeepWindowsCache` (v2)
- 브라우저 graceful 종료, `-OlderThanDays` 파일 단위 나이 필터, 드라이브 루트 가드.

### 검증 (Verification)

- 구문 파싱: `Parser::ParseFile` -> PARSE OK
- `-DeepWindowsCache -Preview -Quiet -LogPath <파일>` :
  파라미터 표 억제 확인, 요약/Preview 출력, exit code 0, 로그 파일 기록(트랜스크립트 종료
  마커까지) 확인.
- 오타 `-Froce` : exit code 2 확인.
- free space 헬퍼/출력 포맷: 독립 검증(유효 바이트 > 0, `before -> after (reclaimed)` 포맷).
- `-Elevate` 인자 재구성: 독립 검증(`-Elevate`/오타 제외, 스위치 유지, 공백 경로 인용).
- DO 요약 행: 이 PC는 DO 캐시가 비어 미표시(정상). 실제 대량 삭제/UAC 상승은 파괴적/대화형
  이라 트리거하지 않고 로직 수준까지 검증.

## 참고: 새 파라미터 요약

| Name | Type | 설명 |
|---|---|---|
| `-ClearUserTraces` | Switch | 썸네일 캐시·최근 항목·점프 목록 정리(옵트인) |
| `-LogPath` | String | 이번 실행의 전체 로그를 파일에 기록(append) |
| `-Quiet` | Switch | 사용법 표/진행 로그 숨김(요약·결과는 유지) |
| `-Elevate` | Switch | 비관리자면 관리자로 재실행(UAC) |

> 동작 변경 주의: v3 에서 기본으로 지우던 **Explorer 썸네일 캐시**와 **최근 항목 바로가기**는
> v4 에서 `-ClearUserTraces` 를 줄 때만 지워집니다(기본 실행 제외).
