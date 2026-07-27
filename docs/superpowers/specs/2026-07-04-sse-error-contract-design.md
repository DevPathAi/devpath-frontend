# C2 설계: SSE 중간 에러 계약 표준화 (크로스레포)

- 날짜: 2026-07-04
- 로드맵: Tier-2 이후 A→C→B 중 **C의 둘째 조각 C2**([[devpath-web-posttier2-roadmap]]). C1(실서버 스모크)에서 실측·확정한 3자 불일치를 표준화.
- 영향 레포: `devpath-shared`(헬퍼) · `devpath-learning-svc` · `devpath-ai-svc` · `devpath-sandbox-svc`(채택) · `devpath-frontend`(SseClient + 컨트롤러).
- 프론트 브랜치: `feat/web-sse-error-contract`(base develop). 백엔드는 각 레포 별도 브랜치.

## 배경 (C1 실측)

SSE 스트림 개통(HTTP 200) 후 발생하는 에러 처리가 3자 불일치:
- **learning** `/learning-paths/me/generate`: 인밴드 `event:progress` + `PathProgressEvent{stage:"error"}` 후 complete(실측).
- **sandbox** `/sandbox/run`: `emitter.completeWithError(e)` — 스트림 중단(프레임 없음).
- **mentor** `/ai-mentor/sessions`: `emitter.completeWithError(e)` ×2 — 스트림 중단.

`completeWithError`는 200 헤더 전송 후라 **§3.4 envelope 코드를 실을 수 없다** → sandbox/mentor 스트리밍 중 실패는 프론트에 "연결 끊김"으로만 보이고 코드/메시지가 유실된다. learning만 인밴드로 메시지를 전달하나 형식이 path 전용(PathProgressEvent)이라 통일되지 않는다.

## 목표 / 비목표

**목표**: 3종 SSE의 중간 에러를 **단일 계약**(`event:error` + §3.4 envelope)으로 통일하고, 프론트 `SseClient`가 이를 `ApiException`으로 해석해 각 컨트롤러가 코드별(kill-switch/quota/일반)로 표면화하게 한다.

**비목표**: HTTP(비-SSE) 에러 envelope(축 A에서 완료). 개시 **전** 비-200 경로(mentor disabled 503, sandbox runner 503 — 변경 없음, 이미 envelope). ai-svc `HttpMessageNotReadableException` 렌더 결함(C1 부수 발견, 별도 백엔드 이슈).

## 표준 계약 (canonical)

스트림 개통 후 실패 시:
```
event:error
data:{"error":{"code":"<ErrorCode>","message":"<msg>","trace_id":null,"timestamp":"<ISO>"}}
```
그 뒤 `emitter.complete()`(정상 종료 — HTTP 스트림을 깨지 않는다). `event:error` payload는 §3.4 `ErrorResponse`와 동일 형태(HTTP 에러 envelope와 일치).

## 컴포넌트

### shared — `SseSupport` 헬퍼 (신규)
`ai.devpath.shared.error` 패키지에 정적 헬퍼 추가:
```java
public static void sendError(SseEmitter emitter, ErrorCode code, String message) {
  // ErrorResponse.of(code, message, null, Instant.now().toString())를
  // SseEmitter.event().name("error").data(envelope)로 방출.
  // 호출자는 이어서 emitter.complete()를 호출한다.
}
```
`ErrorResponse`(기존) 재사용 → Spring이 `trace_id`(snake) 포함 JSON 직렬화. 3 svc가 공유해 DRY.

### 백엔드 채택 (3 svc)
- **learning** `LearningPathController.generate` catch: 인밴드 `send(emitter, PathProgressEvent.error(...))` 제거 → `SseSupport.sendError(emitter, ErrorCode.INTERNAL_ERROR, e.getMessage())` + `complete()`. (도메인 예외가 특정 코드를 가지면 그 코드 사용.)
- **sandbox** `RunController.run` catch: `completeWithError(e)` → `SseSupport.sendError(emitter, <code>, msg)` + `complete()`. 개시전 `SandboxUnavailableException`(503)은 유지.
- **mentor** `MentorService.streamAnswer` catch 2곳(`MentorStreamAbortedException`, generic): `completeWithError` → `SseSupport.sendError` + `complete()`. 부분답변 토큰은 이미 방출됨(보존).

