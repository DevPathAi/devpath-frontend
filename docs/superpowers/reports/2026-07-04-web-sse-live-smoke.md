# C1 실서버 SSE 와이어 스모크 실측 리포트

- 날짜: 2026-07-04
- 브랜치: `feat/web-sse-live-smoke`
- 설계/계획: `specs/2026-07-04-web-sse-live-smoke-design.md` · `plans/2026-07-04-web-sse-live-smoke.md`
- 하네스: `tools/sse-smoke/`(HS256 JWT 발급기 + curl 캡처)

## 실행 환경

- 인프라: postgres(`devpath-local-postgres-1`, pgvector/pg17 :5432, `devpath` DB에 중앙 flyway 스키마 적용 완료). kafka/redis/es는 미기동 — 스모크 대상 SSE 경로는 불요(sandbox=outbox 패턴, ai/learning=기동에 불필요).
- svc 기동: `SERVER_PORT`로 분리(sandbox 8085·ai 8084·learning 8082), 각 `./gradlew bootRun`. learning은 `--devpath.ai-svc.base-url=http://localhost:8084` 오버라이드(기본값 `:8081`은 오설정).
- JWT: HS256 dev 시크릿 로컬 발급(`node tools/sse-smoke/mint-jwt.js 1`), svc oauth2-resource-server가 200으로 수락 — **OAuth 없이 인증 성공 확인**.
- AI provider = `mock` 기본(mentor). path/embed는 mock 스위치 없음(아래 참조).

## 엔드포인트별 실측

### 1) sandbox `POST /sandbox/run` — ✅ 정합

실 와이어(캡처 `captures/sandbox-run.txt`):
```
event:log
data:hi from smoke

event:session
data:19
```
HTTP 200, 스트림 종료=완료.

| 축 | 실 와이어 | 프론트 계약 | 판정 |
|---|---|---|---|
| 이벤트명 | `log`, `session` | `sandbox_run_source.dart`(yield `log`/`session`), `run_controller.dart:35`(`e.event=='session'`) | ✅ |
| payload | log=문자열, session=id(`19`) | log→로그 append, session→sandboxSessionId | ✅ |
| 완료 | 스트림 종료 | `SseClient` 스트림 종료=완료 | ✅ |

### 2) mentor `POST /ai-mentor/sessions` (mock provider) — ✅ 정합

실 와이어(캡처 `captures/mentor-sessions.txt`, body `{"message":"what is recursion?","contentId":null}`):
```
event:token
data:그 질문
event:token
data:에 답하면, 
... (총 5 token) ...
```
`event:references` **없음**(contentId=null → `referenceService.find`가 빈 결과 → 백엔드가 조건부 생략). 스트림 종료=완료.

| 축 | 실 와이어 | 프론트 계약 | 판정 |
|---|---|---|---|
| 이벤트명 | `token`(×N), `references`(조건부) | `mentor_controller.dart:57`(`e.event=='references'`), else token append | ✅ |
| references 순서 | **토큰보다 먼저**, 비면 생략 | 컨트롤러는 **순서 독립**(references 도착 시점 무관하게 `state.references` 세팅) | ✅ 무해 |
| 완료 | 스트림 종료(onDone) | idle 전이 + 빈 버블 prune | ✅ |

- **목 픽스처 부정확(무해)**: `mentor_sse_source.dart`(useMock 데모)는 references를 **토큰 뒤에, 항상** 방출 — 실 백엔드(앞에, 조건부)와 순서/조건이 다르다. 컨트롤러가 순서 독립이라 프로덕션 버그는 아니나, 목이 실 와이어를 오도한다. (선택적 개선 대상, C1 수정 범위 밖.)

### 3) path `POST /learning-paths/me/generate` — ✅ 정합(프레이밍+에러), 해피패스 미실측

