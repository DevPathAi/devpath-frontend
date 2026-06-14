# P4d — AI 코드리뷰(REV-001) + KILL_SWITCH/Quota (Implementation Plan)

> 🔶 **Eng Review 반영(2026-06-14, F6)** — 엔지니어링 리뷰 결정(F6-a~f)을 반영: KILL_SWITCH 대체행동 배선·Retry-After null 안전·카운트다운 정적표시 강등·비동기 폴링 deferral·렌더 테스트 보강. 결정 근거: [`../specs/2026-06-14-eng-review-summary.md`](../specs/2026-06-14-eng-review-summary.md).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** P4c Sandbox의 리뷰 칸(`_ReviewPlaceholder`)을 **AI 코드리뷰(REV-001)** 로 채운다 — 신뢰도·잘한점·개선(라인·심각도)·보안 + 👍👎 피드백을 렌더하고, **`AI_KILL_SWITCH_ACTIVE`(503)→`DpKillSwitch`·`QUOTA_EXCEEDED`(429)→`DpQuota`**(Retry-After **정적 표시** — F6, 카운트다운 아님)를 일괄 처리한다(P4b·P4c가 이월한 §9.2 상태).

> **F6-d 계약 스코프(카운트다운→정적 표시 강등):** §9.2 계약의 "Retry-After 카운트다운"은 본 프로토에서 **정적 표시로 강등**한다. 사유: P3 `DpQuota`는 StatelessWidget(정적 텍스트)이라 카운트다운(StatefulWidget+Timer)은 P3 범위 확대에 해당. 카운트다운은 **후속(P3 `DpQuota` Stateful 전환)** 으로 이월하고 본 플랜에서는 구현하지 않는다.

**Architecture:** P4a~c 토대 위. 리뷰 모델은 dp_core freezed(`CodeReview`/`ReviewIssue`). `ReviewController`(Riverpod `Notifier`)가 `POST /reviews`(목) 호출 후 `ApiException.isKillSwitch`/`isQuota`로 상태 분기 → `ReviewState` sealed. `ReviewPanel`(dp_design 상태위젯 소비)이 SBX 3페인의 리뷰 칸을 대체. web `dio`-free 유지(dp_core `ApiClient.post` 경유).

**Tech Stack:** Flutter Web · flutter_riverpod 3.3 · dp_core(freezed·ApiException)·dp_design(DpKillSwitch·DpQuota·상태위젯) · flutter_test.

---

> **선행:** P4a·P4b·P4c 구현 완료. 본 플랜은 P4c의 `SandboxPage`·`_ReviewPlaceholder`를 수정.
> **참조:** 스펙 §4(REV 와이어프레임: 신뢰도·잘한점·개선[라인·심각도]·보안+👍👎·멘토질문)·§9.2(AI 코드리뷰 행: LOADING/ERROR[KILL_SWITCH·QUOTA]/SUCCESS/PARTIAL)·DD4. DESIGN.md §8(KillSwitch·Quota). 샘플(스펙 §7): `Flutter_재사용_다이얼로그_Confirm_Error`.
> **게이트:** KILL_SWITCH/Quota는 DD4(핵심가치 다운 UX) — 본 플랜이 P4b·P4c 이월분을 종결.
> **YAGNI:** 멘토질문(REV→멘토 연결)은 P4e(MEN) 결선 시. 본 플랜은 리뷰 렌더 + 피드백 토글까지. PARTIAL(항목별 점진 노출)은 단순화(일괄 로드).

## P4d가 소비/수정하는 API

- P4a~c: `apiClientProvider`(providers), `webMockFixtures`(data), `SandboxPage`·`_ReviewPlaceholder`(P4c).
- dp_core(P2): `ApiClient.post`(P4a), `ApiException`(`isKillSwitch`/`isQuota`/`retryAfterSeconds`), freezed.
- dp_design(P3): `DpKillSwitch`·`DpQuota`·`DpLoading`·`DpError`, `DpIcons`, `DpSpacing`, `context.dpColors`(success/warning/danger).

---

## File Structure (P4d에서 생성/수정)

