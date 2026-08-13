# Changelog - clear-cache-gui

`clear-cache-gui.ps1`(WPF GUI), 콘솔 없는 런처(`clear-cache-gui.js` / 이전 `.vbs`),
그리고 그 문서들의 변경 이력입니다.

> 정리 엔진(`clear-browser-and-windows-cache-vN.ps1`)의 이력은 별도 파일
> `clear-browser-and-windows-cache-v6-CHANGELOG.md` 를 참고하세요.

---

## 2026-08-13 — 런처를 `.js` 로 전환

### 변경
- 런처를 **`clear-cache-gui.vbs` → `clear-cache-gui.js`** (WSH JScript)로 전환.
  `.vbs` 는 폴백으로 남겨 둠.
- **`Invoke-GuiElevation`** 이 런처를 `clear-cache-gui.js` -> `clear-cache-gui.vbs` 순으로
  찾도록 변경. 둘 다 없을 때만 PowerShell 을 직접 재실행(이 경우 콘솔이 보일 수 있음).
- `.js` 사용법 주석에서 **`cscript.exe` 실행 방식을 제거**.
  cscript 는 콘솔 애플리케이션이라 콘솔을 할당하고 터미널 창이 순간 깜빡입니다
  (실측: wscript 추가 콘솔 **0개**, cscript **1개**). `.js` 는 `WScript.exe` 에 연결되어
  있으므로 더블클릭도 안전합니다.
- `.js` 오류 처리 개선: catch 안에서 `WScript.Shell` 을 새로 만들지 않고 기존 인스턴스를
  재사용(ActiveX 생성 자체가 실패한 경우 catch 에서 또 예외가 나던 구조), 셸이 없으면
  `WScript.Echo` 로 폴백, 오류 번호를 16진수로 함께 표시.
- WSH JScript 는 ECMAScript 3 기반이라 `'use strict'` 가 무효인 점을 주석으로 정리.
- README: `.vbs` -> `.js` 로 갱신, `cscript` 경고와 실측 비교 행 추가.

### 검증
- 구문: ps1 `PARSE OK`, `.js` 컴파일 오류 없음
  (검사 방법 자체를 일부러 깨뜨린 파일로 먼저 검증 — 깨진 파일은
  `Microsoft JScript compilation error` 를 출력)
- 실행: `wscript.exe clear-cache-gui.js` -> GUI 정상(pwsh 호스트), **콘솔 창 0개**
- 권한상승 경로가 `.js` 를 선택하는 것 확인

---

## 2026-08-07 — 대상 엔진 v5 -> v6 리타깃 (다른 세션 작업)

> 이 항목은 이 세션에서 작성한 것이 아니라 **파일 내용에서 재구성**했습니다.
> 세부 변경이 더 있었다면 보완이 필요합니다.

- `$script:TargetScript` 를 `clear-browser-and-windows-cache-v6.ps1` 로 변경
- 창 제목 `Windows / Browser Cache Cleaner (v6)`, 도움말/주석의 v5 표기를 v6 로 갱신
- `clear-cache-gui-README.md`, `clear-cache-gui-cmdlet-syntax.md` 동시 갱신
- 확인된 사실: 함수 16개 / XAML 컨트롤 27개 구성은 그대로이며, **v6 파라미터 17개를 GUI 가
  모두 커버**합니다(`-Elevate` 는 의도적 미전달, `-LogPath`/`-OlderThanDays` 는 값과 함께 전달)

---

## 2026-08-03 무렵 — 최초 구현과 안정화

시간 순서대로의 작업 내역입니다.

### 1. WPF GUI 최초 작성
- `clear-browser-and-windows-cache-v5.ps1` 의 **얇은 래퍼**로 작성. 엔진 스크립트는 수정하지
  않고 인자만 조립해 자식 프로세스로 실행하고 출력을 창에 스트리밍.
- 기본 선택값을 **`clear-all.ps1` 과 동일**하게 맞춤(브라우저 캐시, WU 캐시, 딥 캐시, 휴지통,
  DISM + `/ResetBase`, Delivery Optimization, 사용 흔적, 관리자 실행).
