# clear-browser-and-windows-cache-v4.ps1 — 사용된 내장 함수 / 문법 설명

이 문서는 `clear-browser-and-windows-cache-v4.ps1` 에서 실제로 쓰인 PowerShell
**cmdlet(내장 명령)**, **.NET 타입/멤버**, **문법 요소**를 정리한 참고 자료입니다.
각 항목에 스크립트에서 발췌한 예시를 함께 실었습니다.

---

## 1. 출력 / 입력 cmdlet

| cmdlet | 설명 | 스크립트 예시 |
|---|---|---|
| `Write-Host` | 콘솔에 텍스트 출력(색상 지정 가능). 파이프로 넘어가지 않는 "사람용" 출력 | `Write-Host 'WARNING' -ForegroundColor Yellow` |
| `Write-Warning` | 경고 스트림으로 출력(노란 `WARNING:` 접두어) | `Write-Warning "Could not stop service $serviceName"` |
| `Read-Host` | 사용자 입력을 한 줄 받음 | `$answer = Read-Host 'Proceed with cleanup? (Y/N)'` |
| `Out-Null` | 파이프 출력 버림(반환값 삼키기) | `Start-Transcript ... | Out-Null` |

- `-ForegroundColor` 로 글자색 지정: `Cyan/Yellow/Red/Green/DarkGray/Magenta` 등.
- "출력을 버린다"는 `| Out-Null` 또는 `$null = ...` 두 방식 모두 스크립트에서 사용됨.

---

## 2. 파일 / 경로 cmdlet

| cmdlet | 설명 | 스크립트 예시 |
|---|---|---|
| `Get-ChildItem` | 파일/폴더 나열(=`ls`/`dir`) | `Get-ChildItem -LiteralPath $Path -Include $Include -Recurse -Force -File` |
| `Remove-Item` | 파일/폴더 삭제 | `Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop` |
| `Test-Path` | 경로 존재 여부(파일/폴더) | `Test-Path -LiteralPath $fullPath -PathType Container` |
| `Join-Path` | 경로 결합(구분자 자동) | `Join-Path $env:LOCALAPPDATA 'Mozilla\Firefox\Profiles'` |
| `Split-Path` | 경로에서 부모/파일명 분리 | `Split-Path -Path $LogPath -Parent` |
| `New-Item` | 파일/폴더 생성 | `New-Item -ItemType Directory -Path $logDir -Force` |
| `Clear-RecycleBin` | 휴지통 비우기 | `Clear-RecycleBin -Confirm:$false -ErrorAction Stop` |

**`Get-ChildItem` 주요 스위치**
- `-LiteralPath` : 경로를 와일드카드 해석 없이 문자 그대로 사용(대괄호 등 특수문자 안전).
- `-Include @('*.log','*.etl')` : 이름 패턴 필터(`-Recurse` 와 함께 써야 동작).
- `-Recurse` : 하위 폴더까지. `-File` : 파일만. `-Directory` : 폴더만. `-Force` : 숨김/시스템 항목 포함.

---

## 3. 파이프라인 처리 cmdlet

| cmdlet | 설명 | 스크립트 예시 |
|---|---|---|
| `Where-Object` | 조건 필터 | `Where-Object { $_.Count -gt 0 }` |
| `ForEach-Object` | 각 항목 반복 처리 | `ForEach-Object { Remove-Item ... }` |
| `Sort-Object` | 정렬(스크립트블록 키/`-Unique`/`-Descending`) | `Sort-Object { $_.FullName.Length } -Descending` |
| `Select-Object` | 선택/상위 N개 | `Select-Object -First 3` |
| `Measure-Object` | 합계/개수 등 집계 | `($files | Measure-Object -Property Length -Sum).Sum` |

- `$_` (또는 `$PSItem`) : 파이프라인에서 "현재 항목".
- `Sort-Object { ... }` 처럼 **스크립트블록을 정렬 키**로 줄 수 있음.
- `Sort-Object Category, Name, Path -Unique` : 여러 속성 기준 정렬 + 중복 제거.

---

## 4. 프로세스 cmdlet

| cmdlet | 설명 | 스크립트 예시 |
|---|---|---|
| `Get-Process` | 프로세스 조회 | `Get-Process -Name $procName -ErrorAction SilentlyContinue` |
| `Stop-Process` | 프로세스 종료 | `$procs | Stop-Process -Force` |
| `Start-Process` | 새 프로세스 실행(권한 상승/대기 등) | `Start-Process -FilePath $hostExe -Verb RunAs -ArgumentList $argString` |
| `Start-Sleep` | 지정 초만큼 대기 | `Start-Sleep -Seconds 1` |

- `Start-Process -Verb RunAs` : UAC 관리자 권한으로 재실행(자기 상승).
- `Start-Process cleanmgr -ArgumentList '/sagerun:100' -Wait -NoNewWindow` : 완료까지 대기, 새 창 없이.

---

## 5. 서비스 cmdlet

