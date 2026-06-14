# P4f — 대시보드(DASH-001) + 커뮤니티(COM-001/003) (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `apps/web`에 **대시보드(DASH-001)** 와 **커뮤니티(COM-001 홈 / COM-003 Q&A 상세)** 를 TDD로 구현해 web 골든패스를 완성한다 — 대시보드는 스트릭→진행률→다음 과제 단일 CTA→배지 위계(카드), 커뮤니티는 **커서 페이지네이션(`Page<T>`)** 목록 + 빈 상태("첫 질문을 남겨보세요"+작성 CTA) + Q&A 상세.

**Architecture:** P4a~e 토대 위. 모델은 dp_core freezed(`DashboardSummary`·`CommunityPost`). 커뮤니티 페이지네이션은 dp_core `Page<T>`(P2)를 `communityFetchProvider` 시ام으로 주입(테스트에서 다중 페이지 검증). web `dio`-free. `/dashboard`·`/community`의 `PlaceholderPage`(P4a)를 교체.

**Tech Stack:** Flutter Web · flutter_riverpod 3.3 · go_router · dp_core(Page·freezed)·dp_design(DpEmpty·DpLoading·DpError·DpMarkdown) · flutter_test.

---

> **선행:** P4a~e 구현 완료. `/dashboard`·`/community` 라우트 교체.
> **참조:** 스펙 §4(대시보드 위계·커뮤니티 홈/Q&A)·§3(커서 페이지네이션 `Page<T>` limit 20)·§9.2(커뮤니티 Q&A 행: LOADING 스켈레톤/EMPTY 작성CTA/ERROR 재시도/SUCCESS 목록·상세/PARTIAL 커서 다음). DESIGN.md §1(displaySmall KPI). 샘플: `Flutter_Repository_FutureProvider_Family_PageResponse_페이지네이션`·`Flutter_리스트_아이템_카드`.
> **YAGNI:** 글쓰기(작성)·답변·투표·평판 게이트는 후속(작성 CTA는 자리). 대시보드 차트는 진행바로 단순화. 커뮤니티 상세 답변목록은 본문 렌더까지(답변 스레드 후속).

## P4f가 소비/수정하는 API

- P4a: `apiClientProvider`(providers), `routerProvider`(`/dashboard`·`/community`).
- dp_core(P2): `ApiClient.get`, `Page<T>`(커서), `ApiException`, freezed.
- dp_design(P3): `DpEmpty`·`DpLoading`·`DpError`·`DpMarkdown`, `DpIcons`, `DpSpacing`, `context.dpColors`.

---

## File Structure (P4f에서 생성/수정)

```
packages/dp_core/lib/src/models/dashboard_summary.dart   # (생성) freezed — Task 1
packages/dp_core/lib/src/models/community_post.dart       # (생성) freezed — Task 1
packages/dp_core/lib/dp_core.dart                         # (수정) export — Task 1
apps/web/lib/src/
├─ data/web_mock_fixtures.dart                             # (수정) /dashboard·/community/posts(:id) — Task 2·3
├─ app/router.dart                                         # (수정) /dashboard·/community·/community/:id — Task 2·5
└─ features/
   ├─ dashboard/{state,application,presentation}/...        # DASH-001 — Task 2
   └─ community/{data,state,application,presentation}/...    # COM-001/003 — Task 3·4·5
```

---

## Task 1: dp_core — `DashboardSummary` + `CommunityPost` 모델

**Files:**
- Create: `packages/dp_core/lib/src/models/dashboard_summary.dart`, `.../community_post.dart`
- Modify: `packages/dp_core/lib/dp_core.dart`
- Test: `packages/dp_core/test/models/dashboard_community_test.dart`

- [ ] **Step 1: 실패 테스트**