- 조립된 명령을 **실시간으로 보여주는 칸**(Command that will run) 추가.
- **짝 옵션 사전 차단**: `/ResetBase` 는 DISM 체크 시에만, `-ForceCloseBrowsers` 는 브라우저
  체크 시에만 활성화(엔진은 경고만 하지만 GUI 는 애초에 못 누르게).
- 실행 전 확인 대화상자에서 위험 항목을 개별 경고(브라우저 종료 / `/ResetBase` 영구성 /
  휴지통 / Explorer 재시작).
- 출력 창은 고정폭 글꼴(`FiraCode Nanum` -> `Consolas` -> `Courier New`)로 요약 표 정렬 유지.
- 종료 코드를 해석해 표시(`completed` / `cancelled at prompt` / `bad arguments`).

**설계 결정 두 가지**
- **`-Force` 를 항상 자식에 전달**: 콘솔이 숨겨져 있어 엔진의 `Proceed with cleanup? (Y/N)`
  프롬프트에 답할 수 없어 멈춥니다. 확인은 GUI 대화상자가 담당.
- **`-Elevate` 는 자식에 전달하지 않음**: 엔진이 새 창으로 자신을 재실행해 버려 출력 캡처가
  끊깁니다. 대신 **GUI 자체를 관리자로 재시작**.

### 2. JSON 설정 저장 (포터블)
- 체크박스/일수/로그 경로를 JSON 으로 저장·복원. Exit(또는 X)와 Preview/Run 시작 시 저장.
- 처음에는 `%APPDATA%\clear-cache-gui\settings.json` 에 저장했으나, **포터블 방식**으로 변경:
  1순위 스크립트 옆 `clear-cache-gui.settings.json`, 2순위 `%APPDATA%`(쓰기 불가 시 폴백).
  읽기는 1순위 우선이라 기존 `%APPDATA%` 설정은 다음 저장 때 자동 이관.
- 깨진 JSON 은 무시하고 기본값으로 시작(실행 실패 없음).

### 3. Exit / Reset defaults 버튼
- 버튼 줄을 Grid 로 바꿔 **`Exit` 를 오른쪽 끝**에 배치. `Reset defaults` 는
  `clear-all.ps1` 기본값으로 복원.

### 4. 콘솔 창 숨기기 (`.vbs` 런처 도입)
- **원인**: 기본 콘솔 호스트가 **Windows Terminal** 이면 `powershell -WindowStyle Hidden` 으로도
  콘솔이 숨겨지지 않습니다(터미널이 별도 프로세스라 창 스타일 요청을 무시). 스크립트 안에서
  `ShowWindow` 로 숨기는 방법도 통하지 않음(실제 콘솔이 `PseudoConsoleWindow`).
- **해결**: 자체 콘솔이 없는 `wscript.exe` + 런처 스크립트에서 `Run(cmd, 0, False)`.
  실측 결과 콘솔 창 0개.

### 5. 창 / 작업표시줄 아이콘
- 바로가기 아이콘은 바로가기에만 적용되므로 `Window.Icon` 을 직접 지정.
- 스크립트 옆 **`clear-cache-gui.ico`** 를 사용하고, 다중 크기 아이콘에서 **32x32 프레임을
  우선 선택**(작업표시줄·Alt+Tab 이 32px, 제목줄이 16px 이므로 가장 선명).

### 6. 작업표시줄 버튼이 안 생기는 문제 수정
- **증상**: 창은 뜨는데 작업표시줄 버튼이 없고, 창을 움직이면 뒤늦게 나타남.
- **원인**: 런처가 프로세스를 **숨긴 상태(SW_HIDE)로 시작**하면 셸이 그 프로세스의 첫 창에 대한
  작업표시줄 버튼을 만들지 않습니다. (`powershell -WindowStyle Hidden` 은 프로세스 시작 상태가
  정상이라 이 문제가 없었음 -> 원인은 **프로세스 시작 시의 창 표시 상태**)
- **해결**: 창이 뜬 뒤 `ShowInTaskbar` 를 토글해 HWND 를 재생성하여 셸에 재등록.
  UI Automation 으로 측정: 수정 전 0/4 -> 수정 후 3/3.

