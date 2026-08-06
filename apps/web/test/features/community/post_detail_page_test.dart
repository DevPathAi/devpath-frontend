import 'dart:async';

import 'package:devpath_web/src/features/community/application/post_detail_controller.dart';
import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/presentation/post_detail_page.dart';
import 'package:devpath_web/src/features/community/state/post_detail_state.dart';
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

  // 아래 두 건은 sliver 전환(Task 11)이 만든 로딩·실패 분기를 잠근다. 전환 전에는
  // Expanded(child: ...)라 레이아웃이 자명했지만 지금은 SliverFillRemaining이라
  // 헤더와 같은 스크롤 표면 위에서 렌더된다 — 분기를 뒤바꾸거나 sliver가 아닌
  // 위젯을 넣으면 렌더 예외가 나야 하고, 이 테스트가 그것을 적발한다.
  testWidgets('로딩 중에도 헤더와 로딩 표시가 함께 렌더된다', (tester) async {
    final completer = Completer<CommunityPostDetail>();
    final c = ProviderContainer(
      overrides: [
        postDetailFetchProvider.overrideWithValue((id) => completer.future),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pump(); // load() 시작 → loading 상태

    expect(tester.widget<DpPageHeader>(find.byType(DpPageHeader)).title, '게시글');
    expect(find.byType(DpLoading), findsOneWidget);

    completer.complete(_detail());
    await tester.pumpAndSettle();
    expect(find.text('오늘 배운 것'), findsOneWidget);
  });

  // loaded인데 detail이 null인 폴백 분기(post_detail_page.dart의 마지막 case).
  // fetch로는 만들 수 없는 상태라 컨트롤러를 직접 고정해 주입한다. 전환으로 이
  // 분기도 sliver가 됐으므로, 비-sliver로 되돌리면 RenderViewport가 예외를 던진다.
  testWidgets('loaded이지만 detail이 없으면 헤더와 로딩 표시로 폴백한다', (tester) async {
    final c = ProviderContainer(
      overrides: [
        postDetailControllerProvider(
          10,
        ).overrideWith(() => _NullDetailController(10)),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pump();

    expect(tester.widget<DpPageHeader>(find.byType(DpPageHeader)).title, '게시글');
    expect(find.byType(DpLoading), findsOneWidget);
  });

  testWidgets('조회 실패 시 헤더와 에러 안내가 함께 렌더된다', (tester) async {
    final c = ProviderContainer(
      overrides: [
        postDetailFetchProvider.overrideWithValue(
          (id) async => throw const ApiException(
            code: ApiErrorCode.unknown,
            message: '불러오지 못했어요',
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    expect(tester.widget<DpPageHeader>(find.byType(DpPageHeader)).title, '게시글');
    expect(find.textContaining('불러오지 못했어요'), findsWidgets);
  });
}

/// loaded인데 detail이 null인 상태를 고정 주입한다(정상 흐름으로는 도달 불가).
class _NullDetailController extends PostDetailController {
  _NullDetailController(super.postId);

  @override
  PostDetailState build() =>
      const PostDetailState(phase: PostDetailPhase.loaded);

  @override
  Future<void> load() async {}
}
