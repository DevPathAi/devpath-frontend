# History — 요청부터 운영 배포와 문서 이관까지

> 모든 시각은 별도 표기가 없으면 KST(UTC+09:00)다.
>
> 비밀값은 의도적으로 제외했다. 해시, 공개 Actions run, 공개 artifact metadata만 기록한다.

## 1. 한 문장 요약

2026-09-15~17에 Flutter Web을 React로 재작성하지 않고도 제품 수준의 IA·반응형·브라우저 계약을
달성할 수 있다는 결론을 코드와 감사 문서로 고정했고, 커뮤니티를
`자유게시판 / Q/A / 피드백`의 직접 계층으로 변경해 테스트·PR·exact-digest 운영 배포·운영 화면
캡처까지 완료했다. 2026-09-17에는 전체 과정을 재현 가능한 Task/Workflow/History/Handoff 문서로
정리했다.

## 2. 배경

초기 요청은 두 부분이었다.

1. `app.leva.ai.kr`의 Flutter 화면이 React 기반 제품과 같은 수준의 디자인과 구성을 갖출 방법을
   검토한다.
2. 커뮤니티 내부의 `QA`, `자유`, `피드백`을 상위 정보 구조로 끌어올려
   `커뮤니티 → 자유게시판 / Q/A / 피드백`으로 만든다.

기존 구현에는 디자인 토큰, Pretendard/D2Coding, 4단계 window class, 공용 shell과 상태 위젯이 이미
있었다. 핵심 문제는 Flutter 렌더러가 아니라 다음이었다.

- desktop과 compact가 같은 목적지 목록을 공유했다.
- 게시판이 전역 위치가 아닌 페이지 내부 필터로만 보였다.
- `/community`의 기본값이 `전체`였다.
- URL, 레일 선택, H1, 브레드크럼이 하나의 상태를 공유하지 않았다.
- 디자인 계획과 운영 화면의 합격 기준이 분리돼 있었다.

따라서 프레임워크 교체 대신 현재 설계 시스템을 유지하면서 IA와 검증 계약을 고치는 방향을 택했다.

## 3. 시간순 기록

### 2026-09-15 — 전체 React급 고도화 계획 수립

**21:25** — commit `b9c6db9351b6daaa993aaa6ea560a731992d9423`
`docs: plan React-grade Flutter web experience`

작성된 계획:

- Flutter Web이 React 제품과 경쟁할 수 있는 조건을 정보 구조, 상태, 반응형, 접근성, 성능, 시각
  회귀의 여섯 축으로 정의했다.
- `DpTheme`, `DpColors`, `AppTokens`, `DpAppShell`을 유지하는 결정을 내렸다.
- `/login`, `/dashboard`, `/path`, `/mentor`, `/community`를 동일한 품질 게이트로 묶었다.
- Core Web Vitals 목표를 LCP ≤2.5초, INP ≤200ms, CLS ≤0.1로 정했다.
- React 재작성은 비용과 회귀 위험 대비 이득이 없다고 결론냈다.

당시 계획에는 커뮤니티의 `전체`가 남아 있었으나, 후속 운영 감사에서 사용자 요구와 위치 설명에 맞지
않는 것으로 판정해 제거했다.

### 2026-09-16 — 커뮤니티 IA 구현

**20:37:40** — commit `4f4954a2d0b8f2f5a5e0b01fec8e29a3ef79d835`
`fix(web): expose community boards in navigation`

주요 코드 변경:

- `kShellDestinations`에 자유게시판, Q/A, 피드백을 직접 추가했다.
- compact 전용 목적지 배열을 신설해 모바일 하단 내비를 네 항목으로 유지했다.
- `DpAppShell`이 desktop과 compact 목적지를 별도로 받을 수 있게 했다.
- `/community` 기본값과 잘못된 board 값을 FREE로 해석했다.
- URL의 board 값을 레일 선택, H1, 설명, 세그먼트, 브레드크럼의 단일 원천으로 사용했다.
- 사용자 선택지에서 `CommunityBoard.all`을 제외했다.
- 검색 URL 갱신에 `replace`를 사용해 브라우저 history 오염을 방지했다.
- 일반 글 상세·작성 경로에 FREE/FEEDBACK 문맥을 보존했다.