```
packages/dp_core/lib/src/models/code_review.dart   # (생성) CodeReview·ReviewIssue freezed — Task 1
packages/dp_core/lib/dp_core.dart                   # (수정) export — Task 1
apps/web/lib/src/
├─ data/web_mock_fixtures.dart                       # (수정) POST /reviews — Task 2
└─ features/review/
   ├─ state/review_state.dart                        # sealed — Task 2
   ├─ application/review_controller.dart             # 요청 + kill/quota 분기 — Task 2
   └─ presentation/review_panel.dart                 # 렌더 — Task 3
apps/web/lib/src/features/sandbox/presentation/sandbox_page.dart  # (수정) 리뷰칸 → ReviewPanel — Task 4
```

---

## Task 1: dp_core — `CodeReview`·`ReviewIssue` 모델

**Files:**
- Create: `packages/dp_core/lib/src/models/code_review.dart`
- Modify: `packages/dp_core/lib/dp_core.dart`
- Test: `packages/dp_core/test/models/code_review_test.dart`

- [ ] **Step 1: 실패 테스트**

Create `packages/dp_core/test/models/code_review_test.dart`:
```dart
import 'package:dp_core/src/models/code_review.dart';
import 'package:test/test.dart';

void main() {
  test('CodeReview JSON 역직렬화(신뢰도·잘한점·개선[라인·심각도]·보안)', () {
    final r = CodeReview.fromJson({
      'confidence': 82,
      'strengths': ['명확한 함수 분리'],
      'improvements': [
        {'line': 12, 'severity': 'warning', 'message': 'null 체크 누락'},
      ],
      'security': [
        {'severity': 'error', 'message': '입력 검증 없음'},
      ],
    });
    expect(r.confidence, 82);
    expect(r.strengths, ['명확한 함수 분리']);
    expect(r.improvements.first.line, 12);
    expect(r.improvements.first.severity, 'warning');
    expect(r.security.first.line, isNull); // 기본 nullable
  });

  test('F6-e 비동기 폴링 자리 선확보: id·status 기본 nullable', () {
    final r = CodeReview.fromJson({'confidence': 50});
    expect(r.id, isNull); // 후속 폴링 전환 대비(동기 프로토에선 미사용)
    expect(r.status, isNull);
  });
}
```

- [ ] **Step 2: 실패 확인** — Run: `cd packages/dp_core && dart test test/models/code_review_test.dart ; cd ../..` → FAIL

- [ ] **Step 3: 구현**

Create `packages/dp_core/lib/src/models/code_review.dart`:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'code_review.freezed.dart';
part 'code_review.g.dart';

/// AI 코드리뷰 결과(REV-001).
@freezed
abstract class CodeReview with _$CodeReview {
  const factory CodeReview({
    required int confidence, // 0~100
    @Default(<String>[]) List<String> strengths,
    @Default(<ReviewIssue>[]) List<ReviewIssue> improvements,
    @Default(<ReviewIssue>[]) List<ReviewIssue> security,
    String? id, // F6-e: 후속 폴링(GET /reviews/:id) 자리 선확보. 동기 프로토에선 미사용.
    String? status, // F6-e: 'pending'|'done' 등 — 폴링 전환 시 사용.
  }) = _CodeReview;

  factory CodeReview.fromJson(Map<String, dynamic> json) =>
      _$CodeReviewFromJson(json);
}

/// 라인·심각도 동반 지적. severity: info | warning | error.
@freezed
abstract class ReviewIssue with _$ReviewIssue {
  const factory ReviewIssue({
    required String message,
    int? line,
    @Default('info') String severity,
  }) = _ReviewIssue;

