import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../ads/presentation/ad_slot_widget.dart';
import '../application/community_controller.dart';
import '../state/community_state.dart';

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
        notifier.selectBoard(board);
      }
    });
  }

  /// FAB 스피드다이얼 — 질문/자유글/피드백 요청 3종 작성 진입.
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
              subtitle: const Text('Q&A 보드에 질문을 올려요'),
              onTap: () {
                Navigator.pop(sheetContext);
                context.go('/community/new');
              },
            ),
            ListTile(
              leading: const Icon(DpIcons.community),
              title: const Text('자유글'),
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
        isQna ? '/community/${post.id}' : '/community/post/${post.id}',
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

/// 통합 피드 상단 보드 필터 — 전체/Q&A/자유/피드백.
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
