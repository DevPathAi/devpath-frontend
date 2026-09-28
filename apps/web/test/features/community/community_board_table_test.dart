import 'package:devpath_web/src/features/community/presentation/web_community_board_projection.dart';
import 'package:devpath_web/src/features/community/state/community_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _qnaPost = CommunityPostSummary(
  id: 1,
  boardType: 'QNA',
  title: 'async/await가 헷갈려요',
  solved: true,
  upvoteCount: 5,
  replyCount: 2,
  excerpt: 'async/await에서 예외는 어디서 잡나요?',
);

const _freePost = CommunityPostSummary(
  id: 10,
  boardType: 'FREE',
  title: '오늘 배운 것 공유',
  upvoteCount: 4,
  replyCount: 1,
  excerpt: '오늘은 Riverpod 을 배웠어요.',
);

void _view(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _host(Widget child) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  test('communityBoardColumns: Q/A 는 상태 칼럼을 갖고 자유게시판은 갖지 않는다', () {
    final qna = communityBoardColumns(CommunityBoard.qna, compact: false);
    final free = communityBoardColumns(CommunityBoard.free, compact: false);

    expect(qna.map((c) => c.label), containsAllInOrder(['질문', '상태']));
    expect(free.map((c) => c.label), contains('제목'));
    expect(free.map((c) => c.label), isNot(contains('상태')));
  });

  test('communityBoardColumns: 작성 시각 칼럼은 없다 — 서버가 보내지 않는다', () {
    for (final board in kCommunityBoards) {
      final labels = communityBoardColumns(
        board,
        compact: false,
      ).map((c) => c.label).toList();
      expect(labels, isNot(contains('작성')));
    }
  });

  test('communityBoardColumns: compact 는 답변/댓글 칼럼을 감춘다', () {
    final wide = communityBoardColumns(CommunityBoard.qna, compact: false);
    final narrow = communityBoardColumns(CommunityBoard.qna, compact: true);
    expect(wide.map((c) => c.label), contains('답변'));
    expect(narrow.map((c) => c.label), isNot(contains('답변')));
  });

  testWidgets('WebCommunityBoardProjection: Q/A 를 표로 그리고 해결 상태를 말한다', (
    tester,
  ) async {
    _view(tester, const Size(1280, 900));
    await tester.pumpWidget(
      _host(
        WebCommunityBoardProjection(
          board: CommunityBoard.qna,
          posts: const [_qnaPost],
          onOpenPost: (_) {},
          onCompose: () {},
        ),
      ),
    );

    expect(find.text('질문'), findsOneWidget);
    expect(find.text('async/await가 헷갈려요'), findsOneWidget);
    expect(find.text('✓ 해결됨'), findsOneWidget);
    expect(find.text('async/await에서 예외는 어디서 잡나요?'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // 답변
    expect(find.text('5'), findsOneWidget); // 추천
  });

  testWidgets('WebCommunityBoardProjection: 자유게시판은 상태 칼럼 없이 그린다', (
    tester,
  ) async {
    _view(tester, const Size(1280, 900));
    await tester.pumpWidget(
      _host(
        WebCommunityBoardProjection(
          board: CommunityBoard.free,
          posts: const [_freePost],
          onOpenPost: (_) {},
          onCompose: () {},
        ),
      ),
    );

    expect(find.text('상태'), findsNothing);
    expect(find.text('오늘 배운 것 공유'), findsOneWidget);
    expect(find.text('댓글'), findsOneWidget);
  });

  testWidgets('WebCommunityBoardProjection: 제목을 누르면 그 글을 넘긴다', (tester) async {
    _view(tester, const Size(1280, 900));
    CommunityPostSummary? opened;
    await tester.pumpWidget(
      _host(
        WebCommunityBoardProjection(
          board: CommunityBoard.free,
          posts: const [_freePost],
          onOpenPost: (post) => opened = post,
          onCompose: () {},
        ),
      ),
    );

    await tester.tap(find.text('오늘 배운 것 공유'));
    await tester.pump();

    expect(opened?.id, 10);
  });

  testWidgets('WebCommunityBoardProjection: 빈 목록은 안내만 하고 중복 액션을 두지 않는다', (
    tester,
  ) async {
    _view(tester, const Size(1280, 900));
    await tester.pumpWidget(
      _host(
        WebCommunityBoardProjection(
          board: CommunityBoard.free,
          posts: const [],
          onOpenPost: (_) {},
          onCompose: () {},
        ),
      ),
    );

    expect(find.text('아직 글이 없어요'), findsOneWidget);
    // 헤더의 작성 버튼 하나만 있어야 한다 — 같은 접근명이 둘이면 스크린리더로
    // 구분할 수 없다(P3 이월).
    expect(find.text('글 작성'), findsOneWidget);
  });

  testWidgets('표 행이 스크린리더에서 칼럼별로 읽힌다', (tester) async {
    _view(tester, const Size(1280, 900));
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        WebCommunityBoardProjection(
          board: CommunityBoard.qna,
          posts: const [_qnaPost],
          onOpenPost: (_) {},
          onCompose: () {},
        ),
      ),
    );

    // 제목은 링크로, 숫자는 별도 라벨로 남는다 — 행 제스처가 셀을 삼키지 않는다.
    expect(find.bySemanticsLabel('async/await가 헷갈려요'), findsOneWidget);
    expect(find.bySemanticsLabel('2'), findsOneWidget);
    handle.dispose();
  });
}
