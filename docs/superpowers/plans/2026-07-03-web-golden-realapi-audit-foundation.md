# 웹 골든패스 실API — 계약 감사 + 전환기반 구현 계획 (조각 1a)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** web 골든패스 실API 전환의 기반을 만든다 — 전 10화면의 프론트↔백엔드 계약 gap을 실측 매트릭스로 확정하고, 실API 실행 프로파일과 부분 bootRun 스모크 절차를 정비한다.

**Architecture:** 코드 변경이 아니라 **감사(문서 산출물) + 전환 프로파일(설정 파일·문서)** 중심 조각이다. 각 화면의 실서버 분기는 이미 존재하므로, 이 조각은 "무엇을 고쳐야 하는지"를 추측 없이 확정하는 단계다. 실제 픽스처·코드 정합(T1)과 회귀는 이 감사 매트릭스를 입력으로 하는 후속 조각(1b)에서 수행한다.

**Tech Stack:** Flutter 모노레포(melos 7 + Dart pub workspaces), `apps/web`, dio+MockHttpAdapter, SSE `*ConnectProvider`. 백엔드 대조 대상 = devpath-gateway·platform·learning·ai·sandbox·community·lcs-svc(전부 `origin/develop`).

## Global Constraints

- 브랜치: 이 플랜은 `docs/web-golden-realapi-spec`(스펙 PR #57과 동일 브랜치)에서 진행. 신규 작업 시 `develop` 분기, `main` 직접 금지.
- 커밋 전 `melos run format`(CI Format 게이트, `dart format --set-exit-if-changed .`). 단 이 조각은 Dart 코드 변경이 거의 없다(Task 1 example/문서 제외).
- **USE_MOCK 목 경로는 삭제하지 않는다** — 테스트·오프라인 개발용 보존(회귀 안전).
- **감사·정합은 각 레포 `origin/develop` 기준.** 로컬 체크아웃이 뒤처질 수 있다(스펙 §2.4 — gateway 로컬 behind 2로 notification 라우트 누락 사례).
- **추측 금지** — 모든 gap 주장은 프론트 data source와 백엔드 컨트롤러/DTO/이벤트 record **양쪽 소스의 `file:line` 근거**를 단다(코드가 진실).
- 산출 문서는 한국어. Conventional Commits.

---

### Task 1: 실API 실행 프로파일 + 실행 문서

목 기본값을 유지한 채 `USE_MOCK=false` 로컬 실행을 위한 프로파일 템플릿과 실행법을 추가한다.

**Files:**
- Create: `apps/web/.env.local.example`
- Modify: `.gitignore`(리포 루트 — `!.env.local.example` 예외 추가)
- Modify: `devpath-frontend/CLAUDE.md`(환경 변수 절에 실API 실행법 추가)

**Interfaces:**
- Produces: `apps/web/.env.local.example`(개발자가 `.env.local`로 복사해 `--dart-define-from-file`로 사용) — 후속 Task 3 스모크 절차가 이 파일을 참조.

- [ ] **Step 1: `.gitignore` 예외 추가**

리포 루트 `.gitignore`는 현재 `.env` / `.env.*` / `!.env.example`이다. `.env.local.example`이 `.env.*`에 걸려 무시되므로 예외를 추가한다. `!.env.example` 아래 줄에:

```
!.env.local.example
```

- [ ] **Step 2: 무시/추적 규칙 검증**

Run: `git -C D:\workspace\dpa\devpath-frontend check-ignore apps/web/.env.local apps/web/.env.local.example`
Expected: `apps/web/.env.local`은 출력됨(무시), `apps/web/.env.local.example`은 **출력 안 됨**(추적 가능). 두 경로 모두 출력되면 Step 1 예외가 안 먹은 것.

- [ ] **Step 3: `apps/web/.env.local.example` 작성**

```json
{
  "API_BASE_URL": "http://localhost:8080",
  "USE_MOCK": "false"
}
```

주: `http://localhost:8080` = devpath-gateway 로컬 진입점(스펙 §2.2). 실제 `.env.local`은 이 파일을 복사해 만들며 gitignore된다.

- [ ] **Step 4: `devpath-frontend/CLAUDE.md` 실행법 추가**

"## 환경 변수" 절에 실API 실행 예시를 추가한다(기존 목 기본값 설명은 유지):

```markdown
- 실API 로컬 실행: `apps/web/.env.local.example`을 `.env.local`로 복사(gitignore됨) 후
  `cd apps/web && flutter run -d chrome --dart-define-from-file=.env.local`.
  게이트웨이(`:8080`)와 대상 서비스가 로컬 구동돼 있어야 한다(부분 bootRun 스모크 절차: docs/superpowers/reports/2026-07-03-web-realapi-contract-audit.md).
```

- [ ] **Step 5: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add .gitignore apps/web/.env.local.example CLAUDE.md
git -C D:/workspace/dpa/devpath-frontend commit -m "chore(web): 실API 실행 프로파일(.env.local.example) + 실행법 문서"
```

---

### Task 2: 웹 골든패스 계약 gap 감사 → 매트릭스

전 10화면의 프론트 실서버 분기를 백엔드 실계약과 소스 대조해 gap 매트릭스를 산출한다. **이 조각의 핵심 산출물** — 후속 T1/T2/T3 정합의 입력.

**Files:**
- Create: `docs/superpowers/reports/2026-07-03-web-realapi-contract-audit.md`

**Interfaces:**
- Consumes: Task 1 산출 없음(독립).
- Produces: gap 매트릭스 문서 — Task 3(스모크 절차)와 후속 조각 1b(T1 정합)의 입력.

**대조 대상 (프론트 = `apps/web/lib/src/features/`, 백엔드 = 각 svc `origin/develop`):**

| # | 화면 | 프론트 data source | 백엔드 라우트→서비스 |
|---|---|---|---|
| 1 | 로그인/인증 | `auth/application/auth_controller.dart`, `auth/presentation/login_page.dart` | `/auth/**`,`/oauth2/**`,`/users/**`→platform-svc |
| 2 | 온보딩/진단 | `path/`(온보딩 트리거) | `/onboarding/assessments/**`→learning-svc |
| 3 | 학습경로(SSE) | `path/data/path_sse_source.dart` | `/learning-paths/**`→learning-svc |
| 4 | 콘텐츠 | `content/`(data source) | `/contents/**`→learning-svc |
| 5 | Sandbox(SSE) | `sandbox/data/sandbox_run_source.dart` | `/sandbox/**`→sandbox-svc |
| 6 | AI 리뷰 | `review/` 또는 sandbox 내 리뷰 | `/reviews/**`→ai-svc |
| 7 | AI 멘토(SSE) | `mentor/data/mentor_sse_source.dart` | `/ai-mentor/**`→ai-svc |
| 8 | 대시보드 | `dashboard/`(data source) | `/dashboard/**`→learning-svc |
| 9 | 커뮤니티 | `community/data/community_source.dart` | `/community/**`→community-svc |
| 10 | LCS | `community/data/lcs_source.dart` | `/lcs/**`→lcs-svc |

- [ ] **Step 1: 화면별 프론트 호출 계약 추출**

각 화면 data source에서 실서버 분기(`if (config.useMock)`의 else / `apiClient.get|post|sse`)를 읽어 {HTTP메서드, 경로, 요청 body shape, 기대 응답 파싱, 에러 처리, SSE 이벤트 소비}를 기록한다. 프론트 근거는 `file:line`으로 단다. (경로 목록 착수점은 스펙 §2.3.)

- [ ] **Step 2: 백엔드 실계약 추출 (origin/develop)**

각 서비스에서 대응 컨트롤러·요청/응답 DTO·(SSE는)이벤트 emit 계약을 읽는다. 로컬이 뒤처질 수 있으므로 `git -C <repo> show origin/develop:<path>` 또는 origin 기준으로 확인한다. 백엔드 근거도 `file:line`.

- [ ] **Step 3: gap 매트릭스 작성**

`docs/superpowers/reports/2026-07-03-web-realapi-contract-audit.md`에 아래 구조로 기록한다:

```markdown
# 웹 골든패스 실API 계약 감사 (2026-07-03)

## 요약 (티어 재확정)
- T1(정합만): ... / T2(응답 DTO 대조): ... / T3(SSE 와이어 합의 필요): ...

## 화면별 gap 매트릭스
### 1. 로그인/인증
| 항목 | 프론트(file:line) | 백엔드(file:line) | 일치? | gap/조치 |
|---|---|---|---|---|
| 경로 | ... | ... | ✅/⚠️/❌ | ... |
| 요청 shape | ... | ... | | |
| 응답 DTO | ... | ... | | |
| 에러/상태코드 | ... | ... | | |
| 인증 헤더 | ... | ... | | |
| SSE 이벤트 | (해당 없음/…) | | | |
(…화면 2~10 동일 구조…)

## 서비스 의존 그래프 (스모크 조합용)
- 화면 → 필요한 최소 서비스 집합 (예: 커뮤니티 = gateway + community-svc + platform-svc[JWT])

## 미결정/리스크
- auth OAuth 리다이렉트 로컬 검증 복잡도(스펙 §7.3) 판정
- SSE 와이어(온보딩/path·sandbox·mentor) 백엔드 계약 확정 여부
```

- [ ] **Step 4: 완료 검증 (자체 체크리스트)**

- 10화면 전부 매트릭스에 존재하는가?
- 각 ⚠️/❌ gap에 프론트·백엔드 양쪽 `file:line` 근거가 있는가(추측 표기 없음)?
- 온보딩 경로(`/onboarding` vs `/onboarding/assessments/**`)·SSE 와이어·auth OAuth 3개 gap 후보에 결론이 있는가?
- 서비스 의존 그래프가 T1 3화면(auth·community·lcs)을 포함하는가?

- [ ] **Step 5: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add docs/superpowers/reports/2026-07-03-web-realapi-contract-audit.md
git -C D:/workspace/dpa/devpath-frontend commit -m "docs(audit): 웹 골든패스 실API 계약 gap 매트릭스 (10화면)"
```

---

### Task 3: 부분 bootRun 스모크 절차

전-스택 상시 구동 없이 화면별로 필요한 서비스만 띄워 실 게이트웨이 경유로 검증하는 절차를 문서화한다. Task 2의 서비스 의존 그래프를 사용한다.

**Files:**
- Modify: `docs/superpowers/reports/2026-07-03-web-realapi-contract-audit.md`(감사 문서에 "## 부분 bootRun 스모크 절차" 절 추가)

**Interfaces:**
- Consumes: Task 2 서비스 의존 그래프.

- [ ] **Step 1: 인프라·서비스 기동 순서 기록**

```markdown
## 부분 bootRun 스모크 절차
### 공통 인프라
docker compose -f devpath-shared/docker-compose.yml up -d   # postgres·pgvector·redis·es·kafka
### 서비스 (필요한 것만)
gateway :8080 / platform :8081 / learning :8082 / ai :8084 / sandbox :8085 / community :8086 / lcs :8087 / notification :8088
각: cd <repo> && ./gradlew bootRun
### web (실API 프로파일)
cd apps/web && flutter run -d chrome --dart-define-from-file=.env.local
```

- [ ] **Step 2: T1 화면별 최소 스모크 조합 명시**

Task 2 의존 그래프에서 T1 3화면의 스모크 조합을 표로(예: `커뮤니티 = 인프라 + gateway + platform[JWT] + community-svc`). 각 조합에 "확인할 동작"(로그인→목록 로드→상세) 1줄.

- [ ] **Step 3: 검증 — 조합 실행 가능성 sanity check**

각 T1 조합의 서비스가 실제 존재하고 포트가 §매트릭스와 일치하는지 확인(추측 금지 — 포트는 스펙 §2.2/§2.4 기준). 실제 기동 실행은 실행 조각(1b) 스모크에서.

- [ ] **Step 4: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add docs/superpowers/reports/2026-07-03-web-realapi-contract-audit.md
git -C D:/workspace/dpa/devpath-frontend commit -m "docs(audit): 부분 bootRun 스모크 절차 + T1 스모크 조합"
```

---

## 다음 조각 (1b — 이 플랜 범위 밖)

Task 2 감사 매트릭스를 입력으로 **T1(auth·커뮤니티·LCS) 계약 정합** 플랜을 작성한다: 실측된 픽스처 shape·경로·에러코드 불일치를 TDD로 수정 + 화면별 `integration_test` 골격 + T1 부분 bootRun 스모크 실행. 감사에서 auth OAuth 로컬 검증 복잡도가 과하면 T1에서 auth는 토큰 경로(`/auth/refresh`)까지로 한정하고 OAuth 실 리다이렉트는 조각 경계 재조정. 이어서 조각 2(T2), 조각 3(T3 SSE 와이어).

## Self-Review (작성자 체크)

- **스펙 커버리지**: 스펙 §7.1(감사)=Task 2, §7.2(전환기반)=Task 1+Task 3, §7.3(T1 정합)=명시적으로 다음 조각으로 분리(추측 회피). §5 검증(melos)은 코드 변경 조각(1b)에서 실질 적용 — 이 조각은 문서/설정이라 회귀 대상 최소.
- **Placeholder 스캔**: 감사 매트릭스는 "템플릿 구조 + 대조 대상 파일 목록"을 실제 제시(빈 TBD 아님). 각 gap의 실제 값은 Task 2 실행 시 소스에서 채운다 — 이는 조사 산출물의 정상 형태.
- **일관성**: 포트(8080~8088)·경로가 스펙 §2.2/§2.4와 일치. `.env.local.example` 파일명이 Task 1·3에서 동일.
