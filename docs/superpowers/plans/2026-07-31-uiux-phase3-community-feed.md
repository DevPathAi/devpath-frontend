# UI/UX Phase 3 — 커뮤니티 피드 고도화 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 하위 B가 구현한 커뮤니티 피드를 `DpListRow`(dp_design Layer 2 신설)로 전환하고, 필터를 `SegmentedButton`+URL 쿼리 동기로, 리스트를 `CustomScrollView`/`SliverList`+`PinnedHeaderSliver` 고정으로 고도화한다(계약 불변).

**Architecture:** dp_design에 재사용 `DpListRow`(순수 표현부, `DpInteractiveCard` 베이스)를 신설하고, `community_home_page.dart`가 이를 조립한다. `CommunityController`/`CommunityState`/`CommunityBoard`/`/community/posts` 계약은 불변.

**Tech Stack:** Flutter Web(CanvasKit), Riverpod 3, go_router, SDK 기본 위젯(`SegmentedButton`·`CustomScrollView`·`SliverList`·`PinnedHeaderSliver`·`FocusableActionDetector`). 외부 패키지 신규 도입 없음. 검증 SSoT = spec `docs/superpowers/specs/2026-07-31-uiux-phase3-community-feed-design.md`.

## Global Constraints

- **계약 불변**: `/community/posts`·`CommunityPostSummary`(`id`·`title`·`boardType`·`authorId?`·`solved`·`upvoteCount`·`replyCount`)·`CommunityController`(`load`·`selectBoard`)·`CommunityState`·`CommunityBoard`(all/qna/free/feedback) 시그니처 변경 금지.
- **`DpListRow`는 go_router·Riverpod 비의존** 순수 표현부(Layer 2). 데이터·라우팅은 화면이 주입.
- **토큰만 사용**: `DpColors`(`context.dpColors`)·`DpSpacing`·`DpRadius`·`AppTokens.panelRadius`. 하드코딩 색/반경 금지.
- **장식 효과 금지**: 그림자·BackdropFilter 미사용.
- **라우팅 계약 유지**: QNA→`/community/:id`, FREE/FEEDBACK→`/community/post/:id`. 광고 슬롯 `COMMUNITY_FEED`(5번째 뒤) 유지.
- **게이트(매 커밋 전 관련 범위, 최종 전체)**: `melos run analyze`(0 issues)·`melos run test`(pass)·`melos run format`(clean). PATH 미설정 시 `dart pub global run melos <cmd>`.
- **커밋**: Conventional Commits. 각 메시지 끝에 `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

## Task 1: DpListRow (dp_design Layer 2)

**Files:**
- Create: `packages/dp_design/lib/src/data/dp_list_row.dart`
- Modify: `packages/dp_design/lib/dp_design.dart` (export 추가)
- Test: `packages/dp_design/test/data/dp_list_row_test.dart`

**Interfaces:**
- Consumes: `DpInteractiveCard`(dp_design), `context.dpColors`, `DpSpacing`, `DpRadius`.
- Produces: `DpListRow({Key? key, required String title, Color? accentColor, List<Widget> badges, Widget? trailing, VoidCallback? onTap})`.

- [ ] **Step 1: Write the failing test**

`packages/dp_design/test/data/dp_list_row_test.dart`:

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DpListRow: 제목·뱃지·trailing 렌더 + onTap 콜백', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: Scaffold(
          body: DpListRow(
            title: 'Riverpod 3 마이그레이션 질문',
            accentColor: const Color(0xFF4F6EF7),
            badges: const [Text('Q&A')],
            trailing: const Text('답변 3'),
            onTap: () => tapped = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Riverpod 3 마이그레이션 질문'), findsOneWidget);
    expect(find.text('Q&A'), findsOneWidget);
    expect(find.text('답변 3'), findsOneWidget);

    await tester.tap(find.text('Riverpod 3 마이그레이션 질문'));
    expect(tapped, isTrue);
  });

  testWidgets('DpListRow: hover/focus 베이스(FocusableActionDetector) 존재', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: Scaffold(
          body: DpListRow(title: '글', onTap: () {}),
        ),
      ),
    );
    expect(find.byType(FocusableActionDetector), findsWidgets);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/dp_design && flutter test test/data/dp_list_row_test.dart`
