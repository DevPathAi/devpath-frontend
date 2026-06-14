# P4b — 온보딩·진단 + 학습경로 SSE 생성(PATH-001) (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `apps/web`에 온보딩·진단(ONB) → **학습경로 SSE 생성(PATH-001)** 골든패스를 TDD로 구현한다 — 진단 제출로 온보딩 게이트를 해제하고, 4단계 SSE 생성(진행 표시) → 12주 타임라인 + 이번 주 과제 3개 + 멘토 rationale을 렌더하며, **DD8(중단 시 완료 단계 보존 + 끊긴 지점부터 이어하기/재연결)** 을 결정적으로 검증한다.

**Architecture:** P4a 토대(셸·게이트·providers·테마) 위. SSE는 dp_core `SseClient`(실서버)/`MockSseSource`(목)를 `pathSseConnectProvider`로 주입 교체. 생성 진행은 `PathController`(Riverpod `Notifier`)가 단계 누적·중단 보존(`PathPhase.partial`)·이어하기(`resume`)로 모델링하고, 결과는 SSE `DONE` 후 `GET /learning-paths/me`로 조회. PATH 도메인 모델은 dp_core에 freezed로 추가(P2가 예고한 "feature 플랜에서 엔티티 추가").

**Tech Stack:** Flutter Web · flutter_riverpod 3.3 · go_router · dp_core(SseClient·freezed 모델) · dp_design(DpSseStageView·상태위젯) · flutter_test.

---

> **선행:** P4a(셸·인증·라우팅) 구현 완료. P1~P3·P4a 모두 구현된 상태에서 실행.
> **참조:** 스펙 §3(SSE 중단 복구 DD8·페이지네이션)·§4(web 골든패스·PATH-001 와이어프레임)·§9.2(상태 매트릭스 PATH 생성 행). DESIGN.md §8(SSE 단계 상태). 샘플(스펙 §7): `Flutter_SSE_실시간_스트림_구독`·`Flutter_Riverpod_비동기_상태관리`·`Flutter_불변_모델_copyWith_JSON직렬화`. **구현 시 해당 .md를 읽어 정렬**.
> **게이트(스펙 VERDICT):** DD8(SSE 재연결)은 아키텍처 영향 → P4 실행 전 `/plan-eng-review` 권장. 본 플랜의 Task 4(PathController)가 그 핵심.
> **YAGNI/추측 경계:** 온보딩(ONB)의 **정확한 진단 문항은 외부 `DevPathAi/documents/06_화면_기능_정의서`에 정의**되며 이 레포엔 없다. 본 플랜은 게이트 해제에 필요한 **최소 진단(GitHub 핸들 입력)** 만 구현하고, 실제 문항/필드는 구현 시 외부 문서로 정렬한다(추측 금지). PATH 결과 모델도 골든패스 렌더에 필요한 최소 필드만.

## P4b가 소비/수정하는 P4a·dp_* API

- P4a: `apiClientProvider`·`appConfigProvider`·`tokenStoreProvider`(providers), `authControllerProvider`/`AuthController`/`AuthAuthenticated`(auth), `gateRedirect`/`routerProvider`(router), `AppShell`, `webMockFixtures`.
- dp_core(P2): `SseClient`·`SseEvent`·`MockSseSource`, `ApiClient.get`, `ApiException`, `User`/`OnboardingStatus`.
- dp_design(P3): `DpSseStageView`, `DpLoading`/`DpError`/`DpEmpty`, `DpIcons`, `DpSpacing`, `context.dpColors`.

---

## File Structure (P4b에서 생성/수정)

```
packages/dp_core/lib/src/models/learning_path.dart   # (생성) LearningPath·PathWeek·WeeklyTask freezed — Task 1
packages/dp_core/lib/dp_core.dart                     # (수정) export 추가 — Task 1

apps/web/
├─ lib/src/
│  ├─ app/router.dart                                 # (수정) ONB/PATH 실제 연결 + 게이트 atOnboarding 보정 — Task 2·6
│  ├─ data/web_mock_fixtures.dart                     # (수정) /onboarding·/learning-paths/me 픽스처 — Task 2·3
│  ├─ features/auth/application/auth_controller.dart  # (수정) onboardingCompleted 추가 — Task 2
│  └─ features/
│     ├─ onboarding/
│     │  ├─ application/onboarding_controller.dart     # 진단 제출 — Task 2
│     │  ├─ state/onboarding_state.dart                # sealed 상태 — Task 2
│     │  └─ presentation/onboarding_page.dart          # 진단 화면(플레이스홀더 대체) — Task 2
│     └─ path/
│        ├─ data/path_sse_source.dart                  # pathSseConnectProvider + 단계 상수 — Task 3
│        ├─ application/path_controller.dart            # PathState + 생성/이어하기(DD8) — Task 4
│        └─ presentation/
│           ├─ path_page.dart                           # 진행/부분/완료/실패 뷰 — Task 5
│           └─ path_plan_view.dart                      # 12주 타임라인+과제+rationale — Task 5
│  └─ features/onboarding/presentation/onboarding_placeholder.dart  # (삭제) — Task 2
└─ test/                                                # 각 모듈 *_test.dart + 통합 스모크 Task 6
```

---

## Task 0: AuthInterceptor 결선 (ENG-REVIEW D1)

> P4a가 "P4b에서 결선"으로 미룬 **401 큐잉 AuthInterceptor(P2)** 를 `apiClientProvider`에 결선한다. 인증 데이터 호출(PATH 생성·`GET /learning-paths/me` 등)이 P4b부터 생기므로 여기가 결선 지점. **미결선 시 목→실서버(스펙 D5) 전환에서 로그인 이후 전 화면이 토큰 없이 호출돼 401**(eng-review 발견 — P2가 만들고 테스트한 인터셉터가 死코드 되는 것 방지).

