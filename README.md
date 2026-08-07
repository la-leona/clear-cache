# clear-browser-and-windows-cache-v6.ps1

Windows 임시 파일과 브라우저 캐시, 그리고 각종 Windows 시스템 캐시를 한 번에 정리하는
PowerShell 스크립트입니다. 삭제 전에 대상과 크기를 요약해 보여주고, 확인을 받은 뒤에만
삭제합니다.

---

## 1. 특징 요약

- 삭제 전 **요약 표 + 확인 프롬프트** (실수 방지). `-Preview` 로 미리보기만도 가능.
- **안전장치**: 드라이브 루트 삭제 차단, 나이 필터는 파일 단위 적용, 잠긴 파일은 건너뜀.
- **브라우저 캐시는 옵트인** (`-ClearBrowserCache`) — 기본 실행은 브라우저를 건드리지 않음.
  - v6: Firefox 의 **Cache API / 서비스워커 스토리지 캐시**까지 정리(보통 Firefox 캐시 중 가장 큼).
- **사용 흔적(썸네일/최근항목/점프목록)도 옵트인** (`-ClearUserTraces`).
- **되돌릴 수 없는 동작도 옵트인** (`-ResetBase`) — 경고를 두 번 표시.
- **Delivery Optimization** 캐시는 OS 공식 cmdlet 으로 안전하게 정리.
- 오타 파라미터 추천, 옵션 조합 경고, 로그 기록, 관리자 자동 상승, 자동화용 조용한 모드 지원.
- PowerShell 5.1 / 7 모두 동작.

**지우지 않는 것**: 방문 기록, 쿠키, 북마크, localStorage, IndexedDB. 로그인은 유지됩니다
(10장 참고).

---

## 2. 요구 사항

| 항목 | 내용 |
|---|---|
| OS | Windows 10 / 11 (Windows Server 포함) |
| PowerShell | Windows PowerShell 5.1 또는 PowerShell 7+ |
| 권한 | 사용자 캐시는 일반 권한으로 가능. `C:\Windows` 하위, Delivery Optimization, DISM 등은 **관리자 권한** 권장 |
| 모듈 | Delivery Optimization 정리는 Windows 기본 제공 `DeliveryOptimization` 모듈 사용 |

관리자가 아니면 접근 불가한 대상은 경고 후 건너뛰고 나머지는 정상 정리합니다.

---

## 3. 빠른 시작

```powershell
# 무엇이 지워질지 미리보기 (아무것도 삭제 안 함)
powershell -ExecutionPolicy Bypass -File .\clear-browser-and-windows-cache-v6.ps1 -Preview

# 기본 정리 (요약 확인 후 Y 입력)
powershell -ExecutionPolicy Bypass -File .\clear-browser-and-windows-cache-v6.ps1

# 브라우저 캐시까지 (브라우저 정상 종료 후 삭제)
.\clear-browser-and-windows-cache-v6.ps1 -ClearBrowserCache

# 딥 클린 + 관리자 자동 상승 + 확인 생략 + 로그
.\clear-browser-and-windows-cache-v6.ps1 -Elevate -DeepWindowsCache -Force -LogPath C:\logs\clean.log

# 공간을 최대로 확보 (주의: 업데이트 롤백 불가, 아래 5.9 참고)
.\clear-browser-and-windows-cache-v6.ps1 -CleanupComponentStore -ResetBase
```

> 인자 없이 실행하면 상단에 전체 파라미터 표(사용법)가 출력됩니다.

---

## 4. 파라미터

v5 와 동일합니다. v6 에서 추가·삭제된 파라미터는 없습니다.

