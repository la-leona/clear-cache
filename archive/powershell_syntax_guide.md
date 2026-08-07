# PowerShell 내장 함수와 문법 설명 (v4 캐시 정리 스크립트 기준)

> 본 문서는 `clear-browser-and-windows-cache-v4.ps1` 스크립트에서 사용된 PowerShell 내장 함수와 문법을 정리한 것입니다.

---

## 1. 스크립트 선언 & 매개변수

### `[CmdletBinding()]`
스크립트를 **고급 함수/고급 스크립트**로 만듭니다. `-Verbose`, `-Debug`, `-ErrorAction` 같은 공통 매개변수를 자동으로 지원하게 됩니다.

### `param(...)` + `[Parameter()]`
스크립트가 받을 **입력 매개변수**를 선언합니다.

```powershell
param(
    [int]$OlderThanDays = 0,          # 정수, 기본값 0
    [switch]$Preview,                  # 스위치 (있으면 $true, 없으면 $false)
    [string]$LogPath,                  # 문자열
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$UnknownArgs             # 문자열 배열, 남는 인수 전부 받기
)
```

- `[switch]`: `-Preview`처럼 값 없이 켜고 끄는 플래그
- `[string[]]`: 문자열 **배열** (여러 개 받을 수 있음)
- `ValueFromRemainingArguments`: 정식 매개변수에 안 걸린 남는 인수(예: 오타)를 받아옴

### `$PSBoundParameters`
현재 **실제로 전달된 매개변수**들의 해시테이블입니다. 어떤 스위치가 켜졌는지 확인할 때 씁니다.

```powershell
$ScriptParameters = $PSBoundParameters
$ScriptParameters.ContainsKey('Preview')  # -Preview가 전달됐는가?
```

---

## 2. 타입 캐스팅 & 객체 생성

### `[pscustomobject]@{}`
**임시 객체(해시테이블 → 커스텀 객체)**를 만듭니다. 함수에서 여러 값을 한꺼번에 반환할 때 유용합니다.

```powershell
return [pscustomobject]@{
    Count = $files.Count
    Bytes = [long]$bytes
}
```

### `[System.Collections.Generic.List[object]]::new()`
.NET의 **제네릭 리스트**를 생성합니다. `@()` 배염보다 추가/삭제가 빠릅니다.

```powershell
$targets = [System.Collections.Generic.List[object]]::new()
$targets.Add($item)   # 동적으로 추가
```

### `[long]`, `[int]`, `[bool]`, `[Math]::Max()`
명시적 **형변환(캐스팅)**입니다.

```powershell
[long]$bytes          # 64비트 정수로 변환
[bool]$procs          # $null/빈값이면 $false, 있으면 $true
[Math]::Max(0, $a - $b)  # 둘 중 큰 값 (음수 방지용)
```

---

## 3. 파일/폴다 다루기

### `Test-Path`
파일이나 폴다가 **존재하는지 확인**합니다.

```powershell
Test-Path -LiteralPath $Path -PathType Container   # 폴다인지?
Test-Path -LiteralPath $Path -PathType Leaf        # 파일인지?
```

- `-LiteralPath`: 와일드카드(`*`, `?`)를 해석하지 않고 **정확한 경로** 그대로 봄

### `Get-ChildItem`
폴다 안의 **파일/하위폴다 목록**을 가져옵니다.

```powershell
Get-ChildItem -LiteralPath $Path -Include '*.log' -Recurse -Force -File
```

- `-Include`: 패턴으로 필터링 (와일드카드 지원)
- `-Recurse`: 하위 폴다까지 재귀 탐색
- `-Force`: 숨김/시스템 파일도 포함
- `-File`: 파일만, 폴다는 제외

### `Remove-Item`
파일이나 폴다를 **삭제**합니다.

```powershell
Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop
```

### `Join-Path` / `Split-Path`
경로를 **조합**하거나 **분리**합니다.

```powershell
Join-Path $env:LOCALAPPDATA 'Mozilla\Firefox\Profiles'   # C:\Users\...\Mozilla\Firefox\Profiles
Split-Path -Path $LogPath -Parent                         # 상위 폴다 경로만
```

### `[System.IO.Path]::GetFullPath()`
상대 경로를 **절대 경로**로 변환합니다.

```powershell
[System.IO.Path]::GetFullPath('.\temp')   # C:\Users\...\temp
```

