# C2 SSE 중간 에러 계약 표준화 Implementation Plan (크로스레포)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox (`- [ ]`).
> **크로스레포 주의:** 5개 레포. 모든 git/파일 명령에 절대경로 또는 `-C <레포루트>`. `cd` 후 상대경로 금지(에이전트 cwd 리셋). 서브에이전트 위임 시 "이 Task만, 끝나면 정지, 명세 밖 즉흥 금지" 경계 명시.

**Goal:** 3종 SSE의 스트림 중간 에러를 `event:error` + §3.4 envelope 단일 계약으로 통일하고, 프론트 `SseClient`가 이를 `ApiException`으로 해석하게 한다.

**Architecture:** shared에 `SseSupport.sendError` 헬퍼 추가 → 3 백엔드 svc가 `completeWithError`/인밴드 대신 이를 호출 → 프론트 `SseClient`가 `event:error`를 `ApiException`으로 throw. 무중단 3단계 롤아웃(프론트 하위호환 선행 → 백엔드 → 프론트 정리).

**Tech Stack:** Spring Boot(webmvc SseEmitter) · Flutter/Dart(dio SSE) · Gradle · melos.

## Global Constraints

- 계약: 중간 실패 시 `event:error` + `{"error":{"code","message","trace_id","timestamp"}}`(§3.4 `ErrorResponse` 형태) 방출 후 `emitter.complete()`(completeWithError 아님).
- `code`는 `ai.devpath.shared.error.ErrorCode` enum 값. 기본 `INTERNAL_ERROR`.
- 백엔드 svc는 shared를 GitHub Packages `ai.devpath:devpath-shared:0.0.1-SNAPSHOT`로 소비 → **shared 변경은 머지·발행 후에야 svc가 당길 수 있음**(Task 3 머지 → 스냅샷 발행 → Task 4~6은 `--refresh-dependencies`).
- 브랜치: 각 레포 develop에서 분기, develop으로 PR. main 직접 금지.
- 프론트 검증: `melos run test`·`melos run analyze`·`dart format --set-exit-if-changed .` 그린. 백엔드: 각 `./gradlew build` 그린.
- 레포 루트: frontend `D:\workspace\dpa\devpath-frontend`, shared `...\devpath-shared`, learning/ai/sandbox `...\devpath-<svc>-svc`.

---

## Phase 1 — 프론트 선행 (하위호환, 브랜치 `feat/web-sse-error-contract`)

### Task 1: SseClient가 `event:error`를 ApiException으로 해석

**Files:**
- Modify: `packages/dp_core/lib/src/error/api_exception.dart`(envelope 파서 추출)
- Modify: `packages/dp_core/lib/src/sse/sse_client.dart`(event:error 처리)
- Test: `packages/dp_core/test/sse/sse_client_error_test.dart`(신규)

**Interfaces:**
- Produces: `factory ApiException.fromEnvelope(Map<String,dynamic> body, {int? status, int? retryAfterSeconds})` — `body['error']`(중첩)에서 code/message/trace_id 매핑. `SseClient.connect`가 `event:error` 프레임에서 이걸 throw.

- [ ] **Step 1: 실패 테스트 작성**

`packages/dp_core/test/sse/sse_client_error_test.dart`:
```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:dp_core/src/error/api_error_code.dart';
import 'package:dp_core/src/error/api_exception.dart';
import 'package:dp_core/src/sse/sse_client.dart';
import 'package:test/test.dart';

class _StreamAdapter implements HttpClientAdapter {
  _StreamAdapter(this.body);
  final String body;
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? rs, Future<void>? cf) async {
    final stream = Stream<Uint8List>.fromIterable([Uint8List.fromList(utf8.encode(body))]);
    return ResponseBody(stream, 200, headers: {
      Headers.contentTypeHeader: ['text/event-stream'],
    });
  }
  @override
  void close({bool force = false}) {}
}

SseClient _client(String body) {
  final dio = Dio(BaseOptions(baseUrl: 'http://x'))..httpClientAdapter = _StreamAdapter(body);
  return SseClient(dio);
}

void main() {
  test('event:error 프레임에서 ApiException(code)을 throw한다', () async {
    const body =
        'event:token\ndata:hello\n\n'
        'event:error\n'
        'data:{"error":{"code":"AI_KILL_SWITCH_ACTIVE","message":"멈춤","trace_id":"t1"}}\n\n';
    final events = <String>[];
    Object? caught;
    try {
      await for (final e in _client(body).connect('/x')) {
        events.add('${e.event}:${e.data}');
      }
    } catch (e) {
      caught = e;
    }
    // 선행 token은 보존되어 전달됨
    expect(events, ['token:hello']);
    // error 프레임은 ApiException으로 throw
    expect(caught, isA<ApiException>());
    final ex = caught as ApiException;
    expect(ex.code, ApiErrorCode.aiKillSwitchActive);
    expect(ex.message, '멈춤');
    expect(ex.traceId, 't1');
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd /d/workspace/dpa/devpath-frontend/packages/dp_core && dart test test/sse/sse_client_error_test.dart`
Expected: FAIL(현재 SseClient는 `error` 이벤트를 일반 SseEvent로 yield → caught null, events에 error 포함).