| 파라미터 | 형식 | 설명 |
|---|---|---|
| `-OlderThanDays <N>` | 정수 | N일보다 오래된 파일만 삭제. 기본 `0` = 나이 무관 전체 |
| `-Preview` | 스위치 | 요약만 표시하고 삭제하지 않음 |
| `-Force` | 스위치 | 확인 프롬프트 생략 |
| `-ClearBrowserCache` | 스위치 | 브라우저를 정상 종료한 뒤 브라우저 캐시 삭제 |
| `-ForceCloseBrowsers` | 스위치 | 브라우저를 즉시 강제 종료 (종료 방식 지정, `-ClearBrowserCache` 와 함께 사용) |
| `-IncludeWindowsUpdateCache` | 스위치 | Windows Update 다운로드/로그 캐시 포함 |
| `-DeepWindowsCache` | 스위치 | 딥 시스템 캐시 정리(아래 5장). WU/DO 캐시도 자동 포함 |
| `-ClearUserTraces` | 스위치 | 썸네일 캐시·최근 항목·점프 목록 정리(사용 흔적) |
| `-EmptyRecycleBin` | 스위치 | 휴지통 비우기 |
| `-CleanupComponentStore` | 스위치 | DISM 구성 요소 저장소 정리 (관리자 필요) |
| `-ResetBase` | 스위치 | 위 DISM 정리에 `/ResetBase` 추가. 공간 더 확보, **업데이트 롤백 불가** |
| `-RunDiskCleanup` | 스위치 | `cleanmgr /sagerun:100` 실행 |
| `-RebuildExplorerCache` | 스위치 | 탐색기 재시작 + 썸네일/아이콘 캐시 재생성 |
| `-ClearDeliveryOptimizationCache` | 스위치 | Delivery Optimization 캐시 정리 (관리자 권장) |
| `-LogPath <파일>` | 문자열 | 이번 실행의 전체 로그를 파일에 기록(append) |
| `-Quiet` | 스위치 | 파라미터 표/진행 로그 숨김(요약·결과·경고는 유지) |
| `-Elevate` | 스위치 | 비관리자면 관리자로 재실행(UAC) |

---

## 5. 무엇을 정리하나

### 5.1 기본(항상 정리)
- Windows Temp (`%WINDIR%\Temp`), **SystemTemp (`%WINDIR%\SystemTemp`, v6 추가)**, User Temp (`%TEMP%`)
- Windows 로그: `Logs`, `debug`, `System32\LogFiles`, USO 로그
- 글꼴 캐시(FontCache)

### 5.2 `-IncludeWindowsUpdateCache`
- Windows Update 다운로드(`SoftwareDistribution\Download`), Update 로그

### 5.3 `-DeepWindowsCache` (딥 시스템 캐시)
- **CryptnetUrlCache** — User / SystemProfile / LocalService / NetworkService 4개 프로필
- **D3DSCache** (DirectX Shader Cache)
- **WER** (Windows Error Reporting) — ReportQueue / ReportArchive / Temp (사용자 + 시스템)
- 추가로 `-IncludeWindowsUpdateCache` 와 `-ClearDeliveryOptimizationCache` 를 자동 활성화

### 5.4 `-ClearUserTraces` (사용 흔적, 기본 제외)
- Explorer 썸네일/아이콘 캐시(`thumbcache_*.db`, `iconcache_*.db`)
- 최근 항목 바로가기(`Recent\*.lnk`)
- 점프 목록(`AutomaticDestinations`, `CustomDestinations`)

### 5.5 `-ClearBrowserCache` (브라우저, 기본 제외)
- **Firefox** — 프로필이 여러 개면 각각 처리 (5.6 참고)
  - `%LOCALAPPDATA%` 쪽: `cache2`, `startupCache`, `thumbnails`, `jumpListCache`, `safebrowsing`
  - `%APPDATA%` 쪽: **Cache API / 서비스워커 스토리지 캐시** (v6 추가)
- Chromium 계열(Chrome/Edge/Brave/Vivaldi): `Cache`, `Code Cache`, `GPUCache`,
  `ShaderCache`, `Service Worker` 캐시 등 프로필별
- Opera

### 5.6 Firefox 프로필과 두 개의 뿌리 (v6 핵심 변경)