실 와이어(캡처 `captures/path-generate.txt`, seeded diagnosis assessment=COMPLETED/BACKEND_SPRING/MID):
```
event:progress
data:{"stage":"collecting","progress":0.15,"message":"진단 결과를 분석하고 있어요.","pathId":null}
event:progress
data:{"stage":"generating","progress":0.45,"message":"개인화 학습경로를 생성하고 있어요.","pathId":null}
event:progress
data:{"stage":"error","progress":1.0,"message":"ai-svc path generate failed","pathId":null}
```
`stage=generating`에서 ai-svc `/ai/path/generate` 호출 → **Ollama(:11434) 미기동**으로 `AiServiceUnavailableException` → 컨트롤러가 **인밴드 `progress(stage="error")`** 방출 후 complete.

| 축 | 실 와이어 | 프론트 계약 | 판정 |
|---|---|---|---|
| 이벤트명 | `progress`(×N) | `path_sse_source`/`path_controller` progress 소비 | ✅ |
| payload | `PathProgressEvent{stage,progress,message,pathId}` | 동일 모델 파싱 | ✅ |
| 단계 | collecting(0.15)→generating(0.45) | `kPathStages` 인덱스 진행 | ✅ |
| **인밴드 에러** | `progress{stage:"error",1.0,msg,pathId:null}` | `path_controller.dart:96` `if(stage=='error') → PathPhase.failed` | ✅ **정합** |
| 해피패스 `done`+pathId·`matching` | **미실측** | `stage=='done'`→`GET /learning-paths/me` 재조회 | ⚠️ 미실측 |

- **미실측 사유**: ai-svc `/ai/path/generate`·`/ai/embed`(`OllamaController`)는 **mock 스위치가 없어 Ollama 실호출**만 지원. Ollama 모델(qwen2.5:7b·nomic-embed-text, 수 GB) 기동은 와이어 검증 대비 과대 비용이라 생략. done+pathId·matching 단계 와이어는 후속(Ollama 로컬 or ai-svc path mock provider 추가 시) 실측.

## C2 인풋 (SSE 중간 에러 계약 — 표준화 대상)

실측·코드로 확정한 **3자 불일치**:
| SSE | 중간 에러 방식 | 프론트 수신 | 프론트 현 처리 |
|---|---|---|---|
| learning path | **인밴드** `event:progress`+`{stage:"error"}` 후 complete(실측 확인) | data 프레임 | `path_controller`가 `stage=='error'`→failed로 처리 ✅ |
| sandbox run | `completeWithError`(스트림 중단, 프레임 없음 — 코드) | 스트림 에러 전파 | `run_controller` onError/RunDone 매핑 |
| mentor | `completeWithError`(스트림 중단 — 코드) | 스트림 에러 전파 | `mentor_controller` onError→partial/failed |

- `completeWithError`는 200 헤더 전송 후라 **§3.4 envelope 코드를 못 실음** → sandbox/mentor 스트리밍 중 kill-switch/quota는 코드 유실(연결 끊김으로만 보임). learning만 인밴드 에러로 메시지 전달.
- **C2 제안 방향**: 3자를 일관된 `event:error`+§3.4 envelope 프레임 후 complete로 표준화하고, 프론트 `SseClient`가 `error` 이벤트를 `ApiException`으로 해석. (C2에서 크로스레포 설계.)

## 부수 발견 (백엔드, C1 범위 밖)

- **ai-svc 에러 envelope 렌더 결함**: 잘못된 JSON body로 mentor 호출 시 `HttpMessageNotReadableException`을 shared `ApiExceptionHandler#handleGeneric`이 렌더하다 실패(로그 `Failure in @ExceptionHandler ... handleGeneric`) → **400 응답 바디가 빈다**(envelope 미생성). [[devpath-error-envelope-standardization]]의 "shared 하드닝(framework 예외)" 후속과 일치. 백엔드 소관 — 별도 처리.

## 종합 판정

- **sandbox·mentor·path 3종 모두 프론트 계약과 정합** — SSE 와이어(이벤트명·payload·완료·인밴드 에러) 실측 확인. **드리프트로 인한 프론트 코드 수정 불필요.**
- 미실측: path 해피패스(done+pathId·matching) — Ollama 부재. 후속 실측 항목으로 남김.
- C2(SSE 중간 에러 계약 표준화)는 위 "C2 인풋"을 근거로 별도 조각에서 진행.