Create `packages/dp_core/test/models/dashboard_community_test.dart`:
```dart
import 'package:dp_core/src/models/community_post.dart';
import 'package:dp_core/src/models/dashboard_summary.dart';
import 'package:test/test.dart';

void main() {
  test('DashboardSummary 역직렬화', () {
    final d = DashboardSummary.fromJson({
      'streakDays': 7,
      'progressPercent': 62,
      'nextTaskTitle': '비동기 기초',
      'badges': ['첫 경로'],
    });
    expect(d.streakDays, 7);
    expect(d.progressPercent, 62);
    expect(d.nextTaskTitle, '비동기 기초');
    expect(d.badges, ['첫 경로']);
  });

  test('CommunityPost 역직렬화(상세 body 옵션)', () {
    final p = CommunityPost.fromJson({
      'id': 'q1',
      'title': 'async 질문',
      'author': '지수',
      'answerCount': 3,
    });
    expect(p.id, 'q1');
    expect(p.answerCount, 3);
    expect(p.body, isNull);
  });
}
```

- [ ] **Step 2: 실패 확인** — Run: `cd packages/dp_core && dart test test/models/dashboard_community_test.dart ; cd ../..` → FAIL

- [ ] **Step 3: 구현 — 모델 2종**

Create `packages/dp_core/lib/src/models/dashboard_summary.dart`:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'dashboard_summary.freezed.dart';
part 'dashboard_summary.g.dart';

/// 대시보드 요약(DASH-001): 스트릭·진행률·다음 과제·배지.
@freezed
abstract class DashboardSummary with _$DashboardSummary {
  const factory DashboardSummary({
    required int streakDays,
    required int progressPercent,
    String? nextTaskTitle,
    @Default(<String>[]) List<String> badges,
  }) = _DashboardSummary;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) =>
      _$DashboardSummaryFromJson(json);
}
```

Create `packages/dp_core/lib/src/models/community_post.dart`:
```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'community_post.freezed.dart';
part 'community_post.g.dart';

/// 커뮤니티 글(COM). 목록은 메타만, 상세는 [body] 포함.
@freezed
abstract class CommunityPost with _$CommunityPost {
  const factory CommunityPost({
    required String id,
    required String title,
    required String author,
    @Default(0) int answerCount,
    String? body,
  }) = _CommunityPost;

  factory CommunityPost.fromJson(Map<String, dynamic> json) =>
      _$CommunityPostFromJson(json);
}
```

- [ ] **Step 4: codegen** — Run: `cd packages/dp_core && dart run build_runner build --delete-conflicting-outputs ; cd ../..` → `*.freezed.dart`·`*.g.dart` 4개 생성

- [ ] **Step 5: export 추가** — `packages/dp_core/lib/dp_core.dart`에:
```dart
export 'src/models/dashboard_summary.dart';
export 'src/models/community_post.dart';
```

- [ ] **Step 6: 통과 확인** — Run: `cd packages/dp_core && dart test test/models/dashboard_community_test.dart ; cd ../..` → PASS

- [ ] **Step 7: 커밋**
```bash
git add packages/dp_core/lib/src/models/dashboard_summary.dart packages/dp_core/lib/src/models/dashboard_summary.freezed.dart packages/dp_core/lib/src/models/dashboard_summary.g.dart packages/dp_core/lib/src/models/community_post.dart packages/dp_core/lib/src/models/community_post.freezed.dart packages/dp_core/lib/src/models/community_post.g.dart packages/dp_core/lib/dp_core.dart packages/dp_core/test/models/dashboard_community_test.dart
git commit -m "feat(dp_core): DashboardSummary·CommunityPost 모델"
```

---

## Task 2: web — 대시보드(DASH-001)

**Files:**
- Create: `apps/web/lib/src/features/dashboard/state/dashboard_state.dart`, `.../application/dashboard_controller.dart`, `.../presentation/dashboard_page.dart`
- Modify: `apps/web/lib/src/data/web_mock_fixtures.dart`(`GET /dashboard`), `apps/web/lib/src/app/router.dart`(`/dashboard`)
- Test: `apps/web/test/features/dashboard/dashboard_page_test.dart`

- [ ] **Step 1: 실패 테스트**

Create `apps/web/test/features/dashboard/dashboard_page_test.dart`:
```dart
import 'package:devpath_web/src/features/dashboard/presentation/dashboard_page.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('대시보드: 스트릭·진행률·다음 과제 CTA 렌더', (tester) async {
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const DashboardPage()),
    ]);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp.router(theme: DpTheme.light(), routerConfig: router),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('7'), findsWidgets); // 스트릭 7일
    expect(find.textContaining('62'), findsWidgets); // 진행률
    expect(find.text('이어서 학습'), findsOneWidget); // 단일 CTA
  });
}
```
> 기본 목 모드(`useMock=true`)라 `GET /dashboard` 픽스처 사용. `MaterialApp.router`는 CTA의 `context.go` 때문(라우터 컨텍스트 필요).

- [ ] **Step 2: 실패 확인** — Run: `cd apps/web && flutter test test/features/dashboard/dashboard_page_test.dart ; cd ../..` → FAIL

- [ ] **Step 3: 구현 — `dashboard_state.dart`**

Create `apps/web/lib/src/features/dashboard/state/dashboard_state.dart`:
```dart
import 'package:dp_core/dp_core.dart';

