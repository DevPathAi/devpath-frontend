import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ads/presentation/ad_slot_widget.dart';
import '../application/community_controller.dart';
import '../application/community_search_controller.dart';
import '../state/community_search_state.dart';
import '../state/community_state.dart';
import 'web_community_board_projection.dart';
import 'widgets/community_search_bar.dart';
import '../../support/presentation/supportable_error.dart';

class CommunityHomePage extends ConsumerStatefulWidget {
  const CommunityHomePage({super.key, this.initialBoard, this.initialQuery});

  /// URL 쿼리 `?board=`(QNA/FREE/FEEDBACK) 프리셋. null=자유게시판.
  final String? initialBoard;

  /// URL 쿼리 `?q=` 프리셋. 값이 있으면 진입 즉시 검색 결과를 보여준다(딥링크·새로고침).
  final String? initialQuery;

  @override
  ConsumerState<CommunityHomePage> createState() => _CommunityHomePageState();
}

class _CommunityHomePageState extends ConsumerState<CommunityHomePage> {
  late CommunityBoard _entryBoard;

  static CommunityBoard _resolveBoard(String? value) => value == null
      ? CommunityBoard.free
      : CommunityBoard.values.firstWhere(
          (board) => board != CommunityBoard.all && board.value == value,
          orElse: () => CommunityBoard.free,
        );

