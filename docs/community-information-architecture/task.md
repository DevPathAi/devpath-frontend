# 상세 Task — 커뮤니티 IA 교정 및 React급 Flutter Web 품질

> 상태 표기: `DONE` 완료 · `NEXT` 다음 세션 · `BLOCKED` 외부 차단
>
> 기능 구현 기준 소스: `8d19a0bf1170085fa238eaddeae40aa7b8f08b90`
>
> 문서 기준 브랜치: `docs/community-ia-design-handoff-20260917`

## 1. 최종 목표

### 제품 목표

- 사용자가 데스크톱 사이드바만 보고도 `커뮤니티` 안에 자유게시판, Q/A, 피드백이 있음을 안다.
- 현재 게시판이 URL, 선택된 내비게이션, 화면 제목, 설명, 브레드크럼에 동일하게 나타난다.
- 모바일은 전역 목적지를 네 개로 유지하면서 커뮤니티 내부의 세 게시판을 빠르게 전환한다.
- Flutter Web의 화면 품질을 프레임워크 이름이 아니라 정보 구조, 디자인 시스템, 반응형, 접근성,
  브라우저 동작, 성능, 검증 수준으로 관리한다.

### 완료 정의

다음 조건이 모두 참일 때 이 요구사항의 구현 부분을 완료로 본다.

- [x] `커뮤니티 → 자유게시판 / Q/A / 피드백`이 데스크톱에서 직접 보인다.
- [x] 사용자 선택지에서 `전체`가 제거된다.
- [x] `/community`의 기본 게시판은 자유게시판이다.
- [x] `FREE`, `QNA`, `FEEDBACK` 딥링크가 새로고침 뒤에도 같은 게시판을 표시한다.
- [x] 상세·작성 경로의 브레드크럼과 복귀 경로가 게시판 문맥을 보존한다.
- [x] compact 하단 내비게이션은 네 항목만 유지한다.
- [x] 대상 위젯 테스트, 전체 분석·테스트, release web build와 CI가 통과한다.
- [x] 운영에 exact digest로 배포하고 FREE/QNA/FEEDBACK 화면을 캡처한다.
- [x] 구현·검증·배포 이력을 상세 Task, Workflow, History, Handoff로 문서화한다.

## 2. 범위와 비범위

### 이번 완료 범위

- 커뮤니티 정보 구조와 명칭 변경
- desktop/compact 목적지 모델 분리
- 게시판 URL 상태와 화면 상태 일치
- 게시판별 H1, 설명, CTA, 빈 상태 문맥
- 브레드크럼과 상세·작성 복귀 문맥
- 관련 회귀 테스트
- React급 Flutter Web 달성 방법 검토
- 전체 Flutter 검증, 시각 캡처, PR, exact-digest 운영 배포와 증적
- 다음 작업자를 위한 상세 문서와 체크포인트

### 의도적으로 다음 세션으로 넘긴 범위

- 전체 앱의 Today/Path 정보 밀도 재편
- 모든 핵심 화면의 loading/empty/error/success/partial 상태 통일
- 전체 키보드·focus-visible·200% 텍스트·reduced-motion 자동화
- Flutter JS/CanvasKit와 wasm renderer A/B 및 Core Web Vitals p75 게이트
- 390/768/1024/1440 전 화면 시각 회귀 baseline 확대
- Cloudflare Landing용 장기 수명 scoped API token 교체

이 비범위는 요구사항 축소가 아니다. 커뮤니티 교정은 이미 운영에 반영됐고, 앱 전체의 React급 고도화는
별도의 검증 가능한 Task로 분리해 다음 세션에서 계속한다.

## 3. 구현 Task

### T00 — 기준선과 증적 수집 (`DONE`)

**목적**

변경 전 화면과 코드가 실제로 어떤 구조인지 고정해 문자열 치환만으로 끝나는 것을 막는다.

**입력**

- 변경 전 운영 캡처: `.artifacts/community-information-architecture/production-before.png`
- 설계 기준: `DESIGN.md`
- 전체 React급 계획: `docs/superpowers/plans/2026-09-15-flutter-web-react-grade-design.md`
- 기존 커뮤니티 구현과 셸 구현

**수행**