### 7. 출력 창 진행률 표시 수정
- **증상**: DISM 진행률이 제자리에서 갱신되지 않고 `[==== 10.0% ]` 줄이 계속 쌓임.
- **원인**: 실제 출력이 `<CR>[bar] <CR><LF>` 형태로, **각 갱신이 CRLF 로 끝나는 완결된 줄**로
  도착합니다(PowerShell 이 native 명령 출력을 줄 단위로 처리하면서 CR 되감기가 이미 줄바꿈으로
  변환됨). 그래서 CR 을 접는 처리만으로는 해결되지 않았습니다.
- **해결**: 진행률 줄을 패턴으로 인식해 **이전 바를 덮어쓰고**, 미완성 줄은 렌더링하지 않고
  버퍼링(청크 경계에서 바가 고정되는 문제 방지). 일반 출력이 오면 마지막 바는 유지.
  실제 DISM 출력 5,542자(진행률 78개)를 불균등 청크로 주입해 검증: **78개 -> 1줄**.
- 부수적으로 발견한 버그 수정: 함수 안 지역변수 `$text` 가 **PowerShell 의 대소문자 비구분**
  특성상 파라미터 `$Text` 를 덮어써 출력이 사라지던 문제 -> `$pane` 으로 개명.

### 8. 다크 테마 + pwsh 우선
- **증상**: `$win.ThemeMode = 'Dark'` 를 넣으면 `.ps1` 직접 실행은 되는데 런처 경유로는 창이
  안 뜸.
- **원인**: `Window.ThemeMode` 는 최신 .NET WPF 전용 속성입니다. pwsh 7(.NET 10)에는 있지만
  런처가 실행하던 Windows PowerShell 5.1(.NET Framework 4.8)에는 없어서, 없는 속성에 대입 ->
  `RuntimeException` -> `$ErrorActionPreference = 'Stop'` 때문에 **종료성 오류** -> 콘솔이
  숨겨져 있어 오류도 안 보인 채 종료.
- **해결**: 리플렉션으로 속성 존재를 먼저 확인
  (`$win.GetType().GetProperty('ThemeMode')`), 런처는 **pwsh 7 우선 / 5.1 폴백**.

### 9. 문서화
- `clear-cache-gui-README.md` (사용법), `clear-cache-gui-cmdlet-syntax.md`
  (WPF/XAML/이벤트/비동기 폴링 등 문법 설명) 작성.

---

## 검증에 사용한 방법 (다음 세션 참고용)

이 GUI 의 문제들은 눈으로 보기 어려워서 아래 방식으로 측정했습니다.

| 확인할 것 | 방법 |
|---|---|
| 콘솔 창이 생기는지 | `EnumWindows` P/Invoke 로 보이는 창을 열거하고 클래스명이 `CASCADIA_HOSTING_WINDOW_CLASS`(Windows Terminal) 또는 `ConsoleWindowClass` 인 것을 셈 |
| 순간 깜빡임 | 위 열거를 80ms 간격으로 25회 반복해 **최대값**을 관찰(6초 뒤 한 번 보면 이미 닫혀 못 잡음) |
| 작업표시줄 버튼 | UI Automation 으로 `Shell_TrayWnd` 의 Button 이름 목록에서 창 제목 검색 |
| 출력 창 로직 | 실제 `dism /Online /Cleanup-Image /AnalyzeComponentStore`(읽기 전용) 출력을 파일로 캡처해 두고, 그 바이트를 불균등 청크로 `Add-Output` 에 주입 |
| GUI 기동 여부 | `wscript` 로 실행 후 `Win32_Process` 에서 `-File ...clear-cache-gui.ps1` 프로세스 확인 |

> 주의: `Win32_Process` 를 `CommandLine -like '*clear-cache-gui*'` 로 필터해 `Stop-Process` 하면
> **명령문에 그 문자열을 포함한 자기 세션까지 종료**됩니다. `$_.ProcessId -ne $PID` 를 꼭 넣으세요.
