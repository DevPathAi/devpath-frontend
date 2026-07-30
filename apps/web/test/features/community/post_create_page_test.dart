import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/presentation/post_create_page.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

CommunityPostDetail _created(int id, String board) => CommunityPostDetail(
  id: id,
  boardType: board,
  title: '새 글',
  bodyMd: '본문',
);

Widget _host(ProviderContainer c, {String board = 'FREE'}) {
  final router = GoRouter(
    initialLocation: '/community/new/post',
    routes: [
      GoRoute(
        path: '/community/new/post',
        builder: (_, _) => PostCreatePage(board: board),
      ),
      GoRoute(
        path: '/community/post/:id',
        builder: (_, state) => Text('상세: ${state.pathParameters['id']}'),
      ),
    ],
  );
  return UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(theme: DpTheme.light(), routerConfig: router),
  );
}

void main() {
  testWidgets('FREE 프리셋: 제목/본문/태그 입력 필드 + 게시 버튼 렌더', (tester) async {
    final c = ProviderContainer(
      overrides: [
        postCreateProvider.overrideWithValue(
          ({required boardType, required title, required bodyMd, required tags}) async =>
              _created(30, boardType),
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    expect(find.text('자유글 작성'), findsOneWidget); // AppBar
    expect(find.byType(TextField), findsNWidgets(3)); // 제목/본문/태그
    expect(find.widgetWithText(FilledButton, '게시'), findsOneWidget);
  });

  testWidgets('FEEDBACK 프리셋: AppBar 라벨이 "피드백 요청"', (tester) async {
    final c = ProviderContainer(
      overrides: [
        postCreateProvider.overrideWithValue(
          ({required boardType, required title, required bodyMd, required tags}) async =>
              _created(31, boardType),
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c, board: 'FEEDBACK'));
    await tester.pumpAndSettle();

    expect(find.text('피드백 요청'), findsOneWidget);
  });

  testWidgets('제목·본문 입력 후 게시하면 postCreate(boardType) 호출 + 상세로 이동', (tester) async {
    String? seenBoard, seenTitle, seenBody;
    List<String>? seenTags;
    final c = ProviderContainer(
      overrides: [
        postCreateProvider.overrideWithValue(({
          required String boardType,
          required String title,
          required String bodyMd,
          required List<String> tags,
        }) async {
          seenBoard = boardType;
          seenTitle = title;
          seenBody = bodyMd;
          seenTags = tags;
          return _created(30, boardType);
        }),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '새 자유글');
    await tester.enterText(find.byType(TextField).at(1), '본문 내용');
    await tester.enterText(find.byType(TextField).at(2), 'dart, async');

    await tester.tap(find.widgetWithText(FilledButton, '게시'));
    await tester.pumpAndSettle();

    expect(seenBoard, 'FREE');
    expect(seenTitle, '새 자유글');
    expect(seenBody, '본문 내용');
    expect(seenTags, ['dart', 'async']);
    expect(find.text('상세: 30'), findsOneWidget);
  });

  testWidgets('제목/본문 비면 게시하지 않고 안내', (tester) async {
    var createCalls = 0;
    final c = ProviderContainer(
      overrides: [
        postCreateProvider.overrideWithValue(({
          required String boardType,
          required String title,
          required String bodyMd,
          required List<String> tags,
        }) async {
          createCalls++;
          return _created(30, boardType);
        }),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '게시'));
    await tester.pumpAndSettle();

    expect(createCalls, 0);
    expect(find.textContaining('제목과 본문'), findsOneWidget);
  });
}
