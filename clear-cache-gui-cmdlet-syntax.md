# clear-cache-gui.ps1 — 사용된 내장 함수 / 문법 설명

이 문서는 `clear-cache-gui.ps1` (PowerShell + WPF GUI) 에서 실제로 쓰인 **cmdlet**,
**.NET 타입/멤버**, **XAML/이벤트 문법**을 정리한 참고 자료입니다.
각 항목의 예시는 스크립트에서 그대로 발췌했습니다.

> 정리 엔진 쪽 문법은 `clear-browser-and-windows-cache-v5-cmdlet-syntax.md` 를 참고하세요.
> 이 문서는 **GUI 에만 등장하는 문법**에 초점을 둡니다.

---

## 1. PowerShell WPF GUI 의 기본 골격 (4단계)

```powershell
# (1) WPF 어셈블리 로드
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml

# (2) XAML 을 문자열로 작성하고 [xml] 로 변환
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" ...>
  ...
</Window>
'@

# (3) XAML 을 실제 창 객체로 만들기
$reader = New-Object System.Xml.XmlNodeReader $xaml
$win = [Windows.Markup.XamlReader]::Load($reader)

# (4) 창 표시(모달)
$win.ShowDialog() | Out-Null
```

| 요소 | 역할 |
|---|---|
| `Add-Type -AssemblyName` | .NET 어셈블리 로드. WPF 는 `PresentationFramework`(컨트롤), `PresentationCore`, `WindowsBase`, `System.Xaml` 이 필요 |
| `[xml]` 형 변환 | 문자열을 `XmlDocument` 로 변환 |
| `New-Object System.Xml.XmlNodeReader` | `XamlReader::Load` 가 요구하는 리더 생성 |
| `[Windows.Markup.XamlReader]::Load()` | XAML 을 객체 트리(Window)로 생성 |
| `ShowDialog()` | 창을 모달로 표시. **`True/False` 를 반환**하므로 `| Out-Null` 로 버림 |

`System.Windows.Forms` 는 파일 저장 대화상자(`SaveFileDialog`)만을 위해 추가로 로드합니다.
WPF 와 WinForms 를 한 스크립트에서 섞어 쓸 수 있습니다.

---

## 2. XAML 문법 요약 (이 GUI 에 쓰인 것)

### 레이아웃
```xml
<Grid Margin="10">
  <Grid.RowDefinitions>
    <RowDefinition Height="Auto"/>   <!-- 내용에 맞춰 -->
    <RowDefinition Height="*"/>      <!-- 남는 공간 전부 -->
  </Grid.RowDefinitions>
  <Grid.ColumnDefinitions>
    <ColumnDefinition Width="Auto"/>
    <ColumnDefinition Width="*"/>
  </Grid.ColumnDefinitions>
  ...
</Grid>
```

| 개념 | 설명 |
|---|---|
| `Grid` | 행/열 격자. 자식은 `Grid.Row="0" Grid.Column="1"` 로 위치 지정, `Grid.ColumnSpan="4"` 로 병합 |
| `Height="Auto"` / `"*"` | 내용 크기 / 남는 공간을 채움(비율 배분) |
| `StackPanel` | 세로(기본) 또는 `Orientation="Horizontal"` 로 가로 나열 |
| `GroupBox` | 제목(`Header`) 있는 테두리 묶음 |
| `Margin="18,3,0,3"` | 좌,상,우,하 여백(값 1개면 사방 동일, 2개면 좌우/상하) |
| `Padding` | 내부 여백 |

**부모-자식 속성 표기**(`Grid.RowDefinitions`, `Grid.Row`)는 XAML 의 "속성 요소 / 첨부 속성"
문법입니다. 점(`.`)이 들어간 태그는 속성이지 컨트롤이 아닙니다.

