import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

import '../state/community_state.dart';

/// 게시판 한 개의 결정적 투영(ET13 증거·위젯 테스트용).
///
/// [CommunityHomePage] 가 provider 로 채우는 것과 같은 H1·설명·게시판 세그먼트·목록·
/// 빈 상태를 순수 입력([board], [posts])만으로 그린다. 검색·광고·라우팅은 포함하지 않는다
/// (ET13 원칙: "controller/provider state replaced by approved deterministic fixture").
class WebCommunityBoardProjection extends StatelessWidget {
  const WebCommunityBoardProjection({
    super.key,
    required this.board,
    required this.posts,
    required this.onOpenPost,
    required this.onCompose,
    this.onSelectBoard,
  });

  final CommunityBoard board;
  final List<CommunityPostSummary> posts;
  final ValueChanged<CommunityPostSummary> onOpenPost;
  final VoidCallback onCompose;

  /// 세그먼트 선택. null 이면 세그먼트는 선택 상태만 보여 준다(증거 캡처).
  final ValueChanged<CommunityBoard>? onSelectBoard;

  static String descriptionFor(CommunityBoard board) => switch (board) {
    CommunityBoard.free => '개발 이야기를 자유롭게 나눕니다',
    CommunityBoard.qna => '막힌 문제를 질문하고 함께 해결합니다',
    CommunityBoard.feedback => '코드와 프로젝트에 구체적인 의견을 나눕니다',
    CommunityBoard.all => '개발 이야기를 자유롭게 나눕니다',
  };

  @override
  Widget build(BuildContext context) => CustomScrollView(
    semanticChildCount: posts.length,
    slivers: [
      SliverToBoxAdapter(
        child: DpPageHeader(
          title: board.label,
          description: descriptionFor(board),
        ),
      ),
      SliverToBoxAdapter(
        child: CommunityBoardFilterBar(
          current: board,
          onSelect: onSelectBoard ?? (_) {},
        ),
      ),
      if (posts.isEmpty)
        SliverFillRemaining(
          child: DpEmpty(
            icon: DpIcons.community,
            title: '아직 글이 없어요',
            message: '첫 글을 남겨보세요.',
            actionLabel: board == CommunityBoard.qna ? '질문하기' : '글 작성',
            onAction: onCompose,
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.all(DpSpacing.lg),
          sliver: SliverList.separated(
            itemCount: posts.length,
            separatorBuilder: (_, _) => const SizedBox(height: DpSpacing.sm),
            itemBuilder: (context, index) => CommunityPostRow(
              post: posts[index],
              onTap: () => onOpenPost(posts[index]),
            ),
          ),
        ),
    ],
  );
}

/// 모바일·본문용 로컬 내비게이션. 데스크톱 레일과 같은 세 게시판만 노출한다.
class CommunityBoardFilterBar extends StatelessWidget {
  const CommunityBoardFilterBar({
    super.key,
    required this.current,
    required this.onSelect,
  });

  final CommunityBoard current;
  final ValueChanged<CommunityBoard> onSelect;

  @override
  Widget build(BuildContext context) => Padding(
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

/// 목록 한 행. 게시판별 강조색·배지·집계를 [DpListRow] 로 그린다.
class CommunityPostRow extends StatelessWidget {
  const CommunityPostRow({super.key, required this.post, required this.onTap});

  final CommunityPostSummary post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
        CommunityBadgeChip(label),
        if (isQna && post.solved) CommunityBadgeChip('✓ 해결됨', tone: c.success),
      ],
      trailing: Text(
        '${isQna ? '답변' : '댓글'} ${post.replyCount} · 추천 ${post.upvoteCount}',
        style: TextStyle(color: c.textSecondary, fontSize: 12),
      ),
      onTap: onTap,
    );
  }
}

/// 게시판·해결 여부 배지. 목록 행과 검색 결과 행이 같은 모양을 쓴다.
class CommunityBadgeChip extends StatelessWidget {
  const CommunityBadgeChip(this.text, {super.key, this.tone});

  final String text;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DpSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: c.border,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: tone ?? c.textSecondary),
      ),
    );
  }
}
