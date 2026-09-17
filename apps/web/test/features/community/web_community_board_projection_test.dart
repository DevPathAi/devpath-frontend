import 'package:devpath_web/src/features/community/presentation/web_community_board_projection.dart';
import 'package:devpath_web/src/features/community/state/community_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<CommunityPostSummary> _posts(String boardType) => [
  CommunityPostSummary(
    id: 1,
    boardType: boardType,
    title: '첫 번째 글',
    solved: boardType == 'QNA',
    upvoteCount: 3,
    replyCount: 2,
    excerpt: '본문 미리보기',
  ),
  CommunityPostSummary(id: 2, boardType: boardType, title: '두 번째 글'),
];

Widget _host(Widget child, {double width = 1240}) => MaterialApp(
  theme: DpTheme.light(),
  home: MediaQuery(
    data: MediaQueryData(size: Size(width, 900)),
    child: Scaffold(body: child),
  ),
);

void main() {
  for (final (board, label, description) in [
    (CommunityBoard.free, '자유게시판', '개발 이야기를 자유롭게 나눕니다'),
    (CommunityBoard.qna, 'Q/A', '막힌 문제를 질문하고 함께 해결합니다'),
    (CommunityBoard.feedback, '피드백', '코드와 프로젝트에 구체적인 의견을 나눕니다'),
  ]) {
    testWidgets('$label projection 은 H1·설명·선택 세그먼트·항목 수를 provider 없이 그린다', (
      tester,
    ) async {
      final opened = <int>[];
      await tester.pumpWidget(
        _host(
          WebCommunityBoardProjection(
            board: board,
            posts: _posts(board.value!),
            onOpenPost: (post) => opened.add(post.id),
            onCompose: () {},
          ),
        ),
      );
      final header = tester.widget<DpPageHeader>(find.byType(DpPageHeader));
      expect(header.title, label);
      expect(header.description, description);
      final segmented = tester.widget<SegmentedButton<CommunityBoard>>(
        find.byType(SegmentedButton<CommunityBoard>),
      );
      expect(segmented.selected, {board});
      expect(find.byType(DpListRow), findsNWidgets(2));
      expect(find.text('첫 번째 글'), findsOneWidget);
      await tester.tap(find.text('첫 번째 글'));
      expect(opened, [1]);
    });
  }

  testWidgets('빈 목록은 DpEmpty 와 글 작성 행동을 보인다', (tester) async {
    var composed = 0;
    await tester.pumpWidget(
      _host(
        WebCommunityBoardProjection(
          board: CommunityBoard.free,
          posts: const [],
          onOpenPost: (_) {},
          onCompose: () => composed += 1,
        ),
      ),
    );
    expect(find.byType(DpEmpty), findsOneWidget);
    await tester.tap(find.text('글 작성'));
    expect(composed, 1);
  });
}