Firefox 는 프로필 하나를 **두 위치에 나눠** 저장합니다. v5 는 앞의 하나만 스캔했습니다.

| 경로 | 담긴 것 |
|---|---|
| `%LOCALAPPDATA%\Mozilla\Firefox\Profiles\<프로필>` | 디스크 캐시(`cache2` 등) |
| `%APPDATA%\Mozilla\Firefox\Profiles\<프로필>` | **Cache API / 서비스워커 스토리지** |

두 뿌리 모두 **프로필 폴더를 전부 순회**하므로 프로필 개수 제한이 없습니다. 요약 표에는
프로필 이름이 함께 찍혀 어느 프로필에서 얼마나 지워지는지 구분됩니다.

스토리지 캐시의 실제 경로는 이렇습니다.

```
%APPDATA%\Mozilla\Firefox\Profiles\<프로필>\storage\<버킷>\<origin>\cache
                                             |         |
                                             |         +-- 사이트별 (예: https+++www.google.com)
                                             +-- default / temporary / permanent
```

**중요: `<origin>` 폴더 자체는 절대 지우지 않고, 그 아래 `cache` 폴더만 지웁니다.**
형제 폴더에 실제 사이트 데이터가 있기 때문입니다.

| 형제 폴더 | 내용 | 처리 |
|---|---|---|
| `cache` | Cache API / 서비스워커 응답 캐시 (재생성됨) | **삭제** |
| `idb` | IndexedDB — 사이트가 저장한 실제 데이터 | 보존 |
| `ls` | localStorage — 로그인 상태 등 | 보존 |
| `.metadata*` | 스토리지 관리 정보 | 보존 |

origin 이 수십 개라 그대로 등록하면 요약이 수십 줄로 도배됩니다. 그래서 **한 줄로 묶고
origin 개수를 함께 표시**합니다.

```
  Firefox        8553 files     459.16 MB   m0tb0fja.default-release / storage cache (59 origins)
```

### 5.7 `-ClearDeliveryOptimizationCache`
- Windows Update 다운로드 공유(P2P) 캐시. 공식 cmdlet `Delete-DeliveryOptimizationCache`
  로 정리(위치/권한/서비스 잠금을 OS 가 처리). cmdlet 이 없을 때만 수동 삭제로 폴백.

### 5.8 추가 동작(파일 삭제 후 실행)
- `-EmptyRecycleBin` : 휴지통 비우기(모든 드라이브)
- `-RebuildExplorerCache` : 탐색기 재시작 + 썸네일/아이콘 캐시 재생성
- `-CleanupComponentStore` : `DISM /Online /Cleanup-Image /StartComponentCleanup`
- `-RunDiskCleanup` : `cleanmgr /sagerun:100` (사전 `cleanmgr /sageset:100` 설정 권장)

### 5.9 `-ResetBase` (구성 요소 저장소 완전 정리, 되돌릴 수 없음)

`-CleanupComponentStore` 와 **함께** 쓸 때만 동작하며, DISM 명령에 `/ResetBase` 를 추가합니다.

| | 내용 |
|---|---|
| **이득** | 대체된(superseded) 컴포넌트를 **전부** 제거 -> WinSxS 가 실제로 줄어들어 보통 **수 GB** 추가 확보. `/StartComponentCleanup` 단독은 최근 업데이트에 30일 유예를 두지만 `/ResetBase` 는 그것까지 정리 |
| **대가** | **설치된 Windows 업데이트를 제거(롤백)할 수 없게 됩니다.** "업데이트 제거" 목록이 비워지고, 문제 있는 업데이트를 되돌릴 수 없습니다 |
| **시간** | 훨씬 오래 걸립니다(수십 분 가능). 스크립트는 완료까지 대기 |

되돌릴 수 없으므로 기본값이 아니라 **옵트인**이며, 실행 전에 경고를 두 번 표시합니다
(조합 경고 + DISM 실행 직전). 디스크 공간이 급할 때 의도적으로만 사용하세요.