1. 데스크톱에서 커뮤니티가 단일 목적지인지 확인한다.
2. 화면 내부에 `전체 / Q/A / 자유 / 피드백`이 있는지 확인한다.
3. `/community`, `?board=FREE`, `?board=QNA`, `?board=FEEDBACK`의 화면 상태와 URL을 비교한다.
4. H1, 브레드크럼, 사이드바 선택 상태가 같은 게시판을 가리키는지 기록한다.
5. compact와 desktop이 같은 목적지 배열을 사용해 생기는 제약을 식별한다.

**산출물**

- 운영 감사: `docs/superpowers/reports/2026-09-16-flutter-react-grade-production-audit.md`
- 변경 전 캡처 SHA-256:
  `16120be5797423b535b26367b98d1c69962b2383d0069612d7bf9844ace0e418`

**합격 기준**

- 문제를 프레임워크 결함이 아니라 IA·상태·검증 계약의 결함으로 설명할 수 있다.
- 변경 전후 비교에 쓸 URL과 시각 증적이 존재한다.

### T01 — IA 계약을 실패하는 테스트로 고정 (`DONE`)

**목적**

구현 전에 사용자가 보는 구조를 테스트 이름과 기대값으로 고정한다.

**수정 파일**

- `apps/web/test/features/community/community_information_architecture_test.dart`
- `apps/web/test/features/community/community_navigation_hierarchy_test.dart`
- `apps/web/test/features/community/community_home_page_test.dart`
- `apps/web/test/features/shell/app_shell_breadcrumb_test.dart`
- `apps/web/test/features/shell/app_shell_view_test.dart`
- `packages/dp_design/test/shell/dp_app_shell_adaptive_destinations_test.dart`

**고정한 계약**

- 사용자 노출 순서는 `자유게시판`, `Q/A`, `피드백`이다.
- desktop 커뮤니티 섹션에는 세 게시판이 직접 목적지로 존재한다.
- URL의 `board`가 desktop 선택 인덱스를 결정한다.
- compact 하단 내비게이션은 네 핵심 목적지만 가진다.
- board 쿼리가 없거나 잘못되면 자유게시판을 조회한다.
- 동일 페이지에서 board 쿼리만 바뀌어도 새 게시판을 조회한다.
- 커뮤니티 브레드크럼은 현재 게시판 계층을 보여 준다.

**합격 기준**

- 변경 전 코드에서는 새 기대값이 실패하고, 구현 후 통과한다.
- 테스트가 텍스트 존재뿐 아니라 목적지 순서, 선택 index, URL, callback 경로를 확인한다.

### T02 — desktop 목적지 모델 교정 (`DONE`)

**목적**

데스크톱 레일이 제품 공간과 현재 위치를 직접 설명하게 한다.

**수정 파일**

- `apps/web/lib/src/features/shell/presentation/app_shell.dart`

**구현 계약**

```text
kShellDestinations
  학습: 오늘 / 학습 경로 / AI 멘토
  커뮤니티: 자유게시판 / Q/A / 피드백
```

- 경로는 각각 `/community?board=FREE`, `/community?board=QNA`,
  `/community?board=FEEDBACK`이다.
- `shellDestinationIndexFor`는 `board` 값에 따라 FREE=3, QNA=4, FEEDBACK=5를 반환한다.
- 질문 작성·질문 상세은 Q/A에, 일반 글 상세·작성은 보존된 board에 연결한다.
- 알 수 없는 `board`는 자유게시판 index로 안전하게 폴백한다.

**합격 기준**

- 840px 이상에서 세 목적지가 동시에 보인다.
- 선택한 게시판과 강조된 목적지가 일치한다.
- 설정·마이페이지·알 수 없는 경로가 잘못된 커뮤니티 또는 Today 항목을 강조하지 않는다.

### T03 — compact 목적지 모델 분리 (`DONE`)

**목적**

데스크톱에 필요한 여섯 목적지를 좁은 화면의 하단 바에 밀어 넣지 않는다.

**수정 파일**

- `apps/web/lib/src/features/shell/presentation/app_shell.dart`
- `packages/dp_design/lib/src/shell/dp_app_shell.dart`

**구현 계약**