| cmdlet | 설명 | 스크립트 예시 |
|---|---|---|
| `Get-Service` | 서비스 상태 조회 | `Get-Service -Name $serviceName -ErrorAction Stop` |
| `Stop-Service` | 서비스 중지 | `Stop-Service -Name $serviceName -Force` |
| `Start-Service` | 서비스 시작 | `Start-Service -Name $serviceName` |

DO 캐시 정리 시 `DoSvc/BITS/UsoSvc/WaaSMedicSvc`, Windows Update 시 `bits/wuauserv` 를 중지 후 복원.

---

## 6. 시스템 / 기타 cmdlet

| cmdlet | 설명 | 스크립트 예시 |
|---|---|---|
| `Get-PSDrive` | 드라이브 정보(여유 공간 등) | `(Get-PSDrive -Name $driveName).Free` |
| `Get-Command` | 명령/함수 존재 확인 | `Get-Command Delete-DeliveryOptimizationCache -ErrorAction SilentlyContinue` |
| `Get-Date` | 현재 시각/날짜 계산 | `(Get-Date).AddDays(-$OlderThanDays)` |
| `Start-Transcript` / `Stop-Transcript` | 콘솔 출력 전체를 파일로 기록/종료 | `Start-Transcript -Path $LogPath -Append` |
| `New-Object` | .NET 객체 생성 | `New-Object 'int[,]' ($n+1),($m+1)` |

**DeliveryOptimization 모듈 cmdlet** (Windows 기본 제공)
- `Delete-DeliveryOptimizationCache -Force` : DO 캐시를 OS 지원 방식으로 삭제.
- `Get-DeliveryOptimizationPerfSnap` : DO 캐시 크기/파일 수 스냅샷(`.CacheSizeBytes`, `.Files`).

**외부 실행 파일 호출**
- `& dism.exe /Online /Cleanup-Image /StartComponentCleanup` — `&`(호출 연산자)로 exe 실행.
- 실행 후 종료코드는 자동변수 `$LASTEXITCODE` 로 확인.

---

## 7. .NET 타입 / 멤버 직접 사용

PowerShell은 .NET 위에 있어 타입을 직접 부를 수 있습니다(`[네임스페이스.타입]::정적멤버`).

| 사용 | 설명 | 스크립트 예시 |
|---|---|---|
| `[Security.Principal.WindowsIdentity]` / `WindowsPrincipal` / `WindowsBuiltInRole` | 현재 사용자 관리자 여부 판정 | `$principal.IsInRole([...WindowsBuiltInRole]::Administrator)` |
| `[System.IO.Path]::GetFullPath / GetPathRoot` | 경로 정규화/루트 추출 | `[System.IO.Path]::GetFullPath($Path)` |
| `[System.Collections.Generic.List[object]]` | 가변 길이 리스트(`.Add()`) | `[System.Collections.Generic.List[object]]::new()` |
| `[Math]::Min / Max` | 수치 min/max | `[Math]::Max(0L, $freeAfter - $freeBefore)` |
| `[pscustomobject]@{ ... }` | 즉석 구조체(속성 묶음) 생성 | `[pscustomobject]@{ Count=...; Bytes=... }` |
| `[System.UnauthorizedAccessException]` / `[System.IO.IOException]` | 예외 타입 판별 | `if ($ex -is [System.IO.IOException])` |
| `.CloseMainWindow()` | 프로세스에 정상 종료 요청(창 닫기) | `$p.CloseMainWindow()` |

**문자열 메서드** (모두 .NET string 멤버)
- `.TrimEnd(':')`, `.TrimStart('-','/')`, `.ToLowerInvariant()`, `.StartsWith(...)`, `.Length`

**형 변환/캐스팅**
- `[long]$bytes`, `[int](...)`, `[bool](...)` : 타입 강제 변환.
- `New-Object 'int[,]' ...` : 2차원 배열 생성(Levenshtein 표).

---

## 8. 자동 변수 (Automatic Variables)

| 변수 | 의미 |
|---|---|
| `$_` / `$PSItem` | 파이프라인 현재 항목 |
| `$PSBoundParameters` | 실제로 전달된 파라미터 이름/값 해시 (`.ContainsKey()`, `.GetEnumerator()`) |
| `$PSCommandPath` | 실행 중인 스크립트 파일의 전체 경로 |
| `$PID` | 현재 프로세스 ID (`(Get-Process -Id $PID).Path` 로 호스트 exe 경로) |
| `$LASTEXITCODE` | 마지막 외부 exe의 종료코드 |
| `$null` | 널. `$null = ...` 로 출력 버리기, `-not $cutoff` 로 널 체크 |
| `$args`(미사용)·`$ErrorActionPreference` | 오류 처리 기본 동작(`'Stop'` 로 설정) |

**변수 스코프 / provider 접두어**
- `$script:targets`, `$script:TranscriptActive` : **스크립트 스코프** 변수(함수 안에서 공유).
- `$env:WINDIR`, `$env:LOCALAPPDATA`, `$env:TEMP`, `$env:SystemDrive` : **환경변수** provider.

---

## 9. 연산자