```
- /ResetBase makes installed Windows updates permanent (they can no longer be uninstalled).
  -> Drop -ResetBase to keep the ability to roll back updates.
```

---

## 6. 브라우저 종료 방식

`-ClearBrowserCache` 는 캐시를 지우기 전에 브라우저를 닫습니다.

- 기본(`-ClearBrowserCache`): **정상 종료 우선** — `CloseMainWindow()` 요청 후 최대 10초
  대기, 그래도 남아 있으면 강제 종료.
- `-ForceCloseBrowsers`: **즉시 강제 종료**.

출력 예:
```
Closing browsers...
  Chrome     Graceful shutdown... OK
  Edge       Graceful shutdown... OK
  Firefox    Graceful shutdown... Timeout
  Firefox    Force kill... OK
```

| 실행 | 결과 |
|---|---|
| (옵션 없음) | 브라우저 캐시 정리 안 함 |
| `-ClearBrowserCache` | 정상 종료 후 캐시 삭제 |
| `-ClearBrowserCache -ForceCloseBrowsers` | 강제 종료 후 캐시 삭제 |

---

## 7. 옵션 조합 경고 / 오타 추천

- **오타 추천**: `-Froce` 처럼 잘못 입력하면 실행을 멈추고 가까운 파라미터를 추천.
  ```
  Unknown parameter : -Froce

  Did you mean?
    -Force
  ```
- **조합 경고**(실행 전 안내):
  - `-Preview -Force` : Preview 중엔 Force 무의미
  - `-ForceCloseBrowsers` 를 `-ClearBrowserCache` 없이 사용 : 브라우저는 닫히지만 캐시는
    안 지워짐 -> `-ClearBrowserCache` 추가 안내
  - `-Preview` + 브라우저 종료 옵션 : Preview 에선 브라우저를 닫지 않음
  - `-ResetBase` 를 `-CleanupComponentStore` 없이 사용 : 무시됨 ->
    `-CleanupComponentStore` 추가 안내
  - `-ResetBase` 를 실제 실행 : 업데이트 롤백 불가 경고(위 5.9)

---

## 8. 로그와 종료 코드 (자동화)

### 8.1 로그
`-LogPath C:\logs\clean.log` 를 주면 이번 실행의 전체 출력(요약·항목별 결과·건너뛴 파일과
사유·최종 결과)이 해당 파일에 append 됩니다. 상위 폴더가 없으면 생성합니다.

### 8.2 조용한 모드
`-Quiet` 는 파라미터 표와 항목별 진행 로그(`Cleaning: ...`)를 숨깁니다. 요약/경고/최종
결과는 유지되어 스케줄러 로그가 깔끔해집니다.

### 8.3 종료 코드

| 코드 | 의미 |
|---|---|
| `0` | 정상 완료 / Preview / 지울 것 없음 |
| `1` | 사용자가 확인 프롬프트에서 취소 |
| `2` | 잘못된 파라미터(오타) |

### 8.4 작업 스케줄러 예시
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass ^
  -File C:\opt\bin\clear-browser-and-windows-cache-v6.ps1 ^
  -DeepWindowsCache -OlderThanDays 7 -Force -Quiet -LogPath C:\logs\clean.log
```
(관리자 권한이 필요하면 작업을 "가장 높은 수준의 권한으로 실행"으로 등록하거나 `-Elevate`
사용. `-Elevate` 는 대화형 UAC 를 띄우므로 무인 실행에는 스케줄러의 관리자 실행 옵션을 권장.)

무인 실행에는 `-ResetBase` 를 넣지 않는 편을 권장합니다(되돌릴 수 없고 오래 걸림).

`-Elevate` 동작:
- **비관리자**에서 실행 -> 관리자로 재실행(UAC). 상승된 실행은 새 창에서 동작.
- **이미 관리자(Admin Console)**에서 실행 -> 재실행하지 않고 현재 세션에서 계속하며 다음 안내
  출력: `Already running as Administrator; -Elevate not needed.`

---

## 9. 요약 표 읽는 법

```
===== Browser + Windows cache cleanup summary =====
  Windows         381 files     326.24 MB   User Temp
  Firefox        1678 files       4.63 MB   m0tb0fja.default-release / cache2
  Firefox          42 files      11.89 MB   m0tb0fja.default-release / safebrowsing
  Firefox        8553 files     459.16 MB   m0tb0fja.default-release / storage cache (59 origins)
  DeepCache        28 files      28.27 KB   CryptnetUrlCache / User
  DO                9 files       6.14 GB   Delivery Optimization (cleared via cmdlet)
  ----------------------------------------------------------------------------
                10691 files       6.93 GB   TOTAL