### 프론트 (dp_core + 컨트롤러)
- **`SseClient`**: `await for` 루프에서 방출 직전, event명이 `error`면 `data`(envelope JSON)를 파싱해 `ApiException`을 **throw**(스트림 종료·소비자 onError로 전파). 이미 yield된 데이터 이벤트는 보존.
  - 파싱: `body['error']['code']`→`ApiErrorCode.fromWire`, `message`, `trace_id`. (HTTP `ApiException.fromDio`와 동일 매핑 — 공용 파서로 추출 가능.)
- **컨트롤러 onError 미세조정**:
  - **path_controller**: 현재 `isKillSwitch→killSwitch / isQuota→failed / else→partial`. 추가: `else if (err is ApiException) → PathPhase.failed(err.message)`(중간 event:error=서버 확정 실패). 비-ApiException(네트워크 끊김)만 partial 유지.
  - **sandbox/mentor**: 기존 onError가 이미 ApiException 코드(isKillSwitch 등)를 매핑 → event:error가 ApiException으로 도달하면 자동 개선. 일반 코드가 적절히 failed로 가는지 확인.

## 롤아웃 순서 (무중단)

1. **프론트 선행(하위호환)**: `SseClient`에 `event:error`→ApiException 처리 추가. **path_controller의 기존 `stage=="error"` 분기는 유지**(백엔드 미이관 구간에도 path 에러가 계속 표면화되도록). 이 단계만으로 sandbox/mentor는 백엔드 이관 후 즉시 개선되고, 기존 동작은 안 깨진다.
2. **백엔드 3 svc 채택**: shared 헬퍼 발행 → 3 svc가 `event:error` 방출(learning은 progress(stage=error) 중단). 각 레포 별도 PR.
3. **프론트 정리**: path 백엔드 이관 확인 후 `path_controller`의 `stage=="error"` 분기 제거(이제 event:error로 대체됨). onError=failed 조정은 1단계에 이미 포함.

## 테스트

- **shared**: `SseSupport.sendError`가 `event:error` + 올바른 envelope(code/message/trace_id) 프레임을 방출하는 단위 테스트(MockSseEmitter 또는 send 캡처).
- **백엔드**: 각 svc SSE IT에 "중간 실패 → `event:error` 프레임 수신 + 스트림 정상 종료" 케이스(learning=ai 실패 주입, sandbox=runner 실패 주입, mentor=LLM 실패 주입). 기존 완료 케이스 회귀 유지.
- **프론트**: `SseClient`가 `event:error` 프레임에서 `ApiException(code)`를 throw하고 선행 데이터는 보존(실패 테스트 선작성). path/sandbox/mentor 컨트롤러 onError가 ApiException을 각 상태(failed/killSwitch/quota)로 매핑. `melos run test`·`analyze`·format 그린.

## 리스크

- **R-C2-1 롤아웃 순서 위반**: 프론트 정리(3단계)를 백엔드 이관(2단계) 전에 하면 path 에러가 무음화. → 3단계는 반드시 2단계(path 백엔드) 머지 확인 후.
- **R-C2-2 event:error 오탐**: 정상 스트림이 `error`라는 event명을 정당하게 쓰지 않음을 확인(3종 다 log/session/token/progress/references만 사용 — C1 실측). 예약어로 안전.
- **R-C2-3 부분데이터 경쟁**: SseClient가 throw할 때 직전까지 yield된 이벤트는 소비자에 이미 전달됨(Stream 순서 보장) → 부분답변 보존 정상.
- **R-C2-4 도메인 코드 매핑**: 각 svc의 중간 실패에 어떤 ErrorCode를 부여할지(예: learning ai 실패=INTERNAL_ERROR vs 신규 코드). 기본 INTERNAL_ERROR, 명확한 도메인 예외는 해당 코드. 플랜에서 svc별 확정.
