# Workflow — 동일 결과를 재현하는 실행 절차

> 이 문서는 새 작업자가 이전 대화나 로컬 셸 기록을 보지 못해도 같은 코드 결과와 같은 검증 수준에
> 도달하도록 작성했다. 명령은 Windows PowerShell 기준이다.

## 1. 완료 흐름

```text
규칙 확인
  → 최신 develop 기반 격리 worktree
  → 변경 전 기준선/캡처
  → RED 테스트
  → shell·community·dp_design 구현
  → 대상 테스트
  → 전체 Flutter 검증
  → PR develop
  → release PR main
  → CI/ET13/서명 산출물
  → sealed GitOps 후보
  → exact-digest 운영 승격·canary
  → landing-last
  → 운영 URL별 화면 검증·캡처
  → History/Handoff 갱신
  → 문서 커밋·푸시
  → context-save
```

## 2. 시작 전 안전 확인

### 2.1 저장소 규칙

1. `D:\workspace\dpa\AGENTS.md`와 `devpath-frontend\AGENTS.md`를 끝까지 읽는다.
2. 저장소 내부에 더 가까운 `AGENTS.md` 또는 `CLAUDE.md`가 있으면 그것을 우선한다.
3. `main` 또는 `develop`에 직접 구현 커밋을 만들지 않는다.
4. 기존 작업 트리에 사용자 변경이 있으면 stash/reset/checkout으로 치우지 않는다.
5. 비밀값, 토큰, 쿠키, kubeconfig 내용을 터미널 출력이나 문서에 남기지 않는다.

### 2.2 현재 상태 수집

```powershell
Set-Location D:\workspace\dpa\devpath-frontend
git fetch origin --prune
git status --short --branch
git worktree list --porcelain
git log --oneline --decorate -10 origin/develop
```

다음 조건이면 기존 작업 트리를 사용하지 않고 새 worktree를 만든다.

- 추적 또는 미추적 변경이 있다.
- 다른 브랜치의 장기 작업이 진행 중이다.
- 현재 브랜치가 `develop`의 최신 커밋을 포함하지 않는다.

### 2.3 격리 worktree 생성

```powershell
$branch = 'fix/community-information-architecture-v2'
$worktree = 'D:\workspace\dpa\.worktrees\frontend-community-information-architecture-v2'

git worktree add -b $branch $worktree origin/develop
Set-Location $worktree
git status --short --branch
```

문서만 갱신하는 경우에는 `docs/<주제>-<날짜>` 브랜치를 사용한다. 이 문서 세트는
`docs/community-ia-design-handoff-20260917`에서 작성했다.

## 3. 요구사항을 구현 계약으로 변환

작업 시작 전에 다음 표를 이슈나 작업 문서에 그대로 고정한다.

| 항목 | 계약 |
|---|---|
| desktop 계층 | `커뮤니티 → 자유게시판 / Q/A / 피드백` |
| compact 계층 | 하단 `커뮤니티` 1개 + 화면 내부 3개 세그먼트 |
| 기본 board | `FREE` |
| 허용 board | `FREE`, `QNA`, `FEEDBACK` |
| 제거할 사용자 선택 | `ALL` 또는 `전체` |
| FREE 제목 | `자유게시판` |
| QNA 제목 | `Q/A` |
| FEEDBACK 제목 | `피드백` |
| URL | `/community?board=<value>` |
| 상태 단일 원천 | 브라우저 URL의 `board` query |
| 검색 history | 입력 변경은 `replace`, 게시판 전환은 명시적 navigation |
| 상세 복귀 | 일반 글은 `board` query 보존, 질문은 Q/A |

문자열 치환만으로는 완료가 아니다. 최소한 목적지 모델, URL, 선택 index, H1, 설명, 브레드크럼,
상세·작성 복귀 경로, desktop/compact 반응형을 함께 다룬다.

## 4. 변경 전 기준선 수집

### 4.1 코드 기준선

