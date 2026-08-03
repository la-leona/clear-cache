# clear-cache-gui.ps1 — 설명 문서

`clear-browser-and-windows-cache-v5.ps1` 을 위한 **PowerShell + WPF GUI 프론트엔드**입니다.
체크박스로 옵션을 고르고, 미리보기로 확인한 뒤 정리를 실행합니다.

> v5 스크립트는 **수정하지 않습니다.** 이 GUI 는 인자를 조립해 v5 를 자식 프로세스로 실행하고
> 그 출력을 창에 스트리밍하는 얇은 래퍼입니다.

---

## 1. 실행 방법

```powershell
powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File C:\opt\bin\clear-cache-gui.ps1
```

위 방법은 **콘솔 창이 함께 뜹니다.** 콘솔 없이 GUI 만 띄우려면 아래 `.vbs` 런처를 쓰세요.

### 권장: `.vbs` 런처 (콘솔 창 없음)

```
wscript.exe "C:\opt\bin\clear-cache-gui.vbs"
```
`clear-cache-gui.vbs` 를 더블클릭하거나, 이 파일로 바탕화면 바로가기를 만들면 됩니다.
바로가기 속성 → **자세히(Advanced) → "관리자 권한으로 실행" 체크**를 권장합니다
(Windows / DISM / Delivery Optimization 대상에 필요).

### 왜 `-WindowStyle Hidden` 으로는 안 되나

기본 콘솔 호스트가 **Windows Terminal** 이면 `-WindowStyle Hidden` 을 줘도 콘솔이 숨겨지지
않습니다. 터미널이 별도 프로세스라 요청한 창 스타일을 무시하기 때문입니다. 스크립트 안에서
`ShowWindow` 로 숨기는 방법도 같은 이유로 통하지 않습니다(실제 콘솔이 `PseudoConsoleWindow`).

실측 결과:

| 실행 방법 | 결과 |
|---|---|
| `powershell.exe -File ...` | GUI + 콘솔 창 |
| `powershell.exe -WindowStyle Hidden -File ...` | GUI + **콘솔 창(그대로 보임)** |
| **`wscript.exe clear-cache-gui.vbs`** | **GUI 만** (깜빡임 없음) |
| `conhost.exe --headless powershell.exe -File ...` | GUI 만 (문서화되지 않은 옵션) |

`wscript.exe` 는 자체 콘솔이 없는 GUI 앱이고 `.vbs` 가 PowerShell 을 숨긴 상태로 실행하므로
콘솔이 아예 생기지 않습니다.

> 참고: 기본 터미널을 "Windows 콘솔 호스트(conhost)"로 바꾸면 `-WindowStyle Hidden` 도
> 동작하지만, 시스템 전체의 콘솔 사용 방식이 바뀌므로 권장하지 않습니다.

**필요 파일** — 같은 폴더에 `clear-browser-and-windows-cache-v5.ps1` 이 있어야 합니다.
(GUI 와 `.vbs` 모두 자기 폴더 기준으로 파일을 찾으므로 폴더째 복사해도 동작합니다.)

### 아이콘 (창 / 작업표시줄)

바로가기에 지정한 아이콘은 **바로가기에만** 적용되므로, 그대로 두면 창 제목줄과 작업표시줄에는
PowerShell 아이콘이 나옵니다. GUI 는 시작할 때 자기 폴더의 **`clear-cache-gui.ico`** 를 찾아
`Window.Icon` 에 적용합니다.

- 파일 이름은 **`clear-cache-gui.ico` 고정**입니다. 다른 아이콘을 쓰려면 이 이름으로 복사하거나
  바꿔 두세요.
- 다중 크기 `.ico` 인 경우 **32x32 프레임을 우선 사용**합니다. Windows 는 작업표시줄과 Alt+Tab 에
  32px, 제목줄에 16px 를 쓰기 때문에, 32px 원본이 가장 또렷합니다(16px 로 축소해도 2:1 로 깔끔).
  32 가 없으면 그보다 큰 가장 작은 프레임, 그것도 없으면 가장 큰 프레임을 씁니다.
- 파일이 없거나 깨져 있으면 조용히 넘어가고 기본 아이콘을 사용합니다(실행에 영향 없음).
- 바로가기 아이콘과 창 아이콘을 맞추려면 바로가기에도 **같은 `.ico` 파일**을 지정하세요.

---

## 2. 화면 구성

| 영역 | 내용 |
|---|---|
| **Cleanup targets** | 정리 대상 체크박스. 좌측은 Windows/시스템, 우측은 브라우저·DISM·기타 |
| **Options** | 나이 필터(N일), 관리자 실행, Quiet, 로그 파일 경로 |
| **Command that will run** | 선택에 따라 실제로 실행될 명령을 실시간 표시 |
| **버튼 줄** | Preview / Run cleanup / Cancel / Clear output / Open log / Reset defaults … 오른쪽 끝 **Exit** |
| **Output** | v5 의 출력을 실시간 표시(요약 표가 정렬되도록 고정폭 글꼴 사용) |
| **하단 상태줄** | 진행 표시 + 상태(Ready / Scanning / Cleaning / Done) |