Expected: FAIL — `DpListRow` 정의되지 않음.

- [ ] **Step 3: Write minimal implementation**

`packages/dp_design/lib/src/data/dp_list_row.dart`:

```dart
import 'package:flutter/material.dart';

import '../interaction/dp_interactive_card.dart';
import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';

/// 리스트 행(Layer 2). 좌측 상태 표시선(accent) + 상단 뱃지행 → 제목 + 우측 trailing 메타.
/// DpInteractiveCard(hover/focus) 베이스. go_router·Riverpod 비의존 순수 표현부.
class DpListRow extends StatelessWidget {
  const DpListRow({
    super.key,
    required this.title,
    this.accentColor,
    this.badges = const [],
    this.trailing,
    this.onTap,
  });

  final String title;
  final Color? accentColor;
  final List<Widget> badges;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DpInteractiveCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (accentColor != null)
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(DpRadius.card),
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(DpSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (badges.isNotEmpty) ...[
                      Wrap(
                        spacing: DpSpacing.xs,
                        runSpacing: DpSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: badges,
                      ),
                      const SizedBox(height: DpSpacing.xs),
                    ],
                    Text(title, style: text.titleSmall),
                  ],
                ),
              ),
            ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DpSpacing.md,
                  vertical: DpSpacing.md,
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: trailing,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
```

`packages/dp_design/lib/dp_design.dart`에 export 추가(`export 'src/data/dp_kpi_card.dart';` 다음 줄):

```dart
export 'src/data/dp_list_row.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/dp_design && flutter test test/data/dp_list_row_test.dart`
Expected: PASS(2 tests).

- [ ] **Step 5: Commit**

```bash
git add packages/dp_design/lib/src/data/dp_list_row.dart packages/dp_design/lib/dp_design.dart packages/dp_design/test/data/dp_list_row_test.dart
git commit -m "feat(dp_design): DpListRow — accent·뱃지·메타 리스트 행(Layer 2)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: 필터 SegmentedButton + URL 쿼리 동기

**Files:**
- Modify: `apps/web/lib/src/features/community/presentation/community_home_page.dart` (필터바·initialBoard)
- Modify: `apps/web/lib/src/app/router.dart:113-115` (`/community` builder에 board 쿼리 전달)
- Test: `apps/web/test/features/community/community_home_page_test.dart` (ChoiceChip 단언 2건 갱신 + URL 동기 신규)

**Interfaces:**
- Consumes: `SegmentedButton<CommunityBoard>`(SDK), `CommunityBoard`, `CommunityController.selectBoard`, `GoRouterState`(라우트 builder).
- Produces: `CommunityHomePage({Key? key, String? initialBoard})` — 진입 시 `initialBoard` 쿼리로 초기 필터 결정.

- [ ] **Step 1: Write the failing test (기존 테스트 갱신 + 신규)**

`community_home_page_test.dart`의 **두 테스트를 아래로 교체**하고 **URL 동기 테스트를 추가**한다. (나머지 테스트 — 목록 렌더·빈·에러·FAB·QNA 탭 — 는 그대로 둔다.)

`'통합 피드: 필터칩 4개 + 보드 뱃지 + 일반글 탭 라우팅'` 테스트의 필터칩 단언 블록을 교체:

```dart
    // 필터: SegmentedButton(전체/Q&A/자유/피드백)
    expect(find.byType(SegmentedButton<CommunityBoard>), findsOneWidget);
    expect(find.text('전체'), findsOneWidget);
    expect(find.text('Q&A'), findsOneWidget);
    expect(find.text('피드백'), findsOneWidget);
    // 카드 제목 + 보드 뱃지('자유')
    expect(find.text('자유글'), findsOneWidget);
    expect(find.text('자유'), findsWidgets); // 세그먼트 + 뱃지
    expect(find.textContaining('댓글 1'), findsOneWidget);
