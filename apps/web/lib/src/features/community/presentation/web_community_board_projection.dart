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
    this.onSelectBoard,
  });

  final CommunityBoard board;
  final List<CommunityPostSummary> posts;
  final ValueChanged<CommunityPostSummary> onOpenPost;
  final VoidCallback onCompose;

  /// compact 제목 메뉴 선택. null 이면 메뉴는 열리되 이동하지 않는다(증거 캡처).
  final ValueChanged<CommunityBoard>? onSelectBoard;

  static String descriptionFor(CommunityBoard board) => board.description;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    semanticChildCount: posts.length,
    slivers: [
      SliverToBoxAdapter(
        child: CommunityBoardHeader(
          board: board,
          onSelectBoard: onSelectBoard ?? (_) {},
        ),
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
/// 게시판 이동은 셸의 몫이다: 레일이 보이는 폭에서는 세 게시판이 레일의 직접 목적지라
/// 본문에서 다시 나누지 않는다. compact 하단 바에는 `커뮤니티` 하나뿐이라, 그 폭에서만
/// 제목이 세 게시판을 고르는 메뉴가 된다.
class CommunityBoardHeader extends StatelessWidget {
  const CommunityBoardHeader({
    super.key,
    required this.board,
    required this.onSelectBoard,
  });

  final CommunityBoard board;
  final ValueChanged<CommunityBoard> onSelectBoard;

  @override
  Widget build(BuildContext context) {
    final compact = context.windowClass == DpWindowClass.compact;
    return DpPageHeader(
      title: board.label,
      description: board.description,
      titleMenuTooltip: '게시판 바꾸기',
      titleMenu: [
        if (compact)
          for (final b in kCommunityBoards)
            (
              label: b.label,
              selected: b == board,
              onSelect: () => onSelectBoard(b),
            ),
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

/// 행 강조색. 한 페이지의 행은 모두 같은 게시판이라 게시판 색은 정보가 없다 —
/// 상태가 있는 Q/A 만 해결 여부를 알리고(배지 문구와 함께), 나머지는 쓰지 않는다.
Color? communityRowAccent(
  DpColors c, {
  required String boardType,
  required bool solved,
}) => boardType == 'QNA' ? (solved ? c.success : c.primary) : null;

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
      accentColor: communityRowAccent(
        c,
        boardType: post.boardType,
        solved: post.solved,
      ),
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

  @override
  void dispose() {
    _buttonFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MenuAnchor(
    key: const ValueKey('community-sort-menu'),
    childFocusNode: _buttonFocus,
    menuChildren: [
      for (final sort in CommunitySort.values)
        MenuItemButton(
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
        onPressed: widget.enabled
            ? () => controller.isOpen ? controller.close() : controller.open()
            : null,
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