Additional actions after confirmation:
  - Run DISM component store cleanup with /ResetBase (installed updates become permanent).
```
- 카테고리: `Windows`, `DeepCache`, `UserTraces`, 브라우저명(`Firefox`/`Chrome` 등), `DO`
- Firefox 행의 앞부분(`m0tb0fja.default-release`)은 **프로필 이름**입니다. 프로필이 여러 개면
  각각 따로 찍힙니다.
- `(59 origins)` 는 여러 폴더를 한 줄로 묶었다는 표시입니다(5.6 참고).
- `DO` 행은 Delivery Optimization 캐시 크기(공식 cmdlet 으로 삭제되며 TOTAL 에 포함)
- "Additional actions" 는 파일 삭제 후 실행될 추가 작업 목록(DISM/휴지통/디스크 정리 등)
- 완료 후에는 디스크 여유 공간을 함께 표시:
  ```
  C: free space: 40.20 GB -> 46.70 GB (reclaimed 6.50 GB)
  ```
- 참고: DISM(`-CleanupComponentStore`) 로 확보되는 공간은 파일 스캔 대상이 아니라 위 TOTAL 에
  포함되지 않습니다. 실제 확보량은 완료 후 free space 줄로 확인하세요.

---

## 10. 안전 및 주의사항

- **되돌릴 수 없는 삭제**입니다. 처음에는 `-Preview` 로 확인하세요.
- **지우지 않는 것**: 방문 기록, 쿠키, 북마크, localStorage(`ls`), IndexedDB(`idb`).
  `-ClearBrowserCache` 를 써도 **사이트 로그인은 유지**됩니다.
  - 방문 기록은 공간 확보 효과가 거의 없어(수십 MB) 제외했습니다.
  - 쿠키는 전 사이트 로그인이 풀리고 2단계 인증을 다시 해야 하는 대가가 커서 제외했습니다.
    특정 사이트 세션만 지우려면 브라우저 개발자도구의 `Delete Session Cookies` 가 정확합니다.
- **v6 에서 Firefox 삭제량이 크게 늘었습니다.** 같은 명령을 써도 v5 대비 훨씬 많이 지워집니다
  (측정 환경 기준 약 23 MB -> 약 494 MB). 부수 효과로 서비스워커 오프라인 캐시가 사라져
  해당 사이트/PWA 는 다음 접속 시 다시 내려받습니다.
- `safebrowsing` 을 지우면 Firefox 가 보호 목록을 다시 내려받습니다(약 12 MB 트래픽 1회).
- **포터블/커스텀 경로 Firefox 프로필은 대상이 아닙니다.** 기본 프로필 루트만 순회하므로
  `profiles.ini` 에 절대 경로(`IsRelative=0`)로 등록된 프로필은 찾지 못합니다.
- `-ResetBase` 는 **업데이트 롤백 능력을 영구히 포기**합니다. 문제 업데이트를 되돌릴 수
  없으니, 공간이 급할 때만 의도적으로 사용하세요(5.9 참고).
- `-ClearBrowserCache` / `-ForceCloseBrowsers` 는 브라우저를 닫습니다 — 저장하지 않은 탭이
  사라질 수 있습니다.
- `-EmptyRecycleBin` 은 모든 드라이브의 휴지통을 비웁니다.
- `-OlderThanDays` 는 파일 단위로 적용되어, 오래된 폴더 안의 최신 파일은 보존됩니다.
  (단, Delivery Optimization 은 cmdlet 에 나이 필터가 없어 전체가 지워지며 경고가 표시됩니다.)
- Delivery Optimization / `C:\Windows` 하위 대상은 관리자 권한과 서비스 중지가 필요할 수
  있으며, 잠긴 파일은 사유(`Access denied` / `Locked by DoSvc`)와 함께 건너뜁니다.
- 썸네일 db 는 탐색기가 사용 중이면 잠겨 건너뜁니다. 완전 재생성은 `-RebuildExplorerCache`.

### 10.1 사각지대 점검 (브라우저 메이저 업데이트 후 한 번)

이 스크립트는 **아는 이름의 폴더만** 지웁니다(5.5 목록). 그래서 브라우저가 새 캐시 폴더를
만들면 조용히 누락되며, **요약 표는 정상으로 보입니다** — 잡은 것만 보여주고 안 잡은 것은
보여주지 않기 때문입니다. v5 가 Firefox 프로필 용량의 5% 만 훑고 있었던 것도 이 방식으로는
드러나지 않았습니다.

그래서 도구 대신 **점검 방법**을 남깁니다. 브라우저를 크게 업데이트한 뒤 한 번 돌려보면
충분합니다.

```powershell
# Firefox (프로필 이름은 %APPDATA%\Mozilla\Firefox\profiles.ini 에서 확인)
Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles\<프로필>" -Directory |
  ForEach-Object { [pscustomobject]@{ Name = $_.Name
    MB = [math]::Round((Get-ChildItem $_.FullName -Recurse -File -EA SilentlyContinue |
         Measure-Object Length -Sum).Sum / 1MB, 1) } } | Sort-Object MB -Descending