**Files:**
- Modify: `apps/web/lib/src/providers/api_providers.dart`(P4a) — `apiClientProvider`에 AuthInterceptor 추가
- Test: `apps/web/test/providers/auth_interceptor_wire_test.dart`

- [ ] **Step 1: 실패 테스트(결선 확인)**

Create `apps/web/test/providers/auth_interceptor_wire_test.dart`:
```dart
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('apiClientProvider에 AuthInterceptor가 결선된다', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final client = c.read(apiClientProvider);
    expect(client.dio.interceptors.whereType<AuthInterceptor>(), isNotEmpty);
  });
}
```
> 401→refresh→재시도 **동작**은 P2 Task 6(동시 401 큐잉 통합 테스트)에서 이미 검증됨. 여기선 **결선 여부**만 스모크(이중 검증 회피).

- [ ] **Step 2: 실패 확인** — Run: `cd apps/web && flutter test test/providers/auth_interceptor_wire_test.dart ; cd ../..` → FAIL

- [ ] **Step 3: 구현 — `apiClientProvider`에 AuthInterceptor 결선**

`apps/web/lib/src/providers/api_providers.dart`의 `apiClientProvider`를 교체:
```dart
final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);
  final store = ref.watch(tokenStoreProvider);
  final client = ApiClient.create(
      ApiConfig(baseUrl: config.baseUrl, useMock: config.useMock));

  // ENG-REVIEW D1: 401 큐잉 AuthInterceptor(P2) 결선 — onRequest Bearer 주입 + onError refresh/retry.
  // ApiClient.create가 에러 정규화 인터셉터를 마지막에 추가하므로, 그 앞(index 0)에 삽입한다.
  client.dio.interceptors.insert(0, AuthInterceptor(
    store: store,
    refresh: (refreshToken) async {
      final data = await client.post<Map<String, dynamic>>(
        '/auth/refresh',
        body: {'refreshToken': refreshToken},
      );
      return TokenPair(
        access: data['accessToken'] as String,
        refresh: data['refreshToken'] as String,
      );
    },
    retry: (options) => client.dio.fetch(options),
  ));

  if (config.useMock) {
    client.dio.httpClientAdapter = MockHttpAdapter(webMockFixtures);
  }
  return client;
});
```
> `'POST /auth/refresh'` 목 픽스처는 P4a `webMockFixtures`에 이미 존재. `client`는 인터셉터 추가 전에 생성되므로 refresh/retry 클로저에서 참조 가능.

- [ ] **Step 4: 통과 확인** — Run: `cd apps/web && flutter test test/providers/auth_interceptor_wire_test.dart ; cd ../..` → PASS

- [ ] **Step 5: 커밋**
```bash
git add apps/web/lib/src/providers/api_providers.dart apps/web/test/providers/auth_interceptor_wire_test.dart
git commit -m "fix(web): apiClientProvider에 AuthInterceptor 결선(401 큐잉, ENG-REVIEW D1)"
```

---

## Task 1: dp_core — PATH 도메인 모델 (`LearningPath`·`PathWeek`·`WeeklyTask`)

> P2 User와 동일한 freezed+json 패턴. 골든패스 렌더 최소 필드.

**Files:**
- Create: `packages/dp_core/lib/src/models/learning_path.dart`
- Modify: `packages/dp_core/lib/dp_core.dart`
- Test: `packages/dp_core/test/models/learning_path_test.dart`

- [ ] **Step 1: 실패 테스트**

Create `packages/dp_core/test/models/learning_path_test.dart`:
```dart
import 'package:dp_core/src/models/learning_path.dart';
import 'package:test/test.dart';

void main() {
  test('LearningPath JSON 역직렬화(주차·과제·rationale)', () {
    final path = LearningPath.fromJson({
      'rationale': 'GitHub 분석 결과 비동기 보강 필요',
      'weeks': [
        {
          'week': 1,
          'title': '비동기 기초',
          'tasks': [
            {'title': 'Future 정리', 'done': false},
            {'title': 'Stream 실습', 'done': true},
          ],
        },
        {'week': 2, 'title': '주차 2', 'tasks': <Map<String, dynamic>>[]},
      ],
    });

    expect(path.rationale, contains('비동기'));
    expect(path.weeks, hasLength(2));
    expect(path.weeks.first.week, 1);
    expect(path.weeks.first.tasks, hasLength(2));
    expect(path.weeks.first.tasks[1].done, isTrue);
    expect(path.weeks[1].tasks, isEmpty); // 기본값
  });
}
```

- [ ] **Step 2: 실패 확인** — Run: `cd packages/dp_core && dart test test/models/learning_path_test.dart ; cd ../..` → FAIL

- [ ] **Step 3: 구현**

Create `packages/dp_core/lib/src/models/learning_path.dart`:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'learning_path.freezed.dart';
part 'learning_path.g.dart';

/// 학습 경로(PATH-001 결과). 12주 타임라인 + 멘토 rationale.
@freezed
abstract class LearningPath with _$LearningPath {
  const factory LearningPath({
    required String rationale,
    @Default(<PathWeek>[]) List<PathWeek> weeks,
  }) = _LearningPath;

  factory LearningPath.fromJson(Map<String, dynamic> json) =>
      _$LearningPathFromJson(json);
}

@freezed
abstract class PathWeek with _$PathWeek {
  const factory PathWeek({
    required int week,
    required String title,
    @Default(<WeeklyTask>[]) List<WeeklyTask> tasks,
  }) = _PathWeek;

  factory PathWeek.fromJson(Map<String, dynamic> json) =>
      _$PathWeekFromJson(json);
}

@freezed
abstract class WeeklyTask with _$WeeklyTask {
  const factory WeeklyTask({
    required String title,
    @Default(false) bool done,
  }) = _WeeklyTask;