### 컨트롤
| 컨트롤 | 용도 | 이 GUI 에서 |
|---|---|---|
| `CheckBox` | 체크박스 | 각 정리 옵션 |
| `TextBox` | 입력/출력 | 일수, 로그 경로, 명령 미리보기, 출력 창 |
| `Button` | 버튼 | Preview / Run / Cancel / Exit 등 |
| `TextBlock` | 읽기 전용 라벨 | 설명, 상태줄 |
| `ProgressBar` | 진행 표시 | `IsIndeterminate` 로 무한 진행 애니메이션 |

### 자주 쓰는 속성
```xml
<TextBox x:Name="txtOutput" IsReadOnly="True" AcceptsReturn="True"
         VerticalScrollBarVisibility="Auto"
         FontFamily="FiraCode Nanum, Consolas, Courier New" FontSize="12"
         Background="#FF1E1E1E" Foreground="#FFDCDCDC"/>
```
- **`x:Name`** : 코드에서 찾을 이름. `XamlReader::Load` 로 로드할 때는 `x:Class` 를 쓸 수 없고
  `x:Name` 만 사용합니다.
- `IsReadOnly`, `AcceptsReturn`(여러 줄), `*ScrollBarVisibility`
- `FontFamily` 는 **쉼표로 폴백 목록**을 줄 수 있음(앞에서부터 설치된 글꼴 사용)
- 색은 `#RRGGBB` 또는 `#AARRGGBB`(알파 포함), 색 이름(`Gray`)도 가능
- `IsEnabled="False"` 로 비활성 시작(Cancel 버튼)

---

## 3. 컨트롤을 코드에서 다루기

```powershell
foreach ($n in @('chkWU','chkDeep', ... ,'lblStatus')) {
    Set-Variable -Name $n -Value $win.FindName($n) -Scope Script
}
```

| 문법 | 설명 |
|---|---|
| `$win.FindName('chkWU')` | `x:Name` 으로 컨트롤 객체 얻기 |
| `Set-Variable -Name $n -Scope Script` | **이름이 변수에 담긴 변수**를 만들 때 사용. 결과적으로 `$chkWU` 처럼 쓸 수 있음 |
| `Get-Variable -Name $n -Scope Script -ValueOnly` | 반대로 이름으로 값(컨트롤)을 꺼냄. 설정 저장/복원 루프에서 사용 |

**`IsChecked` 는 `Nullable[bool]`** 입니다(3상태 지원). 그래서 비교/저장할 때 명시적으로
`[bool]` 캐스팅을 씁니다.
```powershell
$data[$n] = [bool](Get-Variable -Name $n -Scope Script -ValueOnly).IsChecked
$chkResetBase.IsEnabled = [bool]$chkComponent.IsChecked
```

컨트롤 메서드도 그대로 호출합니다.
```powershell
$txtOutput.AppendText($Text)   # 이어붙이기
$txtOutput.ScrollToEnd()       # 맨 아래로 스크롤
$txtOutput.Clear()             # 비우기
$win.Close()                   # 창 닫기
```

---

## 4. 이벤트 처리

WPF 이벤트는 PowerShell 에서 **`Add_<이벤트명>({ 스크립트블록 })`** 으로 등록합니다.

```powershell
$btnClear.Add_Click({ $txtOutput.Clear() })          # 버튼 클릭
$chkWU.Add_Checked({   Update-CommandPreview })      # 체크됨
$chkWU.Add_Unchecked({ Update-CommandPreview })      # 체크 해제됨
$txtDays.Add_TextChanged({ Update-CommandPreview })  # 텍스트 변경
$script:Timer.Add_Tick({ ... })                      # 타이머 틱
$win.Add_Closing({ ... })                            # 창 닫히는 중
```

### 이벤트 인자와 취소
핸들러 안에서 `$_` 는 이벤트 인자(EventArgs)입니다. 닫기를 막을 때 사용합니다.
```powershell
$win.Add_Closing({
    ...
    if ($r -ne 'Yes') { $_.Cancel = $true; return }   # 창 닫기 취소
    ...
})
```