| 분류 | 연산자 | 예시 |
|---|---|---|
| 비교 | `-eq -ne -lt -gt -le -ge` | `$_.Count -gt 0` |
| 논리 | `-and -or -not` | `-not $Quiet` |
| 타입 | `-is` | `$val -is [switch]` |
| 포함 | `-in` | `$kv.Key -in @('Elevate','UnknownArgs')` |
| 정규식 | `-match -notmatch` | `$answer -notmatch '^(y|yes)$'` |
| 형식 문자열 | `-f` | `'{0,-10} {1,8} files' -f $cat, $count` |

**`-f` (형식 연산자) 서식**
- `{0}` : 0번째 인자. `{0,-10}` : 왼쪽 정렬 폭 10. `{1,8}` : 오른쪽 정렬 폭 8.
- `{0:N2}` : 소수점 2자리 숫자 서식. 예) `'{0:N2} GB' -f ($Bytes/1GB)`.

**숫자 리터럴**
- `1GB / 1MB / 1KB` : 크기 배수 상수. `0L` : long 타입 0.

---

## 10. 핵심 문법 구조

**주석 기반 도움말 (Comment-Based Help)**
```powershell
<#
.SYNOPSIS  ...
.PARAMETER OlderThanDays  ...
.EXAMPLE  ...
#>
```
`Get-Help` 가 읽는 표준 도움말 블록.

**param 블록 + 고급 함수 속성**
```powershell
[CmdletBinding()]
param(
    [int]$OlderThanDays = 0,          # 기본값 지정
    [switch]$Preview,                 # 스위치(있으면 $true)
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$UnknownArgs            # 미인식 인자 모두 수집(오타 감지용)
)
```
- `[CmdletBinding()]` : 공통 파라미터(`-ErrorAction`, `-Verbose` 등) 활성화.
- `[Parameter(Mandatory=$true)]` : 필수 파라미터(함수들에서 사용).
- `[switch]` 는 `.IsPresent` 로 존재 여부 확인 가능.

**if 를 "식(expression)"으로 사용** — 결과를 변수에 바로 대입
```powershell
$cutoff = if ($OlderThanDays -gt 0) { (Get-Date).AddDays(-$OlderThanDays) } else { $null }
$marker = if ($active) { '*' } else { ' ' }
```

**try / catch 예외 처리 + 오류 동작 제어**
```powershell
try   { Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop; $deleted++ }
catch { $skipped++ }
```
- `$ErrorActionPreference = 'Stop'` : 스크립트 전역 기본 오류 동작.
- `-ErrorAction Stop` : 이 호출을 종료성 오류로 만들어 `catch` 로 잡음.
- `-ErrorAction SilentlyContinue` : 오류 무시하고 진행.

**컬렉션 리터럴**
```powershell
@('*.log', '*.etl')          # 배열
@{ Name = '...'; Type='...' } # 해시테이블
[ordered]@{ Chrome='chrome'; Edge='msedge' }  # 순서 보장 해시테이블
```

**서브식(subexpression) / 문자열 보간**
```powershell
"Cleaning: [$($target.Category)] $($target.Name)"   # $(...) 안에서 속성 접근
"$serviceName`: $($_.Exception.Message)"            # 백틱(`)으로 ':' 이스케이프
```

**반복/제어 흐름**
- `foreach ($x in $coll) { }`, `for ($i=0; ...)`, `while ($cond) { }`
- `break`, `continue`, `return`(함수 반환), `exit N`(스크립트 종료코드)

**파이프라인 + 백틱 줄바꿈 없이 파이프로 연결**
```powershell
Get-ChildItem ... |
    Where-Object { ... } |
    ForEach-Object { ... }
```

---

## 11. 이 스크립트가 쓰는 "관용 패턴" 요약

- **안전 삭제**: `Get-ChildItem -File` 로 파일만 골라 `Remove-Item -Force -ErrorAction Stop` +
  `try/catch` 로 잠긴 파일은 건너뛰고 카운트.
- **집계 객체 반환**: 각 함수가 `[pscustomobject]@{ Deleted=..; Skipped=..; Freed=.. }` 를 돌려주고
  메인에서 누적.
- **중앙 종료점**: `Complete-Run` 함수가 `Stop-Transcript` 후 `exit <코드>` (0/1/2)로 마무리.
- **자기 권한 상승**: `$PSBoundParameters` 를 문자열 인자로 재구성 → `Start-Process -Verb RunAs` 로
  자신을 관리자 재실행.
- **오타 추천**: 미바인딩 인자를 `ValueFromRemainingArguments` 로 받아 Levenshtein 거리로 유사
  파라미터 제안.

---

## 참고
- cmdlet 상세는 PowerShell에서 `Get-Help <cmdlet> -Full` 또는 `Get-Help <cmdlet> -Online`.
- 이 스크립트 자체 도움말: `Get-Help .\clear-browser-and-windows-cache-v4.ps1 -Full`.
- 문법 개념: `about_*` 도움말 (예: `Get-Help about_Automatic_Variables`,
  `about_Comparison_Operators`, `about_Try_Catch_Finally`, `about_Splatting`).
