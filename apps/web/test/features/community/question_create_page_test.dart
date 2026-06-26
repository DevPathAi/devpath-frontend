import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/presentation/question_create_page.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

CommunityQuestionDetail _created(int id) =>
    CommunityQuestionDetail(id: id, title: '새 질문', bodyMd: '본문');

Widget _host(ProviderContainer c) {
  final router = GoRouter(
    initialLocation: '/community/new',
    routes: [
      GoRoute(
        path: '/community/new',
        builder: (_, _) => const QuestionCreatePage(),
      ),
      GoRoute(
        path: '/community/:id',
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
  testWidgets('제목 입력(디바운스) 시 유사질문 패널을 안내한다', (tester) async {
    final c = ProviderContainer(
      overrides: [
        similarQuestionsProvider.overrideWithValue(
          (q) async => [const SimilarQuestion(questionId: 2, title: '비슷한 질문')],
        ),
        questionCreateProvider.overrideWithValue(
          ({required title, required bodyMd, required tags}) async =>
              _created(99),
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'async');
    await tester.pump(const Duration(milliseconds: 450)); // 디바운스 발화
    await tester.pumpAndSettle();

    expect(find.text('💡 비슷한 질문'), findsOneWidget);
    expect(find.text('비슷한 질문'), findsOneWidget);
  });

  testWidgets('제목·본문 입력 후 게시하면 작성 API 호출 + 상세로 이동', (tester) async {
    String? seenTitle, seenBody;
    List<String>? seenTags;
    final c = ProviderContainer(
      overrides: [
        similarQuestionsProvider.overrideWithValue((q) async => const []),
        questionCreateProvider.overrideWithValue(({
          required String title,
          required String bodyMd,
          required List<String> tags,
        }) async {
          seenTitle = title;
          seenBody = bodyMd;
          seenTags = tags;
          return _created(99);
        }),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '새 질문');
    await tester.enterText(find.byType(TextField).at(1), '본문 내용');
    await tester.enterText(find.byType(TextField).at(2), 'dart, async');

    await tester.tap(find.widgetWithText(FilledButton, '질문 게시'));
    await tester.pumpAndSettle();

    expect(seenTitle, '새 질문');
    expect(seenBody, '본문 내용');
    expect(seenTags, ['dart', 'async']);
    expect(find.text('상세: 99'), findsOneWidget); // 작성 후 상세 이동
  });

  testWidgets('제목/본문 비면 게시하지 않고 안내', (tester) async {
    var createCalls = 0;
    final c = ProviderContainer(
      overrides: [
        similarQuestionsProvider.overrideWithValue((q) async => const []),
        questionCreateProvider.overrideWithValue(({
          required String title,
          required String bodyMd,
          required List<String> tags,
        }) async {
          createCalls++;
          return _created(99);
        }),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '질문 게시'));
    await tester.pumpAndSettle();

    expect(createCalls, 0);
    expect(find.textContaining('제목과 본문'), findsOneWidget);
  });
}