### 스크립트블록을 변수에 담아 재사용
같은 로직을 여러 이벤트에 붙이거나 직접 호출할 때 씁니다. 호출은 **`&`(호출 연산자)**.
```powershell
$syncResetBase = {
    $chkResetBase.IsEnabled = [bool]$chkComponent.IsChecked
    if (-not $chkComponent.IsChecked) { $chkResetBase.IsChecked = $false }
    Update-CommandPreview
}
$chkComponent.Add_Checked($syncResetBase)     # 이벤트로 등록
$chkComponent.Add_Unchecked($syncResetBase)
& $syncResetBase                              # 시작 시 한 번 직접 실행
```

### 스코프 주의
이벤트 핸들러는 나중에 실행되므로, 공유 상태는 **`$script:` 스코프**로 두어야 안전합니다.
```powershell
$script:Proc = $null      # 실행 중 프로세스
$script:Timer = $null     # 폴링 타이머
```

---

## 5. UI 를 멈추지 않고 외부 프로세스 실행 / 출력 스트리밍

GUI 의 핵심 난이도입니다. 이 스크립트는 **파일 리다이렉트 + 타이머 폴링** 방식을 씁니다
(이벤트 기반 비동기 읽기보다 단순하고, UI 스레드에서만 화면을 갱신하므로 안전).

```powershell
# 자식 프로세스를 숨겨서 시작하고 출력/오류를 임시 파일로 리다이렉트
$script:OutFile = [System.IO.Path]::GetTempFileName()
$script:Proc = Start-Process -FilePath (Get-HostExe) -ArgumentList $spArgs `
    -RedirectStandardOutput $script:OutFile -RedirectStandardError $script:ErrFile `
    -WindowStyle Hidden -PassThru

# 300ms 마다 파일에서 새로 늘어난 부분만 읽어 화면에 붙임
$script:Timer = New-Object System.Windows.Threading.DispatcherTimer
$script:Timer.Interval = [TimeSpan]::FromMilliseconds(300)
$script:Timer.Add_Tick({ ... })
$script:Timer.Start()
```

| 요소 | 설명 |
|---|---|
| `Start-Process -PassThru` | 시작한 프로세스 객체를 반환(`.Id`, `.HasExited`, `.ExitCode` 사용) |
| `-RedirectStandardOutput/Error` | 자식의 stdout/stderr 를 각각 **다른** 파일로(같은 파일 지정은 오류) |
| `[System.IO.Path]::GetTempFileName()` | 임시 파일 생성 |
| `DispatcherTimer` | **UI 스레드에서** 주기적으로 실행되는 타이머. WPF 화면 갱신에 안전 |
| `[TimeSpan]::FromMilliseconds(300)` | 간격 지정 |

### 쓰는 중인 파일을 동시에 읽기
자식이 계속 쓰는 파일을 열려면 **공유 모드**를 지정해야 합니다.
```powershell
$fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open,
      [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
return New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8, $true)
```
- `FileShare::ReadWrite` : 다른 프로세스가 쓰는 중에도 읽기 허용
- `StreamReader(..., encoding, $true)` : 마지막 인자는 BOM 으로 인코딩 자동 감지
- `ReadToEnd()` 를 반복 호출하면 **직전까지 읽은 위치 이후**만 반환되므로 증분 읽기가 됨
- 끝나면 `Dispose()` 로 해제(`Stop-Polling` 에서 처리)

### 종료 감지와 종료 코드 해석
```powershell
if ($script:Proc -and $script:Proc.HasExited) {
    $code = $script:Proc.ExitCode
    $meaning = switch ($code) {
        0       { 'completed' }
        1       { 'cancelled at prompt' }
        2       { 'bad arguments' }
        default { 'exit code ' + $code }
    }
}
```
`switch` 를 **식(expression)처럼** 써서 결과를 변수에 바로 대입하는 형태입니다.

### 프로세스 트리 종료
```powershell
& taskkill.exe /PID $script:Proc.Id /T /F | Out-Null
```
`/T` 는 자식까지(여기서는 `dism.exe`, `cleanmgr`), `/F` 는 강제. `Stop-Process` 는 트리를
종료하지 않으므로 `taskkill` 을 사용합니다.

