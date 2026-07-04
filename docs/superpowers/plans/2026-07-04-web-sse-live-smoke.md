# C1 실서버 SSE 와이어 스모크 Implementation Plan (Runbook)

> **실행 모델:** 이 계획은 **메인 세션 인라인 실행**(runbook)이다. 서브에이전트 팬아웃을 쓰지 않는다(spec의 실행 모델). 각 Task는 인라인 체크포인트다. 서버 기동은 `run_in_background`, 캡처/검증은 포그라운드.

**Goal:** path·sandbox·mentor 3종 SSE의 실서버 raw 와이어를 캡처해 프론트 계약과 대조하고, 드리프트를 리포트로 확정한다(발견 시 프론트 소량 수정).

**Architecture:** 로컬 HS256 JWT(dev 시크릿)로 대상 svc를 직접 타격(게이트웨이 우회). **모든 AI provider는 `mock` 기본** — R1은 와이어(이벤트명·payload·완료/에러) 검증이지 토큰 내용이 아니므로 **Claude 키·실 API 비용 불필요**. 산출=리포트 + 재사용 하네스.

**Tech Stack:** node(JWT mint, deps 0) · curl -N(SSE 캡처) · docker compose(인프라) · gradle bootRun(svc) · psql(diagnosis 시드).

## Global Constraints

- 브랜치 `feat/web-sse-live-smoke`(base develop). develop/main 직접 커밋 금지 — PR 경유.
- **백엔드 svc 코드 변경 없음.** C1 산출물은 devpath-frontend의 `tools/sse-smoke/`·`docs/superpowers/reports/`뿐(+드리프트 발견 시 프론트 lib/test).
- JWT: HS256, secret=`test-secret-please-change-min-32-bytes-long-0123456789`, claims `{sub:"<userId>", role:"LEARNER", iat, exp}`.
- 포트: learning 8082 · ai 8084 · sandbox 8085(각 `SERVER_PORT` env로 분리; committed yml은 8080 고정).
- AI provider는 전부 `mock` 기본값 유지(REVIEW/MENTOR/COMMUNITY/RETENTION_PROVIDER 미설정=mock).
- 모든 명령은 절대경로 또는 `-C`. 레포 루트: `D:\workspace\dpa\devpath-frontend`. 백엔드 레포는 각 `D:\workspace\dpa\devpath-<svc>-svc`.
- 실 API 비용 0(mock provider). sandbox만 Docker 러너 사용.

---

### Task 1: 하네스 — node JWT 발급 스크립트 + 검증

**Files:**
- Create: `tools/sse-smoke/mint-jwt.js`
- Create: `tools/sse-smoke/README.md`
- Create: `tools/sse-smoke/.gitignore` (captures/ 무시)

- [ ] **Step 1: mint-jwt.js 작성**

`tools/sse-smoke/mint-jwt.js`:
```js
// HS256 JWT 발급기(의존 0). 사용: node mint-jwt.js <userId> [role] [ttlSec]
const crypto = require('crypto');
const SECRET = process.env.JWT_SECRET
  || 'test-secret-please-change-min-32-bytes-long-0123456789';
const userId = process.argv[2] || '1';
const role = process.argv[3] || 'LEARNER';
const ttl = parseInt(process.argv[4] || '3600', 10);
const b64u = (buf) => Buffer.from(buf).toString('base64url');
const now = Math.floor(Date.now() / 1000);
const header = b64u(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
const payload = b64u(JSON.stringify({ sub: String(userId), role, iat: now, exp: now + ttl }));
const data = `${header}.${payload}`;
const sig = crypto.createHmac('sha256', SECRET).update(data).digest('base64url');
process.stdout.write(`${data}.${sig}`);
```

- [ ] **Step 2: README.md 작성**

`tools/sse-smoke/README.md`:
```md
# SSE Live Smoke 하네스 (C1)

로컬 실서버 SSE 와이어를 캡처해 프론트 계약과 대조한다.

## JWT 발급
    node mint-jwt.js <userId> [role] [ttlSec]
HS256, secret=devpath.auth.jwt-secret dev 기본값. 각 svc는 oauth2-resource-server로 동일 시크릿 검증.

## 캡처
    TOKEN=$(node mint-jwt.js 1)
    curl -N -X POST -H "Authorization: Bearer $TOKEN" \
      -H "Accept: text/event-stream" -H "Content-Type: application/json" \
      -d '<body>' http://localhost:<port><path> | tee captures/<endpoint>.txt

captures/는 gitignore(원문은 리포트에 요약 인용).
```