- [ ] **Step 3: ApiException에 envelope 파서 추출**

`packages/dp_core/lib/src/error/api_exception.dart`의 `fromDio` 내 envelope 파싱을 팩토리로 추출하고 `fromDio`가 이를 재사용:
```dart
  /// 중첩 §3.4 envelope Map → ApiException. HTTP(fromDio)와 SSE(event:error) 공용.
  factory ApiException.fromEnvelope(
    Map<String, dynamic> body, {
    int? status,
    int? retryAfterSeconds,
  }) {
    final err = (body['error'] is Map)
        ? (body['error'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    return ApiException(
      code: ApiErrorCode.fromWire(err['code'] as String?),
      message: (err['message'] as String?) ?? '알 수 없는 오류가 발생했습니다.',
      traceId: err['trace_id'] as String?,
      status: status,
      retryAfterSeconds: retryAfterSeconds,
    );
  }
```
그리고 기존 `fromDio`의 badResponse 분기를 이 팩토리로 위임:
```dart
    final res = e.response;
    final body = res?.data;
    final retryAfter = res?.headers.value('retry-after');
    return ApiException.fromEnvelope(
      body is Map ? body.cast<String, dynamic>() : const {},
      status: res?.statusCode,
      retryAfterSeconds: retryAfter == null ? null : int.tryParse(retryAfter),
    );
```
(네트워크 타입 분기는 그대로 위에 유지.)

- [ ] **Step 4: SseClient가 event:error를 throw**

`packages/dp_core/lib/src/sse/sse_client.dart`의 이벤트 경계 방출 지점(빈 줄에서 `yield SseEvent(...)` 및 스트림 종료 flush)에서, `event == 'error'`이면 envelope를 파싱해 throw. 방출 로직을 다음으로 교체:
```dart
      if (line.isEmpty) {
        if (dataBuf.isNotEmpty) {
          final ev = SseEvent(event: event, data: dataBuf.toString());
          dataBuf.clear();
          final name = event;
          event = null;
          if (name == 'error') {
            throw _sseError(ev.data);
          }
          yield ev;
        }
        continue;
      }
```
그리고 스트림 종료 flush 지점도 동일 가드:
```dart
    if (dataBuf.isNotEmpty) {
      final ev = SseEvent(event: event, data: dataBuf.toString());
      if (event == 'error') throw _sseError(ev.data);
      yield ev;
    }
```
파일 하단(클래스 내부)에 헬퍼 추가:
```dart
  ApiException _sseError(String data) {
    try {
      final decoded = json.decode(data);
      if (decoded is Map) {
        return ApiException.fromEnvelope(decoded.cast<String, dynamic>());
      }
    } catch (_) {}
    return const ApiException(code: ApiErrorCode.unknown, message: '스트림 오류가 발생했습니다.');
  }
```
상단 import에 `api_error_code.dart` 추가(이미 api_exception 경유 가용이면 생략), `dart:convert`의 `json`은 기존 `jsonDecode`/`utf8` import로 가용.

- [ ] **Step 5: 통과 확인**

Run: `cd /d/workspace/dpa/devpath-frontend/packages/dp_core && dart test test/sse/sse_client_error_test.dart`
Expected: PASS.

- [ ] **Step 6: dp_core 전체 회귀 + format**