---

## 6. 대화상자

### WPF MessageBox
```powershell
$r = [System.Windows.MessageBox]::Show($text, $title, 'YesNoCancel', 'Question')
switch ($r) {
    'Yes'   { ... }
    'No'    { ... }
    default { ... }
}
```
| 인자 | 값 |
|---|---|
| 버튼 | `OK`, `OKCancel`, `YesNo`, `YesNoCancel` |
| 아이콘 | `None`, `Information`, `Question`, `Warning`, `Error` |
| 반환 | `OK`/`Cancel`/`Yes`/`No` (문자열로 비교 가능) |

반환값을 쓰지 않을 때는 `| Out-Null` 로 버립니다.

### WinForms 파일 대화상자
```powershell
$dlg = New-Object System.Windows.Forms.SaveFileDialog
$dlg.Filter = 'Log files (*.log)|*.log|All files (*.*)|*.*'
$dlg.FileName = 'clean.log'
$dlg.OverwritePrompt = $false
if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $txtLog.Text = $dlg.FileName }
```
`Filter` 는 `표시이름|패턴` 쌍을 `|` 로 이어 붙인 형식입니다.

---

## 7. JSON 설정 저장/복원

```powershell
$data = [ordered]@{ version = 1 }          # 순서 보장 해시테이블
foreach ($n in $script:OptionBoxes) {
    $data[$n] = [bool](Get-Variable -Name $n -Scope Script -ValueOnly).IsChecked
}
$json = $data | ConvertTo-Json
Set-Content -LiteralPath $path -Value $json -Encoding UTF8 -ErrorAction Stop
```

```powershell
$s = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
$props = $s.PSObject.Properties.Name                    # 존재하는 속성 목록
foreach ($n in $script:OptionBoxes) {
    if ($props -contains $n) {
        (Get-Variable -Name $n -Scope Script -ValueOnly).IsChecked = [bool]$s.$n
    }
}
```

| 문법 | 설명 |
|---|---|
| `[ordered]@{ }` | 키 순서가 유지되는 해시테이블(JSON 필드 순서 고정) |
| `ConvertTo-Json` / `ConvertFrom-Json` | 객체 <-> JSON 문자열. 후자는 `PSCustomObject` 를 반환 |
| `$s.PSObject.Properties.Name` | 그 객체가 실제로 가진 속성 이름들(구버전 파일 호환 확인용) |
| `-contains` | 배열에 값이 있는지 |
| `$s.$n` | **변수에 담긴 이름으로 속성 접근**(동적 속성 접근) |
| `Get-Content -Raw` | 파일 전체를 한 문자열로(줄 배열이 아님) |

### 폴백 저장 패턴 (포터블 우선)
```powershell
foreach ($path in @($script:SettingsPathScript, $script:SettingsPathAppData)) {
    try { ... Set-Content ... -ErrorAction Stop; return $path }
    catch { }        # 다음 위치로
}
```
쓰기 가능 여부를 미리 검사하지 않고 **실제로 써 보고 실패하면 다음 후보로** 넘어가는 방식입니다
(권한/매체 상태를 가장 정확하게 반영).

---

## 8. 기타 문법

