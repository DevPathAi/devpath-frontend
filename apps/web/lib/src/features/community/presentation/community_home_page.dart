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
import 'widgets/community_search_bar.dart';
import 'widgets/search_highlight.dart';
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
    final queryChanged = search.query != nextQuery;
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

  /// FAB 스피드다이얼 — Q/A 질문/자유게시판 글/피드백 요청 3종 작성 진입.
  void _openComposeSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(DpIcons.mentor),
              title: const Text('질문하기'),
              subtitle: const Text('Q/A에 질문을 올려요'),
              onTap: () {
                Navigator.pop(sheetContext);
                context.go('/community/new');
              },
            ),
            ListTile(
              leading: const Icon(DpIcons.community),
              title: const Text('자유게시판'),
              subtitle: const Text('자유롭게 이야기를 나눠요'),
              onTap: () {
                Navigator.pop(sheetContext);
                context.go('/community/new/post?board=FREE');
              },
            ),
            ListTile(
              leading: const Icon(DpIcons.thumbUp),
              title: const Text('피드백 요청'),
              subtitle: const Text('내 코드/프로젝트 리뷰를 요청해요'),
              onTap: () {
                Navigator.pop(sheetContext);
                context.go('/community/new/post?board=FEEDBACK');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(communityControllerProvider);
    final notifier = ref.read(communityControllerProvider.notifier);
    final search = ref.watch(communitySearchControllerProvider);
    final activeBoard = s.board == CommunityBoard.all ? _entryBoard : s.board;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openComposeSheet(context),
        icon: const Icon(DpIcons.edit),
        label: Text(activeBoard == CommunityBoard.qna ? '질문하기' : '글 작성'),
      ),
      body: CustomScrollView(
        // 스크린리더가 「N개 중 M번째」를 읽을 수 있게 목록 항목 수를 알린다.
        // `CustomScrollView`는 `ListView`와 달리 이 값을 자동으로 채우지 않는다.
        //
        // **`itemCount`가 아니라 콘텐츠 수를 센다** — 피드의 광고 슬롯과 검색의
        // 「더 보기」 버튼은 itemCount에는 들어가지만 목록 항목이 아니다.
        // 틀린 개수는 없는 것보다 나쁘다.
        semanticChildCount: search.phase == CommunitySearchPhase.idle
            ? s.posts.length
            : search.items.length,
        slivers: [
          SliverToBoxAdapter(
            child: DpPageHeader(
              title: activeBoard.label,
              description: switch (activeBoard) {
                CommunityBoard.free => '개발 이야기를 자유롭게 나눕니다',
                CommunityBoard.qna => '막힌 문제를 질문하고 함께 해결합니다',
                CommunityBoard.feedback => '코드와 프로젝트에 구체적인 의견을 나눕니다',
                CommunityBoard.all => '개발 이야기를 자유롭게 나눕니다',
              },
            ),
          ),
          PinnedHeaderSliver(
            child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      DpSpacing.lg,
                      DpSpacing.md,
                      DpSpacing.lg,
                      0,
                    ),
                    child: CommunitySearchBar(
                      initialQuery: widget.initialQuery ?? '',
                      onChangedDebounced: (q) =>
                          _onQueryChanged(q, activeBoard),
                    ),
                  ),
                  _BoardFilterBar(
                    current: activeBoard,
                    onSelect: (board) {
                      _entryBoard = board;
                      notifier.selectBoard(board);
                      // 검색 중이면 같은 검색어를 새 보드로 다시 조회한다.
                      if (search.phase != CommunitySearchPhase.idle) {
                        ref
                            .read(communitySearchControllerProvider.notifier)
                            .search(search.query, board: board.value);
                      }
                      context.go('/community?board=${board.value}');
                    },
                  ),
                ],
              ),
            ),
          ),
          ...search.phase == CommunitySearchPhase.idle
              ? _bodySlivers(context, s, notifier)
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
        if (search.items.isEmpty) {
          return [
            SliverFillRemaining(
              key: const ValueKey('search-empty'),
              child: DpEmpty(
                icon: DpIcons.search,
                title: '검색 결과가 없어요',
                message: '"${search.query}"와 맞는 글을 찾지 못했어요. 다른 낱말로 찾아보세요.',
              ),
            ),
          ];
        }
        return [
          SliverPadding(
            padding: const EdgeInsets.all(DpSpacing.lg),
            sliver: SliverList.separated(
              itemCount: search.items.length + (search.hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: DpSpacing.sm),
              itemBuilder: (_, i) {
                if (i == search.items.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: DpSpacing.sm),
                    child: OutlinedButton(
                      key: const ValueKey('search-more'),
                      onPressed: search.loadingMore
                          ? null
                          : () => ref
                                .read(
                                  communitySearchControllerProvider.notifier,
                                )
                                .loadMore(board: board.value),
                      child: Text(
                        search.loadingMore
                            ? '불러오는 중…'
                            : '더 보기 (${search.items.length}/${search.total})',
                      ),
                    ),
                  );
                }
                return _searchRow(context, search.items[i]);
              },
            ),
          ),
        ];
    }
  }

  /// 검색 결과 행. 목록 행(`_postRow`)과 같은 [DpListRow] 를 쓰되 매칭 근거(하이라이트)를
  /// subtitle 로 항상 보여준다.
  Widget _searchRow(BuildContext context, CommunitySearchItem item) {
    final c = context.dpColors;
    final isQna = item.boardType == 'QNA';
    final accent = switch (item.boardType) {
      'FREE' => c.border,
      'FEEDBACK' => c.chart4,
      _ => c.primary,
    };
    final label = switch (item.boardType) {
      'FREE' => '자유게시판',
      'FEEDBACK' => '피드백',
      _ => 'Q/A',
    };
    // 본문 매칭이 없으면 highlight 가 비어 오므로 excerpt 로 폴백한다.
    final body = item.highlight.isNotEmpty ? item.highlight : item.excerpt;
    return DpListRow(
      accentColor: accent,
      title: item.title,
      subtitle: body.isEmpty ? null : SearchHighlightText(body),
      badges: [
        _badgeChip(context, label),
        if (isQna && item.solved) _badgeChip(context, '✓ 해결됨', tone: c.success),
      ],
      trailing: Text(
        '${isQna ? '답변' : '댓글'} ${item.replyCount} · 추천 ${item.upvoteCount}',
        style: TextStyle(color: c.textSecondary, fontSize: 12),
      ),
      onTap: () => context.go(
        isQna
            ? '/community/${item.id}'
            : '/community/post/${item.id}?board=${item.boardType}',
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
            child: SupportableError(
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
        const feedAdAt = 5; // 5번째 게시글(인덱스 4) 뒤
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
      'FEEDBACK' => c.chart4,
      _ => c.primary,
    };
    final label = switch (post.boardType) {
      'FREE' => '자유게시판',
      'FEEDBACK' => '피드백',
      _ => 'Q/A',
    };
    return DpListRow(
      accentColor: accent,
      title: post.title,
      preview: post.excerpt.isEmpty ? null : post.excerpt,
      badges: [
        _badgeChip(context, label),
        if (isQna && post.solved) _badgeChip(context, '✓ 해결됨', tone: c.success),
      ],
      trailing: Text(
        '${isQna ? '답변' : '댓글'} ${post.replyCount} · 추천 ${post.upvoteCount}',
        style: TextStyle(color: c.textSecondary, fontSize: 12),
      ),
      onTap: () => context.go(
        isQna
            ? '/community/${post.id}'
            : '/community/post/${post.id}?board=${post.boardType}',
      ),
    );
  }

  Widget _badgeChip(BuildContext context, String text, {Color? tone}) {
    final c = context.dpColors;
    final fg = tone ?? c.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DpSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: c.border,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: fg)),
    );
  }
}

/// 모바일·본문용 로컬 내비게이션. 데스크톱 레일과 같은 세 게시판만 노출한다.
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
              for (final b in CommunityBoard.values.where(
                (board) => board != CommunityBoard.all,
              ))
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