sealed class DashboardState {
  const DashboardState();
}

class DashLoading extends DashboardState {
  const DashLoading();
}

class DashLoaded extends DashboardState {
  const DashLoaded(this.summary);
  final DashboardSummary summary;
}

class DashFailed extends DashboardState {
  const DashFailed(this.message);
  final String message;
}
```

- [ ] **Step 4: 구현 — `dashboard_controller.dart`**

Create `apps/web/lib/src/features/dashboard/application/dashboard_controller.dart`:
```dart
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../state/dashboard_state.dart';

class DashboardController extends Notifier<DashboardState> {
  @override
  DashboardState build() => const DashLoading();

  Future<void> load() async {
    state = const DashLoading();
    try {
      final json =
          await ref.read(apiClientProvider).get<Map<String, dynamic>>('/dashboard');
      state = DashLoaded(DashboardSummary.fromJson(json));
    } on ApiException catch (e) {
      state = DashFailed(e.message);
    }
  }
}

final dashboardControllerProvider =
    NotifierProvider<DashboardController, DashboardState>(DashboardController.new);
```

- [ ] **Step 5: 목 픽스처 추가**

`apps/web/lib/src/data/web_mock_fixtures.dart`의 `webMockFixtures`에:
```dart
  'GET /dashboard': (
    200,
    {
      'streakDays': 7,
      'progressPercent': 62,
      'nextTaskTitle': '비동기 기초',
      'badges': ['첫 경로', '7일 연속'],
    },
  ),
