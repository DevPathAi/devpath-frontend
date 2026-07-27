# 축 A — 에러 envelope 프론트 정합 마무리 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 이미 구현된 프론트 에러 envelope 처리를 감사로 확정하고, 중첩 envelope 계약을 골든 테스트로 고정하며, 라이브 403 `ONBOARDING_INCOMPLETE`를 전역에서 잡아 온보딩으로 유도한다.

**Architecture:** dp_core의 파싱/전송 정규화(`ApiException.fromDio`, api_client 인터셉터, SSE)는 손대지 않는다. 신규 작업은 (1) dp_core 계약 골든 테스트, (2) apps/web `AuthController.markOnboardingIncomplete()` + 앱-레벨 `OnboardingGateInterceptor`뿐이다. 라우터/auth 반응은 앱 레벨에만 두어 dp_core의 라우터 무지식을 보존한다(401 refresh 배선과 동일 패턴).

**Tech Stack:** Flutter · Dart · dio · flutter_riverpod · freezed. dp_core 테스트=`package:test`, apps/web 테스트=`flutter_test`.

## Global Constraints

- 브랜치: `feat/web-error-envelope-finalize` (base `develop`). `develop`·`main` 직접 커밋 금지 — PR 경유.
- 백엔드 변경 없음(§3.4 envelope는 이미 표준화 완료).
- SSE 스트림 **중간** 에러 프레임은 **비범위**(축 C). 이 계획은 request/response 에러만 다룬다.
- 온보딩 강등 값 = `OnboardingStatus.pending`(enum: `pending`/`inProgress`/`done`/`unknown`). enum 추가 없음.
- apps/web 패키지 임포트 접두사: `package:devpath_web/...`.
- TDD: 실패(또는 계약 골든의 경우 PASS) 확인 → 최소 구현 → 통과 확인 → 커밋. 각 태스크 종료 시 `flutter test` 관련 스코프 그린을 눈으로 확인.
- 모든 git 명령은 `devpath-frontend` 레포 루트(`D:\workspace\dpa\devpath-frontend`)에서 실행.

---

### Task 1: 에러 표면화 감사 리포트 (유닛 1 — 코드 변경 0)

전 feature 컨트롤러의 에러 경로가 무음 소실 없이 사용자에게 표면화되는지 감사하고 리포트를 남긴다. 코드는 바꾸지 않는다. 무음 실패가 발견되면 리포트에 gap으로 기록하고 **멈추고 컨트롤러에 보고**(재-스코핑) — 이 계획은 발견된 gap의 구현을 포함하지 않는다.

**Files:**
- Create: `docs/superpowers/reports/2026-07-04-web-error-surfacing-audit.md`

**감사 대상 컨트롤러(10):**
`apps/web/lib/src/features/` 하위 —
`auth/application/auth_controller.dart`, `community/application/community_controller.dart`, `community/application/qna_detail_controller.dart`, `content/application/content_controller.dart`, `dashboard/application/dashboard_controller.dart`, `diagnostic/application/diagnostic_controller.dart`, `mentor/application/mentor_controller.dart`, `path/application/path_controller.dart`, `review/application/review_controller.dart`, `sandbox/application/run_controller.dart`.

**표면화 위젯(참조):** `dp_design`의 `DpError`/`DpKillSwitch`/`DpQuota`.

- [ ] **Step 1: 각 컨트롤러의 에러 경로 조사**

각 컨트롤러에서 `catch`/`on ApiException`/에러 상태 전이를 찾아 다음을 기록: 어떤 `ApiErrorCode`가 사용자에게 보이는가, `catch`가 상태를 에러로 전이시키는가 아니면 무음으로 삼키는가.

Run:
```bash
grep -rn "catch\|on ApiException\|Error(\|state =" apps/web/lib/src/features --include='*.dart' | grep -v '/build/'
```

- [ ] **Step 2: 감사 리포트 작성**

`docs/superpowers/reports/2026-07-04-web-error-surfacing-audit.md`에 표를 작성한다. 열: `화면 | 컨트롤러 | 에러 catch 경로 | 표면화 방식(DpError/killSwitch/quota/에러상태/무음) | 판정(OK/무음실패)`. 각 컨트롤러 한 행 이상. 말미에 "무음 실패 목록" 절 — 없으면 "없음(전 경로 표면화 확인)"이라고 명시.

- [ ] **Step 3: 무음 실패 발견 시 분기**

무음 실패가 1건 이상이면 리포트 "무음 실패 목록"에 `화면·라인·기대 동작`을 적고 **여기서 멈춰 컨트롤러에 보고**한다(구현은 재-스코핑 후 별도). 무음 실패가 없으면 다음 스텝으로.