```

(`import 'package:devpath_web/src/features/community/state/community_state.dart';`를 테스트 상단에 추가해 `CommunityBoard` 타입을 참조.)

`'필터칩 선택 시 selectBoard로 재조회한다'` → SegmentedButton 세그먼트 탭으로 교체(뱃지와 텍스트 충돌 피하려 post를 QNA로):

```dart
  testWidgets('SegmentedButton 선택 시 selectBoard로 재조회한다', (tester) async {
    final seen = <String?>[];
    final c = ProviderContainer(
      overrides: [
        communityListProvider.overrideWithValue(({
          String? board,
          String? tag,
          String? sort,
        }) async {
          seen.add(board);
          return [_p(10, title: '질문글', boardType: 'QNA')];
        }),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.tap(find.text('자유')); // QNA post라 '자유'는 세그먼트뿐
    await tester.pumpAndSettle();
    expect(seen, contains('FREE'));
  });
```

URL 동기 신규 테스트 추가:

```dart
  testWidgets('initialBoard 쿼리로 진입 시 초기 필터가 반영된다', (tester) async {
    final seen = <String?>[];
    final c = ProviderContainer(
      overrides: [
        communityListProvider.overrideWithValue(({
          String? board,
          String? tag,
          String? sort,
        }) async {
          seen.add(board);
          return const [];
        }),
      ],
    );
    addTearDown(c.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const CommunityHomePage(initialBoard: 'FREE'),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(theme: DpTheme.light(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(seen, contains('FREE'));
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/web && flutter test test/features/community/community_home_page_test.dart`
Expected: FAIL — `SegmentedButton` 미존재·`CommunityHomePage(initialBoard:)` 미정의.

- [ ] **Step 3: Write minimal implementation**

`community_home_page.dart` 수정:

(a) `CommunityHomePage`에 `initialBoard` 추가 + `initState`에서 초기 필터 결정:

```dart
class CommunityHomePage extends ConsumerStatefulWidget {
  const CommunityHomePage({super.key, this.initialBoard});

  /// URL 쿼리 `?board=`(QNA/FREE/FEEDBACK) 프리셋. null=전체.
  final String? initialBoard;

  @override
  ConsumerState<CommunityHomePage> createState() => _CommunityHomePageState();
}

class _CommunityHomePageState extends ConsumerState<CommunityHomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final board = CommunityBoard.values.firstWhere(
        (b) => b.value == widget.initialBoard,
        orElse: () => CommunityBoard.all,
      );
      final notifier = ref.read(communityControllerProvider.notifier);
      if (board == CommunityBoard.all) {
        notifier.load();
      } else {
        notifier.selectBoard(board); // board 설정 + load
      }
    });
  }
  // ... _openComposeSheet 유지 ...
```

(b) `_BoardFilterBar`를 `SegmentedButton`으로 교체:

```dart
class _BoardFilterBar extends StatelessWidget {
  const _BoardFilterBar({required this.current, required this.onSelect});

  final CommunityBoard current;
  final void Function(CommunityBoard) onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DpSpacing.lg,
        DpSpacing.md,
        DpSpacing.lg,
        DpSpacing.sm,
      ),
      child: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<CommunityBoard>(
            segments: [
              for (final b in CommunityBoard.values)
                ButtonSegment(value: b, label: Text(b.label)),
            ],
            selected: {current},
            showSelectedIcon: false,
            onSelectionChanged: (s) => onSelect(s.first),
          ),
        ),
      ),
    );
  }
}
```

(c) build의 필터바 콜백을 URL 동기 포함으로:

```dart
    _BoardFilterBar(
      current: s.board,
      onSelect: (board) {
        ref.read(communityControllerProvider.notifier).selectBoard(board);
        context.go('/community?board=${board.value ?? ''}');
      },
    ),
```

`router.dart:113-115` `/community` builder 수정:

```dart
          GoRoute(
            path: '/community',
            builder: (_, state) => CommunityHomePage(
              initialBoard: state.uri.queryParameters['board'],
            ),
          ),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/web && flutter test test/features/community/community_home_page_test.dart`
Expected: PASS(전 테스트 — 갱신 2 + 신규 1 + 기존 유지).

- [ ] **Step 5: Commit**

```bash
git add apps/web/lib/src/features/community/presentation/community_home_page.dart apps/web/lib/src/app/router.dart apps/web/test/features/community/community_home_page_test.dart
git commit -m "feat(web): 커뮤니티 필터 SegmentedButton + URL(?board=) 동기

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: CustomScrollView/SliverList + PinnedHeaderSliver 고정 + _PostCard→DpListRow