- `kCompactShellDestinations`는 `오늘 / 학습 경로 / AI 멘토 / 커뮤니티` 네 항목이다.
- compact 커뮤니티의 기본 경로는 `/community?board=FREE`다.
- `DpAppShell`은 `compactDestinations`, `compactSelectedIndex`, `onCompactSelect`를 별도로 받는다.
- compact 선택값이 없을 때 desktop index로 잘못 폴백하지 않는다.
- 커뮤니티 내부 세 게시판은 페이지 상단 세그먼트가 담당한다.

**합격 기준**

- 390px에서 하단 내비게이션 항목이 네 개이며 overflow가 없다.
- 어떤 게시판에 있더라도 하단에서는 `커뮤니티`가 선택된다.
- 세 게시판 전환은 최소 44px 높이의 로컬 컨트롤로 가능하다.

### T04 — URL을 게시판 상태의 단일 원천으로 사용 (`DONE`)

**목적**

딥링크, 새로고침, 뒤로가기, 셸 선택, 화면 내용을 일치시킨다.

**수정 파일**

- `apps/web/lib/src/features/community/presentation/community_home_page.dart`
- 라우터의 `CommunityHomePage(initialBoard: ...)` 연결부

**구현 계약**

- `_resolveBoard(null)`과 알 수 없는 값은 `CommunityBoard.free`다.
- `CommunityBoard.all`은 `_resolveBoard`와 사용자 세그먼트에서 제외한다.
- 첫 진입은 `initState` 이후 선택 게시판을 controller에 전달한다.
- 같은 위젯에서 URL만 바뀌면 `didUpdateWidget`이 board/query 변화를 비교해 다시 조회한다.
- 검색어 갱신은 `go`가 아니라 `replace`를 써서 타이핑 문자 수만큼 브라우저 history를 쌓지 않는다.
- 검색 쿼리와 board 쿼리를 함께 유지한다.

**합격 기준**

- URL 직접 입력, 새로고침, 셸 전환, 세그먼트 전환이 모두 같은 결과를 낸다.
- `?board=ALL` 또는 임의 값이 사용자에게 `전체`를 노출하지 않는다.
- 검색어를 지우면 현재 게시판의 기본 목록으로 돌아간다.

### T05 — 화면 위계, 명칭, 행동 교정 (`DONE`)

**목적**

고정된 `커뮤니티` 제목 대신 사용자가 지금 보고 있는 공간과 다음 행동을 즉시 이해하게 한다.

**수정 파일**

- `apps/web/lib/src/features/community/presentation/community_home_page.dart`

**정확한 카피**

| board | H1 | 설명 | 기본 주행동 |
|---|---|---|---|
| FREE | `자유게시판` | `개발 이야기를 자유롭게 나눕니다` | `글 작성` |
| QNA | `Q/A` | `막힌 문제를 질문하고 함께 해결합니다` | `질문하기` |
| FEEDBACK | `피드백` | `코드와 프로젝트에 구체적인 의견을 나눕니다` | `글 작성` |

**추가 계약**

- 게시판 전환 컨트롤에는 세 항목만 표시한다.
- 일반 글 행은 `FREE`를 `자유게시판`, `FEEDBACK`을 `피드백`으로 표시한다.
- QNA 행은 질문 상세로, FREE/FEEDBACK 행은 board 쿼리가 포함된 일반 게시글 상세로 이동한다.
- 빈 상태에서도 현재 게시판에 맞는 작성 행동을 제공한다.

**합격 기준**

- H1과 설명이 URL의 게시판과 일치한다.
- 화면 어디에도 `QA`, `자유`, `전체`가 새 주요 명칭으로 노출되지 않는다.
- `Q/A`, `자유게시판`, `피드백` 표기를 모든 주요 진입점에서 동일하게 쓴다.

### T06 — 브레드크럼과 복귀 문맥 보존 (`DONE`)

**목적**

상세·작성 화면에서도 사용자가 어느 게시판에서 왔는지 잃지 않게 한다.

**수정 파일**

- `apps/web/lib/src/features/shell/presentation/app_shell.dart`

**기대 결과**

```text
/community?board=FREE
  커뮤니티 → 자유게시판

/community/post/12?board=FEEDBACK
  커뮤니티 → 피드백 → 게시글

/community/new
  커뮤니티 → Q/A → 질문하기

/community/new/post?board=FREE
  커뮤니티 → 자유게시판 → 새 글
```