Run:
```bash
cd /d/workspace/dpa/devpath-frontend/packages/dp_core && dart test && dart analyze
cd /d/workspace/dpa/devpath-frontend && dart format --output=none --set-exit-if-changed packages/dp_core/lib/src/sse/sse_client.dart packages/dp_core/lib/src/error/api_exception.dart packages/dp_core/test/sse/sse_client_error_test.dart
```
Expected: 그린 / 0 changed.

- [ ] **Step 7: 커밋**

```bash
cd /d/workspace/dpa/devpath-frontend
git add packages/dp_core/lib/src/error/api_exception.dart packages/dp_core/lib/src/sse/sse_client.dart packages/dp_core/test/sse/sse_client_error_test.dart
git commit -m "feat(dp_core/sse): event:error 프레임을 ApiException으로 해석 (C2 프론트 선행)"
```

### Task 2: 컨트롤러 onError — 중간 ApiException을 failed로

**Files:**
- Modify: `apps/web/lib/src/features/path/application/path_controller.dart`(onError 분기)
- Test: `apps/web/test/features/path/path_controller_test.dart`(케이스 추가)

**Interfaces:**
- Consumes: Task 1의 `SseClient`가 mid-stream `event:error`→`ApiException` throw → `path_controller`의 `.listen(onError:)`로 도달.

- [ ] **Step 1: 실패 테스트 작성**

`apps/web/test/features/path/path_controller_test.dart`에 케이스 추가(기존 `_emitThenError` 패턴 활용 — ApiException을 던지는 변형):
```dart
  test('중간 ApiException(event:error 유래)은 failed로 표면화한다', () async {
    Stream<SseEvent> emitThenApi() async* {
      yield SseEvent(event: 'progress', data: jsonEncode({
        'stage': 'collecting', 'progress': 0.15, 'message': 'x', 'pathId': null,
      }));
      throw const ApiException(
        code: ApiErrorCode.unknown, message: 'ai-svc path generate failed');
    }
    final container = ProviderContainer(overrides: [
      pathSseConnectProvider.overrideWithValue(() => emitThenApi()),
    ]);
    addTearDown(container.dispose);
    await container.read(pathControllerProvider.notifier).loadOrStart();
    final st = container.read(pathControllerProvider);
    expect(st.phase, PathPhase.failed);
    expect(st.error, 'ai-svc path generate failed');
  });
```
(정확한 provider/메서드명은 기존 테스트 상단 참조: `pathSseConnectProvider`·`pathControllerProvider`·start 메서드.)

- [ ] **Step 2: 실패 확인**

Run: `cd /d/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/path/path_controller_test.dart -r compact`
Expected: FAIL(현재 generic ApiException은 else 분기 → partial, failed 아님).

- [ ] **Step 3: onError 분기 추가**

`path_controller.dart` onError(기존 `if (e is ApiException && (e.isKillSwitch || e.isQuota)) {...} else {... partial}`)를 다음으로:
```dart
        if (e is ApiException && (e.isKillSwitch || e.isQuota)) {
          state = state.copyWith(
            phase: e.isKillSwitch ? PathPhase.killSwitch : PathPhase.failed,
            error: e.message,
          );
        } else if (e is ApiException) {
          // 중간 event:error = 서버 확정 실패(네트워크 끊김과 구분).
          state = state.copyWith(phase: PathPhase.failed, error: e.message);
        } else if (state.phase == PathPhase.streaming) {
          state = state.copyWith(phase: PathPhase.partial, error: '생성이 중단됐어요');
        }
```
(기존 비-ApiException partial 분기는 유지.)

- [ ] **Step 4: 통과 확인**

Run: `cd /d/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/path/path_controller_test.dart -r compact`
Expected: PASS(신규 + 기존 회귀).

- [ ] **Step 5: 전체 회귀 + format + 커밋**

```bash
cd /d/workspace/dpa/devpath-frontend/apps/web && flutter test -r compact
cd /d/workspace/dpa/devpath-frontend && dart format --output=none --set-exit-if-changed apps/web/lib/src/features/path/application/path_controller.dart apps/web/test/features/path/path_controller_test.dart
git add apps/web/lib/src/features/path/application/path_controller.dart apps/web/test/features/path/path_controller_test.dart
git commit -m "feat(web/path): 중간 event:error ApiException을 failed로 표면화 (C2 프론트 선행)"
```