  factory WeeklyTask.fromJson(Map<String, dynamic> json) =>
      _$WeeklyTaskFromJson(json);
}
```

- [ ] **Step 4: codegen**

Run:
```bash
cd packages/dp_core && dart run build_runner build --delete-conflicting-outputs ; cd ../..
```
Expected: `learning_path.freezed.dart`·`learning_path.g.dart` 생성(커밋함 — CI는 build_runner 미실행).

- [ ] **Step 5: barrel export 추가**

`packages/dp_core/lib/dp_core.dart`의 models export 옆에 추가:
```dart
export 'src/models/learning_path.dart';
```

- [ ] **Step 6: 통과 확인** — Run: `cd packages/dp_core && dart test test/models/learning_path_test.dart ; cd ../..` → PASS

- [ ] **Step 7: 커밋**
```bash
git add packages/dp_core/lib/src/models/learning_path.dart packages/dp_core/lib/src/models/learning_path.freezed.dart packages/dp_core/lib/src/models/learning_path.g.dart packages/dp_core/lib/dp_core.dart packages/dp_core/test/models/learning_path_test.dart
git commit -m "feat(dp_core): LearningPath·PathWeek·WeeklyTask 모델(PATH-001)"
```

---

## Task 2: web — 온보딩/진단 + 게이트 해제

> 진단 제출 → `POST /onboarding`(목) → DONE 유저 → `AuthController.onboardingCompleted` → `/path`로 이동. 게이트는 온보딩 완료 후 `/onboarding`을 막지 않도록 보정(페이지가 `/path`로 안내).

**Files:**
- Create: `apps/web/lib/src/features/onboarding/state/onboarding_state.dart`, `apps/web/lib/src/features/onboarding/application/onboarding_controller.dart`, `apps/web/lib/src/features/onboarding/presentation/onboarding_page.dart`
- Modify: `apps/web/lib/src/features/auth/application/auth_controller.dart`(`onboardingCompleted`), `apps/web/lib/src/data/web_mock_fixtures.dart`(`POST /onboarding`), `apps/web/lib/src/app/router.dart`(게이트 + ONB 라우트)
- Delete: `apps/web/lib/src/features/onboarding/presentation/onboarding_placeholder.dart`
- Test: `apps/web/test/features/onboarding/onboarding_controller_test.dart`

- [ ] **Step 1: 실패 테스트**

Create `apps/web/test/features/onboarding/onboarding_controller_test.dart`:
```dart
import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/features/onboarding/application/onboarding_controller.dart';
import 'package:devpath_web/src/features/onboarding/state/onboarding_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('진단 제출 → 온보딩 완료 + auth 유저가 DONE으로 갱신', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // 선행: 로그인(PENDING)
    await container.read(authControllerProvider.notifier).login();
    expect(
      (container.read(authControllerProvider) as AuthAuthenticated)
          .user
          .onboardingStatus,
      OnboardingStatus.pending,
    );

    await container
        .read(onboardingControllerProvider.notifier)
        .submit(githubHandle: 'jisoo-dev');

    expect(container.read(onboardingControllerProvider), isA<OnboardingDone>());
    final user =
        (container.read(authControllerProvider) as AuthAuthenticated).user;
    expect(user.onboardingStatus, OnboardingStatus.done);
  });
}
```

- [ ] **Step 2: 실패 확인** — Run: `cd apps/web && flutter test test/features/onboarding/onboarding_controller_test.dart ; cd ../..` → FAIL

- [ ] **Step 3: `AuthController.onboardingCompleted` 추가**

`apps/web/lib/src/features/auth/application/auth_controller.dart`의 `logout` 아래에 추가:
```dart
  /// 온보딩 완료로 갱신된 유저 반영(게이트 재평가 트리거).
  void onboardingCompleted(User user) {
    if (state is AuthAuthenticated) state = AuthAuthenticated(user);
  }
```

- [ ] **Step 4: 목 픽스처에 `POST /onboarding` 추가**

`apps/web/lib/src/data/web_mock_fixtures.dart`를 다음으로 교체(P4a의 const를 `final`로 — Task 3에서 동적 경로 픽스처도 추가):
```dart
import 'package:dp_core/dp_core.dart';

/// web 프로토 목 REST 픽스처: `'METHOD /path'` → (status, jsonBody).
final Map<String, MockFixture> webMockFixtures = {
  'POST /auth/login': (
    200,
    {
      'accessToken': 'mock-access',
      'refreshToken': 'mock-refresh',
      'user': {
        'id': 'u-mock',
        'email': 'learner@devpath.ai',
        'nickname': '지수',
        'role': 'LEARNER',
        'onboardingStatus': 'PENDING',
      },
    },
  ),
  'POST /auth/refresh': (
    200,
    {'accessToken': 'mock-access-2', 'refreshToken': 'mock-refresh-2'},
  ),
  // 진단 제출 → DONE 유저 반환(게이트 해제)
  'POST /onboarding': (
    200,
    {
      'user': {
        'id': 'u-mock',
        'email': 'learner@devpath.ai',
        'nickname': '지수',
        'role': 'LEARNER',
        'onboardingStatus': 'DONE',
      },
    },
  ),
};
```

- [ ] **Step 5: 구현 — `onboarding_state.dart`**

Create `apps/web/lib/src/features/onboarding/state/onboarding_state.dart`:
```dart
sealed class OnboardingState {
  const OnboardingState();
}

class OnboardingIdle extends OnboardingState {
  const OnboardingIdle();
}

class OnboardingSubmitting extends OnboardingState {
  const OnboardingSubmitting();
}

class OnboardingDone extends OnboardingState {
  const OnboardingDone();
}

