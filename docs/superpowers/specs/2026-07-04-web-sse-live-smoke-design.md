# C1 설계: 실서버 SSE 와이어 스모크 실측

- 날짜: 2026-07-04
- 브랜치: `feat/web-sse-live-smoke` (base `develop`)
- 로드맵: Tier-2 이후 A→C→B 중 **C의 첫 조각 C1**([[devpath-web-posttier2-roadmap]]). C2(SSE 중간 에러 계약 표준화)는 후속.

## 배경 / 목표

Tier-2의 SSE 3종(path·sandbox·mentor) 회귀 테스트는 전부 **목 레벨**(dio stream mock)이라 실 계약 회귀를 못 잡는다(감사 교훈, `reports/2026-07-03-web-realapi-contract-audit.md` R1). C1은 실서버를 띄워 SSE 엔드포인트의 **raw 와이어**(이벤트명·순서·payload 스키마·완료/에러 신호)를 캡처하고, 프론트 계약(`SseClient` 파싱·feature 컨트롤러 이벤트 소비·목 픽스처)과 대조해 드리프트를 리포트로 확정한다. 드리프트 발견 시 프론트를 소량 수정한다(발견분만).

**비목표**: SSE 중간 에러 계약의 표준화·수정(→ C2). 게이트웨이 라우팅 재검증(이미 검증됨). 백엔드 svc 코드 변경(C1은 프론트/리포트/하네스만).

## 핵심 사실(실측)

- **JWT = HS256 대칭 서명**(`platform JwtService`, `MacAlgorithm.HS256`), secret=`devpath.auth.jwt-secret` 기본값 `test-secret-please-change-min-32-bytes-long-0123456789`. 각 svc는 oauth2-resource-server로 같은 시크릿 검증 → **OAuth 없이 로컬 JWT 직접 발급 가능**(claims: `sub=<userId>`, `role`, `iat`, `exp`).
- **learning path 생성은 ai-svc를 경유**(`LearningPathGenerationService`가 `AiPathClient.generate`+`embed`) → path 스모크는 learning+ai-svc+pgvector+Claude 키+seeded diagnosis 필요.
- 커밋된 각 svc `application.yml`은 `server.port: 8080` → 로컬 분리 기동은 `SERVER_PORT` 환경변수 오버라이드(gateway 라우팅 기준 platform 8081·learning 8082·ai 8084·sandbox 8085).
- 백엔드 SSE 에러 방식 3자 불일치(실측): learning=인밴드 `event:progress`+`PathProgressEvent("error",1.0,msg,null)` 후 complete; sandbox=`completeWithError`(스트림 중단); mentor=`completeWithError`(스트림 중단). ⇒ C2 대상.

## 하네스 (재사용 가능, 커밋)

1. **JWT mint 스크립트** — `devpath-frontend/tools/sse-smoke/mint-jwt.*`: userId·role·secret·ttl 입력 → HS256 access token 출력. (구현 언어는 플랜에서 확정: python `PyJWT`/`hashlib`+`hmac` 또는 openssl. 순수 표준 라이브러리 우선.)
2. **캡처 절차** — `curl -N -X POST -H "Authorization: Bearer <jwt>" -H "Accept: text/event-stream" -H "Content-Type: application/json" -d '<body>' http://localhost:<port><path>` → raw 프레임을 `tools/sse-smoke/captures/<endpoint>.txt`로 저장.
3. **서비스 기동** — 인프라 `docker compose -f devpath-shared/docker-compose.yml up -d`(postgres/pgvector 이미 up). 각 svc `SERVER_PORT=<port> ./gradlew bootRun`(대상 엔드포인트별 최소 조합만).

## 엔드포인트별 최소 스택 & 캡처 대상

