# P4f — 대시보드(DASH-001) + 커뮤니티(COM-001/003) (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> 🔶 **Eng Review 반영(2026-06-14, D3 / F8)** — 다중페이지 데모(P1)·loadMore 에러 표시(P2)·ERROR/더보기 위젯테스트·copyWith 단위테스트(P2)·Task6 E2E 분리(P3)·오타 정정. 근거·결정: [`../specs/2026-06-14-eng-review-summary.md`](../specs/2026-06-14-eng-review-summary.md).

**Goal:** `apps/web`에 **대시보드(DASH-001)** 와 **커뮤니티(COM-001 홈 / COM-003 Q&A 상세)** 를 TDD로 구현해 web 골든패스를 완성한다 — 대시보드는 스트릭→진행률→다음 과제 단일 CTA→배지 위계(카드), 커뮤니티는 **커서 페이지네이션(`Page<T>`)** 목록 + 빈 상태("첫 질문을 남겨보세요"+작성 CTA) + Q&A 상세.

**Architecture:** P4a~e 토대 위. 모델은 dp_core freezed(`DashboardSummary`·`CommunityPost`). 커뮤니티 페이지네이션은 dp_core `Page<T>`(P2)를 `communityFetchProvider` 심(seam)으로 주입(테스트에서 다중 페이지 검증). web `dio`-free. `/dashboard`·`/community`의 `PlaceholderPage`(P4a)를 교체.

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

  // 🔶 ENG-REVIEW(P2): copyWith의 nextCursor는 명시 대입(L496) — 비대칭 고정.
  // 인자를 안 주면 기존값 유지가 아니라 null이 됨을 회귀 방지로 고정한다.
  test('copyWith: nextCursor를 생략하면 null로 떨어진다(명시 대입 비대칭)', () {
    const s = CommunityState(
      posts: [],
      nextCursor: 'c2',
      phase: CommunityPhase.loaded,
    );
    final next = s.copyWith(loadingMore: true); // nextCursor 미전달
    expect(next.nextCursor, isNull); // ?? this.nextCursor가 아님 — 명시 대입
    final kept = s.copyWith(nextCursor: 'c2'); // 명시해야 유지
    expect(kept.nextCursor, 'c2');
  });
}
```
> 🔶 **ENG-REVIEW(P2)**: `copyWith`의 `nextCursor`는 다른 필드(`??`)와 달리 **명시 대입**(약 L496)이라 생략 시 `null`로 떨어진다. 컨트롤러가 매번 `nextCursor:`를 넘기는 전제를 단위테스트로 고정해 우발적 누락(끝 신호 유실)을 회귀 방지한다.

- [ ] **Step 2: 실패 확인** — Run: `cd apps/web && flutter test test/features/community/community_controller_test.dart ; cd ../..` → FAIL

- [ ] **Step 3: 구현 — `community_source.dart`(fetch 심(seam))**

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

- [ ] **Step 6: 목 픽스처 추가(다중페이지 — query-aware 키, ENG-REVIEW D3)**

> 🔶 **D3 반영**: P2 Task 10에서 `MockHttpAdapter`가 **query-aware**가 되어 `'GET /community/posts?cursor=c2'` 키로 페이지별 픽스처를 등록할 수 있다(query 없으면 path-only 폴백). 1페이지 픽스처에 `nextCursor: 'c2'`를 주고 `?cursor=c2` 키에 2페이지를 등록하면 **앱 기본 목에서도 "더 보기" 다중페이지가 실제 동작**한다(이전엔 query 무시라 단일 페이지였음).

`apps/web/lib/src/data/web_mock_fixtures.dart`의 `webMockFixtures`에:
```dart
  // 1페이지 — nextCursor: 'c2'로 "더 보기" 노출
  'GET /community/posts': (
    200,
    {
      'data': [
        {'id': 'q1', 'title': 'async/await가 헷갈려요', 'author': '지수', 'answerCount': 2},
        {'id': 'q2', 'title': 'Stream 구독 해제는?', 'author': '민준', 'answerCount': 1},
        {'id': 'q3', 'title': 'Riverpod Notifier 패턴', 'author': '서연', 'answerCount': 5},
      ],
      'nextCursor': 'c2', // 다음 페이지 있음 → 더 보기 활성
      'limit': 20,
    },
  ),
  // 2페이지 — query-aware 키(P2 Task 10). nextCursor: null로 마지막
  'GET /community/posts?cursor=c2': (
    200,
    {
      'data': [
        {'id': 'q4', 'title': 'FutureProvider vs Notifier', 'author': '도윤', 'answerCount': 0},
        {'id': 'q5', 'title': 'go_router 가드 적용', 'author': '하은', 'answerCount': 3},
      ],
      'nextCursor': null, // 마지막 페이지
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

  // 🔶 ENG-REVIEW(§9.2 ERROR): 첫 로드 실패 → DpError + 재시도 탭 → reload.
  testWidgets('첫 로드 실패는 DpError와 재시도를 보인다', (tester) async {
    var calls = 0;
    final c = ProviderContainer(overrides: [
      communityFetchProvider.overrideWithValue(({String? cursor}) async {
        calls++;
        if (calls == 1) throw const ApiException('네트워크 오류');
        return Page(
          data: [CommunityPost(id: 'q1', title: '복구된 글', author: '지수')],
          limit: 20,
        );
      }),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();
    expect(find.byType(DpError), findsOneWidget);

    await tester.tap(find.text('다시 시도')); // DpError 재시도
    await tester.pumpAndSettle();
    expect(find.text('복구된 글'), findsOneWidget); // reload 성공
  });

  // 🔶 ENG-REVIEW(더 보기 상호작용): hasMore=true → 버튼 렌더+탭 → 2페이지 누적(PARTIAL).
  testWidgets('"더 보기" 탭은 다음 페이지를 누적한다', (tester) async {
    final c = ProviderContainer(overrides: [
      communityFetchProvider.overrideWithValue(({String? cursor}) async {
        if (cursor == null) {
          return Page(
            data: [CommunityPost(id: 'q1', title: '1페이지글', author: '지수')],
            nextCursor: 'c2',
            limit: 20,
          );
        }
        return Page(
          data: [CommunityPost(id: 'q2', title: '2페이지글', author: '민준')],
          limit: 20,
        );
      }),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();
    expect(find.text('더 보기'), findsOneWidget); // hasMore → 버튼 렌더

    await tester.tap(find.text('더 보기'));
    await tester.pumpAndSettle();
    expect(find.text('1페이지글'), findsOneWidget);
    expect(find.text('2페이지글'), findsOneWidget); // 누적
    expect(find.text('더 보기'), findsNothing); // nextCursor null → 버튼 사라짐
  });

  // 🔶 ENG-REVIEW(P2 loadMore 에러): 더 보기 실패가 무음이면 안 됨 → 인라인 에러 표시.
  testWidgets('"더 보기" 실패는 인라인 에러를 보인다(무음 금지)', (tester) async {
    final c = ProviderContainer(overrides: [
      communityFetchProvider.overrideWithValue(({String? cursor}) async {
        if (cursor == null) {
          return Page(
            data: [CommunityPost(id: 'q1', title: '1페이지글', author: '지수')],
            nextCursor: 'c2',
            limit: 20,
          );
        }
        throw const ApiException('더 보기 실패');
      }),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.tap(find.text('더 보기'));
    await tester.pumpAndSettle();
    // 기존 목록은 유지하면서 에러를 노출(인라인 텍스트 또는 SnackBar)
    expect(find.text('1페이지글'), findsOneWidget);
    expect(find.textContaining('더 보기 실패'), findsWidgets);
    expect(find.text('재시도'), findsOneWidget); // 인라인 재시도
  });
}
```
> 🔶 **ERROR 테스트**(§9.2): 첫 로드 실패→`DpError`+재시도 탭→reload를 커뮤니티 홈에서 고정(세 화면 중 1곳 ERROR 검증 충족).
> 🔶 **더 보기 상호작용**: `hasMore=true`에서 버튼 렌더+탭→2페이지 누적(PARTIAL) override 위젯테스트.
> 🔶 **loadMore 에러 표시**(P2): 컨트롤러는 `copyWith(loadingMore:false, error:…)`(약 L543)로 error를 채우지만 홈은 `phase`만 switch(약 L680)해 "더 보기 실패"가 **무음**이었음 → 본 실패테스트로 **인라인 에러 + 재시도**(또는 SnackBar)를 강제. 실패테스트 먼저 작성 후 Step 3에서 구현.

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
        icon: const Icon(DpIcons.edit),
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
                // 🔶 ENG-REVIEW(P2): loadMore 에러를 무음으로 두지 않는다.
                // error가 있으면 인라인 메시지 + 재시도, 없으면 더 보기 버튼.
                if (s.error != null) {
                  return Column(children: [
                    Text(s.error!,
                        style: TextStyle(color: context.dpColors.danger)),
                    const SizedBox(height: DpSpacing.xs),
                    TextButton(
                      onPressed: s.loadingMore ? null : notifier.loadMore,
                      child: const Text('재시도'),
                    ),
                  ]);
                }
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
> P4f 아이콘: `DpIcons.edit`(Symbols, P3 추가) 사용 — DD3 준수. 작성(FAB)은 프로토 no-op.
> 🔶 ENG-REVIEW(P2): loadMore 에러 시 컨트롤러가 `nextCursor`를 **유지**(L543 `copyWith(loadingMore:false, nextCursor: state.nextCursor, error:…)`)하므로 `hasMore`가 참으로 남아 trailing 슬롯이 계속 렌더 → 위 인라인 에러 분기가 보인다. 재시도 탭은 `loadMore`를 재호출(성공 시 error는 명시 미전달로 자동 해소).

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
    // P4f-A: QnaDetailPage가 context.dpColors(테마 확장)을 쓰므로 theme 필수.
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(theme: DpTheme.light(), home: const QnaDetailPage(postId: 'q1')),
    ));
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

/// P4f-B: 다른 컨트롤러(Content·Dashboard·Path)와 동일한 plain Notifier + load(id) 패턴.
/// (riverpod 3.x family 베이스 클래스 불확실성 회피 + P4 일관성)
class QnaDetailController extends Notifier<QnaDetailState> {
  @override
  QnaDetailState build() => const QnaLoading();

  Future<void> load(String postId) async {
    state = const QnaLoading();
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
    NotifierProvider<QnaDetailController, QnaDetailState>(QnaDetailController.new);
```
> P4f-B: postId는 페이지가 보유(widget 파라미터)하고 `load(postId)`를 initState에서 호출 — Content/Dashboard와 동일. 한 화면에 한 상세만 떠 있으므로 family 인스턴스 분리 불필요(프로토 범위).

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

class QnaDetailPage extends ConsumerStatefulWidget {
  const QnaDetailPage({super.key, required this.postId});
  final String postId;

  @override
  ConsumerState<QnaDetailPage> createState() => _QnaDetailPageState();
}

class _QnaDetailPageState extends ConsumerState<QnaDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(qnaDetailControllerProvider.notifier).load(widget.postId));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(qnaDetailControllerProvider);
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

## Task 6: 골든패스 integration_test E2E (ENG-REVIEW D3) — ⚠️ P4f 단독 범위 밖, P4 종료 후 별도 통합 태스크

> 🔶 **ENG-REVIEW(P3) 분리**: 본 태스크는 P4a~f **전체 선행**(로그인·온보딩·PATH·콘텐츠·SBX·리뷰·멘토·대시보드·커뮤니티)을 요구하는 **횡단 태스크**다. P4f 단독으로는 완결 불가하므로 **P4 종료 후 별도 통합 태스크("P4-E2E")로 분리**해 실행한다. 여기에는 참조용으로만 남기고, P4f 구현·검증(Definition of Done)에는 포함하지 않는다.
>
> 스펙 §5가 명시한 **골든패스 통합 테스트**. 각 플랜의 widget smoke와 별개로 `integration_test`로 목 모드 전체 흐름을 실 렌더 파이프라인에서 검증. Monaco/SBX 시각부는 `flutter drive -d chrome`에서 가치가 크므로, 본 태스크는 headless로 가능한 핵심 흐름(인증→온보딩→PATH→대시보드→커뮤니티)을 커버하고 SBX는 노트로 남긴다. **선행: P4a~f 구현 완료.**
>
> 🔶 **전제**: 셸 내비(대시보드/커뮤니티 탭) 전이 검증은 **단순 ShellRoute(탭 전환 시 화면 재생성)** 전제 위에 성립한다. 탭 상태 보존(`StatefulShellRoute` 등)을 도입하면 `find.byType(...)`/재로드 가정이 달라지므로 분리 태스크에서 재검토한다.

**Files:**
- Modify: `apps/web/pubspec.yaml`(dev: `integration_test`)
- Create: `apps/web/integration_test/golden_path_test.dart`

- [ ] **Step 1: 의존성**

`apps/web/pubspec.yaml`의 `dev_dependencies:`에 추가:
```yaml
  integration_test:
    sdk: flutter
```
Run: `melos bootstrap`

- [ ] **Step 2: E2E 테스트**

Create `apps/web/integration_test/golden_path_test.dart`:
```dart
import 'package:devpath_web/src/app/app.dart';
import 'package:devpath_web/src/features/auth/presentation/login_page.dart';
import 'package:devpath_web/src/features/community/presentation/community_home_page.dart';
import 'package:devpath_web/src/features/dashboard/presentation/dashboard_page.dart';
import 'package:devpath_web/src/features/onboarding/presentation/onboarding_page.dart';
import 'package:devpath_web/src/features/path/presentation/path_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('골든패스 E2E: 로그인→온보딩→PATH→대시보드→커뮤니티(목)', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DevPathWebApp()));
    await tester.pumpAndSettle();

    // 1) 미인증 → 로그인
    expect(find.byType(LoginPage), findsOneWidget);
    await tester.tap(find.text('GitHub로 계속하기 (목)'));
    await tester.pumpAndSettle();

    // 2) 온보딩 진단 제출 → PATH
    expect(find.byType(OnboardingPage), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'jisoo-dev');
    await tester.tap(find.text('진단 시작하기'));
    await tester.pumpAndSettle(const Duration(seconds: 3)); // 목 SSE 4단계(250ms×4)

    // 3) PATH 생성 완료(12주 타임라인)
    expect(find.byType(PathPage), findsOneWidget);
    expect(find.textContaining('비동기 기초'), findsWidgets);

    // 4) 셸 내비 → 대시보드 (PathPage는 ShellRoute 내부라 하단탭/레일 존재)
    await tester.tap(find.text('대시보드').last);
    await tester.pumpAndSettle();
    expect(find.byType(DashboardPage), findsOneWidget);

    // 5) 셸 내비 → 커뮤니티
    await tester.tap(find.text('커뮤니티').last);
    await tester.pumpAndSettle();
    expect(find.byType(CommunityHomePage), findsOneWidget);
  });
}
```
> SBX(Monaco)·콘텐츠·리뷰·멘토는 시각/플랫폼 의존이 커 headless integration_test에서 부분만 검증 가능 → 본 E2E는 인증·온보딩·PATH·셸내비·커뮤니티 핵심 전이를 커버. Monaco 실 렌더·SSE 실스트리밍은 `flutter drive -d chrome` 또는 실서버 단계에서 확장(리스크 참조).

- [ ] **Step 3: 실행 + 커밋**
```bash
cd apps/web && flutter test integration_test/golden_path_test.dart ; cd ../..
git add apps/web/pubspec.yaml apps/web/integration_test pubspec.lock
git commit -m "test(web): 골든패스 integration_test E2E(스펙 §5, ENG-REVIEW D3)"
```

---

## 검증 기준 (Definition of Done)

- [ ] `melos run analyze`/`test` — dp_core(2모델) + web(dashboard·community·qna) PASS
- [ ] 대시보드: 스트릭(displaySmall) → 진행률(바) → 다음 과제 단일 CTA → 배지 위계
- [ ] 커뮤니티 홈: 목록(탭→상세) · 빈상태("첫 질문을 남겨보세요"+CTA) · 커서 "더 보기" — 🔶 **다중페이지 데모 동작(목)**: query-aware 픽스처(`?cursor=c2`)로 앱 기본 목에서도 2페이지 누적 확인(+컨트롤러 테스트로 코드 검증)
- [ ] 🔶 **커뮤니티 "더 보기" 상호작용 위젯테스트**: hasMore→버튼 렌더+탭→2페이지 누적(PARTIAL)
- [ ] 🔶 **loadMore 에러 표시(P2)**: "더 보기" 실패가 무음이 아니라 인라인 에러+재시도로 노출(위젯테스트로 고정)
- [ ] 🔶 **ERROR 위젯테스트(§9.2)**: 커뮤니티 홈 첫 로드 실패→`DpError`+재시도 탭→reload
- [ ] 🔶 **copyWith 단위테스트(P2)**: `nextCursor` 명시 대입(생략 시 null) 비대칭 고정
- [ ] Q&A 상세: 제목·작성자·본문(DpMarkdown)
- [ ] `/dashboard`·`/community`가 `PlaceholderPage`→실제 화면, `/community/:id` 신설
- [ ] **web 골든패스 완성**: 로그인→온보딩→PATH→콘텐츠→Sandbox→리뷰→멘토→대시보드→커뮤니티 전 화면 동작(목)
- [ ] 🔶 골든패스 E2E(Task 6)는 **P4f 범위 밖** — P4 종료 후 별도 통합 태스크("P4-E2E")에서 검증(여기 DoD 비포함)

## 리스크 / 후속 (명시)

- **다중 페이지 목**: ✅ 해소 — P2 Task 10에서 `MockHttpAdapter`가 **query-aware**가 되어 `'GET /community/posts?cursor=c2'` 키로 2페이지를 등록(query 없으면 path-only 폴백). 앱 기본 목에서도 "더 보기" 다중페이지가 **실제 동작**(코드/누적은 컨트롤러 테스트로도 검증). (이전 한계: query 무시 → 단일 페이지였음.)
- **작성/답변/투표 미구현**: 질문 작성(FAB)·답변 스레드·평판 게이트는 프로토 범위 밖(자리만).
- **아이콘**: ✅ 반영 — `DpIcons.edit`(Symbols, P3 추가)로 교체. DD3 준수.
- **대시보드 차트 단순화**: 진행바만. 상세 통계/그래프는 후속.
- **이모지 예외**: 🔥(스트릭)·🏅(배지)는 DD3가 명시 허용한 게이미피케이션 예외(스펙 §9.1).
