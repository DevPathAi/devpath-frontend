import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/presentation/question_create_page.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// 에디터가 FlutterQuillLocalizations 를 요구하고, 저장 성공 시 context.go 로 상세로
/// 이동한다 — question_create_page_test 의 호스트 구성을 그대로 따른다.
Widget _host(ProviderContainer c, Widget child) {
  final router = GoRouter(
    initialLocation: '/edit',
    routes: [
      GoRoute(path: '/edit', builder: (_, _) => child),
      GoRoute(
        path: '/community/:id',
        builder: (_, state) => Text('상세: ${state.pathParameters['id']}'),
      ),
    ],
  );
  return UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(
      theme: DpTheme.light(),
      localizationsDelegates: const [
        DefaultCupertinoLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      routerConfig: router,
    ),
  );
}

void main() {
  testWidgets('편집 모드는 기존 제목을 채운다', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    await tester.pumpWidget(
      _host(
        c,
        const QuestionCreatePage(
          editPostId: 3,
          initialTitle: '원질문',
          initialBodyMd: '원본문',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('원질문'), findsOneWidget);
    expect(find.text('질문 수정'), findsOneWidget);
  });

  testWidgets('편집 모드는 제목을 고쳐도 유사질문을 조회하지 않는다', (tester) async {
    var called = 0;
    final c = ProviderContainer(
      overrides: [
        similarQuestionsProvider.overrideWithValue((q) async {
          called++;
          return const [];
        }),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(
      _host(
        c,
        const QuestionCreatePage(
          editPostId: 3,
          initialTitle: '원질문',
          initialBodyMd: '원본문',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('question-title-field')),
      '고친 제목입니다',
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    // 유사질문은 중복 질문 방지용이라 수정에는 의미가 없다.
    expect(called, 0);
  });

  testWidgets('작성 모드는 제목을 고치면 유사질문을 조회한다 — 대조군', (tester) async {
    var called = 0;
    final c = ProviderContainer(
      overrides: [
        similarQuestionsProvider.overrideWithValue((q) async {
          called++;
          return const [];
        }),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c, const QuestionCreatePage()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('question-title-field')),
      '새 질문입니다',
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(called, greaterThan(0));
  });

  testWidgets('편집 모드에서는 태그 입력을 보이지 않는다', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    await tester.pumpWidget(
      _host(
        c,
        const QuestionCreatePage(
          editPostId: 3,
          initialTitle: '원질문',
          initialBodyMd: '원본문',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('question-tags-field')), findsNothing);
  });

  testWidgets('저장하면 postUpdate 를 부르고 본문이 실린다', (tester) async {
    int? sentId;
    String? sentBody;
    final c = ProviderContainer(
      overrides: [
        postUpdateProvider.overrideWithValue(({
          required id,
          required title,
          required bodyMd,
        }) async {
          sentId = id;
          sentBody = bodyMd;
          return const CommunityPostDetail(
            id: 3,
            boardType: 'QNA',
            title: '원질문',
            bodyMd: '원본문',
          );
        }),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(
      _host(
        c,
        const QuestionCreatePage(
          editPostId: 3,
          initialTitle: '원질문',
          initialBodyMd: '원본문',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('question-submit')));
    await tester.pumpAndSettle();

    expect(sentId, 3);
    // 초기 본문이 에디터에 실렸다가 마크다운으로 되돌아 나온다 — 역변환이 걸렸다는 증거.
    expect(sentBody, contains('원본문'));
  });

  testWidgets('404 는 이미 삭제된 콘텐츠로 안내한다', (tester) async {
    final c = ProviderContainer(
      overrides: [
        postUpdateProvider.overrideWithValue(({
          required id,
          required title,
          required bodyMd,
        }) async {
          throw const ApiException(
            code: ApiErrorCode.resourceNotFound,
            message: 'gone',
          );
        }),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(
      _host(
        c,
        const QuestionCreatePage(
          editPostId: 3,
          initialTitle: '원질문',
          initialBodyMd: '원본문',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('question-submit')));
    await tester.pumpAndSettle();

    expect(find.text('이미 삭제된 콘텐츠예요'), findsOneWidget);
  });
}