**Files:**
- Modify: `apps/web/lib/src/features/community/presentation/community_home_page.dart` (본문 구조·행)
- Test: `apps/web/test/features/community/community_home_page_test.dart` (DpListRow 렌더 확인 추가)

**Interfaces:**
- Consumes: `DpListRow`(Task 1), `CustomScrollView`·`SliverList`·`PinnedHeaderSliver`(SDK), 기존 `AdSlotWidget`.
- Produces: 피드 본문이 `CustomScrollView`(고정 필터 + Sliver 리스트), 행은 `DpListRow`.

- [ ] **Step 1: Write the failing test**

`community_home_page_test.dart`에 DpListRow 렌더 테스트 추가:

```dart
  testWidgets('피드 행이 DpListRow로 렌더된다', (tester) async {
    final c = ProviderContainer(
      overrides: [
        communityListProvider.overrideWithValue(
          ({String? board, String? tag, String? sort}) async => [
            _p(1, title: 'DpListRow 행', boardType: 'FREE'),
          ],
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    expect(find.byType(DpListRow), findsOneWidget);
    expect(find.text('DpListRow 행'), findsOneWidget);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/web && flutter test test/features/community/community_home_page_test.dart --name "DpListRow로 렌더"`
Expected: FAIL — 행이 아직 `_PostCard`(DpListRow 없음).

- [ ] **Step 3: Write minimal implementation**

`community_home_page.dart` build 본문을 `CustomScrollView`로 전환하고 `_PostCard`/`_BoardBadge`를 `DpListRow` 조립으로 교체:

```dart
  @override
  Widget build(BuildContext context) {
    final s = ref.watch(communityControllerProvider);
    final notifier = ref.read(communityControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('커뮤니티')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openComposeSheet(context),
        icon: const Icon(DpIcons.edit),
        label: const Text('새 글'),
      ),
      body: CustomScrollView(
        slivers: [
          PinnedHeaderSliver(
            child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: _BoardFilterBar(
                current: s.board,
                onSelect: (board) {
                  notifier.selectBoard(board);
                  context.go('/community?board=${board.value ?? ''}');
                },
              ),
            ),
          ),
          ..._bodySlivers(context, s, notifier),
        ],
      ),
    );
  }

  List<Widget> _bodySlivers(
    BuildContext context,
    CommunityState s,
    CommunityController notifier,
  ) {
    switch (s.phase) {
      case CommunityPhase.loading:
        return const [SliverFillRemaining(child: DpLoading())];
      case CommunityPhase.failed:
        return [
          SliverFillRemaining(
            child: DpError(
              message: s.error ?? '불러오지 못했어요',
              onRetry: notifier.load,
            ),
          ),
        ];
      case CommunityPhase.loaded:
        if (s.posts.isEmpty) {
          return [
            SliverFillRemaining(
              child: DpEmpty(
                icon: DpIcons.community,
                title: '아직 글이 없어요',
                message: '첫 글을 남겨보세요.',
                actionLabel: '글 작성',
                onAction: () => _openComposeSheet(context),
              ),
            ),
          ];
        }
        const feedAdAt = 5;
        final showAd = s.posts.length >= feedAdAt;
        final count = s.posts.length + (showAd ? 1 : 0);
        return [
          SliverPadding(
            padding: const EdgeInsets.all(DpSpacing.lg),
            sliver: SliverList.separated(
              itemCount: count,
              separatorBuilder: (_, _) => const SizedBox(height: DpSpacing.sm),
              itemBuilder: (_, i) {
                if (showAd && i == feedAdAt) {
                  return const AdSlotWidget(slot: 'COMMUNITY_FEED');
                }
                final p = s.posts[(showAd && i > feedAdAt) ? i - 1 : i];
                return _postRow(context, p);
              },
            ),
          ),
        ];
    }
  }

  Widget _postRow(BuildContext context, CommunityPostSummary post) {
    final c = context.dpColors;
    final isQna = post.boardType == 'QNA';
    final accent = switch (post.boardType) {
      'FREE' => c.border,
      'FEEDBACK' => c.warning,
      _ => c.primary,
    };
    final label = switch (post.boardType) {
      'FREE' => '자유',
      'FEEDBACK' => '피드백',
      _ => 'Q&A',
    };
    return DpListRow(
      accentColor: accent,
      title: post.title,
      badges: [
        _badgeChip(context, label),
        if (isQna && post.solved) _badgeChip(context, '✓ 해결됨', tone: c.success),
      ],
      trailing: Text(
        '${isQna ? '답변' : '댓글'} ${post.replyCount} · 추천 ${post.upvoteCount}',
        style: TextStyle(color: c.textSecondary, fontSize: 12),
      ),
      onTap: () => context.go(
        isQna ? '/community/${post.id}' : '/community/post/${post.id}',
      ),
    );
  }

  Widget _badgeChip(BuildContext context, String text, {Color? tone}) {
    final c = context.dpColors;
    final fg = tone ?? c.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DpSpacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: c.border,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: fg)),
    );
  }
```

