import 'package:devpath_web/src/features/community/presentation/web_community_board_projection.dart';
import 'package:devpath_web/src/features/community/state/community_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

const _titleMenu = ValueKey('page-header-title-menu');

void main() {
  for (final (board, label, description) in [
    (CommunityBoard.free, '자유게시판', '개발 이야기를 자유롭게 나눕니다'),
    (CommunityBoard.qna, 'Q/A', '막힌 문제를 질문하고 함께 해결합니다'),
    (CommunityBoard.feedback, '피드백', '코드와 프로젝트에 구체적인 의견을 나눕니다'),
  ]) {
    testWidgets(
      '$label projection 은 H1·설명·항목 수를 provider 없이 그리고 게시판 세그먼트는 없다',
      (tester) async {
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
        // 게시판은 레일의 독립 목적지다 — 페이지 안에서 다시 나누지 않는다.
        expect(find.byType(SegmentedButton<CommunityBoard>), findsNothing);
        // 레일이 보이는 폭에서는 제목이 메뉴가 아니다.
        expect(find.byKey(_titleMenu), findsNothing);
        // 한 게시판 안의 행은 게시판 이름 배지를 반복하지 않는다(헤더 1회만).
        expect(find.text(label), findsOneWidget);
        expect(find.byType(DpListRow), findsNWidgets(2));
        expect(find.text('첫 번째 글'), findsOneWidget);
        await tester.tap(find.text('첫 번째 글'));
        expect(opened, [1]);
      },
    );
  }

  testWidgets('compact 폭에서는 제목 메뉴가 세 게시판 이동 경로다', (tester) async {
    final picked = <CommunityBoard>[];
    await tester.pumpWidget(
      _host(
        width: 390,
        WebCommunityBoardProjection(
          board: CommunityBoard.free,
          posts: _posts('FREE'),
          onOpenPost: (_) {},
          onCompose: () {},
          onSelectBoard: picked.add,
        ),
      ),
    );

    await tester.tap(find.byKey(_titleMenu));
    await tester.pumpAndSettle();
    for (final label in ['자유게시판', 'Q/A', '피드백']) {
      expect(find.widgetWithText(MenuItemButton, label), findsOneWidget);
    }
    expect(find.widgetWithText(MenuItemButton, '전체'), findsNothing);

    await tester.tap(find.widgetWithText(MenuItemButton, '피드백'));
    await tester.pumpAndSettle();
    expect(picked, [CommunityBoard.feedback]);
  });

  testWidgets('Q/A 행의 강조색은 해결 여부를 알린다', (tester) async {
    await tester.pumpWidget(
      _host(
        WebCommunityBoardProjection(
          board: CommunityBoard.qna,
          posts: _posts('QNA'),
          onOpenPost: (_) {},
          onCompose: () {},
        ),
      ),
    );
    final colors = tester.element(find.byType(DpListRow).first).dpColors;
    final rows = tester.widgetList<DpListRow>(find.byType(DpListRow)).toList();
    expect(rows[0].accentColor, colors.success); // 해결됨
    expect(rows[1].accentColor, colors.primary); // 답변을 기다리는 질문
    expect(find.text('✓ 해결됨'), findsOneWidget);
  });

  testWidgets('자유게시판·피드백 행은 상태가 없어 강조색을 쓰지 않는다', (tester) async {
    await tester.pumpWidget(
      _host(
        WebCommunityBoardProjection(
          board: CommunityBoard.feedback,
          posts: _posts('FEEDBACK'),
          onOpenPost: (_) {},
          onCompose: () {},
        ),
      ),
    );
    for (final row in tester.widgetList<DpListRow>(find.byType(DpListRow))) {
      expect(row.accentColor, isNull);
    }
  });

  for (final (board, title, action) in [
    (CommunityBoard.free, '아직 글이 없어요', '글 작성'),
    (CommunityBoard.qna, '아직 질문이 없어요', '질문하기'),
    (CommunityBoard.feedback, '아직 피드백 요청이 없어요', '피드백 요청'),
  ]) {
    testWidgets('${board.label} 빈 목록은 게시판에 맞는 문구와 작성 행동을 보인다', (tester) async {
      var composed = 0;
      await tester.pumpWidget(
        _host(
          WebCommunityBoardProjection(
            board: board,
            posts: const [],
            onOpenPost: (_) {},
            onCompose: () => composed += 1,
          ),
        ),
      );
      expect(find.byType(DpEmpty), findsOneWidget);
      expect(find.text(title), findsOneWidget);
      await tester.tap(find.text(action));
      expect(composed, 1);
    });
  }

  testWidgets('정렬 메뉴는 키보드로 열고 Escape 로 닫으면 focus 가 여는 버튼으로 돌아온다', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        Center(
          child: CommunitySortMenu(
            current: CommunitySort.latest,
            onSelect: (_) {},
          ),
        ),
      ),
    );
    FocusNode buttonFocus() => Focus.of(tester.element(find.text('최신순')));
    buttonFocus().requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(MenuItemButton, '추천순'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(MenuItemButton, '추천순'), findsNothing);
    expect(buttonFocus().hasPrimaryFocus, isTrue);
  });
}
