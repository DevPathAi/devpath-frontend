import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

import '../state/community_state.dart';

/// 사용자에게 노출하는 게시판. `all` 은 데이터 계층 호환용이라 화면에 나오지 않는다.
const kCommunityBoards = [
  CommunityBoard.free,
  CommunityBoard.qna,
  CommunityBoard.feedback,
];

/// 게시판별 문구·작성 경로. 세 게시판은 각자 독립 페이지라 같은 문구를 돌려 쓰지 않는다.
extension CommunityBoardCopy on CommunityBoard {
  String get description => switch (this) {
    CommunityBoard.qna => '막힌 문제를 질문하고 함께 해결합니다',
    CommunityBoard.feedback => '코드와 프로젝트에 구체적인 의견을 나눕니다',
    CommunityBoard.free || CommunityBoard.all => '개발 이야기를 자유롭게 나눕니다',
  };

  String get composeLabel => switch (this) {
    CommunityBoard.qna => '질문하기',
    CommunityBoard.feedback => '피드백 요청',
    CommunityBoard.free || CommunityBoard.all => '글 작성',
  };

  /// 작성 화면. Q/A 는 질문 전용 화면, 나머지는 `?board=` 프리셋 일반 작성 화면.
  String get composePath => switch (this) {
    CommunityBoard.qna => '/community/new',
    CommunityBoard.feedback => '/community/new/post?board=FEEDBACK',
    CommunityBoard.free ||
    CommunityBoard.all => '/community/new/post?board=FREE',
  };

  String get emptyTitle => switch (this) {
    CommunityBoard.qna => '아직 질문이 없어요',
    CommunityBoard.feedback => '아직 피드백 요청이 없어요',
    CommunityBoard.free || CommunityBoard.all => '아직 글이 없어요',
  };

  String get emptyMessage => switch (this) {
    CommunityBoard.qna => '막힌 부분을 첫 질문으로 남겨보세요.',
    CommunityBoard.feedback => '코드나 프로젝트를 올리고 첫 의견을 받아보세요.',
    CommunityBoard.free || CommunityBoard.all => '첫 글을 남겨보세요.',
  };

  String get searchHint => '$label에서 검색 (제목·본문·태그)';
}

/// 게시판 한 개의 결정적 투영(ET13 증거·위젯 테스트용).
///
/// [CommunityHomePage] 가 provider 로 채우는 것과 같은 H1·설명·목록·빈 상태를 순수
/// 입력([board], [posts])만으로 그린다. 검색·정렬·광고·라우팅은 포함하지 않는다
/// (ET13 원칙: "controller/provider state replaced by approved deterministic fixture").
class WebCommunityBoardProjection extends StatelessWidget {
  const WebCommunityBoardProjection({
    super.key,
    required this.board,
    required this.posts,
    required this.onOpenPost,
    required this.onCompose,
  });

  final CommunityBoard board;
  final List<CommunityPostSummary> posts;
  final ValueChanged<CommunityPostSummary> onOpenPost;
  final VoidCallback onCompose;