**Phase 1 종료**: `feat/web-sse-error-contract` → develop PR. sandbox/mentor 컨트롤러는 기존 onError가 ApiException 코드를 이미 매핑하므로 무변경(백엔드 이관 후 자동 개선). 이 PR은 백엔드 미이관에도 안전(하위호환).

---

## Phase 2 — 백엔드 채택 (shared 선행 → 발행 → 3 svc)

### Task 3: shared `SseSupport` 헬퍼

**Files:**
- Modify: `devpath-shared/build.gradle.kts`(spring-webmvc compileOnly 추가)
- Create: `devpath-shared/src/main/java/ai/devpath/shared/error/SseSupport.java`
- Test: `devpath-shared/src/test/java/ai/devpath/shared/error/SseSupportTest.java`
- 브랜치: `feat/sse-error-frame`(shared, base develop)

- [ ] **Step 1: build.gradle.kts에 spring-webmvc compileOnly 추가**

`devpath-shared/build.gradle.kts`의 `compileOnly("org.springframework:spring-web:7.0.8")` 아래에 추가:
```kotlin
	compileOnly("org.springframework:spring-webmvc:7.0.8")
	testImplementation("org.springframework:spring-webmvc:7.0.8")
```

- [ ] **Step 2: 실패 테스트 작성**

`devpath-shared/src/test/java/ai/devpath/shared/error/SseSupportTest.java`:
```java
package ai.devpath.shared.error;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

class SseSupportTest {
  @Test
  void sendError_emits_error_event_with_envelope() throws Exception {
    List<Object> sent = new ArrayList<>();
    SseEmitter emitter = new SseEmitter() {
      @Override public void send(SseEventBuilder builder) {
        // 직렬화된 데이터 셋을 캡처(이름/데이터 확인은 builder.build()로).
        builder.build().forEach(d -> sent.add(d.getData()));
      }
    };
    SseSupport.sendError(emitter, ErrorCode.INTERNAL_ERROR, "boom");
    // 이벤트 데이터에 ErrorResponse(중첩 error.code)가 포함된다.
    assertThat(sent).anyMatch(o -> o instanceof ErrorResponse
        && ((ErrorResponse) o).error().code().equals("INTERNAL_ERROR")
        && ((ErrorResponse) o).error().message().equals("boom"));
  }
}
```

- [ ] **Step 3: 실패 확인**

Run: `cd /d/workspace/dpa/devpath-shared && ./gradlew test --tests '*SseSupportTest' --console=plain`
Expected: 컴파일 실패(SseSupport 미존재).

- [ ] **Step 4: SseSupport 구현**

`devpath-shared/src/main/java/ai/devpath/shared/error/SseSupport.java`:
```java
package ai.devpath.shared.error;

import java.io.IOException;
import java.time.Instant;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

/**
 * SSE 스트림 중간 에러를 스펙 §3.4 envelope로 방출하는 공용 헬퍼.
 *
 * <p>스트림 개시(HTTP 200) 후 실패 시 {@code completeWithError} 대신 이 메서드로
 * {@code event:error} + {@link ErrorResponse} 프레임을 보내고, 호출자는 이어서
 * {@link SseEmitter#complete()}를 호출한다. 프론트 dp_core SseClient가 이 프레임을
 * ApiException으로 해석한다.
 */
public final class SseSupport {
  private SseSupport() {}

  public static void sendError(SseEmitter emitter, ErrorCode code, String message) {
    ErrorResponse envelope = ErrorResponse.of(code, message, null, Instant.now().toString());
    try {
      emitter.send(SseEmitter.event().name("error").data(envelope));
    } catch (IOException e) {
      throw new IllegalStateException("SSE error frame send failed", e);
    }
  }
}
```

- [ ] **Step 5: 통과 확인 + 빌드**

Run: `cd /d/workspace/dpa/devpath-shared && ./gradlew test --tests '*SseSupportTest' build --console=plain 2>&1 | tail -5`
Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 6: 커밋 + PR**

```bash
cd /d/workspace/dpa/devpath-shared
git add build.gradle.kts src/main/java/ai/devpath/shared/error/SseSupport.java src/test/java/ai/devpath/shared/error/SseSupportTest.java
git commit -m "feat(sse): SseSupport.sendError — event:error + §3.4 envelope 공용 헬퍼 (C2)"
```
그리고 develop PR 생성. **머지 후 CI가 devpath-shared:0.0.1-SNAPSHOT을 발행**해야 Task 4~6이 당길 수 있다(발행 확인 필수).