`Windows temp / logs / font cache` 는 v5 의 기본 정리 대상이라 체크박스가 없습니다(항상 정리).

---

## 3. 버튼

| 버튼 | 동작 |
|---|---|
| **Preview (scan only)** | `-Preview` 로 실행. 아무것도 삭제하지 않고 요약만 표시 |
| **Run cleanup** | 확인 대화상자 후 실제 정리 실행(`-Force` 전달) |
| **Cancel** | 실행 중인 프로세스 트리 종료. DISM 이 켜져 있으면 한 번 더 확인 |
| **Clear output** | 출력 창 비우기 |
| **Open log** | 로그 파일을 메모장으로 열기(경로가 설정되어 있고 파일이 있을 때) |
| **Reset defaults** | 모든 옵션을 `clear-all.ps1` 기본값으로 되돌림 |
| **Exit** | 창 닫기. 설정을 저장하고, 실행 중이면 중단할지 물어봄 |

---

## 4. 옵션 기본값 (`clear-all.ps1` 과 동일)

처음 실행 시 아래가 **체크된 상태**로 시작합니다.

| 체크 | 옵션 |
|---|---|
| v | `-ClearBrowserCache` (브라우저 캐시, 브라우저 먼저 종료) |
| v | `-IncludeWindowsUpdateCache` |
| v | `-DeepWindowsCache` (Cryptnet / D3DSCache / WER) |
| v | `-ClearDeliveryOptimizationCache` |
| v | `-ClearUserTraces` (썸네일 / 최근 항목 / 점프 목록) |
| v | `-EmptyRecycleBin` |
| v | `-CleanupComponentStore` (DISM) |
| v | `-ResetBase` (주의: 업데이트 롤백 불가) |
| v | Run as Administrator |
| | `-ForceCloseBrowsers`, `-RebuildExplorerCache`, `-RunDiskCleanup`, `-Quiet`, 로그 경로 |

나이 필터는 `0`(전체)로 시작합니다.

---

## 5. 짝이 필요한 옵션 (GUI 에서 사전 차단)

v5 는 잘못된 조합을 **경고**로 알려주지만, GUI 는 애초에 선택할 수 없게 막습니다.

| 상위 옵션 | 하위 옵션 | 동작 |
|---|---|---|
| `-ClearBrowserCache` | `-ForceCloseBrowsers` | 상위가 꺼지면 하위는 **비활성 + 자동 해제** |
| `-CleanupComponentStore` | `-ResetBase` | 상위가 꺼지면 하위는 **비활성 + 자동 해제** |

`-ResetBase` 는 되돌릴 수 없는 옵션이라 **빨간색**으로 표시됩니다.

---

## 6. 설정 저장 (JSON, 포터블)

설정은 **스크립트 옆에 저장하는 포터블 방식**입니다. 폴더째로 복사/백업하면 설정까지 함께
따라갑니다.

| 순위 | 경로 | 사용 조건 |
|---|---|---|
| 1 | **`<스크립트 폴더>\clear-cache-gui.settings.json`** (예: `C:\opt\bin\...`) | 그 폴더에 쓸 수 있으면 항상 이곳 |
| 2 | `%APPDATA%\clear-cache-gui\settings.json` | 1번이 불가할 때(읽기 전용 매체, 권한 제한 등) 자동 폴백 |

- **저장 시점**: 창을 닫을 때(Exit / X 버튼), 그리고 Preview·Run 을 시작할 때
  (실행 중 창이 강제 종료되어도 선택이 남도록).
- **복원 시점**: 시작할 때. **1순위 파일이 있으면 그것을**, 없으면 2순위를 읽습니다.
  둘 다 없으면 `clear-all.ps1` 기본값으로 시작하며, 출력 창 첫 줄에 어느 경로를 썼는지 표시합니다.
- **자동 이관**: 이전 버전에서 `%APPDATA%` 에 저장해 뒀다면, 그 값을 한 번 읽어들인 뒤 다음
  저장 때 스크립트 옆으로 옮겨 적습니다(이후로는 1순위 파일만 사용).
  `%APPDATA%` 쪽 파일은 지우지 않으니, 원하면 직접 삭제해도 됩니다.
- 파일이 깨져 있으면 무시하고 기본값으로 시작합니다(실행 실패 없음).
- 초기화하려면 **Reset defaults** 를 누르거나 json 파일을 삭제하면 됩니다.

저장 형식 예시:
```json
{
  "version": 1,
  "chkWU": true,
  "chkDeep": true,
  "chkDO": true,
  "chkTraces": true,
  "chkRecycle": true,
  "chkBrowser": false,
  "chkForceKill": false,
  "chkComponent": true,
  "chkResetBase": false,
  "chkRebuild": false,
  "chkDisk": true,
  "chkQuiet": true,
  "chkElevate": true,
  "olderThanDays": 30,
  "logPath": "C:\\logs\\my clean.log"
}
```