```

- [ ] **Step 6: 구현 — `dashboard_page.dart` + 라우트**

Create `apps/web/lib/src/features/dashboard/presentation/dashboard_page.dart`:
```dart
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/dashboard_controller.dart';
import '../state/dashboard_state.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(dashboardControllerProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(dashboardControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('대시보드')),
      body: switch (s) {
        DashLoading() => const DpLoading(),
        DashFailed(:final message) => DpError(
            message: message,
            onRetry: () => ref.read(dashboardControllerProvider.notifier).load()),
        DashLoaded(:final summary) => _Body(summary: summary),
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;

    Widget card(Widget child) => Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: DpSpacing.md),
          padding: const EdgeInsets.all(DpSpacing.lg),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(DpRadius.card),
          ),
          child: child,
        );

    return ListView(
      padding: const EdgeInsets.all(DpSpacing.lg),
      children: [
        // 1) 스트릭
        card(Row(children: [
          Text('${summary.streakDays}', style: text.displaySmall?.copyWith(color: c.primaryText)),
          const SizedBox(width: DpSpacing.sm),
          Text('일 연속 학습 중 🔥', style: text.titleMedium),
        ])),
        // 2) 진행률
        card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('전체 진행률', style: text.titleMedium),
          const SizedBox(height: DpSpacing.sm),
          LinearProgressIndicator(value: summary.progressPercent / 100),
          const SizedBox(height: DpSpacing.xs),
          Text('${summary.progressPercent}%', style: text.bodySmall),
        ])),
        // 3) 다음 과제 단일 CTA
        card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('다음 과제', style: text.titleMedium),
          const SizedBox(height: DpSpacing.xs),
          Text(summary.nextTaskTitle ?? '경로를 생성해 보세요',
              style: text.bodyMedium?.copyWith(color: c.textSecondary)),
          const SizedBox(height: DpSpacing.md),
          FilledButton(
            onPressed: () => context.go('/path'),
            child: const Text('이어서 학습'),
          ),
        ])),
        // 4) 배지
        if (summary.badges.isNotEmpty)
          card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('배지', style: text.titleMedium),
            const SizedBox(height: DpSpacing.sm),
            Wrap(spacing: DpSpacing.sm, children: [
              for (final b in summary.badges) Chip(label: Text('🏅 $b')),
            ]),
          ])),
      ],
    );
  }
}
```
> 🔥·🏅는 DD3 예외(의도적 게이미피케이션 이모지 — 스펙 §9.1 DD3 단서). 차트는 진행바로 단순화.

`apps/web/lib/src/app/router.dart` ShellRoute `/dashboard` builder 교체(import 포함):
```dart
import '../features/dashboard/presentation/dashboard_page.dart';
// ...
GoRoute(path: '/dashboard', builder: (_, __) => const DashboardPage()),
```

- [ ] **Step 7: 통과 확인** — Run: `cd apps/web && flutter test test/features/dashboard/dashboard_page_test.dart ; cd ../..` → PASS

- [ ] **Step 8: 커밋**
```bash
git add apps/web/lib/src/features/dashboard apps/web/lib/src/data/web_mock_fixtures.dart apps/web/lib/src/app/router.dart apps/web/test/features/dashboard
git commit -m "feat(web): 대시보드(DASH-001 카드 위계 + 단일 CTA)"
```

---

## Task 3: web — 커뮤니티 데이터 + 컨트롤러 (커서 페이지네이션)

**Files:**
- Create: `apps/web/lib/src/features/community/data/community_source.dart`, `.../state/community_state.dart`, `.../application/community_controller.dart`
- Modify: `apps/web/lib/src/data/web_mock_fixtures.dart`(`GET /community/posts`)
- Test: `apps/web/test/features/community/community_controller_test.dart`

- [ ] **Step 1: 실패 테스트(첫 페이지 + 더 보기 누적)**

Create `apps/web/test/features/community/community_controller_test.dart`:
```dart
import 'package:devpath_web/src/features/community/application/community_controller.dart';
import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/state/community_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

CommunityPost _p(String id) =>
    CommunityPost(id: id, title: '글 $id', author: '지수');

void main() {
  test('첫 로드 후 loadMore가 다음 페이지를 누적한다', () async {
    final c = ProviderContainer(overrides: [
      communityFetchProvider.overrideWithValue(({String? cursor}) async {
        if (cursor == null) {
          return Page(data: [_p('1'), _p('2')], nextCursor: 'c2', limit: 20);
        }
        return Page(data: [_p('3')], limit: 20); // nextCursor 없음 → 끝
      }),
    ]);
    addTearDown(c.dispose);

    await c.read(communityControllerProvider.notifier).load();
    var s = c.read(communityControllerProvider);
    expect(s.phase, CommunityPhase.loaded);
    expect(s.posts.map((e) => e.id), ['1', '2']);
    expect(s.nextCursor, 'c2');

    await c.read(communityControllerProvider.notifier).loadMore();
    s = c.read(communityControllerProvider);
    expect(s.posts.map((e) => e.id), ['1', '2', '3']);
    expect(s.nextCursor, isNull); // 더 없음
  });
}
```

- [ ] **Step 2: 실패 확인** — Run: `cd apps/web && flutter test test/features/community/community_controller_test.dart ; cd ../..` → FAIL

- [ ] **Step 3: 구현 — `community_source.dart`(fetch 시ام)**

Create `apps/web/lib/src/features/community/data/community_source.dart`:
```dart
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';