```powershell
rg -n "kShellDestinations|CommunityBoard|board=|전체|QA|자유|Q/A|자유게시판" `
  apps/web/lib apps/web/test packages/dp_design/lib packages/dp_design/test
```

확인할 질문:

1. `kShellDestinations`가 커뮤니티를 몇 개 목적지로 표현하는가?
2. compact가 desktop 목적지 배열을 재사용하는가?
3. `CommunityBoard.all`이 사용자 세그먼트에 노출되는가?
4. `initialBoard`가 null이거나 잘못됐을 때 무엇을 선택하는가?
5. 상세·작성 경로가 board query를 보존하는가?
6. 브레드크럼이 경로의 현재 게시판을 표시하는가?

### 4.2 운영 기준선

인증된 브라우저 세션에서 다음 URL을 각각 연다.

```text
https://app.leva.ai.kr/community
https://app.leva.ai.kr/community?board=FREE
https://app.leva.ai.kr/community?board=QNA
https://app.leva.ai.kr/community?board=FEEDBACK
```

각 URL에서 다음을 기록한다.

- viewport CSS 크기와 DPR
- 사이드바 또는 하단 내비의 항목·선택 상태
- H1과 설명
- 게시판 전환 컨트롤
- 검색과 주행동 CTA
- 브레드크럼
- console error와 실패한 network request
- 캡처 파일 경로와 SHA-256

캡처 이름 형식:

```text
production-before.png
production-after-desktop-free.png
production-after-desktop-qna.png
production-after-desktop-feedback.png
production-after-mobile-qna.png
```

## 5. 테스트 우선 구현

### 5.1 RED — 사용자에게 보일 게시판 목록

수정 대상:

- `apps/web/test/features/community/community_information_architecture_test.dart`

기대값:

```dart
['자유게시판', 'Q/A', '피드백']
```

`전체`가 없어야 하고 순서까지 고정한다. 실패를 확인한 뒤 구현으로 넘어간다.

### 5.2 RED — desktop/compact 계층 분리

수정 또는 추가 대상:

- `apps/web/test/features/community/community_navigation_hierarchy_test.dart`
- `packages/dp_design/test/shell/dp_app_shell_adaptive_destinations_test.dart`

테스트해야 할 값:

- desktop destination 수와 각 label/path/section
- FREE/QNA/FEEDBACK 선택 index
- 1200px에서 rail에 세 게시판이 모두 보임
- 390px에서 하단 내비가 네 핵심 목적지만 가짐
- compact 선택값이 null일 때 desktop index로 오선택하지 않음

### 5.3 RED — URL, 기본값, 위계

수정 대상:

- `apps/web/test/features/community/community_home_page_test.dart`
- `apps/web/test/features/shell/app_shell_breadcrumb_test.dart`
- `apps/web/test/features/shell/app_shell_view_test.dart`

필수 케이스:

- `initialBoard=QNA` 진입
- board query 없는 진입 → FREE
- 잘못된 board → FREE
- 같은 페이지에서 board URL만 변경
- 검색 query 삭제 후 현재 board 목록 복귀
- FREE/FEEDBACK 일반 글 상세의 board 보존
- `/community/new/post`가 `/community/new`보다 먼저 매칭

### 5.4 대상 테스트 실행

```powershell
Push-Location apps\web
flutter test `
  test/features/community/community_information_architecture_test.dart `
  test/features/community/community_navigation_hierarchy_test.dart `
  test/features/community/community_home_page_test.dart `
  test/features/shell/app_shell_breadcrumb_test.dart `
  test/features/shell/app_shell_view_test.dart
Pop-Location

Push-Location packages\dp_design
flutter test test/shell/dp_app_shell_adaptive_destinations_test.dart
Pop-Location
```

구현 전에는 새 기대값 때문에 실패해야 한다. 기존 코드에서도 통과하면 테스트가 잘못된 대상을 보고
있는지 먼저 확인한다.

## 6. 구현 순서

### 6.1 공용 셸에 adaptive 목적지 입력 추가

파일:

- `packages/dp_design/lib/src/shell/dp_app_shell.dart`