  factory ReviewIssue.fromJson(Map<String, dynamic> json) =>
      _$ReviewIssueFromJson(json);
}
```

- [ ] **Step 4: codegen** — Run: `cd packages/dp_core && dart run build_runner build --delete-conflicting-outputs ; cd ../..` → `code_review.freezed.dart`·`code_review.g.dart` 생성

- [ ] **Step 5: export 추가** — `packages/dp_core/lib/dp_core.dart`에 `export 'src/models/code_review.dart';`

- [ ] **Step 6: 통과 확인** — Run: `cd packages/dp_core && dart test test/models/code_review_test.dart ; cd ../..` → PASS

- [ ] **Step 7: 커밋**
```bash
git add packages/dp_core/lib/src/models/code_review.dart packages/dp_core/lib/src/models/code_review.freezed.dart packages/dp_core/lib/src/models/code_review.g.dart packages/dp_core/lib/dp_core.dart packages/dp_core/test/models/code_review_test.dart
git commit -m "feat(dp_core): CodeReview·ReviewIssue 모델(REV-001)"
```

---

## Task 2: web — `ReviewState` + `ReviewController` (kill/quota 분기)

**Files:**
- Create: `apps/web/lib/src/features/review/state/review_state.dart`, `.../application/review_controller.dart`
- Modify: `apps/web/lib/src/data/web_mock_fixtures.dart`(`POST /reviews`)
- Test: `apps/web/test/features/review/review_controller_test.dart`

- [ ] **Step 1: 실패 테스트(성공 + KILL_SWITCH + QUOTA)**

Create `apps/web/test/features/review/review_controller_test.dart`:
```dart
import 'package:devpath_web/src/features/review/application/review_controller.dart';
import 'package:devpath_web/src/features/review/state/review_state.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 'POST /reviews'에 지정 응답을 주는 ApiClient 오버라이드 헬퍼.
ApiClient _client(int status, Object body) {
  final c = ApiClient.create(const ApiConfig(baseUrl: 'https://t/api/v1'));
  c.dio.httpClientAdapter = MockHttpAdapter({'POST /reviews': (status, body)});
  return c;
}

void main() {
  test('성공 시 ReviewLoaded', () async {
    final c = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(_client(200, {
        'confidence': 90,
        'strengths': ['좋음'],
        'improvements': <Map<String, dynamic>>[],
        'security': <Map<String, dynamic>>[],
      })),
    ]);
    addTearDown(c.dispose);

    await c.read(reviewControllerProvider.notifier).request('code');
    final s = c.read(reviewControllerProvider);
    expect(s, isA<ReviewLoaded>());
    expect((s as ReviewLoaded).review.confidence, 90);
  });

  test('AI_KILL_SWITCH_ACTIVE → ReviewKillSwitch', () async {
    final c = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(_client(503, {
        'error': {'code': 'AI_KILL_SWITCH_ACTIVE', 'message': '점검'}
      })),
    ]);
    addTearDown(c.dispose);
    await c.read(reviewControllerProvider.notifier).request('code');
    expect(c.read(reviewControllerProvider), isA<ReviewKillSwitch>());
  });

  test('QUOTA_EXCEEDED → ReviewQuota(retryAfter)', () async {
    final client = ApiClient.create(const ApiConfig(baseUrl: 'https://t/api/v1'));
    // Retry-After 헤더 포함 응답
    client.dio.httpClientAdapter = MockHttpAdapter({
      'POST /reviews': (429, {'error': {'code': 'QUOTA_EXCEEDED', 'message': '한도'}}),
    });
    final c = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(client)]);
    addTearDown(c.dispose);
    await c.read(reviewControllerProvider.notifier).request('code');
    expect(c.read(reviewControllerProvider), isA<ReviewQuota>());
  });
}
```
> Retry-After 초는 헤더 의존 — 목 어댑터가 헤더를 안 실으면 `retryAfterSeconds`는 null → UI는 무기한 문구(F6-b, `?? 0` 미사용). 본 테스트는 분기(타입)만 검증하고, null/음수→UI 문구는 `review_panel_test.dart`에서 검증.

- [ ] **Step 2: 실패 확인** — Run: `cd apps/web && flutter test test/features/review/review_controller_test.dart ; cd ../..` → FAIL

- [ ] **Step 3: 구현 — `review_state.dart`**

Create `apps/web/lib/src/features/review/state/review_state.dart`:
```dart
import 'package:dp_core/dp_core.dart';

sealed class ReviewState {
  const ReviewState();
}

class ReviewIdle extends ReviewState {
  const ReviewIdle();
}