### `[System.IO.Path]::GetPathRoot()`
경로의 **루트(예: C:\)**를 추출합니다.

---

## 4. 프로세스 & 서비스 제어

### `Get-Process`
실행 중인 **프로세스**를 가져옵니다.

```powershell
Get-Process -Name 'chrome' -ErrorAction SilentlyContinue
# 없으면 $null 반환 (에러로 끝나지 않음)
```

### `Stop-Process`
프로세스를 **강제 종료**합니다.

```powershell
$p.CloseMainWindow()          # 창 닫기 요청 (우아한 종료)
Stop-Process -Force           # 강제 종료
```

### `Start-Process`
새 프로세스를 **실행**합니다.

```powershell
Start-Process cleanmgr -ArgumentList '/sagerun:100' -Wait -NoNewWindow
# -Wait: 끝날 때까지 기다림
# -NoNewWindow: 새 창 안 띄움
```

### `Get-Service` / `Stop-Service` / `Start-Service`
Windows **서비스**를 제어합니다.

```powershell
$service = Get-Service -Name 'bits' -ErrorAction Stop
Stop-Service -Name 'bits' -Force   # 의존성 무시하고 중지
Start-Service -Name 'bits'         # 다시 시작
```

---

## 5. 보안 & 권한

### `[Security.Principal.WindowsIdentity]::GetCurrent()`
현재 실행 중인 **Windows 사용자 ID**를 가져옵니다.

### `[Security.Principal.WindowsPrincipal]`
해당 ID의 **권한(역할)**을 확인합니다.

```powershell
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
# 관리자 그룹에 속해 있으면 $true
```

---

## 6. 날짜 & 수학

### `Get-Date` + `.AddDays()`
현재 날짜/시간을 가져오고, **일수를 빼서** 과거 시점을 만듭니다.

```powershell
$cutoff = (Get-Date).AddDays(-30)   # 30일 전 시점
```

### `Measure-Object`
파일 목록의 **합계, 개수, 평균** 등을 계산합니다.

```powershell
($files | Measure-Object -Property Length -Sum).Sum   # 전체 파일 크기 합계
```

---

## 7. 파이프라인 & 필터링

### `Where-Object` (`?`)
조건에 맞는 항목만 **필터링**합니다.

```powershell
| Where-Object { $_.LastWriteTime -lt $cutoff }   # 기한보다 오래된 파일만
| Where-Object { $_.Status -ne 'Stopped' }        # 중지되지 않은 서비스만
```

### `ForEach-Object` (`%`)
파이프라인의 **각 항목을 순회**하며 처리합니다.

```powershell
| ForEach-Object {
    $len = $_.Length
    Remove-Item $_.FullName
}
```

### `Sort-Object`
정렬합니다.

```powershell
| Sort-Object Distance, Name          # Distance 우선, 같으면 Name 순
| Sort-Object { $_.FullName.Length } -Descending   # 문자열 길이 내림차순
```

### `Select-Object -First N`
상위 N개만 **선택**합니다.

```powershell
| Select-Object -First 3
```

---

## 8. 조걸문 & 비교 연산자

### `-match` / `-notmatch`
**정규식**으로 문자열을 비교합니다.

```powershell
$answer -notmatch '^(y|yes)$'   # y 또는 yes가 아니면 $true
$_.Name -match '^Profile \d+$'  # "Profile 숫자" 패턴
```

### `-in` / `-notin`
값이 **배열/컬렉션 안에 있는지** 확인합니다.

```powershell
if ($kv.Key -in @('Elevate', 'UnknownArgs')) { continue }
```

### `-is`
**타입(형)이 맞는지** 확인합니다.

```powershell
if ($ex -is [System.UnauthorizedAccessException]) { ... }
```

### `$( ... )` (Subexpression)
문자열 안이나 파이프라인 안에서 **표현식을 실행**하고 결과를 삽입합니다.

```powershell
"Unknown parameter : $token"          # 변수 삽입
"Deleted : $($deletedTotal + 5)"      # 계산식 삽입
$(if ($Preview) { 'Preview mode' } else { 'Live mode' })  # 인라인 if
```

---

## 9. 에러 처리

### `$ErrorActionPreference = 'Stop'`
스크립트 전체에서 **발생하는 에러를 즉시 중단**시킵니다. (기본은 `Continue`)