- [ ] **Step 4: 커밋**

```bash
git add docs/superpowers/reports/2026-07-04-web-error-surfacing-audit.md
git commit -m "docs(report): 웹 에러 표면화 감사 — feature 컨트롤러 에러 경로 정합 확인"
```

---

### Task 2: 중첩 envelope 골든 계약 테스트 (유닛 2 — dp_core)

백엔드 §3.4 envelope 형태를 프론트 측 앵커로 고정한다. `ApiException.fromDio`/`ApiErrorCode.fromWire` 구현은 이미 존재하므로 이 테스트는 **기존 동작을 고정하는 특성화(characterization) 골든**이다 — 첫 실행부터 PASS가 정상이며, 목적은 백엔드가 envelope 형태를 바꿀 때 이 테스트가 깨져 조기 감지하는 것이다.

**Files:**
- Create: `packages/dp_core/test/error/api_exception_contract_test.dart`
- Test 대상(수정 없음): `packages/dp_core/lib/src/error/api_exception.dart`, `packages/dp_core/lib/src/error/api_error_code.dart`

**Interfaces:**
- Consumes: `ApiException.fromDio(DioException)` → `ApiException{code, message, traceId, status, retryAfterSeconds}`; `ApiErrorCode.fromWire(String?)` → `ApiErrorCode`.

- [ ] **Step 1: 계약 골든 테스트 작성**

`packages/dp_core/test/error/api_exception_contract_test.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:dp_core/src/error/api_error_code.dart';
import 'package:dp_core/src/error/api_exception.dart';
import 'package:test/test.dart';

/// 백엔드 스펙 §3.4 공통 envelope 계약을 프론트 측에서 고정하는 골든.
/// 이 테스트가 깨지면 백엔드 envelope 형태가 바뀐 것이다(조기 감지 앵커).
void main() {
  ApiException fromResponse(int status, Object? data, {Headers? headers}) {
    final req = RequestOptions(path: '/x');
    return ApiException.fromDio(
      DioException(
        requestOptions: req,
        response: Response(
          requestOptions: req,
          statusCode: status,
          data: data,
          headers: headers,
        ),
        type: DioExceptionType.badResponse,
      ),
    );
  }

  group('§3.4 중첩 envelope 계약', () {
    test('중첩 {"error":{code,message,trace_id}}를 필드별로 매핑한다', () {
      final ex = fromResponse(404, {
        'error': {
          'code': 'RESOURCE_NOT_FOUND',
          'message': '없음',
          'trace_id': 'trace-abc',
        },
      });
      expect(ex.code, ApiErrorCode.resourceNotFound);
      expect(ex.message, '없음');
      expect(ex.traceId, 'trace-abc');
      expect(ex.status, 404);
    });

    test('전 ErrorCode wire 문자열을 enum으로 매핑한다', () {
      const wire = {
        'UNAUTHORIZED': ApiErrorCode.unauthorized,
        'FORBIDDEN': ApiErrorCode.forbidden,
        'ONBOARDING_INCOMPLETE': ApiErrorCode.onboardingIncomplete,
        'RESOURCE_NOT_FOUND': ApiErrorCode.resourceNotFound,
        'VALIDATION_FAILED': ApiErrorCode.validationFailed,
        'CONFLICT': ApiErrorCode.conflict,
        'QUOTA_EXCEEDED': ApiErrorCode.quotaExceeded,
        'AI_KILL_SWITCH_ACTIVE': ApiErrorCode.aiKillSwitchActive,
        'SANDBOX_UNAVAILABLE': ApiErrorCode.sandboxUnavailable,
        'INTERNAL_ERROR': ApiErrorCode.unknown, // 프론트 enum에 INTERNAL_ERROR 없음 → unknown 폴백
      };
      wire.forEach((w, expected) {
        expect(ApiErrorCode.fromWire(w), expected, reason: 'wire=$w');
      });
    });

    test('알 수 없는 코드/누락은 unknown으로 폴백한다', () {
      expect(ApiErrorCode.fromWire('SOMETHING_NEW'), ApiErrorCode.unknown);
      expect(ApiErrorCode.fromWire(null), ApiErrorCode.unknown);
    });

    test('429 + retry-after 헤더를 retryAfterSeconds로 보존한다', () {
      final ex = fromResponse(
        429,
        {
          'error': {'code': 'QUOTA_EXCEEDED', 'message': '한도'},
        },
        headers: Headers.fromMap({
          'retry-after': ['45'],
        }),
      );
      expect(ex.code, ApiErrorCode.quotaExceeded);
      expect(ex.retryAfterSeconds, 45);
    });

    test('네트워크 타입은 network로 매핑한다', () {
      final ex = ApiException.fromDio(
        DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionError,
        ),
      );
      expect(ex.code, ApiErrorCode.network);
    });

    test('envelope 형태가 아닌 응답(비-Map/error 누락)은 방어 폴백한다', () {
      // error 키 누락
      final missing = fromResponse(500, {'foo': 'bar'});
      expect(missing.code, ApiErrorCode.unknown);
      expect(missing.message, '알 수 없는 오류가 발생했습니다.');
      expect(missing.status, 500);

      // 본문이 Map이 아님(HTML/텍스트)
      final nonMap = fromResponse(502, '<html>bad gateway</html>');
      expect(nonMap.code, ApiErrorCode.unknown);
      expect(nonMap.status, 502);
    });
  });
}
```

