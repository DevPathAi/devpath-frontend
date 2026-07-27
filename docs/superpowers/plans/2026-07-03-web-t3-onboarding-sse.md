# Tier-2 조각 3 (T3) — 온보딩 정리 + SSE 계약 정합 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development 또는 superpowers:executing-plans로 태스크별 구현. 스텝은 체크박스(`- [ ]`)로 추적.

**Goal:** Tier-2 웹 골든패스 실API 전환의 마지막 조각(T3)을 완결한다 — review #60 머지, 죽은 온보딩 레거시 제거, path·sandbox·mentor SSE 실계약 회귀 테스트로 정합 확정.

**Architecture:** 백엔드(learning `LearningPathController`, sandbox `RunController`, ai `MentorController`)는 이미 SSE를 구현했고(SseEmitter, POST, 이벤트명 progress/log·session/references·token, `emitter.complete()`로 종료), 프론트 `SseClient`(POST + `event:`/`data:` 파싱 + 스트림종료=완료)와 호환된다. 실 온보딩은 `diagnostic` feature(`/onboarding/assessments/**`, `AssessmentController`와 정합, 골든패스 테스트 완비)가 담당하며 라우터 게이트도 `/diagnostic`를 가리킨다. 따라서 이 조각은 (a) 백엔드 대응이 없는 죽은 `onboarding` feature 제거, (b) SSE 3종 실계약 회귀 테스트 추가/정합, (c) review #60 머지다. **백엔드 변경 없음.**

**Tech Stack:** Flutter Web · Riverpod · dio · dp_core(`SseClient`/`SseEvent`) · flutter_test · melos.

## Global Constraints