**주의 사항**

- 긴 경로인 `/community/new/post`를 `/community/new`보다 먼저 매칭한다.
- 일반 게시글 상세는 `FEEDBACK`만 명시적으로 구분하고 나머지는 FREE로 안전하게 처리한다.
- 클릭 가능한 중간 crumb는 정확한 board 쿼리를 포함한다.

**합격 기준**

- 브레드크럼 클릭으로 원래 게시판 목록에 복귀한다.
- 상세 화면에서 레일 선택과 브레드크럼이 서로 다른 게시판을 가리키지 않는다.

### T07 — React급 Flutter Web 구현 방법 검토 (`DONE`, 전체 앱 적용은 `NEXT`)

**결론**

React로 재작성할 필요가 없다. 현재 디자인 시스템과 Flutter Web을 유지하되 아래 여섯 축을 릴리스
계약으로 다룬다.

1. **정보 구조**: route-addressable 상태, 전역 목적지와 로컬 필터 분리, 현재 위치의 중복 확인.
2. **디자인 시스템**: `DpColors`, `DpSpacing`, `DpTypography`, `DpPageHeader`, `DpListRow`,
   공용 상태 primitive를 단일 원천으로 사용.
3. **반응형 구성**: 단순 축소가 아니라 compact/medium/expanded/large에서 정보 우선순위를 바꾼다.
4. **브라우저 UX**: 딥링크, 새로고침, back history, 키보드, focus-visible, hover/pressed/disabled를 계약화.
5. **접근성**: 44px target, 의미 순서, 선택 상태, 200% 텍스트, reduced motion, 실제 브라우저 a11y 트리.
6. **성능·회귀**: release/profile 기준 Core Web Vitals, 초기 자산 예산, renderer A/B, 시각 baseline.

**이번 커뮤니티에서 적용한 부분**

- route-addressable board 상태
- desktop/compact 목적지 분리
- 공용 셸과 디자인 토큰 재사용
- H1/설명/CTA/빈 상태의 게시판 문맥
- 위젯·라우팅 회귀 테스트
- 운영 캡처와 exact-digest 배포 증적

**다음 세션에 남은 부분**

- 전체 화면 상태 matrix, 브라우저 접근성 자동화, 성능 예산, 전 화면 시각 회귀 확대

### T08 — 로컬 및 CI 검증 (`DONE`)

**당시 로컬 실행 결과**

| 범위 | 결과 |
|---|---|
| IA 핵심 테스트 | 14개 통과 |
| shell/community 관련 묶음 | 36개 통과 |
| `dp_design` adaptive 목적지 | 3개 통과 |
| 전체 Flutter 테스트 | 960개 통과 |
| `dart run melos run analyze` | 성공 |
| `flutter build web --release` | 성공 |

**원격 검증**