- [ ] **Step 3: .gitignore 작성**

`tools/sse-smoke/.gitignore`:
```
captures/
```

- [ ] **Step 4: 발급·검증**

Run:
```bash
cd /d/workspace/dpa/devpath-frontend/tools/sse-smoke
node mint-jwt.js 1 LEARNER 3600 | tee /tmp/tok.txt
# payload 디코드 확인
node -e "const t=require('fs').readFileSync('/tmp/tok.txt','utf8');console.log(JSON.parse(Buffer.from(t.split('.')[1],'base64url')))"
```
Expected: `{ sub: '1', role: 'LEARNER', iat: <n>, exp: <n+3600> }` 출력.

- [ ] **Step 5: 커밋**

```bash
cd /d/workspace/dpa/devpath-frontend
git add tools/sse-smoke/mint-jwt.js tools/sse-smoke/README.md tools/sse-smoke/.gitignore
git commit -m "chore(smoke): SSE 라이브 스모크 하네스 — HS256 JWT 발급기 + README"
```

---

### Task 2: sandbox SSE 스모크 (가장 가벼움 — AI·시드 불필요)

**대상:** `POST /sandbox/run` (sandbox-svc :8085). 기대 와이어: `event:log`×N → `event:session`(id) → 스트림종료. 러너 불가 시 개시전 503(SANDBOX_UNAVAILABLE envelope).

- [ ] **Step 1: 인프라 + sandbox DB 설정 확인**

Run:
```bash
docker ps --format '{{.Names}} {{.Status}}' | grep -i postgres
cat /d/workspace/dpa/devpath-sandbox-svc/src/main/resources/application.yml | grep -A6 datasource
```
Expected: postgres up. datasource url/user/pw 확인(로컬 기본이 :5432 pg면 그대로, 아니면 env로 맞춤). Docker 데몬 가용(`docker info` 성공)이면 러너 available 기대.

- [ ] **Step 2: sandbox-svc 기동(백그라운드)**

Run (background):
```bash
cd /d/workspace/dpa/devpath-sandbox-svc && SERVER_PORT=8085 ./gradlew bootRun
```
기동 로그에서 `Started SandboxApplication` + `:8085` 확인(포그라운드에서 로그 tail).

- [ ] **Step 3: SSE 캡처**

Run:
```bash
cd /d/workspace/dpa/devpath-frontend/tools/sse-smoke && mkdir -p captures
TOKEN=$(node mint-jwt.js 1)
curl -N -sS -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Accept: text/event-stream" -H "Content-Type: application/json" \
  -d '{"code":"public class Main{public static void main(String[] a){System.out.println(\"hi\");}}","language":"JAVA"}' \
  http://localhost:8085/sandbox/run | tee captures/sandbox-run.txt
```
Expected: `event:log` 라인들 + `event:session` + 종료. (러너 불가면 HTTP 503 + `{"error":{"code":"SANDBOX_UNAVAILABLE",...}}` — 그것도 유효 실측.)

- [ ] **Step 4: 프론트 계약 대조(기록만, 코드변경 없음)**

대조 대상: `apps/web/lib/src/features/sandbox/data/sandbox_run_source.dart`(SSE 경로·body), `run_controller.dart`(event 소비: `log`→로그append, `session`→sandboxSessionId, sandboxUnavailable→RunUnavailable), 목 픽스처. 캡처의 event명·payload·완료가 이와 일치하는지 판정. 결과를 Task 5 리포트용 메모로 보관.

- [ ] **Step 5: sandbox-svc 정지**

Run: 백그라운드 태스크 종료(TaskStop 또는 해당 gradle 프로세스 kill).

---

### Task 3: mentor SSE 스모크 (mock provider — 키 불필요)

**대상:** `POST /ai-mentor/sessions` (ai-svc :8084, `MENTOR_PROVIDER=mock` 기본). 기대: `event:references`(JSON) → `event:token`×N → 종료. disabled면 개시전 503.

