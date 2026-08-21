import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/data/lcs_source.dart';
import 'package:devpath_web/src/features/community/presentation/post_detail_page.dart';
import 'package:devpath_web/src/features/community/presentation/qna_detail_page.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(ProviderContainer c, Widget child) => UncontrolledProviderScope(
  container: c,
  child: MaterialApp(theme: DpTheme.light(), home: child),
);

void main() {
  testWidgets('삭제된 답변은 비석으로 보이고 본문·메뉴가 없다', (tester) async {
    final c = ProviderContainer(
      overrides: [
        qnaDetailFetchProvider.overrideWithValue(
          (id) async => const CommunityQuestionDetail(
            id: 3,
            title: 'q',
            bodyMd: 'b',
            authorId: 1,
            answers: [
              CommunityAnswer(id: 11, upvoteCount: 2, deleted: true),
              CommunityAnswer(id: 12, authorId: 2, bodyMd: '살아있는 답변'),
            ],
          ),
        ),
        lcsByQuestionProvider.overrideWithValue((qid) async => null),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c, const QnaDetailPage(postId: '3')));
    await tester.pumpAndSettle();

    // 카드 자체는 남아 스레드 순서가 보존된다.
    expect(find.text('삭제된 내용입니다'), findsOneWidget);
    expect(find.text('살아있는 답변'), findsOneWidget);
    // 비석에는 메뉴가 없다 — 질문 헤더 1 + 살아 있는 답변 1 = 2.
    expect(find.byKey(const ValueKey('content-menu')), findsNWidgets(2));
  });

  testWidgets('삭제된 댓글도 같은 규칙이다', (tester) async {
    final c = ProviderContainer(
      overrides: [
        postDetailFetchProvider.overrideWithValue(
          (id) async => const CommunityPostDetail(
            id: 9,
            boardType: 'FREE',
            title: 't',
            bodyMd: 'b',
            authorId: 1,
            comments: [CommunityComment(id: 21, createdAt: 'x', deleted: true)],
          ),
        ),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c, const PostDetailPage(postId: '9')));
    await tester.pumpAndSettle();

    expect(find.text('삭제된 내용입니다'), findsOneWidget);
    expect(find.textContaining('작성자 '), findsNothing);
  });
}
