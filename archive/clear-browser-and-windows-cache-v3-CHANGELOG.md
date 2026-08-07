# Changelog - clear-browser-and-windows-cache-v3.ps1

`clear-browser-and-windows-cache-v2.ps1` 대비 v3 변경 이력입니다.
핵심은 **브라우저 캐시 삭제를 옵트인(opt-in) 으로 전환**한 것입니다.

## 2026-07-25 (v3)

### 동작 변경 (Breaking change)

- **브라우저 캐시는 이제 `-ClearBrowserCache` 를 줄 때만 삭제됨.**
  - 이전(v2): `-CloseBrowsers` / `-ForceCloseBrowsers` 옵션 유무와 관계없이 브라우저
    캐시를 항상 삭제했고, 그 옵션들은 "삭제 전에 브라우저를 닫을지" 만 결정했음.
  - 변경(v3): 기본 실행에서는 브라우저 캐시를 건드리지 않음. Windows/딥 캐시만 정리.

### 옵션 변경

- **`-CloseBrowsers` -> `-ClearBrowserCache` 로 이름 변경 및 의미 확장**
  - `-ClearBrowserCache` 가 있으면: (기존 `-CloseBrowsers` 와 동일한 방식으로) 브라우저를
    정상 종료(graceful) 한 뒤, 브라우저 캐시를 삭제함.
  - 즉 "브라우저를 닫는다" 가 아니라 "브라우저 캐시를 정리한다(그러려면 먼저 닫는다)" 로
    의미가 바뀜.

- **`-ForceCloseBrowsers` : v2 와 동일 (종료 방식 modifier)**
  - 브라우저를 즉시 강제 종료. `-ClearBrowserCache` 와 함께 쓰면 강제 종료 후 캐시 삭제.

### 사용 예

```
clear-browser-and-windows-cache-v3.ps1
    -> 브라우저 캐시 삭제 안 함 (Windows/딥 캐시만)

clear-browser-and-windows-cache-v3.ps1 -ClearBrowserCache
    -> 브라우저 정상 종료 후 캐시 삭제

clear-browser-and-windows-cache-v3.ps1 -ClearBrowserCache -ForceCloseBrowsers
    -> 브라우저 강제 종료 후 캐시 삭제
```

### 구현 세부 (v2 -> v3 diff 요약)

- `param()`: `-CloseBrowsers` -> `-ClearBrowserCache`.
- `$ParameterInfo`(사용법 테이블 + 오타 제안 소스): 항목명/설명 갱신.
  - `-ClearBrowserCache` : "Close browsers (graceful) and clear their caches."
  - `-ForceCloseBrowsers` : "Force-kill browsers immediately (use with -ClearBrowserCache)."
- 대상 수집: `Add-BrowserTargets` 를 `if ($ClearBrowserCache)` 일 때만 호출.
  요약(summary)/Preview 에도 `-ClearBrowserCache` 일 때만 브라우저 항목이 표시됨.
- 브라우저 종료 분기:
  ```
  if     ($ForceCloseBrowsers) { Stop-BrowserProcesses -ForceOnly }   # 즉시 강제
  elseif ($ClearBrowserCache)  { Stop-BrowserProcesses }              # graceful
  ```
- 조합 경고(#2) 갱신:
  - (신규) `-ForceCloseBrowsers` 를 `-ClearBrowserCache` 없이 주면:
    "Browsers will be force-closed, but browser caches will NOT be cleared."
    -> "Add -ClearBrowserCache to also clear browser caches."
  - (신규) `-Preview` + (`-ClearBrowserCache` 또는 `-ForceCloseBrowsers`):
    "Browsers are not closed in Preview mode."
  - (삭제) v2 의 "`-CloseBrowsers` 와 `-ForceCloseBrowsers` 충돌" 경고 — 두 옵션이 이제
    상호 보완(무엇을 vs 어떻게)이라 충돌 아님.
  - (삭제) v2 의 "브라우저 실행 중" 경고 — 기본 실행에서 브라우저 캐시를 건드리지 않으므로
    더 이상 의미 없음.
- Preview 출력에 `Browser cache cleanup: <True/False>` 줄 추가.
- 사용하지 않게 된 `Test-BrowsersRunning` 헬퍼 제거.
- 도움말(.SYNOPSIS/.PARAMETER/.EXAMPLE), Show-Usage 예시, 내부 파일명 참조를 v3 기준으로 갱신.

### 유지된 기능 (Carried over from v2)

- 오타 파라미터 "Did you mean?" 제안 (#1)
- Show-Usage 메타데이터 테이블 (#3)
- Delivery Optimization 캐시: 공식 cmdlet 우선 + 폴백(다중 서비스 중지 + skip 사유 표시) (#4)
- `-DeepWindowsCache`: CryptnetUrlCache / D3DSCache / WER / WU / DO (#5)
- 브라우저 graceful 종료 로직(CloseMainWindow -> 대기 -> 강제) (#6/#7)
- `-OlderThanDays` 파일 단위 나이 필터, 드라이브 루트 가드, 삭제 전 요약/확인.

### 검증 (Verification)

- 구문 파싱: `Parser::ParseFile` -> PARSE OK
- CASE A `-Preview` (옵션 없음): 브라우저 행 없음, `Browser cache cleanup: False`
- CASE B `-ClearBrowserCache -Preview`: Firefox 등 브라우저 항목 표시,
  `Browser cache cleanup: True`
- CASE C `-ForceCloseBrowsers -Preview` (ClearBrowserCache 없음): 경고 출력,
  `Browser cache cleanup: False`
- 실제 삭제/브라우저 종료는 파괴적이라 Preview/구문/로직 수준까지만 검증.