기존 `_PostCard`·`_BoardBadge` 클래스는 제거한다(위 `_postRow`/`_badgeChip`으로 대체). `_BoardFilterBar`는 Task 2 것을 유지.

> `_postRow`의 subtitle 메타는 기존과 동일 문자열(`'답변 N · 추천 N'`)이라 기존 `find.textContaining('답변 1')`·`'댓글 1'` 회귀가 유지된다. 라우팅 onTap도 동일.

- [ ] **Step 4: Run test to verify it passes (전체 community 폴더)**

Run: `cd apps/web && flutter test test/features/community/`
Expected: PASS — 신규 DpListRow 테스트 + Task 2 갱신 + 기존 라우팅/FAB/빈/에러 전부.

- [ ] **Step 5: 전체 게이트**

Run: `dart pub global run melos run analyze` · `dart pub global run melos run test` · `dart pub global run melos run format`
Expected: analyze 0 issues · 전 패키지 test PASS(community·dp_design 포함) · format clean.

- [ ] **Step 6: Commit**

```bash
git add apps/web/lib/src/features/community/presentation/community_home_page.dart apps/web/test/features/community/community_home_page_test.dart
git commit -m "feat(web): 커뮤니티 피드 SliverList + PinnedHeader 고정 + DpListRow 전환

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review (작성자 체크 결과)

**1. Spec coverage:**
- §2.1 DpListRow(Layer 2, 비의존, DpInteractiveCard 베이스) → Task 1 ✓ / §3 accent·뱃지·solved칩·메타·라우팅 → Task 3 `_postRow` ✓ / §3 SegmentedButton 필터 → Task 2 ✓ / §3 PinnedHeaderSliver 고정·SliverList → Task 3 ✓ / §3 URL `?board=` 동기 → Task 2(initialBoard+router+onSelect go) ✓ / §3 광고 슬롯 유지 → Task 3 인덱스 로직 보존 ✓ / §4 테스트 → Task 1~3 ✓ / §5 계약 불변 → Global Constraints + 회귀 ✓.

**2. Placeholder scan:** TBD/TODO 없음. 모든 코드 스텝 실제 코드 포함 ✓.

**3. Type consistency:** `DpListRow`(title/accentColor/badges/trailing/onTap)가 정의(Task 1)와 소비(Task 3 `_postRow`)에서 일치 ✓. `CommunityHomePage(initialBoard:)`가 router(Task 2)·테스트와 일치 ✓. `CommunityBoard.value`(String?)·`selectBoard`·`communityListProvider`(named params) 실측과 일치 ✓. `PinnedHeaderSliver`·`SegmentedButton<CommunityBoard>`·`SliverList.separated` SDK 시그니처 확인 ✓.

**4. 회귀 주의:** SegmentedButton 전환으로 기존 ChoiceChip 단언 2건은 **갱신**(Task 2에 명시). `selectBoard` 테스트는 post를 QNA로 바꿔 '자유' 텍스트 충돌(세그먼트 vs 뱃지)을 회피. 메타 문자열·라우팅 onTap은 불변이라 나머지 회귀 유지.