### Task 4: sandbox 채택

**Files:**
- Modify: `devpath-sandbox-svc/src/main/java/ai/devpath/sandbox/run/RunController.java`(catch)
- Test: sandbox SSE IT(기존 IT에 케이스 추가 — `RunControllerTest`/IT 위치 실측)
- 브랜치: `feat/sse-error-frame`(sandbox, base develop)

- [ ] **Step 1: 최신 shared 스냅샷 확인**

Run: `cd /d/workspace/dpa/devpath-sandbox-svc && ./gradlew dependencies --refresh-dependencies --console=plain 2>&1 | grep devpath-shared | head`
Expected: `0.0.1-SNAPSHOT`(Task 3 발행본). `SseSupport` 심볼 해석 가능해야 함.

- [ ] **Step 2: 실패 테스트 작성**

sandbox SSE IT에 "runner 실행 중 예외 → `event:error` 프레임 + 스트림 정상 종료" 케이스 추가. (기존 IT 파일·러너 mock 패턴을 실측해 예외 주입. 러너 backend를 실패하도록 stub → 응답에서 `event:error`와 envelope 포함 검증.)

- [ ] **Step 3: 실패 확인** — 현재 `completeWithError`라 error 프레임 없음 → FAIL.

- [ ] **Step 4: catch 교체**

`RunController.run`의 catch를:
```java
      } catch (Exception e) {
        SseSupport.sendError(emitter, ErrorCode.INTERNAL_ERROR, e.getMessage());
        emitter.complete();
      }
```
import 추가: `ai.devpath.shared.error.SseSupport`, `ai.devpath.shared.error.ErrorCode`. (개시전 `SandboxUnavailableException` 503 경로는 그대로.)

- [ ] **Step 5: 통과 + build + 커밋 + PR**

Run: `cd /d/workspace/dpa/devpath-sandbox-svc && ./gradlew build --console=plain 2>&1 | tail -3` → `BUILD SUCCESSFUL`.
커밋 `feat(sse): 중간 에러를 event:error 프레임으로 방출 (C2)` → develop PR.

### Task 5: mentor(ai-svc) 채택

**Files:**
- Modify: `devpath-ai-svc/src/main/java/ai/devpath/aigw/mentor/MentorService.java`(catch 2곳)
- Test: mentor SSE IT(예외 주입 케이스)
- 브랜치: `feat/sse-error-frame`(ai-svc, base develop)

- [ ] **Step 1: 최신 shared 스냅샷 확인** — `--refresh-dependencies`로 SseSupport 해석 가능 확인.

- [ ] **Step 2~3: 실패 테스트** — mentor LLM stub이 예외를 던지도록 → 응답에 `event:error` + envelope 기대(현재 없음 → FAIL).

- [ ] **Step 4: catch 2곳 교체**

`MentorService.streamAnswer`의:
```java
    } catch (MentorStreamAbortedException abort) {
      persistence.saveFailed(userId, question, contentId, ctx.snapshotJson(), "CLIENT_ABORTED");
      SseSupport.sendError(emitter, ErrorCode.INTERNAL_ERROR, "stream aborted");
      emitter.complete();
    } catch (Exception e) {
      persistence.saveFailed(userId, question, contentId, ctx.snapshotJson(), "LLM_FAILED");
      SseSupport.sendError(emitter, ErrorCode.INTERNAL_ERROR, e.getMessage());
      emitter.complete();
    }
```
import: `SseSupport`, `ErrorCode`. (부분답변 토큰은 catch 이전에 이미 방출됨 — 보존.)
※ `MentorStreamAbortedException`은 클라이언트가 이미 끊긴 경우라 send가 다시 IOException일 수 있음 → `SseSupport.sendError`가 IllegalState를 던지면 로그만 남기도록 이 catch는 try로 감싸도 됨(구현 시 실측 판단; 최소구현은 위로).

- [ ] **Step 5: 통과 + build + 커밋 + PR** — `./gradlew build` 그린, develop PR.

### Task 6: learning 채택 (인밴드 제거)

**Files:**
- Modify: `devpath-learning-svc/src/main/java/ai/devpath/learning/path/LearningPathController.java`(catch)
- Test: path SSE IT(ai 실패 주입 → event:error)
- 브랜치: `feat/sse-error-frame`(learning, base develop)

