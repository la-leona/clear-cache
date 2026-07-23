# Changelog - clear-browser-and-windows-cache.ps1

이 문서는 `clear-browser-and-windows-cache.ps1` 의 변경 이력을 기록합니다.

## 2026-07-23

### 버그 수정 (Bug fixes)

- **`-OlderThanDays` 사용 시 최신 파일이 삭제되던 문제 수정**
  - 이전: `Remove-TargetContents` / `Invoke-DeliveryOptimizationCacheCleanup` 가 파일과
    디렉터리를 함께 열거한 뒤, 나이 필터를 통과한 폴더를 `Remove-Item -Recurse` 로 지웠음.
    이 때문에 오래된 폴더 안에 있던 지정 기간 이내(최신) 파일까지 함께 삭제됨.
  - 수정: 나이 필터는 **파일 단위로만** 적용하도록 변경(`-File`). 파일 삭제 후,
    **비게 된 디렉터리만** 깊은 경로부터 정리(와일드카드 `*` 타깃에 한함).
    지정 기간 이내 파일과 그 상위 폴더는 보존됨.

- **Delivery Optimization 캐시가 잘 안 지워지던 문제 수정**
  - 원인: 하드코딩된 경로
    (`...\ServiceProfiles\NetworkService\AppData\Local\Microsoft\DeliveryOptimization\Cache`)
    가 Windows 버전/정책에 따라 실제 캐시 위치와 다를 수 있고, 그 폴더는
    NetworkService/SYSTEM 소유라 관리자 권한이어도 `Remove-Item` 이 접근 거부로 실패해
    대부분 skip 처리되었음.
  - 수정: OS 공식 cmdlet **`Delete-DeliveryOptimizationCache -Force`** 를 우선 사용하도록 변경.
    실제 캐시 위치/ACL/서비스 잠금을 OS가 알아서 처리함. cmdlet 이 없는 환경에서만
    기존 파일 삭제 방식으로 폴백.
    - 삭제 규모는 `Get-DeliveryOptimizationPerfSnap` 의 `Files` / `CacheSizeBytes` 를
      삭제 전후로 비교해 리포트.
    - 참고: cmdlet 은 나이 필터(`-OlderThan`)를 지원하지 않으므로, `-OlderThanDays` 와 함께
      쓰면 DO 캐시는 전체가 지워짐(이 경우 경고 메시지 출력).

### 정리 (Cleanup)

- **죽은 변수 `$showUsage` 제거** — 계산만 하고 사용되지 않던 변수. `Show-Usage` 는
  파라미터 유무와 무관하게 항상 호출되므로 불필요.
- **`Write-ParameterLine` 정리** — 함수 자신의 `$PSBoundParameters`(항상 미스) 대신,
  스크립트 시작부에서 담아 둔 `$ScriptParameters` 를 실제로 사용하도록 변경.
  활성 파라미터 노란색 하이라이트가 명확한 방식으로 동작.
- **Explorer 캐시 재생성 시 광범위 `*.db` 패턴 제거** — `Invoke-ExplorerCacheRebuild` 의
  삭제 패턴을 `thumbcache_*.db`, `iconcache_*.db` 로 한정. 해당 폴더의 무관한 `.db` 파일까지
  지우던 위험 제거.

### 검증 (Verification)

- 구문 파싱: `Parser::ParseFile` -> PARSE OK
- `-Preview -OlderThanDays 30` 실행: 파라미터 하이라이트/요약/필터 표기 정상, 삭제 없이 종료
- DO cmdlet 경로: `Get-DeliveryOptimizationPerfSnap` 스냅샷 추출 및 cmdlet 존재 확인(읽기 전용)