| SSE | 최소 서비스 | 외부 의존 | 요청 body | 기대 와이어 |
|---|---|---|---|---|
| sandbox `POST /sandbox/run` | sandbox + postgres + Docker 러너 | 없음 | `{"code":"...","language":"JAVA\|NODE\|PYTHON"}` | `event:log`×N → `event:session`(id) → 스트림종료. 러너 불가=개시전 503(SANDBOX_UNAVAILABLE envelope) |
| path `POST /learning-paths/me/generate` | learning + ai-svc + pgvector | Claude 키·seeded diagnosis | `{"goal":"..."}`(옵션) | `event:progress`×N(stage: collecting→generating→matching→**done**+pathId). 에러=progress(stage="error") |
| mentor `POST /ai-mentor/sessions` | ai-svc | Claude 키 | `{"message":"...","contentId":null}` | `event:references`(JSON) → `event:token`×N → 스트림종료. disabled/kill-switch=개시전 503(envelope) |

## 검증 축 (캡처 ↔ 프론트 계약)

각 엔드포인트에 대해 대조:
1. **이벤트명**: 캡처 `event:` ↔ 프론트 소비(`SseEvent.event` 스위치). path=`progress`, sandbox=`log`/`session`, mentor=`references`/`token`.
2. **payload 스키마**: `data:` JSON/문자열 ↔ 프론트 파싱 모델. path=`PathProgressEvent{stage,progress,message,pathId}`, sandbox log=문자열·session=id문자열, mentor references=JSON·token=문자열.
3. **완료 신호**: 프론트 `SseClient`는 스트림 종료를 완료로 본다 — 서버가 별도 DONE 마커를 보내는지, 안 보내는지(스트림 종료만) 확정.
4. **에러 신호**(C2 예고 관찰): learning 인밴드 `progress(stage="error")`를 `path_controller`가 실패로 처리하는지 코드로 확인·기록. sandbox/mentor `completeWithError`가 프론트 `SseClient`의 `await for`에서 어떻게 표면화되는지(스트림 에러 전파) 관찰.

## 산출물

1. **리포트** `docs/superpowers/reports/2026-07-04-web-sse-live-smoke.md`: 엔드포인트별 캡처 원문 요약 + 대조표 + 판정(정합/드리프트/미실측 사유).
2. **하네스** `tools/sse-smoke/`(mint 스크립트 + 캡처된 raw + README).
3. **드리프트 수정**(발견 시에만, TDD): 프론트 `SseClient`/컨트롤러/모델/목 픽스처 정합. 없으면 리포트만.

## 실행 모델

C1은 코드 구현이 아니라 **인터랙티브 통합 스모크**(서버 기동·curl·raw 관찰)다. 서브에이전트 팬아웃이 아니라 **메인 세션 인라인 실행**으로 진행한다([[devpath-windows-subagent-flakiness]] 회피). 따라서 이 spec의 플랜은 runbook 형태이며, 실행은 인라인(executing-plans 스타일 체크포인트)으로 한다.

## 리스크 / 폴백

- **R-C1-1 Claude 키**: 로컬 ai-svc에 Anthropic 키 없으면 path·mentor 해피패스 불가 → 해당 엔드포인트는 개시전 503/에러경로만 캡처하고 리포트에 "미실측(키 부재)" 명시. ai-svc의 실제 API 키 설정 프로퍼티명은 플랜 첫 스텝에서 실측(`claude-model`만 확인됨).
- **R-C1-2 seeded diagnosis**: path 생성은 `LatestDiagnosisRepository`의 진단 이력 필요 → 없으면 빈/에러. 플랜에서 진단 시드(SQL 또는 `/onboarding/assessments` 완주) 선행.
- **R-C1-3 sandbox Docker 러너**: 러너 이미지/권한 필요 → 불가 시 개시전 503(SANDBOX_UNAVAILABLE) 경로를 대신 캡처(그것도 유효한 와이어 실측).
- **R-C1-4 포트/프로파일**: svc yml이 8080 고정 → `SERVER_PORT` env로 분리. 충돌 시 로그로 확인.
- **R-C1-5 실 API 비용**: path·mentor는 실제 Claude 호출(토큰 비용) 발생 — 최소 횟수(엔드포인트당 1~2회)로 제한.