/// 커서로 한 페이지 조회. 테스트에서 override해 다중 페이지 검증.
typedef CommunityFetch = Future<Page<CommunityPost>> Function({String? cursor});

final communityFetchProvider = Provider<CommunityFetch>((ref) {
  final client = ref.watch(apiClientProvider);
  return ({String? cursor}) async {
    final json = await client.get<Map<String, dynamic>>(
      '/community/posts',
      query: cursor == null ? null : {'cursor': cursor},
    );
    return Page.fromJson(
      json,
      (o) => CommunityPost.fromJson((o as Map).cast<String, dynamic>()),
    );
  };
});
```

- [ ] **Step 4: 구현 — `community_state.dart`**

Create `apps/web/lib/src/features/community/state/community_state.dart`:
```dart
import 'package:dp_core/dp_core.dart';

enum CommunityPhase { loading, loaded, failed }

class CommunityState {
  const CommunityState({
    this.posts = const [],
    this.nextCursor,
    this.phase = CommunityPhase.loading,
    this.loadingMore = false,
    this.error,
  });

  final List<CommunityPost> posts;
  final String? nextCursor;
  final CommunityPhase phase;
  final bool loadingMore;
  final String? error;

  bool get hasMore => nextCursor != null;

  CommunityState copyWith({
    List<CommunityPost>? posts,
    String? nextCursor,
    CommunityPhase? phase,
    bool? loadingMore,
    String? error,
  }) =>
      CommunityState(
        posts: posts ?? this.posts,
        nextCursor: nextCursor, // 명시 전달(끝나면 null)
        phase: phase ?? this.phase,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error,
      );
}
```

- [ ] **Step 5: 구현 — `community_controller.dart`**

Create `apps/web/lib/src/features/community/application/community_controller.dart`:
```dart
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/community_source.dart';
import '../state/community_state.dart';

class CommunityController extends Notifier<CommunityState> {
  @override
  CommunityState build() => const CommunityState();

  Future<void> load() async {
    state = const CommunityState(phase: CommunityPhase.loading);
    try {
      final page = await ref.read(communityFetchProvider)();
      state = CommunityState(
        posts: page.data,
        nextCursor: page.nextCursor,
        phase: CommunityPhase.loaded,
      );
    } on ApiException catch (e) {
      state = CommunityState(phase: CommunityPhase.failed, error: e.message);
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loadingMore) return;
    state = state.copyWith(loadingMore: true, nextCursor: state.nextCursor);
    try {
      final page = await ref.read(communityFetchProvider)(cursor: state.nextCursor);
      state = state.copyWith(
        posts: [...state.posts, ...page.data],
        nextCursor: page.nextCursor,
        loadingMore: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loadingMore: false, nextCursor: state.nextCursor, error: e.message);
    }
  }
}

final communityControllerProvider =
    NotifierProvider<CommunityController, CommunityState>(CommunityController.new);
```

- [ ] **Step 6: 목 픽스처 추가(단일 페이지 — 다중페이지는 query-aware 목 보강 후속)**

`apps/web/lib/src/data/web_mock_fixtures.dart`의 `webMockFixtures`에:
```dart
  'GET /community/posts': (
    200,
    {
      'data': [
        {'id': 'q1', 'title': 'async/await가 헷갈려요', 'author': '지수', 'answerCount': 2},
        {'id': 'q2', 'title': 'Stream 구독 해제는?', 'author': '민준', 'answerCount': 1},
        {'id': 'q3', 'title': 'Riverpod Notifier 패턴', 'author': '서연', 'answerCount': 5},
      ],
      'nextCursor': null, // 프로토 단일 페이지(MockHttpAdapter는 query 무시 — 리스크 참조)
      'limit': 20,
    },
  ),