**20:37:48** — commit `68f0b4f875830a13fb420a22353880892de31203`
`docs: audit Flutter web React-grade parity`

운영 감사 결과:

- 배포 전 전체 평가는 C+로 기록했다.
- 커뮤니티 범위 목표는 B+로 정의했다.
- Flutter로 React급 제품 품질을 만들 수 있으며, 격차는 프레임워크가 아니라 IA·브라우저 UX·성능
  게이트에 있다고 명시했다.
- desktop 직접 목적지, compact 로컬 내비, URL 상태, 공용 디자인 시스템, 성능 예산을 합격 기준으로
  만들었다.

**20:56:43** — PR [#203](https://github.com/DevPathAi/devpath-frontend/pull/203)
`fix(web): expose community boards in navigation`이 `develop`에 병합됐다.

- merge commit: `28927e043ce846cdc2f6b77168efd5a22e44e18e`
- 변경량: 11 files, 652 insertions, 97 deletions
- 새 파일:
  - `community_navigation_hierarchy_test.dart`
  - `dp_app_shell_adaptive_destinations_test.dart`
  - React급 운영 감사 문서

### 2026-09-16 — main 릴리스와 CI

**21:24:58** — PR [#204](https://github.com/DevPathAi/devpath-frontend/pull/204)
`release: deploy community information architecture`가 `main`에 병합됐다.

- main source: `8d19a0bf1170085fa238eaddeae40aa7b8f08b90`
- 이 SHA가 이후 이미지, ET13, 모바일 서명 산출물, GitOps 후보의 프론트엔드 source identity가 됐다.

**21:25~21:43** — main push 기반 CI가 실행됐다.

| Run | 종료 | 결과 | 내용 |
|---|---:|---|---|
| [35095691139](https://github.com/DevPathAi/devpath-frontend/actions/runs/35095691139) | 21:39 | success | analyze-test, mission-on/off web image, admin image, release contract |
| [35095691187](https://github.com/DevPathAi/devpath-frontend/actions/runs/35095691187) | 21:36 | success | ET13 Frontend Evidence atomic pair |
| [35095691181](https://github.com/DevPathAi/devpath-frontend/actions/runs/35095691181) | 21:43 | success | Mobile CI |

구현 세션의 로컬 검증 기록:

- IA 핵심 테스트 14개 통과
- shell/community 묶음 36개 통과
- `dp_design` adaptive 테스트 3개 통과
- 전체 Flutter 테스트 960개 통과
- `melos analyze` 성공
- release web build 성공

### 2026-09-16 — 승인된 시각·접근성·모바일 증적

**22:05~22:13** — 수동 dispatch 증적 생성

| Run | 결과 | 핵심 산출물 |
|---|---|---|
| [35099749034](https://github.com/DevPathAi/devpath-frontend/actions/runs/35099749034) | success | ET13 approved baseline, artifact `10446964240` |
| [35099746520](https://github.com/DevPathAi/devpath-frontend/actions/runs/35099746520) | success | Signed Android Build, artifact `10447624173` |

ET13 provenance:

- visual case: 96개
- automated a11y case: 24개
- source SHA: `8d19a0bf...`
- visual baseline set SHA-256:
  `363590851d3fce1dfedb5a713afe198b10b29f04a1fcef47bd8407413627ada3`
- baseline approval SHA-256:
  `024b0012c353ecc217b39cea9f84f6756474e0473b1c5278860f09353f0c397a`

서명 Android 산출물:

- APK: `mobile/android/leva-release.apk`
- SHA-256: `efd37f50fd1ba8f34ff9513ba235c1d9bdb4b4aa616dff25f79a7648cd9464ab`
- signature verification: true
- source SHA: `8d19a0bf...`

이 모바일 산출물은 웹 UI 변경 자체를 위한 것이 아니라 release candidate가 요구하는 전체 제품 증적
binding을 만족하기 위해 생성했다.

### 2026-09-16 — GitOps 후보 생성과 봉인

**22:16:19** — commit `00871aef0d2092abb86b5650d87955f68d3f15e0`
`release: add ms-20260916-community-ia candidate`

- release ID: `ms-20260916-community-ia`
- candidate spec file SHA-256:
  `a60c112f66cea0217757488c913700c1a323217ba8bc7c4ad28084335de9b93c`
- frontend source: `8d19a0bf...`
- mission-on digest:
  `sha256:a204810fb509a9e68090b078d5720a23aab1feba53625943de038290733f839e`
- mission-off digest:
  `sha256:ff158b7fadf6df4d233e4230d6fd2b4a98a3d5e11fb3607aa093f4f26d4366e8`
- prior rollback digest:
  `sha256:27daf697da46c2a6e3d5c48675b3f8f1de3925906a1c9ec0e01be5cfe5914c16`

**23:15:02** — commit `975f10c98ecb7a9adcc7c8bc59501b459985afbd`
`release(manifest): seal ms-20260916-community-ia validation attestation`

후보를 `release/candidate-ms-20260916-community-ia` 브랜치에 sealed data로 고정했다. 이후 운영
workflow는 이 branch의 exact bytes를 입력으로 사용했다.

### 2026-09-16~17 — migration과 단계별 운영 승격

**23:19:41** — migration commit
`3392c58e2561431b6592d0916e72ea5d341fb7af`

초기 migration gate에서 다음 운영 prerequisite 문제가 발견됐다.

- 필요한 ConfigMap 부재
- GHCR imagePullSecret 부재

처리:

1. 실제 namespace와 Job event로 원인을 확인했다.
2. migration 실행에 필요한 live prerequisite를 임시 복구했다.
3. 정확한 sealed migration Job을 재생성하고 완료를 확인했다.
4. 승격 후 임시 수정을 제거해 live drift를 남기지 않았다.

비밀값이나 secret 내용은 이 기록에 남기지 않았다.

**2026-09-17 00:02:19** — additive services commit
`2d8ea57fceafad81de530cb489a2ea219248cb69`

**00:11:36** — mission-off commit
`357c1fa0d6935ae0964ef3eb128867b747e185f9`

**00:20:08** — mission-on commit
`4f3ed64b2a148394eb0b8b3f5311e327f0edd759`

일부 Argo CD Application은 새 revision 관찰이 늦었다. repo cache 지연으로 판단되는 대상에 hard
refresh를 수행한 뒤, 모든 관련 서비스가 exact `Synced/Healthy`임을 확인하고 다음 단계로 갔다.

**00:17:21~00:40:17** — production promotion/canary run
[35114312986](https://github.com/DevPathAi/devpath-gitops/actions/runs/35114312986) 성공.

이 run은 `357c1fa...`에서 시작해 mission-on `4f3ed64...`를 만들고 exact canary를 완료했다.

### 2026-09-17 — Landing-last 실패와 복구

promotion 성공 뒤 Landing-last를 수행하는 동안 다섯 번의 실패가 있었다. 실패를 숨기지 않고 각각의
원인과 최종 복구를 기록한다.

| Run | 시각 | 실패 지점 | 결과/조치 |
|---|---:|---|---|
| [35117044345](https://github.com/DevPathAi/devpath-gitops/actions/runs/35117044345) | 00:41 | main context 검증이 attempt 문자열을 거부 | 잘못된 재실행 형태를 버리고 새 attempt-1 dispatch 사용 |
| [35117814396](https://github.com/DevPathAi/devpath-gitops/actions/runs/35117814396) | 00:48 | Cloudflare API request 실패 | 기존 credential이 유효하지 않음을 실측하고 복구 |
| [35118698797](https://github.com/DevPathAi/devpath-gitops/actions/runs/35118698797) | 00:56 | public dist marker가 exact artifact와 불일치 | current/prior와 후보 bytes·marker 조사 |
| [35119209463](https://github.com/DevPathAi/devpath-gitops/actions/runs/35119209463) | 01:01 | preflight에서 public marker 불일치 | sealed prior 기준을 복원하고 재시도 |
| [35119566193](https://github.com/DevPathAi/devpath-gitops/actions/runs/35119566193) | 01:04 | 새 deployment 뒤 custom-domain marker 미수렴 | 새 deployment를 추가 생성하지 않고 전파 대기 후 재사용 |

#### Credential 복구

기존 `CLOUDFLARE_API_TOKEN`이 API preflight에서 거부되는 것을 실제 실행으로 확인했다. 로컬 Wrangler
OAuth identity가 유효한지 검증한 뒤 승인 환경 credential을 일시 복구했다. 토큰 값은 출력·문서화하지
않았다. 이 OAuth 기반 credential은 단기 성격이므로 durable scoped API token으로의 교체가 남아 있다.

#### CAS와 prior identity

동일 Home 소스의 다른 deployment가 먼저 landing되어 후보가 기대한 prior deployment와 현재 상태가
달라졌다. current와 prior의 source 및 body bytes가 동일한 것을 확인했지만 CAS를 우회하지 않았다.
sealed prior deployment `740c6ab4...`로 정확히 복귀한 뒤 정식 workflow를 다시 실행했다.

#### Custom-domain marker 전파

run `35119566193`에서 Wrangler upload는 성공했고 deployment
`b02633d0-e2a0-49da-b399-4f1cecd71600`이 만들어졌다. 그러나 직후 `leva.ai.kr`의 public marker가
새 artifact에 결합되지 않아 workflow가 실패했다. 같은 deployment를 두 번 만들지 않고 전파 수렴을
기다린 다음 재사용했다.

**01:08:02~01:10:20** — 최종 Landing-last run
[35119923465](https://github.com/DevPathAi/devpath-gitops/actions/runs/35119923465) 성공.

- GitOps head: `4f3ed64b...`
- deployment ID: `b02633d0-e2a0-49da-b399-4f1cecd71600`
- evidence artifact ID: `10456108479`
- artifact name:
  `ms-20260916-community-ia-landing-last-run-35119923465-attempt-1`
- artifact digest:
  `sha256:3530094761f174505dba3d5fe836cc95c35465a26759861fae5b37d704b9c98a`

### 2026-09-17 — 운영 화면 최종 검증

인증된 headed 브라우저에서 다음을 직접 확인했다.

#### 자유게시판

- URL: `/community?board=FREE`
- H1: `자유게시판`
- 설명: `개발 이야기를 자유롭게 나눕니다`
- CTA: `글 작성`
- desktop sidebar의 자유게시판 선택

#### Q/A

- URL: `/community?board=QNA`
- breadcrumb: `커뮤니티 > Q/A`
- H1: `Q/A`
- 설명: `막힌 문제를 질문하고 함께 해결합니다`
- CTA: `질문하기`
- 검색 textbox: `글 검색 (제목·본문·태그)`

#### 피드백

- URL: `/community?board=FEEDBACK`
- H1: `피드백`
- 설명: `코드와 프로젝트에 구체적인 의견을 나눕니다`
- desktop sidebar의 피드백 선택

#### compact

- 하단 내비는 네 핵심 항목을 유지했다.
- 커뮤니티 화면 내부에 자유게시판, Q/A, 피드백 세 전환 항목이 보였다.
- Q/A H1과 질문하기 CTA가 desktop과 같은 문맥을 유지했다.

세 URL 모두에서 `전체`가 주요 게시판으로 노출되지 않았다. API 호출 중 일시적인 401 뒤 인증 refresh
200과 재시도 200이 관찰됐지만, 사용자 화면은 실패 상태에 고착되지 않았다.

한 차례 FEEDBACK warm smoke의 TTFB는 약 10ms, total/load는 약 223ms였다. 이는 단일 sample이며
Core Web Vitals 인증으로 해석하지 않는다.

### 2026-09-17 — 상세 문서와 다음 세션 이관

문서 전용 브랜치 `docs/community-ia-design-handoff-20260917`를 최신 `origin/develop`
`a8fc36fa7eaa7cd53c84992122d97c4a883d960b`에서 만들었다. 기존의 사용자 변경이 있는 작업 트리를
건드리지 않고 별도 worktree
`D:\workspace\dpa\.worktrees\frontend-community-ia-handoff`를 사용했다.

작성한 문서:

- 문서 인덱스와 상태
- 세부 Task와 완료/다음 세션 구분
- 테스트 우선 구현부터 운영 복구까지의 Workflow
- 이 History
- 소스·배포 증적·캡처·남은 일을 담은 Handoff

이 문서 작업에서는 Flutter 코드를 변경하지 않았다. 따라서 전체 Flutter test/build를 재실행하는 대신
변경된 Markdown의 diff, 링크, 민감정보, Git 상태를 검증한 뒤 문서 전용 커밋으로 푸시한다.

## 4. 주요 기술 결정과 이유

### D01 — React 재작성 대신 Flutter 유지

현재 코드에는 이미 typed token, 공용 shell, window class, 접근성 규칙, ET13 증적 체계가 있다.
React로 바꾸면 같은 설계 시스템과 상태·라우팅·테스트를 재구축해야 하지만 IA 문제는 해결되지 않는다.
따라서 제품 품질 축을 직접 강화했다.

### D02 — desktop과 compact 목적지 분리

한 배열을 공유하면 desktop 계층을 풍부하게 할수록 모바일 하단 바가 과밀해진다. 공용
`DpAppShell`에 adaptive 입력을 추가해 표현 컴포넌트의 라우팅 비의존성을 유지하면서 앱이 폭별 IA를
선택하게 했다.

### D03 — URL을 단일 상태 원천으로 사용

Riverpod 상태만 사용하면 새로고침·딥링크·브라우저 back과 셸 선택이 어긋난다. URL의 board를 기준으로
controller를 동기화하고, 레일·H1·breadcrumb도 같은 값을 해석한다.

### D04 — `전체`는 사용자 IA에서 제거하되 enum은 보존

데이터 계층 호환성을 위해 `CommunityBoard.all`을 즉시 삭제하지 않았다. 대신 resolve와 사용자 세그먼트에서
제외하고 FREE로 안전하게 폴백했다. 이 방식은 API·기존 controller 회귀를 줄인다.

### D05 — 검색 입력은 history replace

검색어 한 글자마다 `go`를 사용하면 뒤로가기를 입력 글자 수만큼 눌러야 한다. URL 공유 가능성은
유지하되 입력 변경은 `replace`로 처리했다.

### D06 — exact digest와 sealed candidate

운영에 tag가 아닌 digest를 사용하고, source SHA·이미지·시각/a11y·모바일·rollback identity를 후보
manifest에 결합했다. 장애 시에도 CAS와 sealed prior 계약을 우회하지 않았다.

### D07 — 페이지 안 게시판 세그먼트 제거(2026-09-17)

세 게시판이 레일의 직접 목적지가 된 뒤에도 각 페이지 상단에 자유/Q/A/피드백 세그먼트가 남아 같은 이동
수단이 둘이었다. 세그먼트를 없애고 게시판 이동을 셸로 일원화했다. 단 compact 하단 바에는 `커뮤니티`
하나뿐이라(세그먼트가 Q/A·피드백으로 가는 유일한 경로였다), 그 폭에서만 H1 이 세 게시판을 고르는 제목
메뉴(`DpPageHeader.titleMenu`)가 된다. 함께 통합 게시판 시절의 잔재를 걷었다: 작성 버튼은 3지선다 시트
없이 현재 게시판 작성 화면으로 직행, 행의 게시판 배지·게시판 색 제거(Q/A 강조색은 해결 여부), 게시판별
빈 상태·검색 힌트, 최신순/추천순 정렬. 목록 API 는 `sort` 를 받기만 하고 무시하지만(community-svc
`QuestionService.list`), 페이지네이션 없는 전체 배열이라 클라이언트 정렬이 정확하다. mock 은 `?board=`
키로 게시판별 글만 돌려주게 했다(배지가 없어 섞이면 구분할 수 없다).

## 5. 실제로 완료된 것과 남은 것

### 완료

- 커뮤니티 명칭과 계층 변경
- URL/선택/H1/브레드크럼 일치
- desktop/compact adaptive navigation
- 회귀 테스트와 전체 CI
- React급 Flutter Web 달성 방법 검토
- ET13/서명 산출물/후보 봉인
- exact-digest 운영 배포와 landing-last
- FREE/QNA/FEEDBACK 운영 화면 캡처
- 재현 문서와 세션 이관

### 남음

- 전체 앱에 동일한 정보 구조와 상태 품질 적용
- 브라우저 접근성·focus·200% text 자동화
- renderer A/B와 CWV p75 성능 예산
- 커뮤니티 세 게시판 ET13 fixture 확대
- Cloudflare durable scoped API token 전환

남은 항목은 커뮤니티 요구사항이 미반영된 것이 아니라, 사용자가 요구한 “Flutter 앱 전체를 React급으로
만드는 방법”을 전 화면에 확장하는 후속 작업이다.