  @override
  void initState() {
    super.initState();
    _entryBoard = _resolveBoard(widget.initialBoard);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(communityControllerProvider.notifier);
      notifier.selectBoard(_entryBoard);

      // 검색어 변경 시 URL 을 갱신하므로 이 페이지가 다시 만들어질 수 있다. 이미 같은 검색어로
      // 결과를 들고 있으면 재조회하지 않는다(타이핑마다 중복 호출 방지).
      final q = widget.initialQuery?.trim() ?? '';
      final search = ref.read(communitySearchControllerProvider);
      if (search.query != q) {
        ref
            .read(communitySearchControllerProvider.notifier)
            .search(q, board: _entryBoard.value);
      }
    });
  }

  @override
  void didUpdateWidget(covariant CommunityHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextBoard = _resolveBoard(widget.initialBoard);
    final boardChanged = nextBoard != _entryBoard;
    if (boardChanged) _entryBoard = nextBoard;

    final nextQuery = widget.initialQuery?.trim() ?? '';
    final search = ref.read(communitySearchControllerProvider);
    // 검색은 게시판 범위라, 검색어가 같아도 게시판이 바뀌면 다시 조회한다.
    final queryChanged =
        search.query != nextQuery || (boardChanged && nextQuery.isNotEmpty);
    if (!boardChanged && !queryChanged) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (boardChanged) {
        ref.read(communityControllerProvider.notifier).selectBoard(nextBoard);
      }
      if (queryChanged) {
        ref
            .read(communitySearchControllerProvider.notifier)
            .search(nextQuery, board: nextBoard.value);
      }
    });
  }

  /// 검색어를 컨트롤러와 URL 에 함께 반영한다. `go` 가 아니라 `replace` 인 이유: 타이핑마다
  /// 히스토리에 쌓이면 뒤로가기가 글자 수만큼 눌러야 하는 화면이 된다.
  void _onQueryChanged(String q, CommunityBoard board) {
    ref
        .read(communitySearchControllerProvider.notifier)
        .search(q, board: board.value);
    final params = <String, String>{
      if (board.value != null) 'board': board.value!,
      if (q.isNotEmpty) 'q': q,
    };
    final uri = Uri(
      path: '/community',
      queryParameters: params.isEmpty ? null : params,
    );
    context.replace(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(communityControllerProvider);
    final notifier = ref.read(communityControllerProvider.notifier);
    final search = ref.watch(communitySearchControllerProvider);
    final activeBoard = s.board == CommunityBoard.all ? _entryBoard : s.board;
    final posts = s.visiblePosts;
    // 게시판마다 독립 페이지라 작성도 고르는 단계 없이 이 게시판의 작성 화면으로 간다.
    void compose() => context.go(activeBoard.composePath);

    return Scaffold(
      body: CustomScrollView(
        // 스크린리더가 「N개 중 M번째」를 읽을 수 있게 목록 항목 수를 알린다.
        // `CustomScrollView`는 `ListView`와 달리 이 값을 자동으로 채우지 않는다.
        //
        // **`itemCount`가 아니라 콘텐츠 수를 센다** — 피드의 광고 슬롯과 검색의
        // 「더 보기」 버튼은 itemCount에는 들어가지만 목록 항목이 아니다.
        // 틀린 개수는 없는 것보다 나쁘다.
        semanticChildCount: search.phase == CommunitySearchPhase.idle
            ? posts.length
            : search.items.length,
        slivers: [
          SliverToBoxAdapter(
            child: CommunityBoardHeader(board: activeBoard, onCompose: compose),
          ),
          PinnedHeaderSliver(
            child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Padding(
                // 좌우 거터는 셸이 준다 — 여기서 또 주면 필터 줄이 헤더보다
                // 더 들여쓰인다.
                padding: const EdgeInsets.only(
                  top: DpSpacing.md,
                  bottom: DpSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: CommunitySearchBar(
                        // 힌트가 게시판을 따라 바뀌어도 입력 상태는 유지한다.
                        initialQuery: widget.initialQuery ?? '',
                        hintText: activeBoard.searchHint,
                        onChangedDebounced: (q) =>
                            _onQueryChanged(q, activeBoard),
                      ),
                    ),
                    const SizedBox(width: DpSpacing.sm),
                    CommunitySortMenu(
                      current: s.sort,
                      enabled: search.phase == CommunitySearchPhase.idle,
                      onSelect: notifier.selectSort,
                    ),
                  ],
                ),
              ),
            ),
          ),
          ...search.phase == CommunitySearchPhase.idle
              ? _bodySlivers(context, s, posts, notifier, activeBoard, compose)
              : _searchSlivers(context, search, activeBoard),
        ],
      ),
    );
  }

  /// 검색 모드 본문. 목록 경로(`_bodySlivers`)와 상호 배타다.
  List<Widget> _searchSlivers(
    BuildContext context,
    CommunitySearchState search,
    CommunityBoard board,
  ) {
    switch (search.phase) {
      case CommunitySearchPhase.idle:
        return const [];
      case CommunitySearchPhase.loading:
        return const [SliverFillRemaining(child: DpLoading())];
      case CommunitySearchPhase.failed:
        return [
          SliverFillRemaining(
            key: const ValueKey('search-error'),
            child: SupportableError(
              message: search.error ?? '검색하지 못했어요',
              onRetry: () => ref
                  .read(communitySearchControllerProvider.notifier)
                  .retry(board: board.value),
            ),
          ),
        ];
      case CommunitySearchPhase.loaded:
        final compact = context.windowClass == DpWindowClass.compact;
        return [
          SliverToBoxAdapter(
            child: DpPanel(
              child: DpWebTable(
                columns: communityBoardColumns(board, compact: compact),
                // 빈 검색 결과는 이제 표의 `empty` 다 — 키는 그대로 둔다
                // (그 키로 상태를 찾는 테스트의 계약을 깨지 않는다).
                empty: Padding(
                  key: const ValueKey('search-empty'),
                  padding: const EdgeInsets.symmetric(vertical: DpSpacing.xl),
                  child: DpEmpty(
                    icon: DpIcons.search,
                    title: '검색 결과가 없어요',
                    message: '"${search.query}"와 맞는 글을 찾지 못했어요. 다른 낱말로 찾아보세요.',
                  ),
                ),
                rows: [
                  for (final item in search.items)
                    communitySearchRow(
                      context: context,
                      item: item,
                      board: board,
                      compact: compact,
                      onTap: () => context.go(
                        item.boardType == 'QNA'
                            ? '/community/${item.id}'
                            : '/community/post/${item.id}?board=${item.boardType}',
                      ),
                    ),
                ],
              ),
            ),
          ),
          // 표 중간에 버튼 행을 끼우면 칼럼 정렬이 깨진다 — 표 아래로 옮긴다.
          if (search.hasMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: DpSpacing.md),
                child: OutlinedButton(
                  key: const ValueKey('search-more'),
                  onPressed: search.loadingMore
                      ? null
                      : () => ref
                            .read(communitySearchControllerProvider.notifier)
                            .loadMore(board: board.value),
                  child: Text(
                    search.loadingMore
                        ? '불러오는 중…'
                        : '더 보기 (${search.items.length}/${search.total})',
                  ),
                ),
              ),
            ),
        ];
    }
  }

  List<Widget> _bodySlivers(
    BuildContext context,
    CommunityState s,
    List<CommunityPostSummary> posts,
    CommunityController notifier,
    CommunityBoard board,
    VoidCallback onCompose,
  ) {
    switch (s.phase) {
      case CommunityPhase.loading:
        return const [SliverFillRemaining(child: DpLoading())];
      case CommunityPhase.failed:
        return [
          SliverFillRemaining(
            child: SupportableError(
              message: s.error ?? '불러오지 못했어요',
              onRetry: notifier.load,
            ),
          ),
        ];
      case CommunityPhase.loaded:
        final compact = context.windowClass == DpWindowClass.compact;
        // 5번째 게시글 뒤에 끼우던 피드 광고를 표 **아래**로 옮긴다 — 표 중간
        // 광고 행은 칼럼 정렬을 깬다. 노출 조건(글이 5개 이상)은 그대로다.
        const feedAdAt = 5;
        return [
          SliverToBoxAdapter(
            child: DpPanel(
              child: DpWebTable(
                columns: communityBoardColumns(board, compact: compact),
                empty: CommunityBoardEmpty(board: board),
                rows: [
                  for (final post in posts)
                    communityPostRow(
                      context: context,
                      post: post,
                      board: board,
                      compact: compact,
                      onTap: () => context.go(
                        post.boardType == 'QNA'
                            ? '/community/${post.id}'
                            : '/community/post/${post.id}?board=${post.boardType}',
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (posts.length >= feedAdAt)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: DpSpacing.lg),
                child: AdSlotWidget(slot: 'COMMUNITY_FEED'),
              ),
            ),
        ];
    }
  }
}
