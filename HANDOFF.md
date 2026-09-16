# HANDOFF — GitHub 로그인 복구와 Flutter Web 고도화

> 최종 업데이트: 2026-09-15
>
> 저장소: `devpath-frontend`
>
> 기준 브랜치: `develop` (`22330eb`)
>
> 작업 브랜치: `feat/mobile-first-redesign`
>
> 격리 worktree: `D:\workspace\dpa\.worktrees\frontend-mobile-first-redesign`

## 1. 현재 상태

- GitHub 로그인 500 수정은 `devpath-platform`의 `main`에 병합되고 운영 배포까지 완료됐다.
- Flutter Web 기능 변경은 이 브랜치에 구현·검증·커밋돼 있지만 아직 PR/배포하지 않았다.
- React 재작성 없이 Flutter Web과 `packages/dp_design`을 유지하는 고도화 계획을 확정했다.
- 이 HANDOFF 커밋을 푸시한 뒤 원격 `feat/mobile-first-redesign`이 다음 세션의 기준점이다.

## 2. 운영 완료 — GitHub 로그인 500

### 원인과 수정

- GitHub OAuth 자체는 성공했지만 로그인 후 `MentorAccessService.ensureForLogin`이 레거시
  `BETA_PENDING` 사용자를 비활성 사용자로 거부해 500을 만들었다.
- 삭제되지 않은 정확한 `BETA_PENDING` 상태만 트랜잭션과 pessimistic lock 안에서 `ACTIVE`로
  복구한다.
- 삭제 사용자와 알 수 없는 비활성 상태는 계속 거부한다. 멘토 접근 상태는 독립적으로
  waitlisted 상태를 유지한다.

### 병합·배포 증거

- platform 수정 커밋: `605ea91`, `9753da7`, `3010492`
- platform `main` 병합 커밋: `8f6c9f5357771ae3dac1017bba5240c729d5cc76`
- 운영 이미지: `ghcr.io/devpathai/devpath-platform-svc@sha256:f2b23a0961ff7f614770d59a5cd824008216ff12d5c2d701193644fd1e4e4089`
- GitOps 운영 HEAD: `b9d6a6700c3c432850d05678a8ec4820e4e3543d`
- release id: `ms-20260915-github-login`
- Landing 배포 id: `1496e6fc-c0ab-41be-b3bb-718911757941`
- platform 전체 테스트 325/325, 빌드, main CI, migration/services/OFF/ON, 900초 canary 통과.
- 운영 재확인: `leva.ai.kr` 200, `app.leva.ai.kr` 200, GitHub OAuth 진입 302,
  immutable release marker 200.
- 운영 platform 로그 최근 45분에서 `active user is required`, `IllegalArgumentException`,
  `ERROR`, HTTP 500 일치 항목 0건.

### 검증 한계와 운영 부채

- 실제 GitHub 계정의 OAuth callback 전체 왕복은 Windows UI 연결기가
  `Browser is not available`을 반환해 자동 실측하지 못했다. 서버 테스트와 운영 진입/로그까지만
  검증됐다.
- GitHub environment `mission-spine-production-landing`에 영구
  `CLOUDFLARE_API_TOKEN`이 없다. 이번 배포에는 로컬 Wrangler OAuth를 일시 주입했고 배포 직후
  GitHub secret을 삭제했다. 다음 Landing 배포 전 영구 자격 증명 정비가 필요하다.
- production migration ServiceAccount에 `imagePullSecrets`가 없고 staging GHCR pull secret은
  유효하지 않다. 현재 이미지는 노드 캐시로 동작하지만 새 이미지 pull 전에 별도 수정해야 한다.

## 3. 이 브랜치에서 완료한 변경

### `7d247d8` — 진단 시작 화면 고도화

- 시작 단계, `15문항 · 약 5분`, 기대 결과, 트랙 선택을 하나의 onboarding surface로 구성.
- compact 1열, 넓은 화면 2열 전환과 정보 위계를 RED 위젯 테스트부터 구현.

### `2bea7f5` — 커뮤니티 IA와 로그아웃

- 커뮤니티 순서·명칭을 `전체 / 자유게시판 / Q/A / 피드백`으로 고정.
- 전역 목적지 명칭을 `커뮤니티`로 통일하고 중복 breadcrumb를 제거.
- 계정 메뉴 첫 단계에 로그아웃을 노출하고 관련 IA·shell 테스트를 추가.

### `b9c6db9` — Flutter Web React급 계획

- 계획 문서:
  `docs/superpowers/plans/2026-09-15-flutter-web-react-grade-design.md`
- 결론: React로 재작성하지 않는다. APP UI는 Flutter Web, 공개·검색 콘텐츠는 DOM 중심
  `leva.ai.kr` 랜딩으로 역할을 분리한다.
- 공용 디자인 시스템, 4단계 window class, 상태 matrix, 브라우저 UX, 접근성, renderer A/B,
  Core Web Vitals, RED 테스트·릴리스 게이트를 확정했다.
- 디자인 계획 검토: 6/10 → 9/10, `CLEAN`, 미결정 사항 0개.

## 4. 검증 기록

기존 Leva v2 리디자인 커밋 `af1995c` 기준 전체 검증:

```powershell
dart run melos run format
dart run melos run analyze
dart run melos run test
flutter build web --release
git diff --check
```

- format 737 files, 변경 0.
- analyze: web/admin/mobile/dp_design/dp_core 이슈 0건.
- test: web 953, admin 156, dp_design 220, dp_core 174 및 mobile 전체 통과.
- web release build 성공.
- 이후 진단·커뮤니티·shell 변경은 해당 위젯/IA 테스트를 RED→GREEN으로 통과했다.
- 최종 브랜치 HEAD에서도 전체 format/analyze/test/web release build와 `git diff --check`가 통과했다.
- light/dark 브라우저 검수용 스크린샷 40장을 캡처해 확인했다.
- 계획 문서는 필수 section, review report, 최종 `NO UNRESOLVED DECISIONS`,
  `git diff --check`를 통과했다.

## 5. 다음 세션에서 할 큰 작업

전체 로컬 검증과 브라우저 캡처는 완료됐다. 다음 작업은 외부 동선과 PR 게이트다.

1. GitHub OAuth와 로그아웃을 staging에서 실제 계정으로 왕복 검증한다.
2. `feat/mobile-first-redesign → develop` PR을 만들고 CI 결과를 확인한다.
3. 고도화 계획의 `/plan-eng-review`를 실행한 뒤 T1 Today/Path를 RED 테스트부터 착수한다.

## 6. 다음 세션 시작 명령

```powershell
cd D:\workspace\dpa\.worktrees\frontend-mobile-first-redesign
git fetch origin --prune
git switch feat/mobile-first-redesign
git status --short --branch
git log -5 --oneline --decorate
Get-Content -Raw HANDOFF.md
Get-Content -Raw docs\superpowers\plans\2026-09-15-flutter-web-react-grade-design.md
```

저장된 세션 문맥은 `/context-restore`로 불러온다. 예상 상태는 원격과 동기화된 clean worktree다.

## 7. 10분 종료·이관 규칙

- 종료 요청을 받으면 새 기능, 전체 테스트, 배포, 대규모 리뷰를 시작하지 않는다.
- 10분 안에 `git 상태 수집 → HANDOFF 갱신 → 문서 검사 → 명시 파일만 커밋 → push →
  context-save` 순서로 끝낸다.
- 10분을 넘길 가능성이 있는 작업은 HANDOFF의 다음 세션 목록으로 이동한다.
- 차단은 실제 명령 결과와 함께 기록한다. 추측으로 사람에게 작업을 넘기지 않는다.