class ReviewLoading extends ReviewState {
  const ReviewLoading();
}

class ReviewLoaded extends ReviewState {
  const ReviewLoaded(this.review);
  final CodeReview review;
}

class ReviewKillSwitch extends ReviewState {
  const ReviewKillSwitch();
}
// F6-a: 대체행동(altActionLabel/onAltAction)은 P3 DpKillSwitch가 제공 —
// 상태가 아닌 위젯(ReviewPanel)에서 배선한다(라우팅 콜백이 상태에 들어가지 않게).

class ReviewQuota extends ReviewState {
  const ReviewQuota(this.retryAfterSeconds);
  final int? retryAfterSeconds;
}

class ReviewFailed extends ReviewState {
  const ReviewFailed(this.message);
  final String message;
}
```

- [ ] **Step 4: 구현 — `review_controller.dart`**

Create `apps/web/lib/src/features/review/application/review_controller.dart`:
```dart
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../state/review_state.dart';

class ReviewController extends Notifier<ReviewState> {
  @override
  ReviewState build() => const ReviewIdle();

  Future<void> request(String code) async {
    state = const ReviewLoading();
    try {
      // F6-e: 본 프로토는 동기 POST — 완성 리뷰를 즉시 반환받는다.
      // 계약(§9.2)의 "비동기 결과는 폴링/알림 후 조회"와의 격차는 후속에서 폴링으로 전환
      // (CodeReview.id/status 자리 선확보로 전환 비용 절감). 리스크 절 참조.
      final json = await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>('/reviews', body: {'code': code});
      state = ReviewLoaded(CodeReview.fromJson(json));
    } on ApiException catch (e) {
      state = switch (e) {
        _ when e.isKillSwitch => const ReviewKillSwitch(),
        _ when e.isQuota => ReviewQuota(e.retryAfterSeconds),
        _ => ReviewFailed(e.message),
      };
    }
  }
}

final reviewControllerProvider =
    NotifierProvider<ReviewController, ReviewState>(ReviewController.new);
```

- [ ] **Step 5: 목 픽스처 `POST /reviews` 추가**

`apps/web/lib/src/data/web_mock_fixtures.dart`의 `webMockFixtures`에 추가:
```dart
  'POST /reviews': (
    200,
    {
      'confidence': 78,
      'strengths': ['main 함수가 간결합니다.', 'print 사용이 적절합니다.'],
      'improvements': [
        {'line': 2, 'severity': 'warning', 'message': '예외 처리를 추가하세요.'},
        {'line': 1, 'severity': 'info', 'message': '함수에 문서 주석을 권장합니다.'},
      ],
      'security': [
        {'severity': 'info', 'message': '외부 입력이 없어 위험이 낮습니다.'},
      ],
    },
  ),
```

- [ ] **Step 6: 통과 확인** — Run: `cd apps/web && flutter test test/features/review/review_controller_test.dart ; cd ../..` → PASS

- [ ] **Step 7: 커밋**
```bash
git add apps/web/lib/src/features/review/state apps/web/lib/src/features/review/application apps/web/lib/src/data/web_mock_fixtures.dart apps/web/test/features/review
git commit -m "feat(web): ReviewController + 상태(KILL_SWITCH/Quota 분기)"
```

---

## Task 3: web — `ReviewPanel` (렌더 + KillSwitch/Quota)

**Files:**
- Create: `apps/web/lib/src/features/review/presentation/review_panel.dart`
- Test: `apps/web/test/features/review/review_panel_test.dart`

- [ ] **Step 1: 실패 테스트(idle 버튼 / loaded 신뢰도 / killSwitch + 대체행동 / quota null·음수 / loading / failed — F6-a·b·f 분기 6종 전수)**

Create `apps/web/test/features/review/review_panel_test.dart`:
```dart
import 'package:devpath_web/src/features/review/application/review_controller.dart';
import 'package:devpath_web/src/features/review/presentation/review_panel.dart';
import 'package:devpath_web/src/features/review/state/review_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart'; // F6-a: 대체행동 라우팅 테스트용