- [ ] **Step 1: ai-svc 기동(mock provider, 백그라운드)**

Run (background):
```bash
cd /d/workspace/dpa/devpath-ai-svc && SERVER_PORT=8084 ./gradlew bootRun
```
`MENTOR_PROVIDER`/`REVIEW_PROVIDER` 미설정=mock 기본. `Started` + `:8084` 확인.

- [ ] **Step 2: SSE 캡처**

Run:
```bash
cd /d/workspace/dpa/devpath-frontend/tools/sse-smoke
TOKEN=$(node mint-jwt.js 1)
curl -N -sS -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Accept: text/event-stream" -H "Content-Type: application/json" \
  -d '{"message":"재귀가 뭔가요?","contentId":null}' \
  http://localhost:8084/ai-mentor/sessions | tee captures/mentor-sessions.txt
```
Expected: `event:references` + `event:token` 반복 + 종료.

- [ ] **Step 3: 프론트 계약 대조(기록만)**

대조 대상: `apps/web/lib/src/features/mentor/data/mentor_sse_source.dart`, `mentor_controller.dart`(references/token 소비, killSwitch/partial/failed 매핑), `mentor_sse_realapi_test.dart`. event명·payload·완료 일치 판정 → 리포트 메모.

- [ ] **Step 4: ai-svc 유지**(Task 4가 재사용) 또는 정지 후 Task 4에서 재기동. 인라인 판단.

---

### Task 4: path SSE 스모크 (mock providers + seeded diagnosis)

**대상:** `POST /learning-paths/me/generate` (learning-svc :8082 → ai-svc :8084 `/ai/path/generate`·`/ai/embed`). 기대: `event:progress`×N(stage: collecting→generating→matching→**done**+pathId). 에러=progress(stage="error").

- [ ] **Step 1: ai-svc `/ai/path/generate`·`/ai/embed` 존재·mock 확인**

Run:
```bash
grep -rn "/ai/path/generate\|/ai/embed\|PathGenerate\|EmbedController\|mock" /d/workspace/dpa/devpath-ai-svc/src/main/java/ai/devpath/aigw 2>/dev/null | grep -iE 'path|embed|mock' | head
```
Expected: 두 엔드포인트 컨트롤러 + mock provider 확인. 없거나 provider가 mock 아니면 리포트에 "path 미실측(ai-svc 계약)" 기록 후 Task 5로(폴백).

- [ ] **Step 2: diagnosis 시드(psql)**

learning-svc DB에 userId=1의 COMPLETED assessment + result 삽입. Run:
```bash
# learning-svc datasource 확인 후 DB명 대입
cat /d/workspace/dpa/devpath-learning-svc/src/main/resources/application.yml | grep -A6 datasource
# 예시(DB/user는 위 확인값으로): assessments + assessment_results 스키마는 learning 마이그레이션(flyway) 참조
psql "postgresql://<user>:<pw>@localhost:5432/<learningdb>" -c "\d assessments" -c "\d assessment_results"
```
스키마 확인 후 INSERT(assessments: user_id=1,status='COMPLETED',track,completed_at=now(); assessment_results: assessment_id,diagnosed_level,strength_concepts(json),weakness_concepts(json),confidence_weight). learning-svc를 먼저 한 번 기동해 flyway가 테이블을 만들게 한 뒤 시드.

- [ ] **Step 3: learning-svc 기동(ai-svc base-url 오버라이드)**

Run (background):
```bash
cd /d/workspace/dpa/devpath-learning-svc && SERVER_PORT=8082 DEVPATH_AI_SVC_BASE_URL=http://localhost:8084 ./gradlew bootRun
```
(learning `devpath.ai-svc.base-url` 기본값 `:8081`은 오설정 — `:8084`로 오버라이드. 프로퍼티→env 매핑명은 기동 시 확인; 안되면 `--args='--devpath.ai-svc.base-url=http://localhost:8084'`.)

- [ ] **Step 4: SSE 캡처**

Run:
```bash
cd /d/workspace/dpa/devpath-frontend/tools/sse-smoke
TOKEN=$(node mint-jwt.js 1)
curl -N -sS -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Accept: text/event-stream" -H "Content-Type: application/json" \
  -d '{"goal":"백엔드 개발자"}' \
  http://localhost:8082/learning-paths/me/generate | tee captures/path-generate.txt
```
Expected: `event:progress` 여러 개, 마지막 stage=done + pathId. (ai-svc/embed 실패 시 progress(stage=error) 또는 503 — 실측 그대로 기록.)

