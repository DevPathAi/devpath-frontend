# Handoff — 커뮤니티 IA·Flutter Web 품질 후속 작업

> 인계 시점: 2026-09-17 KST
>
> 현재 결론: 커뮤니티 요구사항은 구현·테스트·운영 배포·운영 화면 검증까지 완료
>
> 다음 세션 성격: 전체 앱 React급 고도화 후속 Task와 운영 credential 정리

## 1. 먼저 알아야 할 현재 상태

### 1.1 제품 상태

`app.leva.ai.kr` 운영에는 다음 정보 구조가 반영돼 있다.

```text
커뮤니티
  ├─ 자유게시판
  ├─ Q/A
  └─ 피드백
```

- desktop sidebar에 세 게시판이 직접 보인다.
- compact 하단 내비는 네 핵심 목적지를 유지한다.
- 커뮤니티 페이지 안에서 세 게시판을 전환한다.
- `/community`는 자유게시판으로 해석된다.
- `전체`는 사용자에게 주요 게시판으로 노출되지 않는다.
- URL, 레일 선택, H1, 설명, 브레드크럼이 같은 board를 표시한다.

### 1.2 구현 상태

| 상태 | 값 |
|---|---|
| 기능 브랜치 | `fix/community-information-architecture` |
| 구현 commit | `4f4954a2d0b8f2f5a5e0b01fec8e29a3ef79d835` |
| 감사 문서 commit | `68f0b4f875830a13fb420a22353880892de31203` |
| develop merge | `28927e043ce846cdc2f6b77168efd5a22e44e18e` |
| main source | `8d19a0bf1170085fa238eaddeae40aa7b8f08b90` |
| 기능 PR | [#203](https://github.com/DevPathAi/devpath-frontend/pull/203) |
| release PR | [#204](https://github.com/DevPathAi/devpath-frontend/pull/204) |
| 운영 배포 | 완료 |

### 1.3 이 문서 작업 상태

| 항목 | 값 |
|---|---|
| 저장소 | `D:\workspace\dpa\.worktrees\frontend-community-ia-handoff` |
| 브랜치 | `docs/community-ia-design-handoff-20260917` |
| 기준 | `origin/develop`의 `a8fc36fa7eaa7cd53c84992122d97c4a883d960b` |
| 변경 종류 | Markdown 문서만 변경, Flutter 코드 변경 없음 |
| 예정 커밋 제목 | `docs: document community IA delivery and handoff` |
| 커밋 확인법 | `git log -1 --oneline` |
| 원격 확인법 | `git status --short --branch`와 `git ls-remote --heads origin docs/community-ia-design-handoff-20260917` |

자기 자신을 포함하는 문서 commit SHA는 문서 안에 하드코딩하지 않았다. 다음 작업자는 위 명령으로 원격
HEAD를 읽는다.

## 2. 다음 세션 시작 명령

```powershell
Set-Location D:\workspace\dpa\.worktrees\frontend-community-ia-handoff
git fetch origin --prune
git status --short --branch
git log -5 --oneline --decorate
git rev-parse HEAD
git rev-parse '@{upstream}'
```

예상 결과:

- 브랜치가 `docs/community-ia-design-handoff-20260917`이다.
- worktree가 clean이다.
- HEAD와 upstream이 같다.

그 다음 문서를 다음 순서로 읽는다.

1. [README.md](./README.md)
2. [task.md](./task.md)의 “다음 세션 Task 큐”
3. [workflow.md](./workflow.md)의 해당 Task 절차
4. [history.md](./history.md)의 장애/결정 기록
5. 이 문서의 P0/P1 큐

세션 시작 시 `context-restore`를 실행할 수 있으면 가장 최근 체크포인트를 복원한다. 체크포인트가
없거나 도구가 없더라도 이 문서만으로 이어갈 수 있다.

## 3. 절대로 정리하거나 덮어쓰지 말아야 할 작업 트리

기본 경로 `D:\workspace\dpa\devpath-frontend`에는 문서 작업 시작 당시 다음 사용자 소유 상태가 있었다.

```text
branch: feat/evidence-auth-smoke
untracked: .artifacts/
untracked: AGENTS.md
untracked: CODEX.md
```

다음 작업을 하지 않는다.

- `git clean`
- `git reset --hard`
- `git checkout -- .`
- 임의 stash
- `.artifacts` 삭제 또는 이동
- 이 문서 worktree를 기본 경로 위에 복사

새 코드 작업은 최신 `origin/develop`에서 별도 worktree를 만든다.

## 4. 코드 위치와 변경 의도

### 4.1 `app_shell.dart`

경로:
`apps/web/lib/src/features/shell/presentation/app_shell.dart`

책임:

- `kShellDestinations`: desktop의 여섯 목적지
- `kCompactShellDestinations`: compact의 네 목적지
- `_communityBoardLabel`: URL board → 표시명
- `breadcrumbFor`: 커뮤니티 홈/상세/작성 위계
- `shellDestinationIndexFor`: desktop 선택 index
- `compactShellDestinationIndexFor`: compact 선택 index
- `AppShellView`: 공용 `DpAppShell`에 adaptive 입력 배선

회귀 위험:

- 경로 match 순서가 바뀌면 `/community/new/post`가 질문 작성으로 잘못 분류될 수 있다.
- 일반 글 상세에서 board query를 빼면 FEEDBACK이 자유게시판으로 보일 수 있다.
- unknown 경로를 index 0으로 폴백하면 Today가 잘못 강조된다.

### 4.2 `community_home_page.dart`

경로:
`apps/web/lib/src/features/community/presentation/community_home_page.dart`

책임:

- board query 해석과 FREE 기본값
- URL 변경 시 controller 동기화
- 검색 query와 board 보존
- 게시판별 H1·설명·CTA
- 세 게시판 segmented control
- 일반 글/질문 상세 routing
- empty/error/list 문맥

회귀 위험:

- `CommunityBoard.values`를 그대로 표시하면 `전체`가 다시 노출된다.
- `didUpdateWidget` 동기화를 지우면 같은 route에서 query만 바뀔 때 화면이 갱신되지 않는다.
- 검색에 `go`를 사용하면 back history가 입력 문자마다 쌓인다.
- `activeBoard`가 legacy `all`을 그대로 표시하면 H1과 URL이 불일치한다.

### 4.3 `dp_app_shell.dart`

경로:
`packages/dp_design/lib/src/shell/dp_app_shell.dart`

책임:

- 라우팅을 모르는 공용 4-class shell
- compact와 non-compact 목적지·선택·callback 분리
- rail, mobile nav, chrome, account 슬롯 배치

회귀 위험:

- `compactSelectedIndex ?? selectedIndex` 같은 폴백을 넣으면 desktop Q/A index 4가 compact 네 항목에서
  잘못 clamp될 수 있다.
- 공용 package에 `/community` 문자열이나 `go_router`를 넣으면 설계 경계가 깨진다.

## 5. 회귀 테스트 지도

| 테스트 | 방어하는 계약 |
|---|---|
| `community_information_architecture_test.dart` | 노출 게시판 정확한 순서·명칭, shell 목적지, breadcrumb |
| `community_navigation_hierarchy_test.dart` | desktop 세 목적지, URL별 index, compact 네 목적지 |
| `community_home_page_test.dart` | 기본 FREE, query 진입·변경, 세그먼트, 목록·빈 상태·CTA |
| `app_shell_breadcrumb_test.dart` | 홈/상세/작성 계층과 경로 match 순서 |
| `app_shell_view_test.dart` | 폭별 shell, callback, 선택 상태, chrome |
| `dp_app_shell_adaptive_destinations_test.dart` | compact 전용 목적지와 null selection |

대상 테스트 명령은 [workflow.md](./workflow.md#54-대상-테스트-실행)에 있다.

## 6. 릴리스 identity

### 6.1 프론트엔드

```text
repository: DevPathAi/devpath-frontend
source: 8d19a0bf1170085fa238eaddeae40aa7b8f08b90
release_id: ms-20260916-community-ia
mission_on: sha256:a204810fb509a9e68090b078d5720a23aab1feba53625943de038290733f839e
mission_off: sha256:ff158b7fadf6df4d233e4230d6fd2b4a98a3d5e11fb3607aa093f4f26d4366e8
prior: sha256:27daf697da46c2a6e3d5c48675b3f8f1de3925906a1c9ec0e01be5cfe5914c16
```

### 6.2 GitOps

```text
candidate commit: 00871aef0d2092abb86b5650d87955f68d3f15e0
candidate file sha256: a60c112f66cea0217757488c913700c1a323217ba8bc7c4ad28084335de9b93c
sealed commit: 975f10c98ecb7a9adcc7c8bc59501b459985afbd
migration commit: 3392c58e2561431b6592d0916e72ea5d341fb7af
services commit: 2d8ea57fceafad81de530cb489a2ea219248cb69
mission-off commit: 357c1fa0d6935ae0964ef3eb128867b747e185f9
mission-on commit: 4f3ed64b2a148394eb0b8b3f5311e327f0edd759
```

### 6.3 성공한 자동화

| 목적 | Run | 상태 |
|---|---|---|
| Frontend CI | [35095691139](https://github.com/DevPathAi/devpath-frontend/actions/runs/35095691139) | success |
| ET13 evidence | [35095691187](https://github.com/DevPathAi/devpath-frontend/actions/runs/35095691187) | success |
| Mobile CI | [35095691181](https://github.com/DevPathAi/devpath-frontend/actions/runs/35095691181) | success |
| Signed Android | [35099746520](https://github.com/DevPathAi/devpath-frontend/actions/runs/35099746520) | success |
| ET13 baseline approval | [35099749034](https://github.com/DevPathAi/devpath-frontend/actions/runs/35099749034) | success |
| Production promotion/canary | [35114312986](https://github.com/DevPathAi/devpath-gitops/actions/runs/35114312986) | success |
| Landing-last | [35119923465](https://github.com/DevPathAi/devpath-gitops/actions/runs/35119923465) | success |

### 6.4 Landing 증적

```text
deployment_id: b02633d0-e2a0-49da-b399-4f1cecd71600
artifact_id: 10456108479
artifact_name: ms-20260916-community-ia-landing-last-run-35119923465-attempt-1
artifact_digest: sha256:3530094761f174505dba3d5fe836cc95c35465a26759861fae5b37d704b9c98a
```

GitHub artifact의 만료 예정일은 2026-10-16로 조회됐다. 장기 보존이 필요하면 조직의 승인된 증적
보관소로 옮기되, 후보 manifest와 digest 연결을 유지한다.

## 7. 운영 화면 캡처

경로:
`D:\workspace\dpa\.artifacts\community-information-architecture`

| 파일 | 크기 | SHA-256 | 용도 |
|---|---:|---|---|
| `production-before.png` | 55,086 bytes | `16120be5797423b535b26367b98d1c69962b2383d0069612d7bf9844ace0e418` | 변경 전 |
| `production-after-desktop-free.png` | 60,745 bytes | `725f8b88b56b5f5c5c890f936f36564e09b048802d0f4e26f1349122c5bd10e9` | FREE desktop |
| `production-after-desktop-qna.png` | 60,397 bytes | `45c4cb67f9ad51dcf299f850bb93d202aa586ce6766573c4e571828f1f38e18c` | QNA desktop 중간 캡처 |
| `production-final-desktop-qna.png` | 60,269 bytes | `6300e7303b698e28390582052688b8dabf2620f4360cabd16eac3383fd7d959b` | QNA desktop 최종 캡처 |
| `production-after-desktop-feedback.png` | 59,560 bytes | `a820d96d34f893ac0bed8bf861fc763f9d52092e480cabf135e15cac1e6bf509` | FEEDBACK desktop |
| `production-after-mobile-qna.png` | 43,998 bytes | `33af402625f5b59a85863d82f9cc45fee152664b87b8a30f1a25cf67eaab0a00` | QNA compact |

이 파일들은 기본 저장소의 추적 대상이 아니다. 사용자 소유 `.artifacts`이므로 이동·삭제·커밋하지 않는다.

최종 Q/A 캡처에서 확인한 화면:

- 어두운 desktop sidebar
- sidebar의 커뮤니티 section 아래 자유게시판, Q/A, 피드백
- `커뮤니티 > Q/A` breadcrumb
- Q/A H1과 설명
- 검색창
- 자유게시판/Q/A/피드백 세 전환 버튼
- 빈 상태
- `글 작성`, `질문하기` 행동

## 8. 알려진 운영 위험

### P0 — Cloudflare credential 내구성

Landing 실패 시 기존 Cloudflare API token이 실제 API preflight에서 거부됐다. 로컬 Wrangler OAuth로
유효성을 확인한 credential을 승인 환경에 일시 반영해 최종 배포를 완료했다. 이 credential은 단기
세션 성격이므로 다음 landing 전에 장기 수명·최소 권한 scoped API token으로 교체해야 한다.

다음 세션 작업:

1. Cloudflare에서 Pages project 읽기/배포에 필요한 최소 scope를 확인한다.
2. durable token을 승인된 secret manager/GitHub Environment에 저장한다.
3. 기존 secret 값을 출력하지 않고 교체한다.
4. identity/preflight를 비파괴적으로 실행한다.
5. 만료 정책과 담당 환경 이름만 문서화한다. 값은 문서화하지 않는다.

성공 기준:

- local Wrangler OAuth 로그인에 의존하지 않는다.
- `mission-spine-landing-last.yml`의 Cloudflare preflight가 인증 오류 없이 통과한다.
- 토큰이 필요한 project/account 이외의 광범위 권한을 갖지 않는다.

### P1 — Landing marker 수렴 시간

새 deployment 직후 custom domain marker가 provider deployment보다 늦게 갱신됐다. workflow는
정확하게 실패했지만 재실행이 필요했다. 향후에는 같은 deployment reuse와 bounded polling이 계약대로
작동하는지 테스트를 추가할 가치가 있다.

### P1 — GitHub artifact 만료

Landing evidence artifact `10456108479`는 2026-10-16 만료 예정이다. 장기 감사 보존 정책이 있다면
만료 전에 digest를 보존하는 승인된 archive 절차를 실행한다.

## 9. 다음 세션 우선순위

### 9.1 P0 — Cloudflare durable token

예상 산출물:

- environment secret 교체
- 비파괴 preflight 성공 증적
- 만료/회전 runbook 갱신

코드 변경이 필요하지 않을 수 있다. 실제 API/secret update 권한이 거부될 때만 정확한 거부 메시지와
복사 실행 가능한 다음 명령을 남긴다.

### 9.2 P1 — 전체 앱 상태와 정보 구조

첫 구현 후보는 Today/Path다.

```text
Today: 다음 행동 → 완료 조건 → 진행 → 보조 맥락
Path: 현재 주차 → 다음 추천 → 전체 진행
```

실행 전 `docs/superpowers/plans/2026-09-15-flutter-web-react-grade-design.md`의 T1/T2를 최신 코드와
다시 대조한다. 테스트를 먼저 만들고 새 별도 worktree에서 작업한다.

### 9.3 P1 — 브라우저 UX·접근성

필수 case:

- 로그인 후 원래 deep link 복귀
- board 전환 후 back/forward
- 키보드로 rail → search → segment → list → FAB 순회
- menu/dialog 닫힘 후 focus 복귀
- 200% 텍스트에서 overflow 없음
- reduced-motion에서 정보 손실 없음
- 스크린리더가 선택된 board와 목록 항목 수를 정확히 읽음

### 9.4 P1 — 성능 기준선

단일 warm load 숫자를 완료 증적으로 사용하지 않는다. Chrome/Edge와 지원 Firefox/Safari에서 cold/warm,
mobile/desktop을 분리하고 p75를 저장한다. Monaco, 광고, 폰트, CanvasKit/Wasm의 초기 로드 기여도를
route별로 분리한다.

### 9.5 P2 — ET13 커뮤니티 fixture

현재 release candidate의 ET13 catalog는 전체 제품 기준선 96 visual/24 a11y case를 제공하지만,
FREE/QNA/FEEDBACK 세 운영 화면을 전용 fixture로 직접 봉인하지는 않는다. 다음 catalog revision에서
세 board의 desktop/compact fixture를 추가한다.

## 10. 하지 말아야 할 재작업

다음 항목은 이미 완료됐으므로 회귀 증거가 없으면 다시 만들지 않는다.

- React로 프론트엔드 재작성 검토를 처음부터 반복
- 커뮤니티 label 단순 치환
- desktop sidebar에 세 게시판 추가
- compact 목적지 모델 분리
- FREE 기본값과 `전체` 미노출
- board별 H1/설명
- breadcrumb board 문맥
- feature PR #203과 release PR #204 재생성
- release ID `ms-20260916-community-ia`의 후보 수정 또는 재봉인
- 새 mission-on image tag/digest 생성
- 완료된 deployment `b02633d0...` 재배포

변경이 필요하면 새 요구사항, 회귀 테스트, 새 source SHA, 새 release identity로 진행한다. sealed 후보를
수정하지 않는다.

## 11. 장애가 재발했을 때 첫 확인

### 화면에 예전 구조가 보임

1. browser cache/service worker를 확인한다.
2. 응답의 release marker와 운영 source identity를 확인한다.
3. GitOps web image digest가 `a204810...`인지 확인한다.
4. URL이 `/community?board=...`인지 확인한다.
5. 특정 사용자 세션만 문제인지 새 private session과 비교한다.

소스 변경이나 재배포는 위 확인 뒤에만 한다.

### Q/A를 눌렀는데 자유게시판이 선택됨

1. URL query가 `QNA`인지 대소문자까지 확인한다.
2. `shellDestinationIndexFor` 테스트를 실행한다.
3. `CommunityHomePage.didUpdateWidget`이 호출되는지 확인한다.
4. controller가 `all` 상태를 반환하는지 확인한다.

### 모바일 하단 바에 여섯 항목이 보임

1. `AppShellView`가 `compactDestinations`를 전달하는지 확인한다.
2. `DpAppShell` compact 분기가 `compactDestinations ?? destinations`를 사용하는지 확인한다.
3. `dp_app_shell_adaptive_destinations_test.dart`를 실행한다.

### Landing이 public marker에서 실패

1. 새 deployment를 즉시 다시 만들지 않는다.
2. preflight의 `deploy_mode`와 deployment ID를 확인한다.
3. provider deployment와 custom domain marker를 분리해 확인한다.
4. 동일 exact deployment를 reuse할 수 있으면 전파 수렴 뒤 재실행한다.

## 12. 문서 브랜치 완료 확인 체크리스트

- [ ] `git diff --check` 성공
- [ ] 다섯 문서가 서로 연결됨
- [ ] 저장소 루트 README에서 문서 인덱스로 진입 가능
- [ ] 상대 링크 대상 존재
- [ ] 공개 PR/Actions 링크 유효
- [ ] secret/token 값 미포함
- [ ] 사용자 소유 worktree와 `.artifacts` 미변경
- [ ] 문서 commit 생성
- [ ] 원격 branch push 및 upstream 설정
- [ ] context-save checkpoint 생성

## 13. 다음 작업자에게 남기는 최종 판단

커뮤니티 요구사항은 “아직 검토 중”이 아니라 운영 완료 상태다. 다음 세션은 같은 UI를 다시 만드는 데
쓰지 말고, 우선 Cloudflare credential의 내구성을 정리한 뒤 React급 품질 기준을 Today/Path와 전체
상태·접근성·성능 게이트로 확장해야 한다. 이때 커뮤니티 구현은 adaptive navigation과 URL-state
동기화의 참조 구현으로 사용한다.