- 모든 변경은 `develop`에서 분기한 작업 브랜치. `main`·`develop` 직접 push 금지. PR은 develop 대상.
- Test-First(실패 테스트 먼저) → 최소 구현/정합 → `flutter test` 눈으로 통과 확인.
- 커밋 전 `dart format` 적용(CI format 게이트 `dart format --set-exit-if-changed`).
- 검증 명령(apps/web에서): `flutter test` · `flutter analyze`. 현재 baseline = 151 test green · analyze 0.
- 커밋 트레일러: `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- PR 구성(승인됨): (1) 온보딩 정리 PR, (2) SSE 정합 PR. #60 머지는 선행.
- 추측 금지: 소비 컨트롤러 API가 필요한 테스트는 해당 파일을 먼저 읽고 작성한다.

---

### Task 0: review #60 머지 (선행)

**Files:** 없음(GitHub 머지).

- [ ] **Step 1: #60 상태 재확인**

Run: `gh pr view 60 --repo DevPathAi/devpath-frontend --json state,mergeable,mergeStateStatus,statusCheckRollup -q '{state:.state,mergeable:.mergeable,mergeState:.mergeStateStatus,checks:[.statusCheckRollup[]|{name:.name,conclusion:.conclusion}]}'`
Expected: state=OPEN, mergeable=MERGEABLE, mergeState=CLEAN, analyze-test=SUCCESS

- [ ] **Step 2: 머지(merge commit)**

Run: `gh pr merge 60 --repo DevPathAi/devpath-frontend --merge`
Expected: Merged. (실패 시 원인 확인 후 중단·보고 — 강제 금지)

- [ ] **Step 3: 로컬 develop 갱신**

Run: `git -C /d/workspace/dpa/devpath-frontend checkout develop && git -C /d/workspace/dpa/devpath-frontend pull --ff-only origin develop`
Expected: #60 머지 커밋 포함.

---

## PR 1 — 온보딩 정리 (branch `feat/web-t3-onboarding-cleanup`)

### Task 1: 죽은 온보딩 레거시 feature 제거

**배경:** 라우터 게이트(`router.dart:47-48`)는 온보딩 미완 유저를 `/diagnostic`로 보낸다(온보딩 게이트=진단). 실 온보딩 플로우는 `diagnostic` feature(`assessment_api`→`/onboarding/assessments/**`)이며 `AssessmentController`와 정합·골든패스 테스트됨. `onboarding` feature(`OnboardingController.submit`→`POST /onboarding {githubHandle}`)는 **백엔드 대응이 없고 게이트가 절대 라우팅하지 않는** 죽은 코드다.

**Files:**
- Delete: `apps/web/lib/src/features/onboarding/application/onboarding_controller.dart`
- Delete: `apps/web/lib/src/features/onboarding/state/onboarding_state.dart`
- Delete: `apps/web/lib/src/features/onboarding/presentation/onboarding_page.dart` (존재 시)
- Modify: `apps/web/lib/src/app/router.dart` (`/onboarding` GoRoute + `OnboardingPage` import + stale 주석 제거)
- Modify: `apps/web/lib/src/data/web_mock_fixtures.dart` (`POST /onboarding` 픽스처 제거)
- Delete: `apps/web/test/features/onboarding/**` (존재 시)

- [ ] **Step 1: 참조 전수 조사(죽은 코드 확증)**

Run: `cd /d/workspace/dpa/devpath-frontend && grep -rn "OnboardingPage\|onboardingControllerProvider\|OnboardingController\|features/onboarding\|'/onboarding'\|\"/onboarding\"" apps/web/lib apps/web/test`
Expected: 참조가 `features/onboarding/` 내부 + `router.dart`의 `/onboarding` 라우트 등록/ import + `web_mock_fixtures`의 `POST /onboarding` 로만 국한. **외부 리다이렉트/링크/게이트가 `/onboarding`을 가리키면 중단하고 보고**(죽은 코드 아님). `OnboardingStatus`(auth 열거형)는 게이트가 쓰므로 제거 대상 아님 — 혼동 금지.

- [ ] **Step 2: 온보딩 라우트 제거 시 게이트가 무한 리다이렉트하지 않음을 검증하는 테스트 작성**

`apps/web/test/app/router_onboarding_gate_test.dart` 신규. 온보딩 미완 유저가 임의 경로 접근 시 `/diagnostic`로 유도되고, `/onboarding` 라우트가 없어도 게이트가 정상 동작함을 검증. (router.dart의 `redirect` 순수 함수 시그니처를 먼저 읽고 그에 맞춰 작성.)

- [ ] **Step 3: 테스트 실패 확인(라우트 아직 존재)**

Run: `cd /d/workspace/dpa/devpath-frontend/apps/web && flutter test test/app/router_onboarding_gate_test.dart`
Expected: 신규 테스트가 의도한 대로 실패(또는 라우트 존재로 인한 어서션 실패).

- [ ] **Step 4: 온보딩 feature + 라우트 + 픽스처 + 테스트 제거**

`onboarding` feature 디렉토리 삭제, `router.dart`에서 `/onboarding` GoRoute·`OnboardingPage` import·stale 주석 제거, `web_mock_fixtures.dart`에서 `POST /onboarding` 엔트리 제거, 기존 `test/features/onboarding/**` 삭제.

- [ ] **Step 5: analyze + 전체 test 통과 확인**

Run: `cd /d/workspace/dpa/devpath-frontend/apps/web && flutter analyze && flutter test`
Expected: analyze 0 issues, 전체 green(제거된 온보딩 테스트 수만큼 감소, 신규 게이트 테스트 포함).

- [ ] **Step 6: format + 커밋 + 푸시 + PR**

Run: `cd /d/workspace/dpa/devpath-frontend && dart format apps/web && git checkout -b feat/web-t3-onboarding-cleanup && git add -A apps/web && git commit -m "refactor(web): 죽은 온보딩 레거시 제거 — 실 온보딩=diagnostic(assessments) 정합 (조각 3)" && git push -u origin feat/web-t3-onboarding-cleanup`
그 후 `gh pr create --base develop` (제목/본문: 죽은 `POST /onboarding` 제거 근거 = 게이트가 `/diagnostic`, 백엔드는 `AssessmentController`만). CI green 확인.

---

## PR 2 — SSE 실계약 회귀 테스트 (branch `feat/web-t3-sse-verify`, PR1 머지 후 develop에서 분기)

> 각 SSE 태스크의 공통 패턴: 백엔드가 실제로 보내는 wire(`event:<name>\ndata:<payload>\n\n` … 스트림종료)를 dio stream mock 어댑터로 재현해, 실 소스(`apiClient.sse(...)`)→컨트롤러→상태 전이가 올바른지 검증한다. 목 소스가 아니라 **실 분기**(`useMock=false`)를 통과시키는 게 목적(목-마스킹 방지).

### Task 2: path SSE 실계약 회귀 테스트

**계약(실측):** 백엔드 `LearningPathController`: `@PostMapping("/me/generate", produces=text/event-stream)`, `SseEmitter.event().name("progress").data(PathProgressEvent)`, 종료 `emitter.complete()`. `PathProgressEvent(String stage, double progress, String message, Long pathId)`. 프론트 `PathSseEvent{stage,progress,message,pathId?}` — **필드 완전 일치**. 소스 `path_sse_source.dart` 실분기 = `apiClient.sse('/learning-paths/me/generate')`, stage 상수 `[collecting,generating,matching,done]`.

**Files:**
- Test: `apps/web/test/features/path/path_sse_realapi_test.dart` (신규)
- (정합 불일치 발견 시에만) Modify: path 컨트롤러/state 또는 `path_sse_event.dart`

- [ ] **Step 1: path 소비 컨트롤러 API 확인**

Run: `cd /d/workspace/dpa/devpath-frontend && cat apps/web/lib/src/features/path/application/*controller*.dart apps/web/lib/src/features/path/state/*state*.dart 2>/dev/null | head -120`
컨트롤러가 `event=='progress'` 이벤트의 data를 `PathSseEvent.fromJson`으로 파싱하고 stage=`done` 또는 스트림 종료에서 완료 상태로 전이하는지 확인.

- [ ] **Step 2: 실계약 wire를 재현하는 실패 테스트 작성**

dio `ResponseType.stream` mock 어댑터로 `event:progress\ndata:{"stage":"collecting","progress":0.1,"message":"진단 분석","pathId":null}\n\n` … `data:{"stage":"done","progress":1.0,"message":"완료","pathId":7}\n\n` 후 스트림 종료를 방출. 실 소스(useMock=false, `apiClientProvider` override)로 path 컨트롤러를 구동해 최종 상태(생성 완료·pathId=7)를 어서션.

- [ ] **Step 3: 실패 확인** — Run: `cd /d/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/path/path_sse_realapi_test.dart` → 미구현/불일치로 실패.

- [ ] **Step 4: 정합(불일치 시에만) + 통과** — 이벤트명·필드가 이미 일치하면 테스트만으로 GREEN. 불일치 발견 시 최소 정합 후 통과. Run 동일 → PASS.

- [ ] **Step 5: 커밋** — `git add apps/web && git commit -m "test(web): path SSE 실계약(progress·PathProgressEvent) 회귀 테스트 (조각 3)"`

### Task 3: sandbox SSE 실계약 회귀 테스트

**계약(실측):** 백엔드 `RunController`: `@PostMapping("/run", produces=text/event-stream)`, `name("log").data(line)` + `name("session").data(sessionId)`, 종료 `complete()`. 프론트 `sandbox_run_source.dart` 실분기 = `client.sse('/sandbox/run', body:{code,language})`; `run_controller`가 `RunDone(sandboxSessionId)`로 수렴(리뷰 자동폴링 트리거). **이벤트명·body 정합 확인 대상.**

**Files:**
- Test: `apps/web/test/features/sandbox/sandbox_run_sse_realapi_test.dart` (신규)
- (불일치 시) Modify: `run_controller.dart` 또는 소스

- [ ] **Step 1: RunController body 계약 확인**

Run: `cd /d/workspace/dpa && grep -n "record\|String code\|String language\|@RequestBody\|RunRequest" devpath-sandbox-svc/src/main/java/ai/devpath/sandbox/run/RunController.java` → 프론트 body `{code,language}`와 필드 일치 확인. 불일치면 프론트 소스 정합.

- [ ] **Step 2: 실계약 wire 재현 실패 테스트** — `event:log\ndata:> run\n\n` … `event:session\ndata:42\n\n` 후 종료 → 실 소스로 `run_controller` 구동, `RunDone.sandboxSessionId==42` + 로그 누적 어서션.

- [ ] **Step 3: 실패 확인** — Run: `flutter test test/features/sandbox/sandbox_run_sse_realapi_test.dart`

- [ ] **Step 4: 정합(필요 시) + 통과**

- [ ] **Step 5: 커밋** — `test(web): sandbox run SSE 실계약(log·session) 회귀 테스트 (조각 3)`

### Task 4: mentor SSE 실계약 회귀 테스트

**계약(실측):** 백엔드 `MentorService`: `name("references").data(json)` → `name("token").data(t)`×N → `complete()`. `MentorController.sessions(@RequestBody MentorRequest)`. 프론트 `mentor_sse_source.dart` 실분기 = `apiClient.sse('/ai-mentor/sessions', body:{message,contentId})`; 이벤트 `references`+`token` 소비. **body(message,contentId)↔MentorRequest, references+token 소비 확인.**

**Files:**
- Test: `apps/web/test/features/mentor/mentor_sse_realapi_test.dart` (신규)
- (불일치 시) Modify: `mentor_controller.dart`/state 또는 소스

- [ ] **Step 1: MentorRequest 필드 + 프론트 mentor 소비 컨트롤러 확인**

Run: `cd /d/workspace/dpa && grep -rn "record MentorRequest\|message\|contentId" devpath-ai-svc/src/main/java/ai/devpath/aigw/mentor/Mentor*.java | head` 및 `cat devpath-frontend/apps/web/lib/src/features/mentor/application/mentor_controller.dart` → body 필드 일치 + `references`/`token` 이벤트 처리·스트림종료 완료 확인.

- [ ] **Step 2: 실계약 wire 재현 실패 테스트** — `event:references\ndata:[{...}]\n\n` → `event:token\ndata:비동기 \n\n` … 후 종료 → 실 소스로 mentor 컨트롤러 구동, 답변 누적 + 참고자료 반영 상태 어서션.

- [ ] **Step 3: 실패 확인** — Run: `flutter test test/features/mentor/mentor_sse_realapi_test.dart`

- [ ] **Step 4: 정합(필요 시) + 통과**

- [ ] **Step 5: format + 전체 검증 + 커밋 + PR**

Run: `cd /d/workspace/dpa/devpath-frontend && dart format apps/web && cd apps/web && flutter analyze && flutter test` → analyze 0·전체 green. 그 후 `git add apps/web && git commit -m "test(web): mentor SSE 실계약(references·token) 회귀 테스트 (조각 3)"` → push → `gh pr create --base develop`(제목: SSE 3종 실계약 회귀 테스트). CI green 확인.

---

### Task 5: Tier-2 전체 코드 점검 (PR1·PR2 머지 후)

**목표:** Tier-2(조각 1a·1b·2·3) 누적 정합 표면을 점검 — 실API 계약 정합의 회귀·누락·목-마스킹·불일치 탐지.

- [ ] **Step 1: 점검 대상 집합 확정** — Tier-2에서 바뀐 실서버 분기 표면: auth(refresh)·community·lcs(T1), content·dashboard·review(T2), path·sandbox·mentor SSE + 온보딩(diagnostic)(T3). 각 화면의 프론트 경로·요청 body·응답/이벤트 DTO ↔ 백엔드 계약 대조표를 audit 리포트(`docs/superpowers/reports/2026-07-03-web-realapi-contract-audit.md`) 기준으로 갱신.

- [ ] **Step 2: 다중 관점 코드 점검** — `oh-my-claudecode:code-reviewer`(또는 `/code-review`)로 누적 diff(develop 대비 Tier-2 커밋 범위)를 리뷰: 계약 불일치·에러 처리·목vs실 분기 누락·죽은 코드·테스트 적정성. 발견은 심각도 순으로 정리.

- [ ] **Step 3: 검증** — `flutter analyze`(0) + `flutter test`(green) 최종 확인. 잔여 gap은 audit 리포트 "잔여/후속"에 명시(에러 envelope=별도 발행 게이트, OAuth e2e=R4 인프라).

- [ ] **Step 4: 점검 결과 보고** — 발견·수정·잔여를 요약 보고. 수정이 필요하면 별도 후속 태스크로 분리(스코프 이탈 방지).

---

## Self-Review 메모
- **Spec 커버리지:** A(#60 Task0)·B(온보딩 Task1)·C(path Task2)·D(mentor Task4)·E(sandbox Task3)·점검(Task5) 전부 태스크 존재. ✅
- **범위 밖 명시:** 에러 envelope 표준화([[devpath-error-envelope-standardization]], shared 발행 게이트)·OAuth 실 e2e(R4)는 제외. ✅
- **온보딩 제거 안전장치:** Task1 Step1에서 참조 전수 조사로 죽은 코드 확증, 외부 참조 발견 시 중단·보고. ✅
- **목-마스킹 방지:** SSE 테스트는 실 분기(useMock=false)를 dio stream mock으로 구동 — 목 소스 우회. ✅