```

- [ ] **Step 7: 통과 확인** — Run: `cd apps/web && flutter test test/features/community/community_controller_test.dart ; cd ../..` → PASS

- [ ] **Step 8: 커밋**
```bash
git add apps/web/lib/src/features/community/data apps/web/lib/src/features/community/state apps/web/lib/src/features/community/application apps/web/lib/src/data/web_mock_fixtures.dart apps/web/test/features/community/community_controller_test.dart
git commit -m "feat(web): 커뮤니티 컨트롤러(커서 페이지네이션 Page<T>)"
```

---

## Task 4: web — 커뮤니티 홈(COM-001)

**Files:**
- Create: `apps/web/lib/src/features/community/presentation/community_home_page.dart`
- Modify: `apps/web/lib/src/app/router.dart`(`/community`)
- Test: `apps/web/test/features/community/community_home_page_test.dart`

- [ ] **Step 1: 실패 테스트(목록 + 빈상태)**

Create `apps/web/test/features/community/community_home_page_test.dart`:
```dart
import 'package:devpath_web/src/features/community/application/community_controller.dart';
import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/presentation/community_home_page.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget _host(ProviderContainer c) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const CommunityHomePage()),
    GoRoute(path: '/community/:id', builder: (_, __) => const SizedBox()),
  ]);
  return UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(theme: DpTheme.light(), routerConfig: router),
  );
}

