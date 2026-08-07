# Changelog - clear-browser-and-windows-cache-v6.ps1

`clear-browser-and-windows-cache-v5.ps1` 대비 v6 변경 이력과, 참고용으로 v5 이력을 함께
담았습니다. v4 이전 이력은 `clear-browser-and-windows-cache-v5-CHANGELOG.md` 를 참고하세요.

## 2026-08-07 (v6)

### 배경 (Why)

"Firefox 프로필이 여러 개일 때 각각 캐시가 삭제되는가" 를 확인하다 발견한 누락입니다.
프로필 순회 자체는 정상이었으나(모든 프로필을 순회하며 개수 제한 없음), **Firefox 는
프로필을 두 뿌리에 나눠 저장**한다는 점이 v5 설계에서 빠져 있었습니다.

| 경로 | 담긴 것 | v5 |
|---|---|---|
| `%LOCALAPPDATA%\Mozilla\Firefox\Profiles\<프로필>` | 디스크 캐시 (`cache2` 등) | 스캔함 |
| `%APPDATA%\Mozilla\Firefox\Profiles\<프로필>` | **Cache API / 서비스워커 스토리지** | **스캔 안 함** |

측정 환경(프로필 `m0tb0fja.default-release`)에서 실제 크기 비교입니다.

| 대상 | 크기 | v5 |
|---|---|---|
| `cache2` | 4.63 MB | 삭제 |
| `startupCache` | 18.38 MB | 삭제 |
| `thumbnails` + `jumpListCache` | 0.10 MB | 삭제 |
| `safebrowsing` | 11.89 MB | 누락 |
| **Cache API 스토리지 (59 origins)** | **459.16 MB** | **누락** |

즉 v5 는 Firefox 캐시의 약 23 MB 를 지우고 **459 MB 를 남겨두고 있었습니다.** Chromium 계열은
`Service Worker\CacheStorage` / `ScriptCache` 를 이미 처리하고 있었으므로 브라우저 간 비대칭이기도
했습니다.

### 새 기능 (Features)

- **Firefox Cache API / 서비스워커 스토리지 캐시 정리**
  - 대상: `%APPDATA%\Mozilla\Firefox\Profiles\<프로필>\storage\<버킷>\<origin>\cache`
  - 버킷 3종(`default`, `temporary`, `permanent`)을 모두 순회.
  - **origin 폴더 자체는 절대 대상이 아니며, 그 아래 `cache` 폴더만 지웁니다.** 형제 폴더인
    `idb`(IndexedDB) / `ls`(localStorage) 는 실제 사이트 데이터이므로 보존합니다.
  - 새 파라미터 없이 기존 **`-ClearBrowserCache`** 에 포함(재생성되는 순수 캐시이므로 별도
    옵트인이 불필요하다고 판단).

- **`safebrowsing` 캐시 정리 추가**
  - Firefox 가 필요할 때 다시 내려받는 순수 다운로드 캐시. `$cacheNames` 에 추가.
  - 지운 직후 재다운로드 트래픽(약 12 MB)이 한 번 발생합니다.

- **`%WINDIR%\SystemTemp` 정리 추가 (기본 대상)**
  - Windows 11 이 `Windows\Temp` 옆에 추가한 머신 레벨 임시 폴더. v5 대상에 없었음(측정 12.8 MB).
  - 위험도가 `Windows Temp` 와 같으므로(관리자 필요, 사용 중 파일은 건너뜀) 스위치 없이 기본 정리.
  - Firefox 건과 같은 방식으로 발견: 코드가 아니라 **파일시스템을 실측해** v6 대상 목록과 대조.
    함께 점검한 다른 후보들은 넣지 않았습니다 — `%LOCALAPPDATA%\Packages`(1.92 GB, UWP 앱
    `LocalState` 혼재), `%ProgramData%\Package Cache`(298.9 MB, VS 복구/제거에 필요),
    `Windows\Panther`(업그레이드 실패 진단 로그), `INetCookies`(쿠키 방침).
    `INetCache` / `WebCache` 는 `-RunDiskCleanup` 의 `Internet Cache Files` 핸들러가 담당.

