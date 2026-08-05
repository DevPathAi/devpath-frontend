import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/presentation/post_detail_page.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

CommunityPostDetail _detail({List<CommunityComment> comments = const []}) =>
    CommunityPostDetail(
      id: 10,
      boardType: 'FREE',
      title: '오늘 배운 것',
      bodyMd: '# 공유\n\n본문입니다',
      upvoteCount: 5,
      tags: const ['riverpod'],
      comments: comments,
    );

CommunityComment _comment(int id, String body) =>
    CommunityComment(id: id, authorId: 42, bodyMd: body, createdAt: 'x');

Widget _host(ProviderContainer c) => UncontrolledProviderScope(
  container: c,
  child: MaterialApp(
    theme: DpTheme.light(),
    home: const PostDetailPage(postId: '10'),
  ),
);

void main() {
  testWidgets('상세: 제목·본문·태그·댓글·입력 필드 렌더', (tester) async {
    final c = ProviderContainer(
      overrides: [
        postDetailFetchProvider.overrideWithValue(
          (id) async => _detail(comments: [_comment(100, '좋은 정리네요!')]),
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    expect(find.text('오늘 배운 것'), findsOneWidget);
    expect(find.textContaining('본문입니다'), findsWidgets);
    expect(find.text('좋은 정리네요!'), findsOneWidget); // 댓글 본문
    expect(find.byType(TextField), findsOneWidget); // 댓글 입력
    expect(tester.widget<DpPageHeader>(find.byType(DpPageHeader)).title, '게시글');
  });

  testWidgets('댓글 등록: 작성 시 commentCreate 호출 후 재조회', (tester) async {
    var fetchCalls = 0;
    String? seenBody;
    final c = ProviderContainer(
      overrides: [
        postDetailFetchProvider.overrideWithValue((id) async {
          fetchCalls++;
          return _detail(
            comments: fetchCalls >= 2 ? [_comment(101, '새 댓글')] : const [],
          );
        }),
        commentCreateProvider.overrideWithValue((postId, body) async {
          seenBody = body;
          return _comment(101, body);
        }),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '새 댓글');
    await tester.tap(find.widgetWithText(FilledButton, '댓글 등록'));
    await tester.pumpAndSettle();

    expect(seenBody, '새 댓글');
    expect(fetchCalls, 2); // 작성 후 재조회
    expect(find.text('새 댓글'), findsWidgets);
  });

  testWidgets('추천 버튼: 탭 시 upvote 호출(target=post)', (tester) async {
    var fetchCalls = 0;
    CommunityVoteTarget? seenTarget;
    int? seenId;
    final c = ProviderContainer(
      overrides: [
        postDetailFetchProvider.overrideWithValue((id) async {
          fetchCalls++;
          return _detail();
        }),
        communityVoteProvider.overrideWithValue(({
          required CommunityVoteTarget target,
          required int id,
          required int value,
        }) async {
          seenTarget = target;
          seenId = id;
        }),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(DpIcons.thumbUp));
    await tester.pumpAndSettle();

    expect(seenTarget, CommunityVoteTarget.post);
    expect(seenId, 10);
    expect(fetchCalls, 2); // load + upvote 후 재조회
  });
}