작업:

1. 기존 `destinations`, `selectedIndex`, `onSelect`는 desktop/medium/large 계약으로 유지한다.
2. 선택 입력으로 `compactDestinations`, `compactSelectedIndex`, `onCompactSelect`를 추가한다.
3. compact 분기에서 별도 목적지가 있으면 그것만 `DpMobileNavigation`에 전달한다.
4. compact selection이 null이면 desktop selection으로 폴백하지 않는다.
5. non-compact 분기의 `DpNavRail` 동작은 바꾸지 않는다.

검증:

- `DpAppShell`이 라우팅 패키지를 import하지 않는다.
- 공용 package가 Leva의 `/community` 경로를 알지 않는다.
- adaptive 테스트 3개가 통과한다.

### 6.2 앱 셸 목적지와 선택 resolver 변경

파일:

- `apps/web/lib/src/features/shell/presentation/app_shell.dart`

작업:

1. `kShellDestinations`의 커뮤니티 section을 FREE/QNA/FEEDBACK 세 항목으로 만든다.
2. `kCompactShellDestinations` 네 항목을 별도로 만든다.
3. `shellDestinationIndexFor`가 URL path와 board query를 함께 읽게 한다.
4. `compactShellDestinationIndexFor`는 모든 `/community...`를 compact index 3으로 해석한다.
5. `AppShellView`에서 desktop과 compact 목록, index, callback을 각각 배선한다.
6. 명령 팔레트는 desktop 전체 목적지를 계속 제공한다.

주의:

- `Uri.parse(location)`으로 path와 query를 분리한다. 단순 `startsWith`만으로 query를 판별하지 않는다.
- 설정·마이페이지·레거시 content 경로를 index 0으로 폴백하지 않는다.

### 6.3 브레드크럼 변경

같은 파일에서 다음 순서로 경로를 검사한다.

1. `/community/new/post`
2. `/community/new`
3. `/community/post/<id>`
4. 정확한 `/community`
5. 그 밖의 `/community/...` 질문 상세

일반 글의 중간 crumb path는 `/community?board=FREE|FEEDBACK`을 포함한다. 질문은 Q/A로 고정한다.

### 6.4 커뮤니티 화면의 URL·화면 상태 변경

파일:

- `apps/web/lib/src/features/community/presentation/community_home_page.dart`

작업:

1. `_resolveBoard`가 `all`을 거부하고 FREE로 폴백하게 한다.
2. `_entryBoard`로 진입 board를 보관한다.
3. `initState`의 post-frame callback에서 controller를 동기화한다.
4. `didUpdateWidget`에서 board/query 변경을 각각 계산하고 필요한 호출만 수행한다.
5. `activeBoard`가 legacy `all` 상태를 만나도 `_entryBoard`를 사용하게 한다.
6. H1과 설명을 board별 switch로 만든다.
7. 세그먼트는 `CommunityBoard.all`을 필터링한다.
8. 전환 시 `/community?board=${board.value}`로 이동한다.
9. 검색 query 변경은 현재 board를 보존하고 `context.replace`를 사용한다.
10. 일반 글 상세 링크에 item의 `boardType` query를 포함한다.

### 6.5 제품 카피와 접근성 확인

- label은 `자유게시판`, `Q/A`, `피드백`으로 정확히 통일한다.
- 선택 상태는 색만이 아니라 Material `SegmentedButton`의 selected semantics로 전달한다.
- compact의 각 터치 목표는 44px 이상이어야 한다.
- `CustomScrollView.semanticChildCount`는 광고/더 보기 버튼을 제외한 콘텐츠 수다.
- H1은 `DpPageHeader`를 유지하고 별도 AppBar 제목을 추가하지 않는다.

## 7. 검증 계단

### 7.1 포맷과 대상 테스트

```powershell
dart format apps\web\lib\src\features\community\presentation\community_home_page.dart `
  apps\web\lib\src\features\shell\presentation\app_shell.dart `
  packages\dp_design\lib\src\shell\dp_app_shell.dart `
  apps\web\test\features\community `
  apps\web\test\features\shell `
  packages\dp_design\test\shell\dp_app_shell_adaptive_destinations_test.dart