void main() {
  testWidgets('목록을 렌더한다', (tester) async {
    final c = ProviderContainer(overrides: [
      communityFetchProvider.overrideWithValue(({String? cursor}) async => Page(
            data: [CommunityPost(id: 'q1', title: 'async 질문', author: '지수')],
            limit: 20,
          )),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();
    expect(find.text('async 질문'), findsOneWidget);
  });

  testWidgets('빈 목록은 작성 CTA를 보인다', (tester) async {
    final c = ProviderContainer(overrides: [
      communityFetchProvider.overrideWithValue(
          ({String? cursor}) async => const Page(data: [], limit: 20)),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();
    expect(find.textContaining('첫 질문'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 실패 확인** — Run: `cd apps/web && flutter test test/features/community/community_home_page_test.dart ; cd ../..` → FAIL

- [ ] **Step 3: 구현**

Create `apps/web/lib/src/features/community/presentation/community_home_page.dart`:
```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/community_controller.dart';
import '../state/community_state.dart';

class CommunityHomePage extends ConsumerStatefulWidget {
  const CommunityHomePage({super.key});

  @override
  ConsumerState<CommunityHomePage> createState() => _CommunityHomePageState();
}

class _CommunityHomePageState extends ConsumerState<CommunityHomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(communityControllerProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(communityControllerProvider);
    final notifier = ref.read(communityControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('커뮤니티')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {}, // 작성(후속)
        icon: const Icon(Icons.edit),
        label: const Text('질문하기'),
      ),
      body: switch (s.phase) {
        CommunityPhase.loading => const DpLoading(),
        CommunityPhase.failed =>
          DpError(message: s.error ?? '불러오지 못했어요', onRetry: notifier.load),
        CommunityPhase.loaded when s.posts.isEmpty => DpEmpty(
            icon: DpIcons.community,
            title: '첫 질문을 남겨보세요',
            message: '막힌 부분을 커뮤니티에 물어보세요.',
            actionLabel: '질문 작성',
            onAction: () {},
          ),
        CommunityPhase.loaded => ListView.separated(
            padding: const EdgeInsets.all(DpSpacing.lg),
            itemCount: s.posts.length + (s.hasMore ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: DpSpacing.sm),
            itemBuilder: (_, i) {
              if (i >= s.posts.length) {
                return Center(
                  child: TextButton(
                    onPressed: s.loadingMore ? null : notifier.loadMore,
                    child: Text(s.loadingMore ? '불러오는 중…' : '더 보기'),
                  ),
                );
              }
              final p = s.posts[i];
              final c = context.dpColors;
              return Card(
                child: ListTile(
                  title: Text(p.title),
                  subtitle: Text('${p.author} · 답변 ${p.answerCount}',
                      style: TextStyle(color: c.textSecondary)),
                  onTap: () => context.go('/community/${p.id}'),
                ),
              );
            },
          ),
      },
    );
  }
}
```
> `Icons.edit`는 임시 → `DpIcons` 이관(DD3). 작성(FAB)은 프로토 no-op.

`apps/web/lib/src/app/router.dart` ShellRoute `/community` builder 교체:
```dart
import '../features/community/presentation/community_home_page.dart';
// ...
GoRoute(path: '/community', builder: (_, __) => const CommunityHomePage()),
```

- [ ] **Step 4: 통과 확인** — Run: `cd apps/web && flutter test test/features/community/community_home_page_test.dart ; cd ../..` → PASS

- [ ] **Step 5: 커밋**
```bash
git add apps/web/lib/src/features/community/presentation/community_home_page.dart apps/web/lib/src/app/router.dart apps/web/test/features/community/community_home_page_test.dart
git commit -m "feat(web): 커뮤니티 홈(COM-001 목록·빈상태·더보기)"
```

---

## Task 5: web — Q&A 상세(COM-003) + 라우트 + 전체 검증

**Files:**
- Create: `apps/web/lib/src/features/community/application/qna_detail_controller.dart`, `.../state/qna_detail_state.dart`, `.../presentation/qna_detail_page.dart`
- Modify: `apps/web/lib/src/data/web_mock_fixtures.dart`(`GET /community/posts/q1`), `apps/web/lib/src/app/router.dart`(`/community/:id`)
- Test: `apps/web/test/features/community/qna_detail_page_test.dart`

- [ ] **Step 1: 실패 테스트**

Create `apps/web/test/features/community/qna_detail_page_test.dart`:
```dart
import 'package:devpath_web/src/features/community/presentation/qna_detail_page.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('상세: 제목·본문 렌더(목)', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: const MaterialApp(home: QnaDetailPage(postId: 'q1')),
    ));
    // theme 필요 시 MaterialApp(theme: DpTheme.light())로 감싼다.
    await tester.pumpAndSettle();
    expect(find.textContaining('async'), findsWidgets); // 목 제목/본문
  });
}
```

- [ ] **Step 2: 실패 확인** — Run: `cd apps/web && flutter test test/features/community/qna_detail_page_test.dart ; cd ../..` → FAIL

- [ ] **Step 3: 구현 — state + controller**

Create `apps/web/lib/src/features/community/state/qna_detail_state.dart`:
```dart
import 'package:dp_core/dp_core.dart';

sealed class QnaDetailState {
  const QnaDetailState();
}

class QnaLoading extends QnaDetailState {
  const QnaLoading();
}

class QnaLoaded extends QnaDetailState {
  const QnaLoaded(this.post);
  final CommunityPost post;
}

class QnaFailed extends QnaDetailState {
  const QnaFailed(this.message);
  final String message;
}
```

Create `apps/web/lib/src/features/community/application/qna_detail_controller.dart`:
```dart
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../state/qna_detail_state.dart';

class QnaDetailController extends FamilyNotifier<QnaDetailState, String> {
  @override
  QnaDetailState build(String postId) {
    _load(postId);
    return const QnaLoading();
  }

  Future<void> _load(String postId) async {
    try {
      final json = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/community/posts/$postId');
      state = QnaLoaded(CommunityPost.fromJson(json));
    } on ApiException catch (e) {
      state = QnaFailed(e.message);
    }
  }
}

final qnaDetailControllerProvider =
    NotifierProvider.family<QnaDetailController, QnaDetailState, String>(
        QnaDetailController.new);
```
> `FamilyNotifier`/`NotifierProvider.family`로 postId별 인스턴스(Riverpod 3). `build`에서 비동기 로드 트리거(초기 `QnaLoading` 반환 후 state 갱신).

- [ ] **Step 4: 목 픽스처 + 페이지**

`web_mock_fixtures.dart`에:
```dart
  'GET /community/posts/q1': (
    200,
    {
      'id': 'q1',
      'title': 'async/await가 헷갈려요',
      'author': '지수',
      'answerCount': 2,
      'body': '# 질문\n\n`async/await`에서 예외는 어디서 잡나요?\n\n```dart\ntry { await f(); } catch (e) {}\n```',
    },
  ),
```

Create `apps/web/lib/src/features/community/presentation/qna_detail_page.dart`:
```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/qna_detail_controller.dart';
import '../state/qna_detail_state.dart';

class QnaDetailPage extends ConsumerWidget {
  const QnaDetailPage({super.key, required this.postId});
  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(qnaDetailControllerProvider(postId));
    return Scaffold(
      appBar: AppBar(title: const Text('Q&A')),
      body: switch (s) {
        QnaLoading() => const DpLoading(),
        QnaFailed(:final message) => DpError(message: message),
        QnaLoaded(:final post) => ListView(
            padding: const EdgeInsets.all(DpSpacing.lg),
            children: [
              Text(post.title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: DpSpacing.xs),
              Text('${post.author} · 답변 ${post.answerCount}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: context.dpColors.textSecondary)),
              const SizedBox(height: DpSpacing.lg),
              if (post.body != null) DpMarkdown(data: post.body!),
            ],
          ),
      },
    );
  }
}
```

`apps/web/lib/src/app/router.dart` ShellRoute에 추가:
```dart
import '../features/community/presentation/qna_detail_page.dart';
// ...
GoRoute(
  path: '/community/:id',
  builder: (_, state) => QnaDetailPage(postId: state.pathParameters['id']!),
),
```

- [ ] **Step 5: 통과 + 전체 검증**

Run:
```bash
cd apps/web && flutter test test/features/community/qna_detail_page_test.dart ; cd ../..
melos run analyze
melos run test
```
Expected: 상세 PASS, `dp_core`·`devpath_web` analyze 이슈 없음, 전 멤버 test PASS(골든 제외).

- [ ] **Step 6: 커밋**
```bash
git add apps/web/lib/src/features/community apps/web/lib/src/data/web_mock_fixtures.dart apps/web/lib/src/app/router.dart apps/web/test/features/community/qna_detail_page_test.dart
git commit -m "feat(web): Q&A 상세(COM-003) + 라우트 결선"
```

---

## 검증 기준 (Definition of Done)

- [ ] `melos run analyze`/`test` — dp_core(2모델) + web(dashboard·community·qna) PASS
- [ ] 대시보드: 스트릭(displaySmall) → 진행률(바) → 다음 과제 단일 CTA → 배지 위계
- [ ] 커뮤니티 홈: 목록(탭→상세) · 빈상태("첫 질문을 남겨보세요"+CTA) · 커서 "더 보기"(다중 페이지 누적 — 컨트롤러 테스트로 검증)
- [ ] Q&A 상세: 제목·작성자·본문(DpMarkdown)
- [ ] `/dashboard`·`/community`가 `PlaceholderPage`→실제 화면, `/community/:id` 신설
- [ ] **web 골든패스 완성**: 로그인→온보딩→PATH→콘텐츠→Sandbox→리뷰→멘토→대시보드→커뮤니티 전 화면 동작(목)

## 리스크 / 후속 (명시)

- **다중 페이지 목 한계**: `MockHttpAdapter`는 query(`cursor`)를 무시(path만 매칭) → 앱 기본 목은 단일 페이지(`nextCursor: null`). 커서 페이지네이션 **코드/누적은 컨트롤러 테스트로 검증**. 실다중페이지 목은 `MockHttpAdapter` query-aware 매칭 보강(dp_core 후속, T 후보).
- **작성/답변/투표 미구현**: 질문 작성(FAB)·답변 스레드·평판 게이트는 프로토 범위 밖(자리만).
- **임시 아이콘**: `Icons.edit` → `DpIcons` 이관(DD3, dp_design 추가).
- **대시보드 차트 단순화**: 진행바만. 상세 통계/그래프는 후속.
- **이모지 예외**: 🔥(스트릭)·🏅(배지)는 DD3가 명시 허용한 게이미피케이션 예외(스펙 §9.1).