- **요약 표에 한 줄로 집계 (`Add-CleanupTargetGroup`)**
  - origin 마다 캐시 폴더가 따로 있어 그대로 등록하면 요약이 **59줄로 도배**됩니다.
  - 여러 폴더를 한 타겟으로 묶어 origin 개수와 함께 한 줄로 표시:
    ```
      Firefox        8553 files     459.16 MB   m0tb0fja.default-release / storage cache (59 origins)
    ```

### 구현 세부 (v5 -> v6)

- `Add-WindowsTargets` : `Windows SystemTemp` 타겟 1줄 추가(`Windows Temp` 바로 뒤).
- `Add-CleanupTarget` : 결과 객체에 `Paths = @($safePath)` 추가(단일 폴더도 1개짜리 목록).
- **`Add-CleanupTargetGroup` 신설** : 여러 폴더를 받아 개수/크기를 합산해 **한 타겟**으로 등록.
  `Path` 에는 대표 폴더(첫 번째)를 넣어 기존 `Sort-Object Category, Name, Path -Unique` 가
  그대로 동작하게 함.
- `Add-FirefoxTargets` : `$localRoot` / `$roamingRoot` 두 뿌리를 각각 순회하도록 분리.
  `$cacheNames` 에 `safebrowsing` 추가.
- **`Add-FirefoxStorageCacheTarget` 신설** : 프로필 하나의 `storage\<버킷>\<origin>\cache` 를
  모아 `Add-CleanupTargetGroup` 으로 등록.
- `Remove-TargetContents` : `$Target.Path` 단일 처리에서 **`$Target.Paths` 순회**로 변경.
  ```powershell
  $paths = if ($Target.PSObject.Properties['Paths'] -and $Target.Paths) { @($Target.Paths) } else { @($Target.Path) }
  foreach ($path in $paths) { ... }
  ```
  `Paths` 가 없는 타겟이 생겨도 `Path` 로 폴백하므로 하위 호환.
- 도움말 `.DESCRIPTION` 2번 항목에 roaming 프로필 스토리지 언급 추가.
- 도움말/`Show-Usage` 예시의 파일명을 v6 로 갱신.

### 동작 변경 (Behavior)

- **`-ClearBrowserCache` 의 삭제 범위가 넓어집니다.** 기존 파라미터 조합 그대로 실행하면
  Firefox 에서 v5 보다 훨씬 많이 지워집니다(측정 환경 기준 약 23 MB -> 약 494 MB).
- 부수 효과: 서비스워커 오프라인 캐시가 사라져 해당 사이트/PWA 는 다음 접속 시 다시 내려받습니다.
  로그인은 유지됩니다(쿠키·localStorage·IndexedDB 를 건드리지 않으므로).
- 그 외 파라미터 동작은 v5 와 동일. 추가·삭제된 파라미터 없음.

### 검증 (Verification)

- 구문 파싱: `Parser::ParseFile` -> **PARSE OK** (1010행)
- `-ClearBrowserCache -Preview -Quiet` 실행: `storage cache (59 origins)` 행이
  **459.16 MB** 로 집계되고 59줄이 아니라 한 줄로 표시됨을 확인. 사전 실측치와 일치.
- 경로 수집 안전성 (실제 프로필 대상, 삭제 없음):

  | 검증 항목 | 결과 |
  |---|---|
  | 수집 경로 수 | 59 |
  | 모두 `cache` 폴더로 끝나는가 | True |
  | `idb` / `ls` / `.metadata` 포함 건수 | 0 |
  | 단일 폴더 타겟의 `Paths` 가 모두 1개인가 | True |

- 다중 경로 삭제 (합성 트리, `scratchpad\Test-V6MultiPath.ps1`) — **ALL PASS**:

  | 검증 항목 | 실측 | 기대 |
  |---|---|---|
  | Deleted (두 폴더 x 2파일) | 4 | 4 |
  | Skipped | 0 | 0 |
  | 타겟 폴더 내 잔존 파일 | 0 | 0 |
  | 타겟 내 빈 하위폴더 정리 | 0 | 0 |
  | 형제 `idb` 파일 보존 | 2 | 2 |
  | 형제 `ls` 파일 보존 | 2 | 2 |