### `-ErrorAction SilentlyContinue`
해당 명령 한 줄에서만 **에러를 무시**하고 넘어갑니다.

```powershell
Get-Process -Name 'chrome' -ErrorAction SilentlyContinue
# chrome이 없어도 에러 메시지 안 띄우고 $null 반환
```

### `-ErrorAction Stop`
해당 명령 한 줄에서만 **에러 발생 시 즉시 중단** (try/catch로 잡을 수 있음)

### `try / catch`
에러가 발생할 수 있는 구역을 감싸서 **예외 처리**합니다.

```powershell
try {
    Remove-Item ... -ErrorAction Stop
}
catch {
    Write-Warning "Failed: $($_.Exception.Message)"
}
```

---

## 10. 출력 & 사용자 입력

### `Write-Host`
화면에 **색상 있는 텍스트**를 출력합니다. (파이프라인으로 값을 넘기지 않음)

```powershell
Write-Host 'Done' -ForegroundColor Green
Write-Host 'Warning' -ForegroundColor Yellow
```

### `Write-Warning`
**경고 메시지**를 노란색으로 출력합니다.

### `Read-Host`
사용자에게 **키보드 입력**을 받습니다.

```powershell
$answer = Read-Host 'Proceed? (Y/N)'
```

---

## 11. 로깅 & 기타

### `Start-Transcript` / `Stop-Transcript`
화면에 출력되는 **모든 내용을 파일에 기록**합니다.

```powershell
Start-Transcript -Path $LogPath -Append   # 기존 파일 뒤에 이어쓰기
Stop-Transcript
```

### `Get-PSDrive`
드라이브 정보를 가져옵니다. `Free` 속성으로 **남은 용량**을 확인합니다.

```powershell
$drive = Get-PSDrive -Name 'C'
$drive.Free   # 남은 바이트 수
```

### `Clear-RecycleBin`
휴지통을 **비웁니다**.

```powershell
Clear-RecycleBin -Confirm:$false   # 확인 없이 즉시 비우기
```

### `Start-Sleep`
지정된 **초/밀리초만큼 대기**합니다.

```powershell
Start-Sleep -Seconds 10
```

### `exit`
스크립트를 **종료**하고 종료 코드를 반환합니다.

```powershell
exit 0   # 성공
exit 1   # 사용자 취소
exit 2   # 잘못된 인수
```

---

## 12. 문자열/객체 메서드

### `.ToLowerInvariant()` / `.StartsWith()` / `.TrimStart()`
문자열 메서드입니다.

```powershell
$token.TrimStart('-', '/')      # 앞의 -나 /를 제거
$name.ToLowerInvariant()         # 대소문자 구분 없는 비교용 소문자 변환
$name.StartsWith('Profile')     # 'Profile'로 시작하는가?
```

### `.GetEnumerator()`
해시테이블(`@{}`)을 **키-값 쌍으로 순회**할 때 사용합니다.

```powershell
foreach ($kv in $ScriptParameters.GetEnumerator()) {
    # $kv.Key, $kv.Value
}
```

---

## 요약표

| 문법/함수 | 용도 |
|---|---|
| `[CmdletBinding()]` | 고급 스크립트 기능 활성화 |
| `[switch]` | On/Off 플래그 매개변수 |
| `[pscustomobject]@{}` | 여러 값을 묶어 반환 |
| `::new()` | .NET 객체 생성 |
| `Test-Path -LiteralPath` | 경로 존재 여부 (와일드카드 무시) |
| `Get-ChildItem -Include -Recurse -Force -File` | 파일 검색 |
| `Measure-Object -Property -Sum` | 합계/개수 계산 |
| `Where-Object`, `ForEach-Object`, `Sort-Object` | 파이프라인 필터/반복/정렬 |
| `Get-Process` / `Stop-Process` / `Start-Process` | 프로세스 제어 |
| `Get-Service` / `Stop-Service` / `Start-Service` | 서비스 제어 |
| `[Security.Principal.WindowsPrincipal]` | 관리자 권한 확인 |
| `try / catch` | 예외 처리 |
| `-ErrorAction SilentlyContinue/Stop` | 에러 제어 |
| `Start-Transcript` / `Stop-Transcript` | 실행 내역 파일 기록 |
| `$()` | 문자열/파이프라인 내 표현식 실행 |
| `-match`, `-in`, `-is` | 정규식, 포함, 타입 비교 |
