# 방법 B — PowerShell로 바로가기(.lnk) 직접 생성 (260자 제한 우회)

> `clear-browser-and-windows-cache.ps1`를 `clear-all.ps1` 래퍼 없이, 파라미터를 모두 붙여 바로가기로 등록하는 방법.
> 바로가기 **속성창의 "대상" 입력칸만 260자 제한**이 있고, **.lnk의 인수(Arguments) 필드 자체는 훨씬 길게** 담기므로 스크립트로 만들면 제한을 피할 수 있다.

---

## 0. 원리 요약
- GUI 속성창 "대상(Target)" 텍스트박스 = 260자(MAX_PATH)에서 잘림.
- `WScript.Shell.CreateShortcut()`으로 만든 .lnk의 `Arguments`는 수천 자까지 OK → **풀네임 파라미터 그대로 사용 가능.**
- 덤으로 **아이콘 지정**과 **"관리자 권한으로 실행" 플래그**도 스크립트로 설정 가능.

---

## 1. (권장) 아이콘을 안정적인 경로로 복사
바로가기의 아이콘 경로는 **고정**되어야 한다. 아이콘 파일이 옮겨지면 바로가기 아이콘이 깨진다.
스크립트 옆(`C:\opt\bin`)에 두는 것을 권장:

```powershell
Copy-Item "C:\LGCNS\workspace\lgoneid\claude-generated-doc\clear-cache.ico" "C:\opt\bin\clear-cache.ico" -Force
```

---

## 2. 바로가기 생성 스크립트

아래를 `make-shortcut.ps1` 로 저장하고 실행하면 된다. 상단 **설정 블록**만 취향대로 바꾸면 됨.

```powershell
# ===== 설정 (여기만 수정) =====
$ScriptPath   = "C:\opt\bin\clear-browser-and-windows-cache.ps1"   # 실행할 대상 스크립트
$IconPath     = "C:\opt\bin\clear-cache.ico"                        # 아이콘(.ico) — 고정 경로 권장
$ShortcutDir  = [Environment]::GetFolderPath('Desktop')            # 바로가기 위치(바탕화면). 시작메뉴 등으로 변경 가능
$ShortcutName = "캐시 정리"                                         # 바로가기 이름
$RunAsAdmin   = $true                                              # 관리자 권한으로 실행 (컴포넌트 스토어 정리에 필요)
$KeepWindow   = $false                                             # 실행 후 창 유지($true면 -NoExit 추가)

# 대상 스크립트에 넘길 파라미터 (풀네임 그대로 — 길이 제한 없음)
$Params = @(
    '-CloseBrowsers'
    '-EmptyRecycleBin'
    '-CleanupComponentStore'
    '-ClearDeliveryOptimizationCache'
    # '-IncludeWindowsUpdateCache'   # WU 캐시까지 지우려면 주석 해제(멈춤 감수)
    # '-Force'                       # 확인 프롬프트 없이 실행하려면 주석 해제
)
# ==============================

$psExe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$argList = @()
if ($KeepWindow) { $argList += '-NoExit' }
$argList += @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $ScriptPath))
$argList += $Params
$arguments = [string]::Join(' ', $argList)

$lnkPath = Join-Path $ShortcutDir ("{0}.lnk" -f $ShortcutName)

$ws = New-Object -ComObject WScript.Shell
$sc = $ws.CreateShortcut($lnkPath)
$sc.TargetPath       = $psExe
$sc.Arguments        = $arguments
$sc.WorkingDirectory = Split-Path $ScriptPath -Parent
$sc.IconLocation     = ("{0},0" -f $IconPath)
$sc.Description       = "브라우저/윈도우 캐시 정리"
$sc.WindowStyle      = 1
$sc.Save()

# "관리자 권한으로 실행" 플래그 세팅 (.lnk 헤더 0x15 바이트의 0x20 비트)
if ($RunAsAdmin) {
    $bytes = [System.IO.File]::ReadAllBytes($lnkPath)
    $bytes[0x15] = $bytes[0x15] -bor 0x20
    [System.IO.File]::WriteAllBytes($lnkPath, $bytes)
}

Write-Host "생성 완료: $lnkPath" -ForegroundColor Green
Write-Host "  Target : $psExe"
Write-Host "  Args   : $arguments"
```

---

## 3. 실행 방법
생성 스크립트 자체도 실행 정책에 걸릴 수 있으니:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\경로\make-shortcut.ps1"
```

- 바탕화면/시작메뉴 사용자 폴더에 만드는 경우 **관리자 권한 불필요**(생성만 하므로).
- (만든 바로가기를 클릭해 실제 청소를 돌릴 때는, `-CleanupComponentStore` 때문에 관리자 권한이 필요 → 그래서 `$RunAsAdmin = $true` 권장.)

---

## 4. 확인
- 바탕화면에 `캐시 정리.lnk` 생성, 아이콘이 `clear-cache.ico`로 표시되는지 확인.
- 우클릭 → 속성 → "대상"이 260자 넘어도 **잘리지 않고** 저장돼 있음(더블클릭 실행됨).
- 더블클릭 시 관리자 승인(UAC) 뜨면 `$RunAsAdmin` 정상 적용된 것.

---

## 5. 커스터마이징

| 항목 | 변경 방법 |
|---|---|
| 바로가기 위치 | `$ShortcutDir` — 시작메뉴: `"$env:APPDATA\Microsoft\Windows\Start Menu\Programs"` |
| 이름 | `$ShortcutName` |
| 관리자 실행 | `$RunAsAdmin = $true/$false` |
| 실행 후 창 유지 | `$KeepWindow = $true` (`-NoExit` 추가) |
| WU 캐시 포함 | `$Params`에서 `-IncludeWindowsUpdateCache` 주석 해제 |
| 무인 실행(확인 생략) | `$Params`에 `-Force` 추가 |

---

## 6. 트러블슈팅

| 증상 | 원인/해결 |
|---|---|
| 아이콘이 깨져 보임 | `$IconPath`의 .ico가 이동/삭제됨 → 고정 경로(예: `C:\opt\bin`)에 두고 그 경로로 지정 |
| 클릭해도 "not digitally signed" | Arguments에 `-ExecutionPolicy Bypass`가 들어가 있는지 확인(위 스크립트는 포함). 또는 대상 .ps1에 `Unblock-File` |
| 컴포넌트 스토어 정리 안 됨 | 관리자 권한 필요 → `$RunAsAdmin = $true` |
| 창이 바로 닫혀 결과 못 봄 | `$KeepWindow = $true` (`-NoExit`) |

---

## 참고 — 방법 A (GUI에서 축약해 넣기)
스크립트 없이 속성창에서 바로 하려면 파라미터를 축약해 260자 안에 맞추면 됨:
```
powershell -nop -ep Bypass -File "C:\opt\bin\clear-browser-and-windows-cache.ps1" -Clo -Em -Clean -Clear
```
(`-Clo`=CloseBrowsers, `-Em`=EmptyRecycleBin, `-Clean`=CleanupComponentStore, `-Clear`=ClearDeliveryOptimizationCache)