# LOCALAPPDATA 쪽도 같은 방식으로. Chromium 계열은 프로필 폴더가 한 곳에 모여 있음:
#   %LOCALAPPDATA%\Google\Chrome\User Data\Default
```

**판단 기준**: 크기 상위 폴더 중 **캐시 성격인데 5.5 목록에 없는 것**이 있으면 사각지대입니다.
지워선 안 되는 것과 구분해야 합니다. 2026-08-07 측정 시점의 Firefox roaming 프로필은
폴더 19개 중 50 MB 초과가 `storage` 하나였고, 그것이 v6 에서 대상에 포함되었습니다.

| 폴더 | 크기 | 성격 | 대상 |
|---|---|---|---|
| `storage` | 626.6 MB | Cache API + IndexedDB + localStorage | `cache` 하위만 (5.6) |
| `extensions` | 23.0 MB | 설치된 확장기능 | 아니오 |
| `gmp-widevinecdm` | 21.6 MB | 미디어 DRM 모듈 | 아니오 |
| `security_state` | 17.0 MB | 인증서 폐기 목록 등 | 아니오 |
| `wallpaper` | 14.9 MB | 새 탭 배경 | 아니오 |

> 이 점검을 스크립트 기능으로 넣지 않은 이유: "안 지우는 폴더" 화이트리스트를 브라우저마다
> 영구히 관리해야 하고, 업데이트로 폴더가 늘면 오탐이 떠서 결국 무시하게 됩니다. 반면
> `unclaimed <크기>` 처럼 숫자만 출력하면 지켜야 할 데이터 때문에 **항상 0 이 아니라** 신호가
> 되지 못합니다. 몇 년에 한 번인 점검은 수동이 맞습니다.

### 10.2 `-RunDiskCleanup` 의 사각지대 (cleanmgr 설정)

`Windows.old` 와 `$Windows.~BT` 는 소유권이 TrustedInstaller 라 스크립트가 직접 지우지 않고
`-RunDiskCleanup`(`cleanmgr /sagerun:100`)에 맡깁니다. 그런데 `cleanmgr` 는 **`/sageset:100` 에서
체크된 항목만** 지웁니다. 즉 해당 항목이 빠져 있으면 `-RunDiskCleanup` 을 줘도 그 폴더는
남습니다.

2026-08-07 점검 시점의 상태입니다(핸들러 32개 중 21개 선택됨).

| cleanmgr 핸들러 | 해당 폴더 | 상태 |
|---|---|---|
| `Previous Installations` | `C:\Windows.old` (보통 5~20 GB) | **미선택** |
| `Temporary Setup Files` | `$Windows.~BT` / `$Windows.~WS` | **미선택** |
| `Update Cleanup` | WinSxS 업데이트 잔여 | 선택됨 |
| `System error memory dump files` | `MEMORY.DMP` | 선택됨 |
| `Internet Cache Files` | `INetCache` / `WebCache` | 선택됨 |

현재 두 폴더가 없어 증상은 없습니다. 다만 Windows 를 크게 업데이트한 뒤에는 `Windows.old` 가
생기므로, 그 전에 아래 중 하나로 설정해 두어야 `-RunDiskCleanup` 이 실제로 회수합니다.

**주의: `cleanmgr /sageset:100` 대화상자에는 "지금 지울 것이 있는" 핸들러만 표시됩니다.**
`Windows.old` 가 없는 상태에서는 `Previous Installations` 항목이 **목록에 아예 나오지 않아
체크할 수 없습니다.** 반면 레지스트리 키는 항상 존재하므로, 미리 설정하려면 방법 2를 써야
합니다. (2026-08-07 확인: 대화상자에 `Temporary Setup Files` 는 보이고
`Previous Installations` 는 안 보였음.)

```powershell
# 방법 1: 대화형으로 체크 - 해당 폴더가 이미 생긴 뒤에만 가능
cleanmgr /sageset:100