- [ ] **Step 5: 프론트 계약 대조 + 에러신호 관찰(기록만)**

대조: `apps/web/lib/src/features/path/data/path_sse_source.dart`, `path_controller.dart`(progress→PathProgressEvent, stage=done→`GET /learning-paths/me` 재조회, stage=error 처리 여부), `path_sse_realapi_test.dart`. **C2 예고: path_controller가 인밴드 `stage=error`를 실패로 처리하는지 코드로 확인해 리포트에 기록.**

- [ ] **Step 6: 서버 정지**

learning·ai 백그라운드 태스크 종료.

---

### Task 5: 리포트 통합 + 드리프트 수정 + 커밋

**Files:**
- Create: `docs/superpowers/reports/2026-07-04-web-sse-live-smoke.md`
- (드리프트 발견 시) Modify: 해당 프론트 파일 + 테스트

- [ ] **Step 1: 리포트 작성**

`docs/superpowers/reports/2026-07-04-web-sse-live-smoke.md`에 엔드포인트별로: 실행 조합·캡처 요약(event명 시퀀스·payload 샘플·완료/에러 신호)·프론트 계약 대조표·판정(정합/드리프트/미실측+사유). 말미에 "C2 인풋" 절 — SSE 중간 에러 3자 불일치 실측 요약(learning 인밴드 stage=error vs sandbox/mentor completeWithError)과 프론트 현 처리 상태.

- [ ] **Step 2: 드리프트 분기**

정합이면 코드 변경 없음(리포트만). 드리프트 발견 시 **발견분만** TDD 수정: 실패 테스트 선작성(`melos run test`)→최소 수정→통과 확인→`dart format`. 범위 밖(예: SSE 중간 에러 계약)은 수정하지 말고 C2 인풋으로 기록.

- [ ] **Step 3: 검증**

Run(변경 있을 때만):
```bash
cd /d/workspace/dpa/devpath-frontend/packages/dp_core && dart test
cd /d/workspace/dpa/devpath-frontend/apps/web && flutter test -r compact
cd /d/workspace/dpa/devpath-frontend && dart format --output=none --set-exit-if-changed .
```
Expected: 그린 / format 0 changed.

- [ ] **Step 4: 커밋**

```bash
cd /d/workspace/dpa/devpath-frontend
git add docs/superpowers/reports/2026-07-04-web-sse-live-smoke.md
# 드리프트 수정 파일 있으면 함께 add
git commit -m "docs(report): C1 실서버 SSE 와이어 스모크 실측 — path/sandbox/mentor 대조 + C2 인풋"
```

- [ ] **Step 5: 인접 레포 스팟체크**

Run:
```bash
for r in sandbox ai learning; do echo "-- $r --"; git -C /d/workspace/dpa/devpath-$r-svc status --short; git -C /d/workspace/dpa/devpath-$r-svc branch --show-current; done
```
Expected: 백엔드 레포에 낯선 커밋·브랜치 없음(스모크는 svc 코드 무변경). 미커밋 잔여(예: 로컬 config)는 원복.

---

## Self-Review 결과

- **Spec 커버리지**: 하네스→Task1, sandbox→Task2, mentor→Task3, path→Task4, 리포트+수정→Task5. 검증 축(이벤트명·payload·완료·에러신호) 각 Task Step에 반영. C2 인풋(중간에러 실측) Task5 Step1. ✅
- **플레이스홀더**: mint-jwt.js·curl·리포트 구조 실제 코드/명령 포함. diagnosis 시드는 "스키마 확인 후 INSERT"로 스키마 의존 — 실 DB 스키마는 Task4 Step2에서 psql `\d`로 실측 후 값 대입(런북 특성상 불가피, 폴백=미실측 기록). ✅
- **단순화 반영**: mock provider로 Claude 키 불필요(spec R-C1-1/R-C1-5 완화) — 리포트에 명시. ✅
- **비범위 준수**: SSE 중간 에러 *수정*은 C2 — Task5 Step2에서 명시적으로 제외하고 C2 인풋으로만 기록. ✅