class _FakeReview extends ReviewController {
  _FakeReview(this._initial);
  final ReviewState _initial;
  @override
  ReviewState build() => _initial;
}

Widget _host(ProviderContainer c) => UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: DpTheme.light(),
        home: Scaffold(body: ReviewPanel(onRequest: () {})),
      ),
    );

// F6-a: context.go('/community')가 동작하도록 GoRouter를 끼운 호스트.
Widget _hostRouter(ProviderContainer c) {
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => Scaffold(body: ReviewPanel(onRequest: () {})),
    ),
    GoRoute(
      path: '/community',
      builder: (_, __) => const Scaffold(body: Text('COMMUNITY_STUB')),
    ),
  ]);
  return UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(theme: DpTheme.light(), routerConfig: router),
  );
}

void main() {
  testWidgets('idle: 리뷰 요청 버튼', (tester) async {
    final c = ProviderContainer(overrides: [
      reviewControllerProvider.overrideWith(() => _FakeReview(const ReviewIdle())),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    expect(find.text('AI 리뷰 요청'), findsOneWidget);
  });

  testWidgets('loaded: 신뢰도와 개선 라인 표시', (tester) async {
    final c = ProviderContainer(overrides: [
      reviewControllerProvider.overrideWith(() => _FakeReview(const ReviewLoaded(
            CodeReview(confidence: 80, improvements: [
              ReviewIssue(message: 'null 체크', line: 3, severity: 'warning')
            ]),
          ))),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    expect(find.textContaining('80'), findsWidgets);
    expect(find.textContaining('null 체크'), findsOneWidget);
  });

  testWidgets('killSwitch: 점검 배너', (tester) async {
    final c = ProviderContainer(overrides: [
      reviewControllerProvider
          .overrideWith(() => _FakeReview(const ReviewKillSwitch())),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    expect(find.byType(DpKillSwitch), findsOneWidget);
  });

  // F6-a: KILL_SWITCH 대체행동(altActionLabel/onAltAction) 배선 검증.
  testWidgets('killSwitch: 대체행동 버튼 존재 + 탭(라우팅)', (tester) async {
    final c = ProviderContainer(overrides: [
      reviewControllerProvider
          .overrideWith(() => _FakeReview(const ReviewKillSwitch())),
    ]);
    addTearDown(c.dispose);
    // context.go가 동작하려면 GoRouter가 필요 — _hostRouter로 '/community' 라우트 제공.
    await tester.pumpWidget(_hostRouter(c));
    await tester.pumpAndSettle();
    expect(find.text('커뮤니티 둘러보기'), findsOneWidget);
    await tester.tap(find.text('커뮤니티 둘러보기'));
    await tester.pumpAndSettle();
    expect(find.text('COMMUNITY_STUB'), findsOneWidget); // 대체행동이 /community로 이동
  });

  // F6-b: Retry-After null/음수 안전 — 0초 오안내 없이 무기한 문구로 분기.
  testWidgets('quota: retryAfter=null이면 무기한 문구(0초 미표시)', (tester) async {
    final c = ProviderContainer(overrides: [
      reviewControllerProvider
          .overrideWith(() => _FakeReview(const ReviewQuota(null))),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    expect(find.byType(DpQuota), findsOneWidget);
    expect(find.textContaining('0초'), findsNothing); // 0초 오안내 차단
    expect(find.textContaining('잠시 후 다시 시도'), findsOneWidget);
  });

  testWidgets('quota: retryAfter=음수도 무기한 문구로 안전 처리', (tester) async {
    final c = ProviderContainer(overrides: [
      reviewControllerProvider
          .overrideWith(() => _FakeReview(const ReviewQuota(-5))),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    expect(find.byType(DpQuota), findsOneWidget);
    expect(find.textContaining('-5'), findsNothing);
  });

  // F6-f: 누락 분기 렌더(Loading/Failed) 보강 — 분기 6종 전수 커버.
  testWidgets('loading: 생성 중 표시', (tester) async {
    final c = ProviderContainer(overrides: [
      reviewControllerProvider
          .overrideWith(() => _FakeReview(const ReviewLoading())),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    expect(find.byType(DpLoading), findsOneWidget);
  });

  testWidgets('failed: 에러 메시지 + 재시도', (tester) async {
    final c = ProviderContainer(overrides: [
      reviewControllerProvider
          .overrideWith(() => _FakeReview(const ReviewFailed('서버 오류'))),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    expect(find.byType(DpError), findsOneWidget);
    expect(find.textContaining('서버 오류'), findsOneWidget);
  });
}
```
> F6-b: `DpQuota(retryAfterSeconds: null)`이 "잠시 후 다시 시도해 주세요" 무기한 문구를 렌더한다는 전제는 P3 `DpQuota` 계약(null→무기한 문구)에 의존. P3 위젯이 null 분기를 제공하지 않으면 본 테스트가 실패하므로, 그 경우 P3 보강을 선행 태스크로 올린다(추측 금지 — 구현 전 `DpQuota` 소스로 null 처리 확인).

- [ ] **Step 2: 실패 확인** — Run: `cd apps/web && flutter test test/features/review/review_panel_test.dart ; cd ../..` → FAIL

- [ ] **Step 3: 구현**

Create `apps/web/lib/src/features/review/presentation/review_panel.dart`:
```dart
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // F6-a: KILL_SWITCH 대체행동 라우팅(context.go)

import '../application/review_controller.dart';
import '../state/review_state.dart';

/// SBX 3페인의 리뷰 칸. 상태별 렌더(요청/생성중/결과/점검/한도/실패).
class ReviewPanel extends ConsumerWidget {
  const ReviewPanel({super.key, required this.onRequest});
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(reviewControllerProvider);
    return switch (s) {
      ReviewIdle() => DpEmpty(
          icon: DpIcons.content,
          title: 'AI 코드리뷰',
          message: '코드를 작성하고 리뷰를 받아보세요.',
          actionLabel: 'AI 리뷰 요청',
          onAction: onRequest,
        ),
      ReviewLoading() => const DpLoading(label: '리뷰 생성 중…'),
      // F6-a: P3 DpKillSwitch의 대체행동(altActionLabel/onAltAction)을 배선 —
      // 핵심가치 다운(DD4) 시 사용자에게 최소 1개 대체 경로 제공.
      ReviewKillSwitch() => DpKillSwitch(
          altActionLabel: '커뮤니티 둘러보기',
          onAltAction: () => context.go('/community'),
        ),
      // F6-b: Retry-After null 안전 — `?? 0`(0초 오안내) 제거.
      // null/음수면 DpQuota가 "잠시 후 다시 시도해 주세요" 무기한 문구로 분기.
      ReviewQuota(:final retryAfterSeconds) =>
        DpQuota(retryAfterSeconds: retryAfterSeconds),
      ReviewFailed(:final message) =>
        DpError(message: message, onRetry: onRequest),
      ReviewLoaded(:final review) => _ReviewBody(review: review),
    };
  }
}

class _ReviewBody extends StatelessWidget {
  const _ReviewBody({required this.review});
  final CodeReview review;

  Color _sevColor(BuildContext context, String sev) {
    final c = context.dpColors;
    return switch (sev) {
      'error' => c.danger,
      'warning' => c.warning,
      _ => c.textSecondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;

    Widget issues(String title, List<ReviewIssue> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: DpSpacing.md),
            Text(title, style: text.titleMedium),
            for (final i in items)
              Padding(
                padding: const EdgeInsets.only(top: DpSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(DpIcons.dotSmall, size: 8, color: _sevColor(context, i.severity)),
                    const SizedBox(width: DpSpacing.sm),
                    Expanded(
                      child: Text(
                        i.line != null ? 'L${i.line} · ${i.message}' : i.message,
                        style: text.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );

    return ListView(
      padding: const EdgeInsets.all(DpSpacing.lg),
      children: [
        Row(
          children: [
            Text('신뢰도', style: text.titleMedium),
            const Spacer(),
            Text('${review.confidence}%',
                style: text.titleMedium?.copyWith(color: c.primaryText)),
          ],
        ),
        const SizedBox(height: DpSpacing.xs),
        LinearProgressIndicator(value: review.confidence / 100),
        if (review.strengths.isNotEmpty) ...[
          const SizedBox(height: DpSpacing.md),
          Text('잘한 점', style: text.titleMedium),
          for (final s in review.strengths)
            Padding(
              padding: const EdgeInsets.only(top: DpSpacing.xs),
              child: Row(children: [
                Icon(DpIcons.stepDone, size: 16, color: c.success),
                const SizedBox(width: DpSpacing.sm),
                Expanded(child: Text(s, style: text.bodyMedium)),
              ]),
            ),
        ],
        if (review.improvements.isNotEmpty) issues('개선', review.improvements),
        if (review.security.isNotEmpty) issues('보안', review.security),
        const SizedBox(height: DpSpacing.lg),
        Row(children: [
          IconButton(
            onPressed: () {},
            icon: const Icon(DpIcons.thumbUp),
            tooltip: '도움됨',
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(DpIcons.thumbDown),
            tooltip: '아쉬움',
          ),
        ]),
      ],
    );
  }
}
```
> P4d 아이콘: `DpIcons.thumbUp/thumbDown/dotSmall`(Symbols, P3 추가) 사용 — DD3 단일 Symbols 준수. 피드백 전송은 프로토 범위 밖(no-op).

- [ ] **Step 4: 통과 확인** — Run: `cd apps/web && flutter test test/features/review/review_panel_test.dart ; cd ../..` → PASS

- [ ] **Step 5: 커밋**
```bash
git add apps/web/lib/src/features/review/presentation apps/web/test/features/review/review_panel_test.dart
git commit -m "feat(web): ReviewPanel(신뢰도·개선·보안 + KillSwitch/Quota)"
```

---

## Task 4: Sandbox 결선 (리뷰 칸 교체) + 통합 스모크

**Files:**
- Modify: `apps/web/lib/src/features/sandbox/presentation/sandbox_page.dart`(`_ReviewPlaceholder` → `ReviewPanel`)
- Test: `apps/web/test/features/sandbox/sandbox_review_smoke_test.dart`

- [ ] **Step 1: `SandboxPage`의 리뷰 칸 교체**

`apps/web/lib/src/features/sandbox/presentation/sandbox_page.dart`:
- import 추가: `import '../../review/presentation/review_panel.dart';`, `import '../../review/application/review_controller.dart';`
- `_ReviewPlaceholder` 위젯과 그 사용처를 제거하고, `SandboxLayout(review: ...)`를 다음으로:
```dart
        review: ReviewPanel(
          onRequest: () =>
              ref.read(reviewControllerProvider.notifier).request(_code),
        ),
```
> `_code`는 `_SandboxPageState`가 보유(Monaco onChanged로 갱신). `ref`는 `ConsumerState`에서 접근.

- [ ] **Step 2: 통합 스모크 테스트**

Create `apps/web/test/features/sandbox/sandbox_review_smoke_test.dart`:
```dart
import 'package:devpath_web/src/features/sandbox/presentation/sandbox_page.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ApiClient _reviewClient() {
  final c = ApiClient.create(const ApiConfig(baseUrl: 'https://t/api/v1'));
  c.dio.httpClientAdapter = MockHttpAdapter({
    'POST /reviews': (200, {
      'confidence': 70,
      'strengths': <String>[],
      'improvements': [
        {'line': 1, 'severity': 'warning', 'message': '예외 처리 추가'}
      ],
      'security': <Map<String, dynamic>>[],
    }),
  });
  return c;
}

void main() {
  testWidgets('AI 리뷰 요청 → 신뢰도/개선 표시(넓은 화면)', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final c = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(_reviewClient())]);
    addTearDown(c.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: DpTheme.light(), home: const SandboxPage()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('AI 리뷰 요청'));
    await tester.pumpAndSettle();
    expect(find.textContaining('70'), findsWidgets);
    expect(find.textContaining('예외 처리 추가'), findsOneWidget);
  });
}
```

- [ ] **Step 3: 통과 + 전체 검증**

Run:
```bash
cd apps/web && flutter test test/features/sandbox/sandbox_review_smoke_test.dart ; cd ../..
melos run analyze
melos run test
```
Expected: 스모크 PASS, `dp_core`·`devpath_web` analyze 이슈 없음, 전 멤버 test PASS(골든 제외).

- [ ] **Step 4: 커밋**
```bash
git add apps/web/lib/src/features/sandbox/presentation/sandbox_page.dart apps/web/test/features/sandbox/sandbox_review_smoke_test.dart
git commit -m "feat(web): Sandbox 리뷰 칸을 ReviewPanel로 결선 + 스모크"
```

---

## 검증 기준 (Definition of Done)

- [ ] `melos run analyze`/`test` — dp_core(CodeReview) + web(review-controller·panel·sandbox 스모크) PASS
- [ ] REV 결과: 신뢰도(진행바) + 잘한점 + 개선(라인·심각도 색) + 보안 렌더
- [ ] `AI_KILL_SWITCH_ACTIVE`(503) → `DpKillSwitch`(점검 배너) **+ 대체행동 1개("커뮤니티 둘러보기"→`/community`) 배선·탭 테스트 통과**(F6-a)
- [ ] `QUOTA_EXCEEDED`(429) → `DpQuota`(Retry-After **정적 표시**) — `?? 0` 제거, **null/음수는 "잠시 후 다시 시도" 무기한 문구**(0초 오안내 없음, F6-b·d)
- [ ] **카운트다운은 미구현(정적 표시로 강등)** — 카운트다운은 후속(P3 `DpQuota` Stateful 전환)으로 이월 명시(F6-d)
- [ ] **렌더 분기 6종(idle/loaded/killSwitch/quota/loading/failed) 위젯테스트 전수 통과**(F6-f)
- [ ] **비동기 폴링 deferral 명시** — 동기 `POST /reviews` 유지, `CodeReview.id/status` 자리 선확보, 폴링 전환은 후속(F6-e)
- [ ] SBX 3페인 리뷰 칸이 `_ReviewPlaceholder`→`ReviewPanel`로 교체(P4c 이월 종결)
- [ ] web `dio`-free 유지(dp_core `ApiClient.post` 경유)

## 리스크 / 후속 (명시)

- **멘토질문 연결 미구현**: REV의 "이 부분 멘토에게 질문" 액션은 P4e(MEN) 결선 시 추가(현재 리뷰 렌더까지).
- **피드백 전송 no-op**: 👍👎는 프로토에서 UI만. 실제 전송(`POST /reviews/:id/feedback`)은 백엔드 연동 시.
- **Retry-After 카운트다운 강등(F6-d)**: 본 프로토는 Retry-After를 **정적 표시**로만 보인다(카운트다운 미구현). P3 `DpQuota`가 StatelessWidget이라 카운트다운(StatefulWidget+Timer)은 P3 범위 확대 → **카운트다운은 후속(P3 `DpQuota` Stateful 전환)** 으로 이월. 목 어댑터가 `retry-after` 헤더를 안 실으면 `retryAfterSeconds`는 null → `DpQuota`는 무기한 문구(`?? 0` 제거, F6-b). 실서버는 헤더 그대로 사용(P2 `ApiException.retryAfterSeconds`).
- **비동기 결과 폴링 deferral(F6-e)**: 본 프로토는 동기 `POST /reviews`로 완성 리뷰를 즉시 반환한다. 계약 §9.2 "비동기 결과는 폴링/알림 후 조회"와는 격차가 있으며, **동기→폴링 전환은 후속**으로 이월한다. 전환 비용 절감을 위해 `CodeReview`에 `id`/`status` 자리를 선확보했다(현재 동기 경로에선 미사용).
- **PARTIAL 단순화**: §9.2 "항목별 점진 노출"은 일괄 로드로 단순화. 스트리밍 리뷰가 필요하면 SSE로 전환(후속).
- **아이콘**: ✅ 반영 — `DpIcons.thumbUp`/`thumbDown`/`dotSmall`(Symbols, P3 추가)로 교체. DD3 단일 Symbols 준수.