| 실행 | 결과 | 검증 범위 |
|---|---|---|
| [CI 35095691139](https://github.com/DevPathAi/devpath-frontend/actions/runs/35095691139) | success | analyze-test, web mission on/off image, admin image, release contract |
| [ET13 35095691187](https://github.com/DevPathAi/devpath-frontend/actions/runs/35095691187) | success | atomic visual/a11y evidence pair |
| [Mobile CI 35095691181](https://github.com/DevPathAi/devpath-frontend/actions/runs/35095691181) | success | 모바일 회귀 |

숫자는 구현 세션의 로컬 실행 기록이며, 원격 성공 여부의 권위 있는 증적은 링크된 GitHub Actions다.

### T09 — 운영 화면 검증과 캡처 (`DONE`)

**검증 URL**

- `https://app.leva.ai.kr/community?board=FREE`
- `https://app.leva.ai.kr/community?board=QNA`
- `https://app.leva.ai.kr/community?board=FEEDBACK`

**확인 항목**

- 세 게시판 H1과 설명이 정확하다.
- desktop 레일에 세 게시판이 동시에 보이고 현재 게시판이 선택된다.
- compact 하단 내비는 네 항목이고 페이지 내부에서 세 게시판을 전환한다.
- `전체`가 보이지 않는다.
- 검색, 작성/질문 CTA, 빈 상태가 렌더된다.
- 인증 만료 시 401 뒤 refresh/retry 200이 발생해도 화면 실패로 고착되지 않는다.

**캡처**

캡처 경로와 해시는 [handoff.md](./handoff.md)에 고정한다.

### T10 — PR, 릴리스, 운영 승격 (`DONE`)

**프론트엔드**

- 구현 커밋: `4f4954a2d0b8f2f5a5e0b01fec8e29a3ef79d835`
- 감사 문서 커밋: `68f0b4f875830a13fb420a22353880892de31203`
- `develop` 병합 커밋: `28927e043ce846cdc2f6b77168efd5a22e44e18e`
- `main` 병합 커밋: `8d19a0bf1170085fa238eaddeae40aa7b8f08b90`

**GitOps**

- 후보 추가: `00871aef...`
- 후보 파일 SHA-256: `a60c112f66cea0217757488c913700c1a323217ba8bc7c4ad28084335de9b93c`
- 검증 attestation 봉인: `975f10c...`
- mission-on 운영 커밋: `4f3ed64b2a148394eb0b8b3f5311e327f0edd759`
- 운영 승격 run `35114312986`: success
- landing-last run `35119923465`: success

**합격 기준**

- 소스 SHA, 이미지 digest, 후보 manifest, GitOps 커밋, Actions run이 서로 연결된다.
- 운영에서 최종 UI를 다시 확인한다.
- rollback digest가 후보에 포함된다.

### T11 — 문서·핸드오프·세션 이관 (`DONE`)

**산출물**

- `README.md`: 문서 인덱스와 현재 상태
- `task.md`: 이 문서
- `workflow.md`: 재현 절차
- `history.md`: 실제 수행 이력과 장애 해결
- `handoff.md`: 다음 세션 시작점과 남은 일
- 저장소 루트 `README.md`: 문서 진입 링크
- 로컬 gstack context checkpoint: 다음 세션에서 `context-restore`가 읽을 상태

**합격 기준**

- 새 작업자가 기존 대화를 보지 않고도 구현의 의도, 파일, 테스트, 배포 증적, 남은 일과 시작 명령을 안다.
- 문서 링크와 민감정보 검사가 통과한다.
- 문서 전용 브랜치가 원격에 푸시된다.

## 4. 최종 요구사항 추적표

| 사용자 요구 | 구현 위치 | 자동 검증 | 운영 검증 | 상태 |
|---|---|---|---|---|
| React급 디자인·구성 방법 검토 | 운영 감사, T07, 기존 전체 계획 | 설계 계약을 테스트 목록에 연결 | 운영 캡처·ET13 | DONE |
| 커뮤니티 하위에 자유게시판 | shell/home page | IA·hierarchy·home tests | FREE 캡처 | DONE |
| `QA`를 `Q/A`로 표기 | shell/home page | 정확한 label 테스트 | QNA 캡처 | DONE |
| `자유`를 `자유게시판`으로 표기 | shell/home page | 정확한 label 테스트 | FREE 캡처 | DONE |
| 피드백 직접 노출 | shell/home page | 목적지·index 테스트 | FEEDBACK 캡처 | DONE |
| `게시판` 중간 계층 제거 | desktop 목적지·breadcrumb | 목적지 계층 테스트 | sidebar/breadcrumb 육안 확인 | DONE |
| `전체` 제거 | 세그먼트 필터 | exposed board 테스트 | 세 URL에서 미노출 확인 | DONE |
| 다른 작업자가 같은 결과 재현 | workflow/history/handoff | 링크·diff 검사 | 다음 세션 restore 절차 | DONE |

## 5. 다음 세션 Task 큐

> 2026-09-17 후속 세션에서 N02~N06을 순서대로 구현·머지했다(모두 `origin/develop`, 각 PR은 CI 녹색 확인 후 merge commit).
> N01만 실측 차단(인간 단계)으로 남았다. 각 항목의 상세 설계·실측·후속 과제는 `docs/design/*.md`가 원천이다.
> 같은 날 릴리스 PR #213으로 `main`(`d10ee171`)에 반영됐고, 후속 폰트 다이어트 #215는 그 뒤 `develop`에만 있다(handoff.md §1.3·§6.1.5).

### N01 — Cloudflare 장기 자격 증명 정리 (`BLOCKED_HUMAN`, P0 운영)

- 실측 차단(2026-09-17): 로컬 wrangler OAuth 토큰은 Cloudflare 토큰 관리 API에서 `9109`로 거부되고 Global API Key는 로컬에 없다.
  대시보드에서 `Account → Cloudflare Pages → Edit` 단일 권한 토큰을 만드는 것만 인간 단계다. 값은 어디에도 기록하지 않는다.
- 인간이 실행할 명령(토큰을 `%USERPROFILE%\cf-pages-token.txt`에 저장한 뒤):
  `! gh secret set CLOUDFLARE_API_TOKEN --repo DevPathAi/devpath-gitops --env mission-spine-production-landing < "$env:USERPROFILE\cf-pages-token.txt"; Remove-Item "$env:USERPROFILE\cf-pages-token.txt"`
- 그 뒤 AI가 `mission-spine-landing-last.yml` preflight를 비파괴로 실행하고 런북을 갱신한다.

- 임시로 복구한 Landing 배포 자격 증명을 장기 수명·최소 권한의 scoped API token으로 교체한다.
- 토큰 값은 어떤 문서나 로그에도 기록하지 않는다.
- 교체 후 dry-run 또는 비파괴 identity 검증과 Landing workflow의 인증 단계만 검증한다.
- 성공 기준: 다음 landing-last 실행이 로컬 OAuth 세션에 의존하지 않는다.

### N02 — 전체 앱 상태 matrix 통일 (`DONE`, P1 제품)

- 결과: PR [#206](https://github.com/DevPathAi/devpath-frontend/pull/206) → develop merge `41e267a8`.
- 신설 primitive는 `DpInlineNotice`(danger/warning/info) 하나. `DpLoading`은 `SemanticsRole.status` 라벨을 가진다.
- 계약 테스트 `apps/web/test/app/state_matrix_contract_test.dart`가 13개 화면 소스에서 임시 로딩·에러 패턴을 금지한다.
- 로그인은 세션 복원 중 버튼 대신 로딩을 보인다(의도된 동작 변경). 문서: `docs/design/app-state-matrix.md`.

- 대상: 로그인, 진단, Today, Path, Community, Content, Sandbox, Mentor.
- 각 화면의 loading/empty/error/success/partial과 복구 행동을 테스트로 먼저 고정한다.
- `DpStateScaffold`를 우선 재사용하고, 두 화면 이상에 같은 의미가 있을 때만 새 primitive를 만든다.

### N03 — 브라우저 UX·접근성 자동화 (`DONE`, P1 품질)

- 결과: PR [#208](https://github.com/DevPathAi/devpath-frontend/pull/208) → develop merge `c375b36b`. CI job `browser-ux`(ET13 핀 Playwright 이미지, `--network none`).
- `tools/browser_ux/run.mjs` 8 시나리오(deep link 복귀·새로고침·back/forward·키보드 순회·dialog focus 복귀·overflow/44px·reduced-motion·axe wcag22aa), 390/768/1024/1440, 200% 텍스트.
- dp_design 수정 4건(카드 단일 탭 정지·`SemanticsRole` status/alert·셸 `WidgetOrderTraversalPolicy`·표준 밀도+세그먼트 44px). 부트스트랩이 커스텀 host element에 임베딩한다(axe meta-viewport 해소).
- 편차: 키보드 순회 기대값은 실측 순서(검색 → 게시판 3 → 글 작성 → 행 3)다. 라우트 `FocusScope` 경계 때문에 레일이 페이지 순회에 없다(레일 우선 순회는 후속). 문서: `docs/design/browser-ux-contract.md`.

- deep link, 새로고침, back, focus 복귀, 키보드 순회, 200% 텍스트, reduced-motion을 자동화한다.
- 390/768/1024/1440에서 overflow와 44px target을 검증한다.
- 실제 Flutter semantics와 브라우저 접근성 트리를 모두 확인한다.

### N04 — 성능 기준선과 예산 (`DONE`, P1 성능)

- 결과: PR [#209](https://github.com/DevPathAi/devpath-frontend/pull/209) → develop merge `c370c73e`. CI job `perf-gate`.
- `tools/perf/measure.mjs`(5 라우트 × mobile/desktop × cold/warm, runs=3, nearest-rank p75), `perf/baseline.json`(CanvasKit), `perf/renderer-ab-2026-09-17.json`(wasm), `perf/budget.json`, `tools/perf/gate.mjs`.
- 실측: cold 전송 22 MB(폰트 10.4 · JS 5.9 · CanvasKit 5.7), 모바일 Slow 4G ready 21.4 s, 데스크톱 3.8 s. wasm은 −12% 전송, −27%/−21% ready.
- 후속 수정: PR [#212](https://github.com/DevPathAi/devpath-frontend/pull/212)(merge `9687b05e`) — `networkidle` 대기만 기본 30 s 라 Slow 4G 에서 간헐 만료(코드 무변경 PR 에서 실측) → 명시 120 s + 계약 테스트. 기준선은 3회, CI 는 5회 표본이다.
- 편차: 절대 예산(LCP 2.5 s 등)은 첫 기준선이 밖이라 `enforce_absolute: false` 경고 모드, 전송량 +5% 회귀만 강제. 브라우저는 Chromium만(Firefox/Safari A/B 미수행). CanvasKit은 LCP 후보가 없어 `ready_ms`를 대용. 문서: `docs/design/perf-baseline.md`.

- `/login`, `/dashboard`, `/path`, `/mentor`, `/community`의 cold/warm p75를 분리한다.
- 기본 web 빌드와 wasm 빌드를 지원 브라우저별로 A/B한다.
- LCP ≤2.5s, INP ≤200ms, CLS ≤0.1과 초기 전송량 5% 회귀 방지 기준을 CI에 연결한다.

### N05 — Today/Path 정보 밀도 재편 (`DONE`, P1 디자인)

- 결과: PR [#207](https://github.com/DevPathAi/devpath-frontend/pull/207) → develop merge `846228d5`.
- `DpMissionHeader`에 `action` 슬롯(순서 eyebrow → title → action → 완료 조건 → progress → why). Today/Path는 expanded 이상에서 3:2 두 열, compact는 한 열.
- 장식 카드(도넛·배지)와 중복 제목·설명을 제거했다. 그리드 열 수는 `LayoutBuilder` 가용 폭으로 정한다. 문서: `docs/design/today-path-hierarchy.md`.

- `다음 행동 → 완료 조건 → 진행 → 보조 맥락` 순서로 재구성한다.
- compact와 large의 구성 자체를 다르게 설계한다.
- 사용자 행동이 아닌 장식 카드와 중복 제목을 제거한다.

### N06 — 시각 회귀 확대 (`DONE`, P2 출시)

- 결과: PR [#210](https://github.com/DevPathAi/devpath-frontend/pull/210) → develop merge `fa778c2d`.
- `WebCommunityBoardProjection` 추출 후 FREE/QNA/FEEDBACK fixture 3종을 catalog에 추가(12→15, visual 96→120, a11y 24→30, browser smoke 16→22). projection sha `106e8d29…`.
- 편차: 기존 matrix(320/600/840/1240 × light/dark, a11y 320 light 200% / 1240 dark 200%)를 그대로 적용했고 DPR 1/2 분리는 하지 않았다(ET13 matrix 계약 변경이 필요해 후속).
- baseline은 `pending_external_review` 그대로다. release_ready 전환은 `et13-baseline-approval.yml` 경로의 사람 승인·provenance로만 한다.
- 실측: 첫 CI의 `produce-atomic-pair`가 `browser smoke requires 8 web-hosted fixtures`로 실패했다(`tools/et13/capture.mjs`의 하드코딩, 로컬 게이트 미대조). 11로 핀했다. 두 번째 CI는 `captureSummary.case_count must be 120; found 150`(총합 96+24를 하드코딩, 새 visual 120과 우연히 일치)로 실패해 총합도 파생시켰다. 둘 다 producer 계약 테스트로 막았다. 문서: `docs/design/et13-community-fixtures.md`.

- 커뮤니티 FREE/QNA/FEEDBACK fixture를 ET13 catalog에 추가한다.
- 390/768/1024/1440 smoke와 light/dark, DPR 1/2, text 100/200%를 분리한다.
- baseline 갱신은 사람 승인과 provenance 없이는 수행하지 않는다.