---

## 7. 설계상 알아둘 점

**(1) `-Force` 를 항상 자식에 전달합니다.**
GUI 는 콘솔을 숨기고 v5 를 실행하므로 v5 의 `Proceed with cleanup? (Y/N)` 프롬프트에 답할 수
없어 그대로 멈춥니다. 그래서 확인은 **GUI 의 대화상자**가 담당하고, v5 에는 `-Force` 를 넘깁니다.
확인 대화상자는 선택한 위험 항목을 개별로 안내합니다(브라우저 종료 / `/ResetBase` 영구성 /
휴지통 / Explorer 재시작).

**(2) `-Elevate` 는 자식에 전달하지 않습니다.**
v5 의 `-Elevate` 는 **새 창**을 띄워 자신을 재실행하는데, 그러면 GUI 가 출력을 캡처할 수
없습니다. 그래서 "Run as Administrator" 가 켜져 있고 현재 관리자가 아니면 **GUI 자체를 관리자로
재시작**할지 물어봅니다(효과는 동일).
- Yes : 관리자 창으로 다시 시작(현재 창은 닫힘)
- No : 권한 없이 계속(일부 대상은 건너뜀)
- Cancel : 실행 취소

**(3) Preview 에는 `-Force` 를 넣지 않습니다.**
Preview 는 프롬프트가 없어 `-Force` 가 무의미하고, 넣으면 v5 가
`Force has no effect while Preview is enabled` 경고를 띄우기 때문입니다.

**(4) 출력은 v5 의 콘솔 출력을 그대로 보여줍니다.**
요약 표를 GUI 로 다시 그리지 않고 원본 출력을 표시합니다. 고정폭 글꼴
(`FiraCode Nanum` → `Consolas` → `Courier New` 순으로 시도)로 표 정렬이 유지됩니다.

**(5) 취소는 프로세스 트리를 강제 종료합니다.**
`taskkill /T /F` 로 자식(dism.exe, cleanmgr 등)까지 종료합니다. **DISM 진행 중 중단은 권장하지
않으므로** DISM 옵션이 켜져 있으면 한 번 더 확인합니다.

---

## 8. 종료 코드 표시

v5 의 종료 코드를 출력 마지막 줄에 해석해 표시합니다.

| 코드 | 표시 |
|---|---|
| `0` | `completed` |
| `1` | `cancelled at prompt` |
| `2` | `bad arguments` |
| 기타 | `exit code N` |

---

## 9. 문제 해결

| 증상 | 확인할 것 |
|---|---|
| `Target script not found` | 같은 폴더에 `clear-browser-and-windows-cache-v5.ps1` 이 있는지 |
| 출력이 비어 있음 | 관리자 권한 여부, 그리고 v5 를 콘솔에서 직접 실행해 동작하는지 |
| 대상이 대부분 건너뛰어짐 | 관리자 권한 없이 실행한 경우. "Run as Administrator" 사용 |
| 설정이 복원되지 않음 | 스크립트 옆 `clear-cache-gui.settings.json` 존재 여부(Exit 또는 Preview/Run 시 저장). 없으면 `%APPDATA%\clear-cache-gui\settings.json` 확인 |
| 설정이 스크립트 옆에 안 생김 | 그 폴더에 쓰기 권한이 없어 `%APPDATA%` 로 폴백된 경우. 출력 첫 줄의 경로 확인 |
| 창은 뜨는데 실행이 안 됨 | `-ExecutionPolicy Bypass` 로 실행했는지 |
| 작업표시줄에 버튼이 안 보임 | 해결됨. `.vbs` 가 프로세스를 숨긴 상태(SW_HIDE)로 시작해 셸이 첫 창의 버튼을 만들지 않던 문제로, 창이 뜬 뒤 `ShowInTaskbar` 를 토글해 재등록합니다(이전에는 창을 움직이면 나타났음) |

---

## 10. 관련 파일

| 파일 | 설명 |
|---|---|
| `clear-cache-gui.ps1` | 이 GUI |
| `clear-cache-gui.vbs` | 콘솔 없이 GUI 를 띄우는 런처(바로가기용) |
| `clear-cache-gui.settings.json` | GUI 옵션 저장 파일(포터블, 자동 생성) |
| `clear-browser-and-windows-cache-v5.ps1` | 실제 정리 엔진 |
| `clear-all.ps1` | 원클릭 CLI (GUI 기본값의 근거) |
| `clear-browser-and-windows-cache-v5-README.md` | v5 사용 설명서 |
| `clear-browser-and-windows-cache-v5-CHANGELOG.md` | v5 변경 이력 |
| `clear-browser-and-windows-cache-v5-cmdlet-syntax.md` | v5 에 쓰인 cmdlet/문법 설명 |