- [ ] **Step 2: 테스트 실행 — PASS 확인(특성화 골든)**

Run:
```bash
cd packages/dp_core && dart test test/error/api_exception_contract_test.dart
```
Expected: All tests PASS. (구현이 이미 존재하므로 PASS가 정상. FAIL이면 현 구현이 §3.4 계약과 어긋난 것이므로 멈추고 보고.)

- [ ] **Step 3: 커밋**

```bash
git add packages/dp_core/test/error/api_exception_contract_test.dart
git commit -m "test(dp_core): §3.4 중첩 에러 envelope 계약 골든 — 백엔드 drift 조기 감지 앵커"
```

---

### Task 3: AuthController.markOnboardingIncomplete() (유닛 3a — apps/web)

라이브 403 `ONBOARDING_INCOMPLETE`를 받았을 때 게이트를 재평가시키기 위해, 현재 인증 유저의 `onboardingStatus`를 `pending`으로 강등하는 메서드를 추가한다.

**Files:**
- Modify: `apps/web/lib/src/features/auth/application/auth_controller.dart` (신규 메서드 추가)
- Test: `apps/web/test/features/auth/auth_controller_test.dart` (신규 group 추가)

**Interfaces:**
- Produces: `void AuthController.markOnboardingIncomplete()` — `state`가 `AuthAuthenticated`이고 `user.onboardingStatus != pending`이면 `AuthAuthenticated(user.copyWith(onboardingStatus: pending))`로 전이. 그 외 상태에선 무동작. Task 4가 이 메서드를 호출한다.

- [ ] **Step 1: 실패 테스트 작성**

`apps/web/test/features/auth/auth_controller_test.dart` 파일 상단(기존 `_MockRefreshAdapter` 아래)에 DONE 유저 어댑터를 추가한다:

```dart
// onboardingStatus=DONE 유저를 반환하는 refresh 어댑터(markOnboardingIncomplete 검증용).
class _DoneUserRefreshAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode({
        'access_token': 'test-access-token',
        'user': {
          'id': 'u-2',
          'email': 'done@devpath.ai',
          'nickname': '완료자',
          'role': 'LEARNER',
          'onboardingStatus': 'DONE',
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
```

그리고 `main()` 안에 group을 추가한다:

```dart
  group('markOnboardingIncomplete()', () {
    test('AuthAuthenticated(done) → onboardingStatus를 pending으로 강등한다', () async {
      final container = _containerWithAdapter(_DoneUserRefreshAdapter());
      addTearDown(container.dispose);
      final ctrl = container.read(authControllerProvider.notifier);
      await ctrl.bootstrapFromCallback(); // AuthAuthenticated(done)로 만든다
      expect(
        (container.read(authControllerProvider) as AuthAuthenticated)
            .user
            .onboardingStatus,
        OnboardingStatus.done,
      );

      ctrl.markOnboardingIncomplete();

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthAuthenticated>());
      expect(
        (state as AuthAuthenticated).user.onboardingStatus,
        OnboardingStatus.pending,
      );
    });

    test('비-AuthAuthenticated(AuthLoading) 상태에선 무동작', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // build() 직후 microtask 실행 전 → AuthLoading.
      final before = container.read(authControllerProvider);
      expect(before, isA<AuthLoading>());

      container.read(authControllerProvider.notifier).markOnboardingIncomplete();

      expect(container.read(authControllerProvider), isA<AuthLoading>());
    });
  });
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

Run:
```bash
cd apps/web && flutter test test/features/auth/auth_controller_test.dart -r compact
```
Expected: 컴파일 실패 — `markOnboardingIncomplete` 메서드 미정의.

- [ ] **Step 3: 최소 구현**

`apps/web/lib/src/features/auth/application/auth_controller.dart`의 `onboardingCompleted` 메서드 바로 아래에 추가:

```dart
  /// 서버가 라이브 403 ONBOARDING_INCOMPLETE를 반환하면(캐시된 onboardingStatus와
  /// 서버 진실 불일치) 온보딩 상태를 pending으로 강등해 게이트를 재평가시킨다.
  void markOnboardingIncomplete() {
    final s = state;
    if (s is AuthAuthenticated &&
        s.user.onboardingStatus != OnboardingStatus.pending) {
      state = AuthAuthenticated(
        s.user.copyWith(onboardingStatus: OnboardingStatus.pending),
      );
    }
  }