- 실제 Firefox 캐시 삭제는 브라우저를 강제로 닫아 열린 탭이 사라지므로 트리거하지 않고,
  Preview 집계와 합성 트리 삭제까지 검증했습니다.

### 알려진 제약 (Known limits)

- **포터블/커스텀 경로 프로필**은 대상이 아닙니다. 기본 프로필 루트만 순회하며,
  `profiles.ini` 의 `IsRelative=0` (절대 경로) 프로필은 찾지 못합니다.
- **`-RunDiskCleanup` 은 `cleanmgr /sageset:100` 에서 체크된 항목만 지웁니다.** 점검 시점에
  `Previous Installations`(`Windows.old`) 와 `Temporary Setup Files`(`$Windows.~BT`) 가
  **미선택** 상태였습니다. 지금은 두 폴더가 없어 증상이 없지만, Windows 를 크게 업데이트하면
  `Windows.old` 가 수 GB 생기므로 미리 설정해 두어야 회수됩니다(README 10.2 절에 설정 방법).
  스크립트 결함이 아니라 OS 쪽 설정 항목입니다.
- **개발도구 캐시는 대상이 아닙니다.** 실측에서 가장 큰 덩어리였으나(JetBrains 2.71 GB,
  Gradle 1.03 GB, npm 770.5 MB) 이 도구의 범위가 아니고, 지우면 재인덱싱·재다운로드 비용이
  발생하므로 의도적으로 제외했습니다.
- `-OlderThanDays` 는 스토리지 캐시에도 파일 단위로 적용됩니다.
- **방문 기록·쿠키는 대상이 아닙니다.** 검토했으나 제외했습니다 —
  방문 기록은 공간 확보 효과가 거의 없고(수십 MB), 쿠키는 전 사이트 로그인이 풀리는
  대가가 캐시 정리 도구의 범위를 넘습니다. 특정 사이트 세션만 지우려면 브라우저
  개발자도구의 `Delete Session Cookies` 가 정확합니다.

### 참고: 새 파라미터

없습니다. v6 는 기존 `-ClearBrowserCache` 의 커버리지를 넓힌 변경입니다.

---

# (참고) v5 이력

`clear-browser-and-windows-cache-v4.ps1` 대비 v5 변경 이력 요약입니다.
상세는 `clear-browser-and-windows-cache-v5-CHANGELOG.md` 참고.

## 2026-07-31 (v5)

- **`-ResetBase` : DISM 구성 요소 저장소 정리에 `/ResetBase` 추가(옵트인)**
  - `-CleanupComponentStore` 와 함께 쓸 때만 동작. 대체된 컴포넌트를 전부 제거해 WinSxS 가
    실제로 줄어들어 보통 수 GB 추가 확보.
  - **대가**: 설치된 Windows 업데이트를 제거(롤백)할 수 없게 됨. 시간도 훨씬 오래 걸림.
  - 되돌릴 수 없어 옵트인으로 설계하고 경고를 두 번 표시.
- 조합 경고 2건 추가(`-CleanupComponentStore` 없이 단독 사용 / 실제 실행 시 영구성 경고).
- DISM 호출을 문자열 고정에서 **배열 + splatting**(`& dism.exe @dismArgs`)으로 변경.
- Preview 출력에 `Component Store /ResetBase: True/False` 줄 추가.
- 도움말/예시의 파일명을 v5 로, 경로를 실제 위치인 `C:\opt\bin` 으로 정정.

> v5 동작 변경: 없음(옵션 추가만).
> v4 동작 변경: 썸네일 캐시/최근 항목 삭제가 기본 -> `-ClearUserTraces` 옵트인.
> v3 동작 변경: 브라우저 캐시 삭제가 항상 -> `-ClearBrowserCache` 옵트인.