| 문법 | 예시 | 설명 |
|---|---|---|
| `if` 를 식으로 | `$lblStatus.Text = if ($PreviewMode) { 'Scanning...' } else { 'Cleaning...' }` | 결과를 바로 대입 |
| `$( )` 서브식 | `("===== {0} =====" -f $(if ($PreviewMode) {'PREVIEW'} else {'CLEANUP'}))` | 식 결과를 문자열/인자 안에서 사용 |
| `[int]::TryParse` + `[ref]` | `[int]::TryParse($txtDays.Text.Trim(), [ref]$days)` | 예외 없이 숫자 변환 시도 |
| `-match` | `if ($_ -match '\s') { "`"$_`"" }` | 공백 있는 인자만 따옴표로 감싸기 |
| `-f` 형식 연산자 | `'.\{0} {1}' -f $name, $args` | 문자열 조립 |
| `-join` | `$shown -join ' '` | 배열을 문자열로 |
| `+=` 배열 추가 | `$a += '-Preview'` | 인자 목록 구성 |
| 백틱 이스케이프 | `"`r`n"`, `` "`"$path`"" `` | 개행, 문자열 안의 따옴표 |
| `switch` 파라미터 | `param([switch]$PreviewMode)` / `-PreviewMode:$PreviewMode` | 스위치 값을 그대로 전달 |
| 중첩 `Join-Path` | `Join-Path (Join-Path $env:APPDATA 'clear-cache-gui') 'settings.json'` | 3단 이상 경로 결합 |

---

## 9. 이 GUI 에서 쓰인 cmdlet 목록

| cmdlet | 용도 |
|---|---|
| `Add-Type` | WPF / WinForms 어셈블리 로드 |
| `New-Object` | XmlNodeReader, DispatcherTimer, StreamReader, SaveFileDialog 생성 |
| `Set-Variable` / `Get-Variable` | 이름으로 컨트롤 변수 만들기/읽기 |
| `Start-Process` | v5 실행(`-PassThru`, 리다이렉트), 권한 상승(`-Verb RunAs`), 메모장 열기 |
| `Get-Process` | 현재 호스트 exe 경로 확인(`(Get-Process -Id $PID).Path`) |
| `Start-Sleep` | 종료 직후 남은 출력 flush 대기 |
| `Test-Path` | 스크립트/로그/설정 파일 존재 확인 |
| `Join-Path` / `Split-Path` | 경로 결합, 부모 폴더 및 파일명 추출 |
| `New-Item` | 설정 폴더 생성(`-ItemType Directory -Force`) |
| `Get-Content` / `Set-Content` | 설정 JSON 읽기/쓰기(`-Raw`, `-Encoding UTF8`) |
| `ConvertTo-Json` / `ConvertFrom-Json` | 설정 직렬화 |
| `Remove-Item` | 임시 파일 정리 |
| `Where-Object` / `Select-Object` / `ForEach-Object` | 설정 경로 후보 선택, 인자 따옴표 처리 |
| `Out-Null` | 반환값 버리기(`ShowDialog`, `MessageBox`, `taskkill`) |

---

## 10. 사용된 .NET 타입

| 타입 / 멤버 | 용도 |
|---|---|
| `[Windows.Markup.XamlReader]::Load()` | XAML -> 창 객체 |
| `System.Xml.XmlNodeReader` | XamlReader 입력 |
| `System.Windows.Threading.DispatcherTimer` | UI 스레드 타이머 |
| `[System.Windows.MessageBox]::Show()` | 확인/경고 대화상자 |
| `System.Windows.Forms.SaveFileDialog` / `[…DialogResult]::OK` | 파일 저장 대화상자 |
| `[System.IO.Path]::GetTempFileName()` | 임시 파일 |
| `[System.IO.File]::Open()` + `FileMode/FileAccess/FileShare` | 공유 읽기로 파일 열기 |
| `System.IO.StreamReader` + `[System.Text.Encoding]::UTF8` | 증분 읽기 |
| `[TimeSpan]::FromMilliseconds()` | 타이머 간격 |
| `[Security.Principal.WindowsIdentity]` / `WindowsPrincipal` / `WindowsBuiltInRole` | 관리자 권한 확인 |
| `[string]::IsNullOrEmpty()` | 빈 문자열 확인 |
| `[int]::TryParse()` | 안전한 숫자 변환 |
| `.HasExited` / `.ExitCode` / `.Id` | 자식 프로세스 상태 |

---

## 11. 함정 / 알아두면 좋은 것

- **XAML 은 단일 인용 here-string(`@'...'@`)으로** 작성합니다. `@"..."@` 를 쓰면 XAML 안의
  `$` 가 PowerShell 변수로 치환될 위험이 있습니다.
- **`x:Class` 는 쓸 수 없습니다.** `XamlReader::Load` 는 코드비하인드가 없으므로 `x:Name` 만
  사용하고, 이벤트는 코드에서 `Add_Click` 등으로 붙입니다.
- **`IsChecked` 는 `Nullable[bool]`** 이라 `-eq $true` 또는 `[bool]` 캐스팅이 필요합니다.
- **`ShowDialog()` 는 값을 반환**하므로 `| Out-Null` 로 버려야 콘솔/파이프가 지저분해지지 않습니다.
- **GUI 에서는 `Read-Host` / `Write-Host` 를 쓸 수 없습니다.** 콘솔이 숨겨져 있어 입력이 불가하고
  출력도 보이지 않습니다. 그래서 이 GUI 는 v5 에 항상 `-Force` 를 넘기고 확인은 MessageBox 로,
  출력은 TextBox 로 처리합니다.
- **오래 걸리는 작업은 반드시 UI 스레드와 분리**해야 창이 멈추지 않습니다. 여기서는 별도
  프로세스 + `DispatcherTimer` 폴링으로 해결했습니다(Runspace 를 쓰는 방법도 있음).
- **이벤트 핸들러 안에서 공유 상태는 `$script:`** 로 접근합니다.
- **`Add-Type` 을 같은 세션에서 두 번 실행하면** 동일 타입 정의 시 오류가 날 수 있습니다
  (`-AssemblyName` 방식은 안전).
- **`$PID` 등 예약 변수 이름은 재사용할 수 없습니다**(읽기 전용). 새 변수는 다른 이름으로.
- **`-WindowStyle Hidden` 이 콘솔을 못 숨기는 경우가 있습니다.** 기본 콘솔 호스트가
  Windows Terminal 이면 터미널이 별도 프로세스라 창 스타일 요청을 무시합니다. 그래서 바로가기는
  `clear-cache-gui.vbs`(wscript) 를 사용합니다. 자세한 내용은 GUI README 1장 참고.

---

## 부록: `clear-cache-gui.vbs` (런처) 문법

```vbscript
Option Explicit
Dim sh, fso, here, target, cmd
Set sh  = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
here   = fso.GetParentFolderName(WScript.ScriptFullName)
target = here & "\clear-cache-gui.ps1"
If Not fso.FileExists(target) Then
    MsgBox "GUI script not found:" & vbCrLf & target, 16, "Cache Cleaner"
    WScript.Quit 1