  static String descriptionFor(CommunityBoard board) => board.description;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    semanticChildCount: posts.length,
    slivers: [
      SliverToBoxAdapter(
        child: CommunityBoardHeader(board: board, onCompose: onCompose),
      ),
      if (posts.isEmpty)
        SliverFillRemaining(
          child: CommunityBoardEmpty(board: board, onCompose: onCompose),
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

/// 게시판 페이지 헤더.
///
/// 게시판 이동은 셸의 몫이다 — 어느 폭에서도 본문에서 다시 나누지 않는다.
/// 좁은 폭에서는 셸 헤더의 햄버거 메뉴가 세 게시판을 보여 준다(S3-P2).
class CommunityBoardHeader extends StatelessWidget {
  const CommunityBoardHeader({super.key, required this.board, this.onCompose});

  final CommunityBoard board;

  /// 이 게시판의 작성 화면으로 가는 액션. 시안은 주요 액션을 페이지 헤더
  /// 우측에 두고 FAB 을 쓰지 않는다.
  final VoidCallback? onCompose;

  @override
  Widget build(BuildContext context) {
    return DpPageHeader(
      title: board.label,
      description: board.description,
      actions: [
        // 시안 `.btn.p` 는 글자만이다(아이콘 없음).
        if (onCompose != null)
          FilledButton(onPressed: onCompose, child: Text(board.composeLabel)),
      ],
    );
  }
}

/// 게시판별 빈 상태.
class CommunityBoardEmpty extends StatelessWidget {
  const CommunityBoardEmpty({
    super.key,
    required this.board,
    required this.onCompose,
  });

  final CommunityBoard board;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) => DpEmpty(
    icon: DpIcons.community,
    title: board.emptyTitle,
    message: board.emptyMessage,
    actionLabel: board.composeLabel,
    onAction: onCompose,
  );
}

/// 목록 한 행. 해결 배지·집계를 [DpListRow] 로 그린다.
class CommunityPostRow extends StatelessWidget {
  const CommunityPostRow({super.key, required this.post, required this.onTap});

  final CommunityPostSummary post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final isQna = post.boardType == 'QNA';
    return DpListRow(
      title: post.title,
      preview: post.excerpt.isEmpty ? null : post.excerpt,
      badges: [
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

/// 목록 정렬 메뉴. 검색 결과(관련도 순)에는 적용되지 않아 그때는 비활성이다.
class CommunitySortMenu extends StatefulWidget {
  const CommunitySortMenu({
    super.key,
    required this.current,
    required this.onSelect,
    this.enabled = true,
  });

  final CommunitySort current;
  final ValueChanged<CommunitySort> onSelect;
  final bool enabled;

  @override
  State<CommunitySortMenu> createState() => _CommunitySortMenuState();
}

class _CommunitySortMenuState extends State<CommunitySortMenu> {
  // 메뉴가 닫힐 때 focus 를 여는 버튼으로 되돌리려면 MenuAnchor 가 그 노드를 알아야 한다.
  final _buttonFocus = FocusNode(debugLabel: 'community-sort-button');
  final _firstItemFocus = FocusNode(debugLabel: 'community-sort-first-item');

  @override
  void dispose() {
    _buttonFocus.dispose();
    _firstItemFocus.dispose();
    super.dispose();
  }

  /// 열 때 focus 를 첫 항목으로 옮긴다(WAI-ARIA 메뉴 버튼). 웹 시맨틱스에서는 메뉴 안에
  /// focus 받은 노드가 없으면 DOM focus 가 body 로 빠져 Escape·화살표가 닿지 않는다.
  void _toggle(MenuController controller) {
    if (controller.isOpen) {
      controller.close();
      return;
    }
    controller.open();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && controller.isOpen) _firstItemFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) => MenuAnchor(
    key: const ValueKey('community-sort-menu'),
    childFocusNode: _buttonFocus,
    menuChildren: [
      for (final sort in CommunitySort.values)
        MenuItemButton(
          focusNode: sort == CommunitySort.values.first
              ? _firstItemFocus
              : null,
          leadingIcon: sort == widget.current
              ? const Icon(Icons.check, size: 18)
              : const SizedBox(width: 18),
          onPressed: () => widget.onSelect(sort),
          child: Text(sort.label),
        ),
    ],
    builder: (context, controller, _) => Tooltip(
      message: '정렬',
      child: TextButton(
        focusNode: _buttonFocus,
        onPressed: widget.enabled ? () => _toggle(controller) : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort, size: 18),
            const SizedBox(width: DpSpacing.xs),
            Text(widget.current.label),
          ],
        ),
      ),
    ),
  );
}

/// 해결 여부 배지. 목록 행과 검색 결과 행이 같은 모양을 쓴다.
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