class OnboardingError extends OnboardingState {
  const OnboardingError(this.message);
  final String message;
}
```

- [ ] **Step 6: 구현 — `onboarding_controller.dart`**

Create `apps/web/lib/src/features/onboarding/application/onboarding_controller.dart`:
```dart
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../state/onboarding_state.dart';

/// 최소 진단 제출(GitHub 핸들). 실제 문항은 외부 06_화면_기능_정의서로 정렬.
class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() => const OnboardingIdle();

  Future<void> submit({required String githubHandle}) async {
    state = const OnboardingSubmitting();
    try {
      final json = await ref.read(apiClientProvider).post<Map<String, dynamic>>(
            '/onboarding',
            body: {'githubHandle': githubHandle},
          );
      final user =
          User.fromJson((json['user'] as Map).cast<String, dynamic>());
      ref.read(authControllerProvider.notifier).onboardingCompleted(user);
      state = const OnboardingDone();
    } on ApiException catch (e) {
      state = OnboardingError(e.message);
    }
  }
}

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
        OnboardingController.new);
```

- [ ] **Step 7: 통과 확인** — Run: `cd apps/web && flutter test test/features/onboarding/onboarding_controller_test.dart ; cd ../..` → PASS

- [ ] **Step 8: 구현 — `onboarding_page.dart` + 게이트 보정 + 플레이스홀더 삭제**

Create `apps/web/lib/src/features/onboarding/presentation/onboarding_page.dart`:
```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/onboarding_controller.dart';
import '../state/onboarding_state.dart';