# 방법 2: 레지스트리로 직접 (관리자 필요). 폴더가 없어도 미리 설정 가능
#         StateFlags0100 = 2 가 "선택됨"
$base = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
foreach ($h in 'Previous Installations', 'Temporary Setup Files') {
    Set-ItemProperty -Path (Join-Path $base $h) -Name StateFlags0100 -Value 2 -Type DWord
}

# 현재 선택 상태 확인
Get-ChildItem $base | ForEach-Object {
    [pscustomobject]@{ Handler = $_.PSChildName
        Selected = (Get-ItemProperty $_.PSPath -EA SilentlyContinue).StateFlags0100 }
} | Sort-Object Handler
```

> `Internet Cache Files` 가 선택되어 있어 `INetCache` / `WebCache` 는 `-RunDiskCleanup` 이
> 처리합니다. 그래서 스크립트 자체 대상에는 중복으로 넣지 않았습니다.

---

## 11. 버전 메모

- v6 기준 문서입니다. 상세 변경 이력은 `clear-browser-and-windows-cache-v6-CHANGELOG.md` 참고.
- 스크립트에 쓰인 cmdlet/문법 설명은 `clear-browser-and-windows-cache-v6-cmdlet-syntax.md` 참고.
- **v6 추가**: Firefox Cache API / 서비스워커 스토리지 캐시, `safebrowsing` 캐시,
  여러 폴더를 한 줄로 묶는 `Add-CleanupTargetGroup`. **파라미터 변경 없음.**
- v5 대비 동작 변경: `-ClearBrowserCache` 의 Firefox 삭제 범위 확대(위 10장).
- v5 추가: `-ResetBase` (DISM `/ResetBase`, 옵트인). 기본 동작 변경 없음.
- v4 대비 동작 변경: 없음(옵션 추가만).
- v3 대비 동작 변경: 썸네일 캐시/최근 항목 삭제가 기본 -> `-ClearUserTraces` 옵트인으로 이동.
- v2 대비 동작 변경: 브라우저 캐시 삭제가 항상 -> `-ClearBrowserCache` 옵트인으로 이동.