- [ ] **Step 1: 최신 shared 스냅샷 확인.**

- [ ] **Step 2~3: 실패 테스트** — `AiPathClient`를 실패 stub → 응답에 `event:error` + envelope 기대(현재는 `event:progress{stage:error}` → FAIL).

- [ ] **Step 4: catch 교체(인밴드 progress(stage=error) 제거)**

`generate`의 catch를:
```java
      } catch (Exception e) {
        SseSupport.sendError(emitter, ErrorCode.INTERNAL_ERROR, e.getMessage());
        emitter.complete();
      }
```
import: `SseSupport`, `ErrorCode`. `PathProgressEvent.error(...)` 방출 제거(중첩 try 삭제). `PathProgressEvent.error` 팩토리는 다른 사용처 없으면 제거 가능(실측 후).

- [ ] **Step 5: 통과 + build + 커밋 + PR** — `./gradlew build` 그린, develop PR.

**Phase 2 종료**: shared PR 머지·발행 → sandbox/mentor/learning PR 각 머지. 모든 백엔드가 `event:error` 방출.

---

## Phase 3 — 프론트 정리 (Phase 2 머지 확인 후)

### Task 7: path_controller의 `stage=='error'` 분기 제거

**Files:**
- Modify: `apps/web/lib/src/features/path/application/path_controller.dart`
- Test: `apps/web/test/features/path/path_controller_test.dart`(stage=error 케이스를 event:error 케이스로 대체)
- 브랜치: `chore/web-path-sse-error-cleanup`(frontend, base develop)

- [ ] **Step 1: 선행 조건 확인**

learning develop이 Task 6(인밴드 제거)을 머지했는지 확인:
```bash
git -C /d/workspace/dpa/devpath-learning-svc log --oneline -5 | grep -i "event:error\|sse"
```
미머지면 **중단**(무음화 방지, R-C2-1).

- [ ] **Step 2: stage=error 테스트를 event:error로 대체**

기존 path_controller_test의 인밴드 `progress{stage:error}` 케이스가 있으면 삭제하고(백엔드가 더는 안 보냄), Task 2의 event:error→failed 케이스가 이를 대체함을 확인.

- [ ] **Step 3: 분기 제거**

`path_controller.dart`에서 `if (pathEvent.stage == 'error') { ... PathPhase.failed ... }` 블록 제거(이제 error는 SseClient가 throw → onError로 처리). 정상 stage 진행·`done` 분기는 유지.

- [ ] **Step 4: 통과 + 회귀 + format + 커밋 + PR**

Run: `cd /d/workspace/dpa/devpath-frontend/apps/web && flutter test -r compact` → 그린. format 0 changed. 커밋 `chore(web/path): 인밴드 stage=error 처리 제거 — event:error로 대체됨 (C2 정리)` → develop PR.

---

## Self-Review 결과

- **Spec 커버리지**: 계약→Task1/3, shared 헬퍼→Task3, 백엔드 3 svc→Task4/5/6, 프론트 SseClient→Task1, onError 조정→Task2, 롤아웃 3단계→Phase1/2/3, 테스트→각 Task. ✅
- **플레이스홀더**: 백엔드 IT 테스트(Task4/5/6 Step2)는 "기존 IT 패턴 실측 후 예외 주입"으로 서술 — 각 svc IT 구조가 상이해 실 코드는 실측 필요(런북 성격). 프론트/shared는 실 코드 포함. 백엔드 IT는 실행 시 해당 svc의 기존 SSE IT를 열어 패턴 복제. ⚠️(불가피, 실측 지시로 명시)
- **타입 일관성**: `ApiException.fromEnvelope`(Task1 정의)=SseClient·fromDio 사용. `SseSupport.sendError(SseEmitter,ErrorCode,String)`(Task3)=Task4/5/6 호출 동일. `event:error`+`ErrorResponse` 형태=프론트 파서 대칭. ✅
- **의존 순서**: Task3(shared) 머지·발행 → Task4/5/6(`--refresh-dependencies`). Phase3는 Task6 머지 후. 명시. ✅
- **하위호환**: Phase1이 백엔드 미이관에도 안전(SseClient는 event:error 안 오면 기존대로, path stage=error 유지). ✅