# 5.4의 대상 테스트를 다시 실행한다.
```

### 7.2 패키지 회귀

```powershell
Push-Location apps\web
flutter test test/features/community test/features/shell
Pop-Location

Push-Location packages\dp_design
flutter test
Pop-Location
```

### 7.3 전체 Flutter 검증

```powershell
dart pub get --enforce-lockfile
dart run melos bootstrap --enforce-lockfile
dart run melos run format
dart run melos run analyze
dart run melos run test

Push-Location apps\web
flutter build web --release
Pop-Location
```

실패하면 첫 실패를 수정하고 같은 계단에서 다시 시작한다. 전체 테스트가 오래 걸린다는 이유로 대상
테스트만 통과한 상태를 릴리스하지 않는다.

### 7.4 diff 검토

```powershell
git diff --check
git diff --stat
git diff -- `
  apps/web/lib/src/features/community/presentation/community_home_page.dart `
  apps/web/lib/src/features/shell/presentation/app_shell.dart `
  packages/dp_design/lib/src/shell/dp_app_shell.dart
git status --short
```

검토 질문:

- unrelated 파일이 섞였는가?
- `ALL`을 데이터 enum에서 지우면서 API 호환성을 깨지 않았는가?
- desktop 수정이 compact 목적지 수를 늘리지 않았는가?
- 검색 입력이 history entry를 계속 생성하지 않는가?
- 상세 복귀 URL이 board를 잃지 않는가?

## 8. 브라우저 QA와 화면 캡처

### 8.1 최소 매트릭스

| viewport | URL | 필수 확인 |
|---|---|---|
| 1440 desktop | FREE | 세 sidebar 목적지, 자유게시판 H1/설명, 글 작성 |
| 1440 desktop | QNA | Q/A 선택, 질문하기, breadcrumb |
| 1440 desktop | FEEDBACK | 피드백 선택, 설명, 글 작성 |
| 390 compact | QNA | 하단 네 목적지, 내부 세 게시판, overflow 없음 |

추가 권장 폭: 768, 1024. 경계 테스트는 599/600, 839/840, 1239/1240을 사용한다.

### 8.2 확인 절차

1. 로그인 상태에서 각 URL로 직접 이동한다.
2. 페이지가 안정될 때까지 기다린다.
3. URL, H1, 설명, 선택 상태, breadcrumb가 같은 board인지 읽는다.
4. FREE → QNA → FEEDBACK을 사이드바 또는 세그먼트로 전환한다.
5. 새로고침 후 선택이 유지되는지 확인한다.
6. 글 행이 있으면 상세 진입 후 breadcrumb로 복귀한다.
7. console error와 network failure를 확인한다.
8. 화면을 캡처하고 SHA-256을 계산한다.

```powershell
Get-FileHash D:\workspace\dpa\.artifacts\community-information-architecture\*.png `
  -Algorithm SHA256
```

### 8.3 성능 숫자의 해석

한 차례 운영 FEEDBACK warm smoke에서 TTFB 약 10ms, total/load 약 223ms가 관찰됐다. 이것은 동일
브라우저 세션의 단일 warm sample이며 Core Web Vitals 또는 p75 성능 인증이 아니다. 성능 완료 판단은
다음 세션의 N04 절차를 따라야 한다.

## 9. PR과 프론트엔드 릴리스

### 9.1 기능 브랜치 커밋·푸시

```powershell
git add -- `
  apps/web/lib/src/features/community/presentation/community_home_page.dart `
  apps/web/lib/src/features/shell/presentation/app_shell.dart `
  apps/web/test/features/community/community_header_test.dart `
  apps/web/test/features/community/community_home_page_test.dart `
  apps/web/test/features/community/community_information_architecture_test.dart `
  apps/web/test/features/community/community_navigation_hierarchy_test.dart `
  apps/web/test/features/shell/app_shell_breadcrumb_test.dart `
  apps/web/test/features/shell/app_shell_view_test.dart `
  packages/dp_design/lib/src/shell/dp_app_shell.dart `
  packages/dp_design/test/shell/dp_app_shell_adaptive_destinations_test.dart