```

(`OnboardingStatus`·`AuthAuthenticated`·`User.copyWith`는 기존 임포트(`dp_core`, `auth_state.dart`)로 이미 가용.)

- [ ] **Step 4: 테스트 실행 — 통과 확인**

Run:
```bash
cd apps/web && flutter test test/features/auth/auth_controller_test.dart -r compact
```
Expected: All tests PASS.

- [ ] **Step 5: 커밋**

```bash
git add apps/web/lib/src/features/auth/application/auth_controller.dart apps/web/test/features/auth/auth_controller_test.dart
git commit -m "feat(auth): markOnboardingIncomplete — 라이브 403 시 온보딩 상태 pending 강등"
```

---

### Task 4: OnboardingGateInterceptor + 배선 (유닛 3b — apps/web)

응답이 403 `ONBOARDING_INCOMPLETE`이면 콜백으로 `markOnboardingIncomplete()`를 호출하는 앱-레벨 인터셉터를 만들고 `apiClientProvider`에 결선한다.

**Files:**
- Create: `apps/web/lib/src/providers/onboarding_gate_interceptor.dart`
- Modify: `apps/web/lib/src/providers/api_providers.dart` (인터셉터 결선 + import)
- Test: `apps/web/test/providers/onboarding_gate_interceptor_test.dart`

**Interfaces:**
- Consumes: `AuthController.markOnboardingIncomplete()` (Task 3); `ApiException.fromDio` (dp_core).
- Produces: `class OnboardingGateInterceptor extends Interceptor` — 생성자 `OnboardingGateInterceptor(void Function() onOnboardingIncomplete)`. `onError`에서 `ApiException.fromDio(err).isOnboardingIncomplete`면 콜백 호출 후 `handler.next(err)`.

- [ ] **Step 1: 실패 테스트 작성**

`apps/web/test/providers/onboarding_gate_interceptor_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:devpath_web/src/providers/onboarding_gate_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.statusCode, this.body);
  final int statusCode;
  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(_StubAdapter adapter, void Function() onIncomplete) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test.local'))
    ..httpClientAdapter = adapter
    ..interceptors.add(OnboardingGateInterceptor(onIncomplete));
  return dio;
}

void main() {
  test('403 ONBOARDING_INCOMPLETE에서 콜백을 호출한다', () async {
    var called = false;
    final dio = _dioWith(
      _StubAdapter(
        403,
        jsonEncode({
          'error': {'code': 'ONBOARDING_INCOMPLETE', 'message': '온보딩 필요'},
        }),
      ),
      () => called = true,
    );
    await expectLater(
      dio.get<dynamic>('/protected'),
      throwsA(isA<DioException>()),
    );
    expect(called, isTrue);
  });

  test('다른 403(FORBIDDEN)에서는 콜백을 호출하지 않는다', () async {
    var called = false;
    final dio = _dioWith(
      _StubAdapter(
        403,
        jsonEncode({
          'error': {'code': 'FORBIDDEN', 'message': '금지'},
        }),
      ),
      () => called = true,
    );
    await expectLater(
      dio.get<dynamic>('/protected'),
      throwsA(isA<DioException>()),
    );
    expect(called, isFalse);
  });

  test('apiClientProvider에 OnboardingGateInterceptor가 결선된다', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final client = c.read(apiClientProvider);
    expect(
      client.dio.interceptors.whereType<OnboardingGateInterceptor>(),
      isNotEmpty,
    );
  });
}
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

Run:
```bash
cd apps/web && flutter test test/providers/onboarding_gate_interceptor_test.dart -r compact
```
Expected: 컴파일 실패 — `onboarding_gate_interceptor.dart` 미존재 / `OnboardingGateInterceptor` 미정의.

- [ ] **Step 3: 인터셉터 구현**