/// 최소 진단 화면(ONB). 제출 성공 시 PATH 생성으로 이동.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _handle = TextEditingController();

  @override
  void dispose() {
    _handle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final c = context.dpColors;

    // 제출 완료 → PATH 생성 화면으로(게이트는 onboarding 완료 시 /onboarding 강제 안 함).
    ref.listen(onboardingControllerProvider, (_, next) {
      if (next is OnboardingDone) context.go('/path');
    });

    final submitting = state is OnboardingSubmitting;

    return Scaffold(
      appBar: AppBar(title: const Text('진단')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(DpSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('GitHub 계정을 분석해 경로를 만들어요',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: DpSpacing.lg),
                TextField(
                  controller: _handle,
                  enabled: !submitting,
                  decoration: const InputDecoration(
                    labelText: 'GitHub 핸들',
                    hintText: '예: jisoo-dev',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (state is OnboardingError) ...[
                  const SizedBox(height: DpSpacing.sm),
                  Text(state.message,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: c.danger)),
                ],
                const SizedBox(height: DpSpacing.lg),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () => ref
                          .read(onboardingControllerProvider.notifier)
                          .submit(githubHandle: _handle.text.trim()),
                  child: Text(submitting ? '분석 준비 중…' : '진단 시작하기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

`apps/web/lib/src/app/router.dart` 수정:
- `gateRedirect`의 마지막 분기에서 `atOnboarding` 바운스를 제거(온보딩 완료 후 페이지가 `/path`로 안내하도록):
```dart
  if (atLogin) return '/dashboard'; // 기존: if (atLogin || atOnboarding)
  return null;
```
- import에서 `onboarding_placeholder.dart`를 `onboarding_page.dart`로 교체하고 `/onboarding` 라우트 builder를 `const OnboardingPage()`로 변경.

플레이스홀더 삭제:
```bash
rm apps/web/lib/src/features/onboarding/presentation/onboarding_placeholder.dart
```

- [ ] **Step 9: 게이트 테스트 보강**

`apps/web/test/app/gate_redirect_test.dart`의 `group`에 추가(완료 유저가 `/onboarding`에서 막히지 않음):
```dart
    test('인증 + 온보딩 완료 + /onboarding → 그대로(null, 페이지가 /path로 안내)', () {
      expect(
        gateRedirect(AuthAuthenticated(_user(OnboardingStatus.done)), '/onboarding'),
        isNull,
      );
    });
```

- [ ] **Step 10: 통과 확인** — Run: `cd apps/web && flutter test test/app/gate_redirect_test.dart test/features/onboarding ; cd ../..` → PASS

- [ ] **Step 11: 커밋**
```bash
git add apps/web/lib/src/features/onboarding apps/web/lib/src/features/auth/application/auth_controller.dart apps/web/lib/src/data/web_mock_fixtures.dart apps/web/lib/src/app/router.dart apps/web/test/features/onboarding apps/web/test/app/gate_redirect_test.dart
git rm apps/web/lib/src/features/onboarding/presentation/onboarding_placeholder.dart
git commit -m "feat(web): 온보딩 진단(목) + 게이트 해제 → PATH 생성 이동"
```

---

## Task 3: web — PATH SSE 소스 주입 (`pathSseConnectProvider`)

> 목/실서버 SSE를 교체 주입. `fromStep`으로 이어하기(중단 지점부터) 지원. 목은 dp_core `MockSseSource`, 실서버는 `SseClient`.

**Files:**
- Create: `apps/web/lib/src/features/path/data/path_sse_source.dart`
- Modify: `apps/web/lib/src/data/web_mock_fixtures.dart`(`GET /learning-paths/me`)
- Test: `apps/web/test/features/path/path_sse_source_test.dart`

- [ ] **Step 1: 실패 테스트(목 소스가 fromStep부터 단계 emit)**

Create `apps/web/test/features/path/path_sse_source_test.dart`:
```dart
import 'dart:convert';

import 'package:devpath_web/src/features/path/data/path_sse_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('목 소스는 fromStep부터 단계를 emit한다', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final connect = container.read(pathSseConnectProvider);
    final steps = await connect(fromStep: 2)
        .map((e) => (jsonDecode(e.data) as Map)['step'] as String)
        .toList();

    expect(steps, ['BUILD', 'DONE']); // kSseSteps[2..] = BUILD, DONE
  });
}
```

- [ ] **Step 2: 실패 확인** — Run: `cd apps/web && flutter test test/features/path/path_sse_source_test.dart ; cd ../..` → FAIL

- [ ] **Step 3: 구현 — `path_sse_source.dart`**

Create `apps/web/lib/src/features/path/data/path_sse_source.dart`:
```dart
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';

/// SSE 와이어 단계(목 emit 순서). 마지막 DONE은 완료 신호.
const List<String> kSseSteps = ['ANALYZE', 'MAP', 'BUILD', 'DONE'];

/// 사용자에게 보이는 단계 라벨(DONE 제외 3단계, DESIGN §8 / 스펙 §4).
const List<String> kPathStageLabels = ['GitHub 분석', '약점 매핑', '주차 배치'];

/// `fromStep`(kSseSteps 인덱스)부터 SSE 이벤트를 흘리는 함수.
typedef PathSseConnect = Stream<SseEvent> Function({int fromStep});

/// 목=MockSseSource, 실서버=SseClient. useMock로 교체.
final pathSseConnectProvider = Provider<PathSseConnect>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMock) {
    return ({int fromStep = 0}) => MockSseSource(
          stages: kSseSteps.sublist(fromStep),
          delay: const Duration(milliseconds: 250),
        ).stream();
  }
  final client = ref.watch(apiClientProvider);
  return ({int fromStep = 0}) => SseClient(client.dio).connect(
        '/learning-paths/me/generate',
        body: {'fromStep': fromStep},
      );
});
```

- [ ] **Step 4: 목 픽스처에 `GET /learning-paths/me` 추가**

`apps/web/lib/src/data/web_mock_fixtures.dart`에 결과 픽스처 추가 — 파일에 헬퍼와 엔트리를 더한다:
```dart
/// 12주 경로 목 데이터(week1만 과제 3개, 나머지는 제목만).
Map<String, dynamic> mockLearningPath() => {
      'rationale': 'GitHub 분석 결과 비동기·테스트 역량 보강이 필요해 12주 경로를 구성했어요.',
      'weeks': [
        {
          'week': 1,
          'title': '비동기 기초',
          'tasks': [
            {'title': 'Future/async-await 정리', 'done': false},
            {'title': 'Stream 구독 실습', 'done': false},
            {'title': '에러 처리 패턴 적용', 'done': false},
          ],
        },
        for (var w = 2; w <= 12; w++)
          {'week': w, 'title': '주차 $w 학습', 'tasks': <Map<String, dynamic>>[]},
      ],
    };
```
그리고 `webMockFixtures` 맵에 엔트리 추가:
```dart
  'GET /learning-paths/me': (200, mockLearningPath()),
```
> `webMockFixtures`는 Task 2에서 `final`로 바뀜 → 동적 `mockLearningPath()` 값 허용.

- [ ] **Step 5: 통과 확인** — Run: `cd apps/web && flutter test test/features/path/path_sse_source_test.dart ; cd ../..` → PASS

- [ ] **Step 6: 커밋**
```bash
git add apps/web/lib/src/features/path/data apps/web/lib/src/data/web_mock_fixtures.dart apps/web/test/features/path/path_sse_source_test.dart
git commit -m "feat(web): PATH SSE 소스 주입(목/실서버 교체 + fromStep 이어하기)"
```

---

## Task 4: web — `PathController` (생성 + DD8 이어하기/재연결)

> **DD8 핵심(스펙 VERDICT·T5).** 단계 누적 → 중단 시 완료 단계 보존(`partial`) → `resume()`로 끊긴 지점부터 재연결. 전체 재시작 금지.

**Files:**
- Create: `apps/web/lib/src/features/path/application/path_controller.dart`
- Test: `apps/web/test/features/path/path_controller_test.dart`

- [ ] **Step 1: 실패 테스트(정상 완료 + 중단→보존→이어하기)**

Create `apps/web/test/features/path/path_controller_test.dart`:
```dart
import 'package:devpath_web/src/features/path/application/path_controller.dart';
import 'package:devpath_web/src/features/path/data/path_sse_source.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Stream<SseEvent> _emit(List<String> steps) async* {
  for (final s in steps) {
    yield SseEvent(event: 'stage', data: '{"step":"$s"}');
  }
}

Stream<SseEvent> _emitThenError(List<String> steps) async* {
  yield* _emit(steps);
  throw Exception('연결 끊김');
}

void main() {
  test('정상: 4단계 후 완료(타임라인 결과 로드)', () async {
    final container = ProviderContainer(overrides: [
      pathSseConnectProvider.overrideWithValue(
          ({int fromStep = 0}) => _emit(kSseSteps.sublist(fromStep))),
    ]);
    addTearDown(container.dispose);

    await container.read(pathControllerProvider.notifier).start();

    final s = container.read(pathControllerProvider);
    expect(s.phase, PathPhase.complete);
    expect(s.completed, kPathStageLabels); // 3단계 모두
    expect(s.result, isNotNull);
    expect(s.result!.weeks, hasLength(12));
    expect(s.result!.weeks.first.tasks, hasLength(3));
  });

  test('DD8: 중단 시 완료 단계 보존 후 이어하기로 완성', () async {
    var calls = 0;
    final container = ProviderContainer(overrides: [
      pathSseConnectProvider.overrideWithValue(({int fromStep = 0}) {
        calls++;
        return calls == 1
            ? _emitThenError(['ANALYZE', 'MAP']) // 2단계 후 끊김
            : _emit(kSseSteps.sublist(fromStep)); // 이어하기: BUILD, DONE
      }),
    ]);
    addTearDown(container.dispose);

    final ctrl = container.read(pathControllerProvider.notifier);
    await ctrl.start();

    var s = container.read(pathControllerProvider);
    expect(s.phase, PathPhase.partial); // 중단
    expect(s.completed, ['GitHub 분석', '약점 매핑']); // 완료 단계 보존
    expect(s.result, isNull);

    await ctrl.resume(); // 끊긴 지점(fromStep=2)부터

    s = container.read(pathControllerProvider);
    expect(calls, 2); // 전체 재시작 아님 — resume 1회
    expect(s.phase, PathPhase.complete);
    expect(s.completed, kPathStageLabels);
    expect(s.result, isNotNull);
  });
}
```

- [ ] **Step 2: 실패 확인** — Run: `cd apps/web && flutter test test/features/path/path_controller_test.dart ; cd ../..` → FAIL

- [ ] **Step 3: 구현**

Create `apps/web/lib/src/features/path/application/path_controller.dart`:
```dart
import 'dart:async';
import 'dart:convert';

import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../data/path_sse_source.dart';

enum PathPhase { idle, streaming, partial, complete, failed }

/// PATH 생성 상태. [completed]=완료 단계 라벨(중단 시 보존), [current]=진행 라벨.
class PathState {
  const PathState({
    this.phase = PathPhase.idle,
    this.completed = const [],
    this.current,
    this.result,
    this.error,
  });

  final PathPhase phase;
  final List<String> completed;
  final String? current;
  final LearningPath? result;
  final String? error;

  PathState copyWith({
    PathPhase? phase,
    List<String>? completed,
    String? current,
    LearningPath? result,
    String? error,
  }) =>
      PathState(
        phase: phase ?? this.phase,
        completed: completed ?? this.completed,
        current: current,
        result: result ?? this.result,
        error: error,
      );
}

class PathController extends Notifier<PathState> {
  StreamSubscription<SseEvent>? _sub;

  @override
  PathState build() {
    ref.onDispose(() => _sub?.cancel());
    return const PathState();
  }

  /// 처음부터 생성.
  Future<void> start() => _run(fromStep: 0);

  /// 중단 지점(완료 단계 수)부터 이어하기 — 전체 재시작 아님(DD8).
  Future<void> resume() => _run(fromStep: state.completed.length);

  Future<void> _run({required int fromStep}) {
    _sub?.cancel();
    final done = Completer<void>();

    state = PathState(
      phase: PathPhase.streaming,
      completed: kPathStageLabels.take(fromStep).toList(),
      current: fromStep < kPathStageLabels.length
          ? kPathStageLabels[fromStep]
          : null,
    );

    _sub = ref.read(pathSseConnectProvider)(fromStep: fromStep).listen(
      (event) async {
        final step = _stepOf(event.data);
        if (step == 'DONE') {
          await _sub?.cancel(); // onDone 경합 방지
          await _loadResult();
          if (!done.isCompleted) done.complete();
          return;
        }
        final idx = kSseSteps.indexOf(step ?? '');
        if (idx < 0 || idx >= kPathStageLabels.length) return;
        state = state.copyWith(
          completed: kPathStageLabels.take(idx + 1).toList(),
          current: idx + 1 < kPathStageLabels.length
              ? kPathStageLabels[idx + 1]
              : null,
        );
      },
      onError: (Object _) {
        // 중단 — 완료 단계 보존, 이어하기 가능.
        state = state.copyWith(phase: PathPhase.partial, error: 'SSE 연결이 끊겼어요');
        if (!done.isCompleted) done.complete();
      },
      onDone: () {
        // DONE 없이 정상 종료 = 중단으로 간주.
        if (state.phase == PathPhase.streaming) {
          state = state.copyWith(phase: PathPhase.partial, error: '생성이 중단됐어요');
        }
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );

    return done.future;
  }

  Future<void> _loadResult() async {
    try {
      final json = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/learning-paths/me');
      state = state.copyWith(
        phase: PathPhase.complete,
        completed: kPathStageLabels,
        result: LearningPath.fromJson(json),
      );
    } on ApiException catch (e) {
      state = state.copyWith(phase: PathPhase.failed, error: e.message);
    }
  }

  String? _stepOf(String data) {
    try {
      final m = jsonDecode(data);
      return (m is Map && m['step'] is String) ? m['step'] as String : null;
    } catch (_) {
      return null;
    }
  }
}

final pathControllerProvider =
    NotifierProvider<PathController, PathState>(PathController.new);
```
> `copyWith`의 `current`/`error`는 의도적으로 null 전달 가능(진행 라벨·에러 해제). `result`는 nullable이나 누적 보존을 위해 `??` 유지(완료 시 한 번만 세팅).

- [ ] **Step 4: 통과 확인** — Run: `cd apps/web && flutter test test/features/path/path_controller_test.dart ; cd ../..` → PASS(정상 + DD8 둘 다)

- [ ] **Step 5: 커밋**
```bash
git add apps/web/lib/src/features/path/application apps/web/test/features/path/path_controller_test.dart
git commit -m "feat(web): PathController — SSE 생성 + DD8 중단 보존·이어하기"
```

---

## Task 5: web — PATH 화면 (`PathPage` + `PathPlanView`)

> 진행=DpSseStageView, 부분=단계 보존+이어서 생성(DD8), 완료=12주 타임라인+이번 주 과제 3+rationale, 실패=DpError.

**Files:**
- Create: `apps/web/lib/src/features/path/presentation/path_page.dart`, `apps/web/lib/src/features/path/presentation/path_plan_view.dart`
- Test: `apps/web/test/features/path/path_page_test.dart`

- [ ] **Step 1: 실패 테스트(상태별 렌더)**

Create `apps/web/test/features/path/path_page_test.dart`:
```dart
import 'package:devpath_web/src/features/path/application/path_controller.dart';
import 'package:devpath_web/src/features/path/data/path_sse_source.dart';
import 'package:devpath_web/src/features/path/presentation/path_page.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Stream<SseEvent> _emit(List<String> steps) async* {
  for (final s in steps) {
    yield SseEvent(event: 'stage', data: '{"step":"$s"}');
  }
}

Stream<SseEvent> _emitThenError(List<String> steps) async* {
  yield* _emit(steps);
  throw Exception('끊김');
}

Widget _host(ProviderContainer c) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: DpTheme.light(), home: const PathPage()),
    );

void main() {
  testWidgets('완료 시 12주 타임라인과 이번 주 과제를 렌더', (tester) async {
    final c = ProviderContainer(overrides: [
      pathSseConnectProvider.overrideWithValue(
          ({int fromStep = 0}) => _emit(kSseSteps.sublist(fromStep))),
    ]);
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    expect(c.read(pathControllerProvider).phase, PathPhase.complete);
    expect(find.textContaining('비동기 기초'), findsWidgets); // week1 제목
    expect(find.text('Stream 구독 실습'), findsOneWidget); // 이번 주 과제
  });

  testWidgets('중단 시 "이어서 생성" 노출(DD8)', (tester) async {
    final c = ProviderContainer(overrides: [
      pathSseConnectProvider.overrideWithValue(
          ({int fromStep = 0}) => _emitThenError(['ANALYZE', 'MAP'])),
    ]);
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    expect(c.read(pathControllerProvider).phase, PathPhase.partial);
    expect(find.text('이어서 생성'), findsOneWidget);
    expect(find.byType(DpSseStageView), findsOneWidget); // 완료 단계 보존 표시
  });
}
```

- [ ] **Step 2: 실패 확인** — Run: `cd apps/web && flutter test test/features/path/path_page_test.dart ; cd ../..` → FAIL

- [ ] **Step 3: 구현 — `path_plan_view.dart`**

Create `apps/web/lib/src/features/path/presentation/path_plan_view.dart`:
```dart
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

/// 완료된 경로: 멘토 rationale + 이번 주 과제 + 12주 타임라인.
class PathPlanView extends StatelessWidget {
  const PathPlanView({super.key, required this.plan});
  final LearningPath plan;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;
    final thisWeek = plan.weeks.isNotEmpty ? plan.weeks.first : null;

    return ListView(
      padding: const EdgeInsets.all(DpSpacing.lg),
      children: [
        Text('학습 경로', style: text.headlineSmall),
        const SizedBox(height: DpSpacing.sm),
        Container(
          padding: const EdgeInsets.all(DpSpacing.md),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(DpRadius.card),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(DpIcons.mentor, size: 18, color: c.primaryText),
              const SizedBox(width: DpSpacing.sm),
              Expanded(
                child: Text(plan.rationale,
                    style: text.bodyMedium?.copyWith(color: c.textSecondary)),
              ),
            ],
          ),
        ),
        if (thisWeek != null) ...[
          const SizedBox(height: DpSpacing.xl),
          Text('이번 주 과제', style: text.titleMedium),
          const SizedBox(height: DpSpacing.sm),
          for (final t in thisWeek.tasks)
            ListTile(
              dense: true,
              leading: Icon(
                  t.done ? DpIcons.stepDone : DpIcons.stepPending,
                  color: t.done ? c.success : c.textSecondary),
              title: Text(t.title, style: text.bodyMedium),
            ),
        ],
        const SizedBox(height: DpSpacing.xl),
        Text('12주 타임라인', style: text.titleMedium),
        const SizedBox(height: DpSpacing.sm),
        for (final w in plan.weeks)
          ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: c.primary,
              child: Text('${w.week}',
                  style: text.labelLarge?.copyWith(color: c.onPrimary)),
            ),
            title: Text(w.title, style: text.bodyMedium),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: 구현 — `path_page.dart`**

Create `apps/web/lib/src/features/path/presentation/path_page.dart`:
```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/path_controller.dart';
import '../data/path_sse_source.dart';
import 'path_plan_view.dart';

/// PATH-001. 진입 시 생성 시작, 상태별 렌더(진행/부분/완료/실패).
class PathPage extends ConsumerStatefulWidget {
  const PathPage({super.key});

  @override
  ConsumerState<PathPage> createState() => _PathPageState();
}

class _PathPageState extends ConsumerState<PathPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(pathControllerProvider).phase == PathPhase.idle) {
        ref.read(pathControllerProvider.notifier).start();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(pathControllerProvider);
    final notifier = ref.read(pathControllerProvider.notifier);

    final body = switch (s.phase) {
      PathPhase.complete when s.result != null => PathPlanView(plan: s.result!),
      PathPhase.failed => DpError(
          message: s.error ?? '경로 생성에 실패했어요',
          onRetry: notifier.start,
        ),
      PathPhase.partial => _Progress(
          completed: s.completed,
          current: s.current,
          note: s.error ?? '연결이 끊겼어요',
          onResume: notifier.resume,
        ),
      _ => _Progress(completed: s.completed, current: s.current),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('학습 경로 생성')),
      body: body,
    );
  }
}

/// SSE 진행/부분 공통: 단계 표시 + (중단 시) 이어서 생성.
class _Progress extends StatelessWidget {
  const _Progress({
    required this.completed,
    this.current,
    this.note,
    this.onResume,
  });

  final List<String> completed;
  final String? current;
  final String? note;
  final VoidCallback? onResume;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    // 완료+현재 라벨을 합쳐 단계 리스트 구성, currentIndex=완료 수.
    final stages = [
      ...completed,
      if (current != null && !completed.contains(current)) current!,
    ];
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DpSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DpSseStageView(stages: stages, currentIndex: completed.length),
            if (note != null) ...[
              const SizedBox(height: DpSpacing.lg),
              Text(note!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: c.warning)),
            ],
            if (onResume != null) ...[
              const SizedBox(height: DpSpacing.md),
              FilledButton(onPressed: onResume, child: const Text('이어서 생성')),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: 통과 확인** — Run: `cd apps/web && flutter test test/features/path/path_page_test.dart ; cd ../..` → PASS

- [ ] **Step 6: 커밋**
```bash
git add apps/web/lib/src/features/path/presentation apps/web/test/features/path/path_page_test.dart
git commit -m "feat(web): PATH 화면(진행/이어하기/타임라인 결과)"
```

---

## Task 6: web — 라우터 결선(PATH) + 골든패스 통합 스모크 + 전체 검증

**Files:**
- Modify: `apps/web/lib/src/app/router.dart`(`/path` → `PathPage`)
- Create: `apps/web/test/golden_path_onboarding_test.dart`

- [ ] **Step 1: `/path` 라우트를 실제 화면으로 교체**

`apps/web/lib/src/app/router.dart`의 ShellRoute 내 `/path` builder를 교체:
```dart
import '../features/path/presentation/path_page.dart';
// ...
GoRoute(path: '/path', builder: (_, __) => const PathPage()),
```
> `/dashboard`·`/mentor`·`/community`는 P4c/P4d까지 `PlaceholderPage` 유지.

- [ ] **Step 2: 골든패스 통합 스모크(로그인→온보딩→진단→PATH 생성)**

Create `apps/web/test/golden_path_onboarding_test.dart`:
```dart
import 'package:devpath_web/src/app/app.dart';
import 'package:devpath_web/src/features/onboarding/presentation/onboarding_page.dart';
import 'package:devpath_web/src/features/path/presentation/path_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('로그인 → 온보딩 진단 → PATH 생성까지 게이트 흐름', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DevPathWebApp()));
    await tester.pumpAndSettle();

    // 로그인(PENDING) → 온보딩
    await tester.tap(find.text('GitHub로 계속하기 (목)'));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingPage), findsOneWidget);

    // 진단 제출 → PATH 생성 화면 + 목 SSE 완료(타임라인)
    await tester.enterText(find.byType(TextField), 'jisoo-dev');
    await tester.tap(find.text('진단 시작하기'));
    await tester.pumpAndSettle();

    expect(find.byType(PathPage), findsOneWidget);
    expect(find.textContaining('비동기 기초'), findsWidgets); // 생성 완료된 타임라인
  });
}
```
> 목 SSE delay(250ms×4)는 `pumpAndSettle`이 흡수. 느리면 `tester.pump(const Duration(seconds: 2))` 후 재settle.

- [ ] **Step 3: 전체 검증**

Run (레포 루트):
```bash
melos run analyze
melos run test
```
Expected: `dp_core`·`devpath_web` 포함 `analyze` 이슈 없음, `test` 전 멤버 PASS(골든 제외).

- [ ] **Step 4: 커밋**
```bash
git add apps/web/lib/src/app/router.dart apps/web/test/golden_path_onboarding_test.dart
git commit -m "feat(web): PATH 라우트 결선 + 온보딩→PATH 골든패스 스모크"
```

---

## 검증 기준 (Definition of Done)

- [ ] `melos run analyze` — `dp_core`·`devpath_web` 이슈 없음
- [ ] `melos run test` — dp_core(LearningPath) + web(onboarding·path-sse·path-controller·path-page·gate·smoke) PASS
- [ ] 진단 제출 → `onboardingStatus=DONE` 반영 → 게이트 해제 → `/path` 이동
- [ ] PATH 생성: 4단계 SSE 진행 표시(DpSseStageView) → 완료 시 12주 타임라인 + 이번 주 과제 3 + 멘토 rationale
- [ ] **DD8**: SSE 중단 시 완료 단계 보존(`partial`) + "이어서 생성"으로 끊긴 지점부터 재연결(전체 재시작 아님) — 단위·위젯 테스트로 실증
- [ ] PATH 결과는 SSE `DONE` 후 `GET /learning-paths/me`로 조회(스펙 §3 비동기 결과 조회 패턴)

## 리스크 / 후속 (명시)

- **온보딩 문항 미명세**: 실제 ONB-001/002 진단 항목은 외부 `06_화면_기능_정의서`에 있음 → 본 플랜은 GitHub 핸들 1개로 최소화. 구현 시 실제 문항으로 확장(추측 금지).
- **실서버 SSE 미검증**: `pathSseConnectProvider`의 실서버 분기(`SseClient.connect`)는 목 프로토에선 미실행. 실서버 연동 시 `/learning-paths/me/generate`의 `fromStep` 재개 프로토콜을 백엔드와 합의(현재 목만 `fromStep` 지원).
- **PATH 중 KILL_SWITCH/Quota 미처리(§9.2)**: 본 플랜은 SSE 끊김(partial/이어하기 — DD8)과 결과 조회 실패(failed)만 처리. `AI_KILL_SWITCH_ACTIVE`(503)→`DpKillSwitch`·`QUOTA_EXCEEDED`(429)→`DpQuota` 분기(위젯은 P3에 존재)는 **AI 리뷰·멘토와 동일 패턴이라 P4c에서 일괄 적용**한다. 통합 지점: `PathController._run`의 `onError`/`_loadResult` `catch`에서 `ApiException.isKillSwitch`/`isQuota`를 분기해 전용 phase로 매핑.
- **DD8 재연결 정책**: 본 구현은 "완료 단계 수 = 재개 인덱스"의 단순 모델. 실제 SSE `id:`/`Last-Event-ID` 기반 재개(스펙 §3 표준)는 dp_core `SseClient` 확장 시 정렬(P2 "id:/retry: 범위 밖" 후속).
- **이번 주 과제 = weeks.first**: 현재 주차 계산(진행률 기반)은 대시보드(P4d)에서. P4b는 첫 주를 "이번 주"로 표시.
- **eng-review 게이트**: DD8 재연결은 아키텍처 영향 → 구현 착수 전 `/plan-eng-review` 권장.