git diff --cached --check
git commit -m "fix(web): expose community boards in navigation"
git push -u origin HEAD
```

### 9.2 PR 생성

```powershell
$prBody = @'
## Summary

- 커뮤니티를 자유게시판, Q/A, 피드백의 직접 계층으로 변경
- desktop/compact 목적지 모델 분리

## Verification

- 대상 위젯 테스트 통과
- melos analyze/test 통과
- release web build 통과
- desktop/compact 캡처 확인
'@

gh pr create `
  --repo DevPathAi/devpath-frontend `
  --base develop `
  --head fix/community-information-architecture-v2 `
  --title "fix(web): expose community boards in navigation" `
  --body $prBody
```

PR 본문에는 요구사항 추적표, 대상/전체 테스트, release build, desktop/mobile 캡처를 포함한다.
PR #203은 이 흐름으로 `develop`에 병합됐다.

### 9.3 release PR

조직 정책에 따라 `develop → main` release PR을 만들고, `main` CI와 image digest가 생성될 때까지
기다린다. 이 작업의 release PR은 #204, main 소스는
`8d19a0bf1170085fa238eaddeae40aa7b8f08b90`이다.

확인할 Actions:

- CI: analyze-test, mission-on/off web image, admin image, release contract
- ET13 Frontend Evidence: visual/a11y atomic pair
- Mobile CI
- 필요한 경우 Signed Android Build와 ET13 Baseline Approval

## 10. GitOps exact-digest 배포

이 절차는 `devpath-gitops`의 현재 runbook과 보호 환경 승인을 따른다. 후보 파일을 수동으로 임의
수정하지 않는다.

### 10.1 후보가 포함해야 할 값

- release ID
- 프론트엔드 main 소스 SHA
- mission-on과 mission-off image digest
- prior rollback digest와 identity
- visual/a11y evidence provenance
- signed mobile artifact binding
- 서비스와 migration의 exact digest
- production/rollback 순서

이 릴리스의 기준값:

```text
release_id: ms-20260916-community-ia
frontend source: 8d19a0bf1170085fa238eaddeae40aa7b8f08b90
mission-on: sha256:a204810fb509a9e68090b078d5720a23aab1feba53625943de038290733f839e
mission-off: sha256:ff158b7fadf6df4d233e4230d6fd2b4a98a3d5e11fb3607aa093f4f26d4366e8
```

### 10.2 sealed 후보 검증

- 후보 commit: `00871aef...`
- candidate spec SHA-256: `a60c112f66cea0217757488c913700c1a323217ba8bc7c4ad28084335de9b93c`
- validation attestation commit: `975f10c...`
- sealed branch: `release/candidate-ms-20260916-community-ia`

sealed 뒤에는 같은 release ID의 후보 bytes를 바꾸지 않는다. 변경이 필요하면 새 release ID 또는
정식 재봉인 절차를 사용한다.

### 10.3 운영 승격 실행

현재 GitOps `main`과 sealed 후보가 정확히 일치하는지 먼저 확인한 뒤 다음 workflow를 실행한다.

```powershell
gh workflow run mission-spine-promote.yml `
  --repo DevPathAi/devpath-gitops `
  --ref main `
  -f release_id=ms-20260916-community-ia
```

workflow가 수행하는 순서:

1. shared migration
2. additive services
3. frontend mission-off
4. compatibility smoke
5. frontend mission-on
6. exact canary hold

성공한 실행: [35114312986](https://github.com/DevPathAi/devpath-gitops/actions/runs/35114312986).

### 10.4 landing-last 실행

canary 성공과 protected main의 현재 상태를 확인한 뒤 실행한다.

```powershell
gh workflow run mission-spine-landing-last.yml `
  --repo DevPathAi/devpath-gitops `
  --ref main `
  -f release_id=ms-20260916-community-ia
```