End If
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File """ & target & """"
sh.Run cmd, 0, False
```

| 요소 | 설명 |
|---|---|
| `Option Explicit` / `Dim` / `Set` | 변수 선언 강제, 변수 선언, 객체 대입 |
| `CreateObject("WScript.Shell")` | 프로그램 실행용 COM 객체 |
| `CreateObject("Scripting.FileSystemObject")` | 파일/경로 조작 |
| `WScript.ScriptFullName` | 이 vbs 의 전체 경로(폴더 기준 경로 계산에 사용) |
| `sh.Run cmd, 0, False` | 실행. **0 = 창 숨김**, `False` = 종료를 기다리지 않음 |
| `MsgBox text, 16, title` | 대화상자. `16` = 오류 아이콘 |
| `&` / `""` | 문자열 연결 / 문자열 안의 따옴표(2개로 이스케이프) |
| `vbCrLf` | 개행 |

`wscript.exe` 는 콘솔이 없는 GUI 호스트라서 이 방식이면 콘솔 창이 아예 생기지 않습니다
(`cscript.exe` 로 실행하면 콘솔이 생기므로 반드시 `wscript`).

---

## 참고
- cmdlet 상세: `Get-Help <cmdlet> -Full`
- 개념 도움말: `Get-Help about_Automatic_Variables`, `about_Script_Blocks`, `about_Scopes`,
  `about_Try_Catch_Finally`, `about_Splatting`
- 이 GUI 사용법: `clear-cache-gui-README.md`
- 정리 엔진 문법: `clear-browser-and-windows-cache-v5-cmdlet-syntax.md`
