# 웹 골든패스 실API 정합 설계 (MD3 Tier-2)

> 작성 2026-07-03 · 대상 레포 `devpath-frontend`(`apps/web`) · 접근 = **계약정합 우선 → 부분 e2e**
> 상위 로드맵: `documents/17_스케줄` MD3 Tier-2 §#7 멘토·#8 커뮤니티·#9 LCS 프론트 실API 전환.

## 1. 배경·목적

`apps/web`은 **의도적으로 "목(mock) 프로토타입"으로 완성**됐다(P1~P5, HANDOFF.md). 전 화면이 `AppConfig.useMock` 분기를 갖고, 기본값이 목(`true`)이라 백엔드 없이 골든패스가 돈다. 이후 백엔드가 slice7/8/9 + 참여촉진배치로 대부분 구현됐고, 프론트에서도 `web-auth-realapi`(#15)·`slice8-frontend-community`(#35)·`slice9-frontend-lcs`(#37)가 실API로 개별 머지됐다.

**목적**: web 골든패스 10개 화면을 `USE_MOCK=false` 실API로 전환한다. 단, "플래그 한 줄"이 아니라 각 화면의 실서버 분기를 **실제 백엔드 계약(게이트웨이 라우트·응답 DTO·SSE 와이어)과 정합**시키는 작업이다.

**비목표(이번 스펙)**: 모바일(#10)·랜딩(#11) 전환, 실 FCM/SMTP 발송(gitops 후속), 신규 화면·기능 추가.

## 2. 현황 스냅샷 (2026-07-03 소스 실측)

### 2.1 전환 메커니즘
- `AppConfig.fromEnvironment()`: `USE_MOCK` 기본 `true`, `API_BASE_URL` 기본 `https://mock.devpath.ai`. `--dart-define`(또는 `--dart-define-from-file`)로 주입.
- `useMock=true` → `apiClientProvider`가 `MockHttpAdapter`(픽스처)를 dio에 주입해 **모든 HTTP를 가로챔**. `false` → 어댑터 미주입, 실 게이트웨이로 호출.
- SSE는 HTTP 어댑터와 별개로 feature별 `*ConnectProvider`가 `config.useMock` 분기(목=`MockSseSource`/inline, 실서버=`apiClient.sse(path)`).

### 2.2 게이트웨이 라우트 (`devpath-gateway` `application.yml`, 진입점 `:8080`)
| route | uri(로컬) | Path 프리픽스 |
|---|---|---|
| platform-auth | :8081 | `/oauth2/**`, `/login/**`, `/auth/**`, `/users/**` |
| learning | :8082 | `/onboarding/assessments/**`, `/learning-paths/**`, `/dashboard/**`, `/contents/**` |
| sandbox | :8085 | `/sandbox/**` |
| ai-review | :8084 | `/reviews/**`, `/ai-mentor/**` |
| community | :8086 | `/community/**` |
| notification | :8088 | `/notifications/**` |
| lcs | :8087 | `/lcs/**` |

### 2.3 web 화면 실서버 호출 경로 vs 라우트 대조
- ✅ 일치: auth(`/auth/refresh`, `login()`=OAuth) · community(`/community/posts|questions|answers|tags|...`) · lcs(`/lcs/snapshots/*`) · mentor(`/ai-mentor/sessions` SSE) · review(`POST /reviews`) · dashboard(`GET /dashboard`) · content(`GET /contents/:id`)
- ⚠️ gap 후보:
  1. **온보딩**: P4b는 `POST /onboarding` 전제였으나 게이트웨이는 `/onboarding/assessments/**`만 라우팅(단독 `/onboarding` 미매칭). path SSE 실서버 경로도 확정 필요(`/learning-paths/**`).
  2. **SSE 와이어**: 멘토·path·sandbox의 토큰 event명·`DONE` 마커·payload가 백엔드와 미합의 이력(HANDOFF P4e/P4c).
  3. **auth OAuth 리다이렉트**: 목은 `bootstrapFromCallback()` 즉시 인증, 실서버는 `login()` OAuth 리다이렉트 — 로컬 콜백 검증 복잡도 미확정.

### 2.4 로컬 검증 인프라
- `devpath-shared/docker-compose.yml`은 **인프라만**(postgres·pgvector·redis·elasticsearch·kafka). 서비스는 각각 `./gradlew bootRun`(gateway :8080 / platform :8081 / learning :8082 / ai :8084 / sandbox :8085 / community :8086 / lcs :8087 / notification :8088). 전-스택 상시 구동은 무겁다.
- **주의(handoffs-lag)**: 로컬 서비스 레포 체크아웃이 `origin/develop`보다 뒤처질 수 있다. 이 스펙 작성 중 로컬 `devpath-gateway`가 origin보다 behind 2로 `notification` 라우트(§2.2)가 누락돼 있었다 — 감사·정합은 반드시 `origin/develop` 기준으로 본다.
- `devpath-gitops`는 k8s(kustomize) 배포용 — 로컬 e2e 부적합.

## 3. 전환 아키텍처 (기존 구조 유지)

- `AppConfig.useMock` 런타임 토글을 **삭제하지 않는다.** 목 경로는 테스트·오프라인 개발용으로 보존(회귀 안전). 전환은 **기본 실행 프로파일**로 제어한다: `apps/web/.env.local`(gitignore) = `{ "API_BASE_URL": "http://localhost:8080", "USE_MOCK": "false" }` + `flutter run -d chrome --dart-define-from-file=.env.local`.
- 각 화면 실서버 분기는 **이미 존재**한다. 따라서 일은 "분기 신규 작성"이 아니라 **계약 정합·검증**이다.

## 4. 화면 3티어 분해 (gap 크기 = 실행 순서)

- **T1 성숙**(경로 일치·실API PR 머지됨): `auth` · `community` · `lcs` → 계약 정합 확정 + 목 픽스처를 실계약 shape에 맞춤.
- **T2 HTTP**(경로 일치·목만 검증): `content` · `dashboard` · `review` → 응답 DTO를 백엔드 실제 반환과 대조·정합.
- **T3 SSE 와이어**(백엔드 미합의 이력): `온보딩/path` · `sandbox` 실행 · `mentor` → 백엔드 SSE 이벤트명·`DONE` 마커·payload 계약 확정 후 결선. 가장 무겁다.

## 5. 검증 전략

- **회귀**: `melos run analyze` + `melos run test`(목 경로 보존 확인 — 전환이 기존 목 테스트를 깨지 않아야 함). 커밋 전 `melos run format`(CI 게이트).
- **실동작(부분 e2e)**: 화면이 닿는 **서비스만 부분 bootRun** + docker-compose 인프라 → 실 게이트웨이(`:8080`) 경유 스모크. 전-스택 상시 구동 회피.
- **골든패스 회귀 골격**: Flutter `integration_test` 스캐폴드(T1 경로부터). 실서버 프로파일과 목 프로파일 양쪽에서 재사용.

## 6. 조각 경계 (각 조각 = 별도 spec→plan→구현)

- **이번 스펙(조각 1)**: (a) 전 10화면 **계약 gap 감사** → gap 매트릭스 (b) **전환 기반** 정비 (c) **T1 3화면 정합** + integration_test 골격.
- **후속 조각 2**: T2(content·dashboard·review) 정합.
- **후속 조각 3**: T3(온보딩·sandbox·mentor SSE) 와이어 계약 확정·결선 — 백엔드(ai-svc·learning-svc·sandbox-svc)와의 SSE 계약 합의가 선행.

감사(조각 1의 첫 작업)에서 나온 실측이 T1 수정 범위와 조각 2·3 경계를 정한다.

## 7. 이번 조각(조각 1) 상세

### 7.1 계약 gap 감사 → 산출물
전 10화면을 아래 항목으로 소스 대조하고 gap 매트릭스(화면 × {경로·요청 shape·응답 DTO·에러/상태코드·인증 헤더·SSE 이벤트})를 작성한다. **추측 금지 — 프론트 data source와 백엔드 컨트롤러/DTO/이벤트 record를 양쪽 소스로 대조**한다(코드가 진실). **각 레포는 반드시 `origin/develop` 기준**으로 본다(로컬 체크아웃이 뒤처질 수 있음 — §2.4 주의).
- 산출: `docs/superpowers/reports/2026-07-03-web-realapi-contract-audit.md`(gap 매트릭스 + 화면별 난이도·서비스 의존 그래프).

### 7.2 전환 기반
- `apps/web/.env.local.example` 커밋(실제 `.env.local`은 gitignore) + README/CLAUDE.md에 실API 실행법 명시.
- 부분 bootRun 스모크 절차 문서화(화면→필요 서비스 매핑, 예: community 스모크 = 인프라 + platform(토큰) + gateway + community-svc).

### 7.3 T1 3화면 계약 정합
- 감사에서 나온 T1 불일치(픽스처 shape·경로·에러코드)를 수정한다. 실서버 분기 자체는 존재하므로 **최소 수정**.
- 화면별 `integration_test` 골격 추가(목 프로파일에서 먼저 green, 실서버 프로파일은 부분 bootRun 스모크).
- **auth OAuth 리다이렉트 실 콜백** 검증 복잡도는 감사(7.1)에서 판정 — 로컬 GitHub OAuth 앱·콜백 URL 설정이 과하면 이번 조각은 **토큰 기반 경로(`/auth/refresh`)·계약 대조까지**로 한정하고 OAuth 실 리다이렉트 e2e는 조각 경계 재조정(사용자 확인).

## 8. 리스크·미결정

- **R1 SSE 와이어 미합의(T3)**: 백엔드 SSE 이벤트 계약이 코드로 확정돼 있는지 감사에서 확인. 미확정 시 조각 3은 백엔드 합의(ai/learning/sandbox-svc) 선행 — 프론트 단독 완결 불가.
- **R2 픽스처 shape 드리프트**: 목 픽스처가 상정한 응답과 실 DTO 불일치 가능(특히 T2). 감사로 화면별 확정.
- **R3 부분 bootRun 서비스 의존**: 인증 토큰(platform)·이벤트 전파(kafka) 등으로 "한 화면=한 서비스"가 안 될 수 있음. 감사의 의존 그래프로 스모크 조합 확정.
- **R4 auth OAuth 로컬 검증**: 8080 게이트웨이 경유 OAuth 리다이렉트·콜백의 로컬 재현 비용. 7.3대로 감사 후 배치 결정.
- **R5 목 경로 회귀**: 전환이 기존 목 테스트를 깨면 안 됨 — `melos run test`로 양 프로파일 보존 확인.

## 9. 참조
- HANDOFF: `devpath-frontend/HANDOFF.md`(P1~P7 프로토 구현 이력) · README/CLAUDE.md
- 게이트웨이: `devpath-gateway/src/main/resources/application.yml`
- 인프라: `devpath-shared/docker-compose.yml`
- 상위 스케줄: `documents/17_스케줄.md` MD3 Tier-2 · 정합성 스냅샷 `documents/42_전체_정합성_점검_2차.md`