성공한 실행: [35119923465](https://github.com/DevPathAi/devpath-gitops/actions/runs/35119923465).

landing은 배포 marker가 사용자 도메인까지 전파된 뒤 성공으로 판정해야 한다. 새 deployment를 만들었다는
사실만으로 완료 처리하지 않는다.

## 11. 장애 복구 절차

### 11.1 migration이 ConfigMap 또는 GHCR imagePullSecret 부재로 시작하지 못함

증상:

- Job pod가 구성 참조 오류 또는 image pull 오류로 실행되지 않는다.
- promotion workflow가 migration gate에서 멈춘다.

대응:

1. 실제 namespace, Job, Event를 읽기 전용으로 확인한다.
2. sealed release가 요구하는 정확한 ConfigMap/Secret 이름과 live 상태를 비교한다.
3. 승인된 운영 절차 안에서 누락된 런타임 prerequisite만 임시 복구한다.
4. migration Job을 정확한 후보로 재생성하고 완료 상태를 확인한다.
5. 승격이 끝난 뒤 임시 live 수정이 GitOps 선언과 충돌하지 않도록 제거 또는 선언화한다.
6. migration 완료 SHA와 Job 결과를 History에 남긴다. Secret 값은 남기지 않는다.

이번 릴리스에서는 임시 prerequisite 복구 후 migration을 완료했고, Job을 깨끗하게 재생성한 뒤 임시
수정을 제거했다.

### 11.2 Argo CD가 새 commit을 즉시 반영하지 않음

증상:

- Git commit은 맞지만 Application이 이전 revision 또는 `OutOfSync`에 머문다.

대응:

1. Application의 target revision, observed revision, sync/health를 확인한다.
2. repo cache 지연이 확인되면 hard refresh를 수행한다.
3. 모든 대상 서비스가 exact `Synced/Healthy`가 될 때까지 다음 phase로 가지 않는다.
4. timeout을 늘리기 전에 실제로 어느 Application이 지연되는지 식별한다.

### 11.3 Cloudflare credential 거부

증상:

- landing workflow가 API 인증에서 실패한다.

대응:

1. 토큰 값을 출력하지 않고 identity/권한 검증 호출로 유효성을 확인한다.
2. 기존 environment secret이 만료·폐기된 것이 확인되면 승인된 최소 권한 credential로 교체한다.
3. credential 복구와 deployment 재사용 여부를 구분한다.
4. 장기적으로는 로컬 OAuth 세션이 아닌 durable scoped API token으로 교체한다.

이번 릴리스는 로컬 Wrangler OAuth로 유효성을 검증한 credential을 environment에 일시 반영해 복구했다.
그 실제 값은 어떤 문서에도 남기지 않는다. 장기 token 교체는 다음 세션 P0다.

### 11.4 stale CAS 또는 다른 동일 Home 배포가 먼저 landing됨

증상:

- current deployment가 후보가 예상한 prior deployment와 달라 compare-and-swap가 거부된다.

대응:

1. 현재와 후보가 참조한 prior deployment의 source SHA, body bytes, marker를 비교한다.
2. 동일 소스·동일 bytes라도 CAS를 우회하지 않는다.
3. workflow의 rollback/rebaseline 계약에 따라 정확한 prior ID로 복귀하거나 후보를 재기준화한다.
4. 수동 강제 덮어쓰기는 금지한다.

이번 릴리스에서는 동일 source/body를 확인하고 sealed prior deployment
`740c6ab4...`로 정확히 복귀한 뒤 재실행했다.

### 11.5 custom-domain marker 전파 지연

증상:

- 새 deployment `b02633d0-e2a0-49da-b399-4f1cecd71600`은 만들어졌지만
  `leva.ai.kr`의 marker가 즉시 갱신되지 않아 검증이 실패한다.

대응:

1. 같은 deployment가 이미 존재하면 새 deployment를 또 만들지 않는다.
2. provider deployment 상태와 custom-domain 응답을 분리해 확인한다.
3. 전파가 수렴한 뒤 exact deployment를 재사용해 검증한다.
4. marker, source identity, 사용자 도메인 응답이 모두 일치해야 성공 처리한다.

최종 landing-last run은 수렴한 같은 deployment를 재사용해 성공했다.

## 12. 배포 후 canary

### 12.1 인프라 상태

- GitOps main이 mission-on commit을 가리킨다.
- web image digest가 후보의 mission-on digest와 정확히 같다.
- 관련 Argo CD Applications가 `Synced/Healthy`다.
- release-ready endpoint와 호환성 smoke가 성공한다.
- landing marker와 source identity가 sealed 후보와 같다.

### 12.2 사용자 화면

FREE, QNA, FEEDBACK URL을 직접 열고 다음을 확인한다.

- 로그인 후 예상 경로로 돌아온다.
- board title/description/sidebar/breadcrumb가 일치한다.
- `전체`가 보이지 않는다.
- 검색과 작성 CTA가 동작한다.
- desktop/compact 모두 overflow가 없다.
- 인증 refresh가 발생해도 사용자 화면이 오류 상태에 고착되지 않는다.

### 12.3 롤백 조건

다음 중 하나라도 발생하면 새 UI를 유지하기보다 sealed rollback 계약을 실행한다.

- 새 이미지가 release-ready 또는 compatibility smoke를 지속적으로 실패
- board URL이 잘못된 화면 또는 빈 화면을 표시
- navigation이 주요 화면 접근을 막음
- 인증 refresh 실패가 반복되어 커뮤니티 진입 불가
- 시각 회귀가 정보 또는 행동을 가림

rollback 순서와 digest는 후보 manifest를 따른다. 임의 태그나 `latest`를 사용하지 않는다.

## 13. 문서 마감·커밋·푸시

### 13.1 문서 검증

```powershell
git diff --check
rg -n "TODO|TBD|FIXME|<token>|Bearer |api[_-]?key|secret" `
  docs\community-information-architecture README.md
git status --short
```

로컬 상대 링크는 존재 여부를 검사하고, GitHub/Actions 링크는 실제 리소스를 가리키는지 확인한다.

### 13.2 문서 전용 커밋

```powershell
git add -- `
  README.md `
  docs/community-information-architecture/README.md `
  docs/community-information-architecture/task.md `
  docs/community-information-architecture/workflow.md `
  docs/community-information-architecture/history.md `
  docs/community-information-architecture/handoff.md

git diff --cached --check
git diff --cached --stat
git commit -m "docs: document community IA delivery and handoff"
git push -u origin HEAD
```

### 13.3 다음 세션 체크포인트

커밋과 푸시가 끝난 뒤에만 context checkpoint를 만든다. 체크포인트에는 다음을 적는다.

- 저장소 절대 경로와 브랜치
- 원격에 푸시된 HEAD
- 완료한 Task와 검증
- 변경 파일
- 다음 세션 P0/P1 큐
- 첫 실행 명령
- 알려진 credential/운영 위험, 단 비밀값 제외

다음 세션은 `context-restore`로 체크포인트를 읽고 `git fetch`와 clean status 확인부터 시작한다.

## 14. 30분 내 종료 운영법

남은 시간이 10분 이하이면 새 기능 구현을 시작하지 않는다. 다음 순서로 세션을 닫는다.

1. 현재 변경의 검증 가능 상태를 기록한다.
2. 미완료 항목을 Task ID, 파일, 첫 명령, 합격 기준과 함께 Handoff로 옮긴다.
3. 완결된 문서 또는 안전한 작은 변경만 커밋한다.
4. 원격 푸시와 upstream을 확인한다.
5. context-save 체크포인트를 만든다.

중간 구현이 테스트를 깨뜨린 상태라면 완료로 표시하거나 배포하지 않는다. 안전한 별도 브랜치에 남기고
정확한 실패 테스트와 마지막 명령을 기록한다.