`apps/web/lib/src/providers/onboarding_gate_interceptor.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';

/// 앱-레벨 인터셉터: 응답이 403 ONBOARDING_INCOMPLETE면 [onOnboardingIncomplete]로
/// 온보딩 게이트 재평가를 트리거한다.
///
/// dp_core는 라우터/auth를 모른다(레이어링 보존) — 반응은 앱에서 주입한다.
/// 에러는 삼키지 않고 그대로 전파한다(정규화 인터셉터가 후속 처리).
class OnboardingGateInterceptor extends Interceptor {
  OnboardingGateInterceptor(this.onOnboardingIncomplete);

  final void Function() onOnboardingIncomplete;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (ApiException.fromDio(err).isOnboardingIncomplete) {
      onOnboardingIncomplete();
    }
    handler.next(err);
  }
}
```

- [ ] **Step 4: apiClientProvider에 결선**

`apps/web/lib/src/providers/api_providers.dart`:

먼저 import 블록에 두 줄 추가:
```dart
import '../features/auth/application/auth_controller.dart';
import 'onboarding_gate_interceptor.dart';
```

그리고 `AuthInterceptor`를 삽입하는 `client.dio.interceptors.insert(0, AuthInterceptor(...))` 블록 **직후**, `if (config.useMock)` 앞에 추가:
```dart
  // 라이브 403 ONBOARDING_INCOMPLETE → 온보딩 게이트 재평가.
  // ref.read은 에러 발생 시점(지연)에 실행되므로 build-time 순환 의존이 없다
  // (AuthInterceptor의 refresh 콜백과 동일 패턴 — auth는 api를 의존하지만
  //  api는 빌드 시점에 auth를 읽지 않는다).
  client.dio.interceptors.insert(
    0,
    OnboardingGateInterceptor(
      () =>
          ref.read(authControllerProvider.notifier).markOnboardingIncomplete(),
    ),
  );
```

(참고: `api_providers.dart` ↔ `auth_controller.dart`는 상호 import가 되지만 Dart는 top-level `final` provider의 지연 초기화로 이를 허용한다. 순환은 런타임 초기화 사이클이 없으므로 안전하다.)

- [ ] **Step 5: 테스트 실행 — 통과 확인**

Run:
```bash
cd apps/web && flutter test test/providers/onboarding_gate_interceptor_test.dart -r compact
```
Expected: All 3 tests PASS.

- [ ] **Step 6: 전체 회귀 — dp_core + apps/web**

Run:
```bash
cd packages/dp_core && dart test
cd ../../apps/web && flutter test -r compact
```
Expected: 양쪽 모두 그린(기존 테스트 회귀 없음).

- [ ] **Step 7: 커밋**

```bash
git add apps/web/lib/src/providers/onboarding_gate_interceptor.dart apps/web/lib/src/providers/api_providers.dart apps/web/test/providers/onboarding_gate_interceptor_test.dart
git commit -m "feat(web): OnboardingGateInterceptor — 라이브 403 ONBOARDING_INCOMPLETE 전역 게이트 재평가"
```

---

## 최종 통합 검증 (전 태스크 후)

- [ ] `cd packages/dp_core && dart test` 그린.
- [ ] `cd apps/web && flutter test` 그린.
- [ ] `git log --oneline` 으로 커밋 범위가 Task 1~4 산출물에 한정됐는지 확인.
- [ ] `feat/web-error-envelope-finalize` → `develop` PR 생성, CI 그린 확인 후(규칙상 명시 요청 시) 머지.

## Self-Review 결과

- **Spec 커버리지**: 유닛 1→Task 1, 유닛 2→Task 2, 유닛 3(메서드+인터셉터)→Task 3·4. 비범위(SSE 중간에러·백엔드·OAuth)는 태스크 없음(의도적). ✅
- **플레이스홀더 스캔**: TBD/TODO 없음. 모든 코드 스텝에 실제 코드 포함. ✅
- **타입 일관성**: `markOnboardingIncomplete()`(Task 3 정의) = Task 4 호출부 동일. `OnboardingGateInterceptor(void Function())` 생성자 시그니처 = 테스트/결선 동일. `ApiErrorCode`/`OnboardingStatus` 값은 실측 enum과 일치. ✅
- **주의**: Task 2의 `INTERNAL_ERROR`→`unknown` 매핑은 프론트 `ApiErrorCode` enum에 `INTERNAL_ERROR`가 없어 `fromWire`가 `unknown`으로 폴백하는 현 구현을 반영한 것(계약 골든이 이 사실을 고정).
