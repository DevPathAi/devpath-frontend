import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

import '../state/community_state.dart';
import 'widgets/search_highlight.dart';

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
  Widget build(BuildContext context) {
    // 시안 `.hide-n` — 좁은 폭에서 감추는 칼럼.
    final compact = context.windowClass == DpWindowClass.compact;
    return CustomScrollView(
      semanticChildCount: posts.length,
      slivers: [
        SliverToBoxAdapter(
          child: CommunityBoardHeader(board: board, onCompose: onCompose),
        ),
        // 좌우 패딩은 셸이 준다 — 표는 자기 행 패딩을 갖는다.
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
                    onTap: () => onOpenPost(post),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 게시판별 표 칼럼(시안 `free`/`qna`/`feedback` 의 `<thead>`).
///
/// **「작성」 칼럼이 없다.** 서버 `PostSummaryView` 가 작성 시각도 작성자 표시
/// 이름도 보내지 않는다(`id·boardType·title·authorId·solved·upvoteCount·
/// replyCount·excerpt`). 시안의 그 칼럼은 백엔드 계약 변경이 있어야 한다.
///
/// [compact] 는 시안 `.hide-n` — 좁은 폭에서 감추는 칼럼을 목록에서 뺀다.
/// 최상위 함수인 이유: 표와 테스트가 **같은 정의 하나**를 쓰게 한다.
List<DpTableColumn> communityBoardColumns(
  CommunityBoard board, {
  required bool compact,
}) {
  final isQna = board == CommunityBoard.qna;
  return [
    (label: isQna ? '질문' : '제목', width: null, numeric: false),
    if (isQna) (label: '상태', width: 80, numeric: false),
    if (!compact) (label: isQna ? '답변' : '댓글', width: 56, numeric: true),
    (label: '추천', width: 56, numeric: true),
  ];
}

/// 목록 한 행. 셀 개수는 [communityBoardColumns] 와 반드시 같아야 한다
/// (`DpWebTable` 의 assert 가 어긋남을 배치 전에 잡는다).
DpTableRowSpec communityPostRow({
  required BuildContext context,
  required CommunityPostSummary post,
  required CommunityBoard board,
  required bool compact,
  required VoidCallback onTap,
}) {
  final isQna = board == CommunityBoard.qna;
  return (
    cells: [
      _titleCell(
        context: context,
        title: post.title,
        preview: post.excerpt.isEmpty ? null : Text(post.excerpt),
        onTap: onTap,
      ),
      if (isQna)
        post.solved
            ? const DpStatusText(text: '✓ 해결됨', tone: DpStatusTone.done)
            : DpStatusText(
                text: post.replyCount == 0 ? '답변 대기' : '답변 중',
                tone: DpStatusTone.idle,
              ),
      if (!compact) Text('${post.replyCount}'),
      Text('${post.upvoteCount}'),
    ],
    onTap: onTap,
  );
}

/// 검색 결과 한 행. 미리보기 자리에 매칭 근거(하이라이트)를 항상 보여 준다.
DpTableRowSpec communitySearchRow({
  required BuildContext context,
  required CommunitySearchItem item,
  required CommunityBoard board,
  required bool compact,
  required VoidCallback onTap,
}) {
  final isQna = board == CommunityBoard.qna;
  // 본문 매칭이 없으면 highlight 가 비어 오므로 excerpt 로 폴백한다.
  final body = item.highlight.isNotEmpty ? item.highlight : item.excerpt;
  return (
    cells: [
      _titleCell(
        context: context,
        title: item.title,
        preview: body.isEmpty ? null : SearchHighlightText(body),
        onTap: onTap,
      ),
      if (isQna)
        item.solved
            ? const DpStatusText(text: '✓ 해결됨', tone: DpStatusTone.done)
            : DpStatusText(
                text: item.replyCount == 0 ? '답변 대기' : '답변 중',
                tone: DpStatusTone.idle,
              ),
      if (!compact) Text('${item.replyCount}'),
      Text('${item.upvoteCount}'),
    ],
    onTap: onTap,
  );
}

/// 제목 셀 — 시안 `a.ttl` + `.ex`. 접근성 컨트롤은 이 링크 하나다
/// (행 제스처는 `DpWebTable` 이 시맨틱스에서 뺀다).
Widget _titleCell({
  required BuildContext context,
  required String title,
  required Widget? preview,
  required VoidCallback onTap,
}) {
  final c = context.dpColors;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      DpLink.title(text: title, onTap: onTap),
      if (preview != null) ...[
        const SizedBox(height: DpSpacing.xs),
        DefaultTextStyle.merge(
          style: TextStyle(fontSize: 13, color: c.textSecondary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          child: preview,
        ),
      ],
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
///
/// **작성 액션을 갖지 않는다.** 페이지 헤더의 작성 버튼이 빈 목록에서도 보이고,
/// 같은 라벨의 버튼이 둘이면 스크린리더가 둘을 구분할 수 없다(P3 이월 과제).
class CommunityBoardEmpty extends StatelessWidget {
  const CommunityBoardEmpty({super.key, required this.board});

  final CommunityBoard board;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: DpSpacing.xl),
    child: DpEmpty(
      icon: DpIcons.community,
      title: board.emptyTitle,
      message: board.emptyMessage,
    ),
  );
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
