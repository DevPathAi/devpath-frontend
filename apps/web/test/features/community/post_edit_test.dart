import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/presentation/post_create_page.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

ProviderContainer _container({PostUpdate? update}) {
  final c = ProviderContainer(
    overrides: [
      if (update != null) postUpdateProvider.overrideWithValue(update),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

/// 에디터가 FlutterQuillLocalizations 를 요구한다 — post_create_page_test 와 같은 구성이다.
/// 저장 성공 시 context.go 로 상세로 이동하므로 라우터도 필요하다.
Widget _host(ProviderContainer c, Widget child) {
  final router = GoRouter(
    initialLocation: '/edit',
    routes: [
      GoRoute(path: '/edit', builder: (_, _) => child),
      GoRoute(
        path: '/community/post/:id',
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
  /// 본문은 Quill 이 Text 위젯으로 렌더하지 않아 find 로 볼 수 없다 — 대신 저장 경로에서
  /// 실제로 실려 나가는지 확인한다(아래 「저장하면 postUpdate 를 부른다」).
  testWidgets('편집 모드는 기존 제목을 채운다', (tester) async {
    await tester.pumpWidget(
      _host(
        _container(),
        const PostCreatePage(
          board: 'FREE',
          editPostId: 9,
          initialTitle: '원제목',
          initialBodyMd: '원본문',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('원제목'), findsOneWidget);
  });

  testWidgets('편집 모드에서는 태그 입력을 보이지 않는다', (tester) async {
    await tester.pumpWidget(
      _host(
        _container(),
        const PostCreatePage(
          board: 'FREE',
          editPostId: 9,
          initialTitle: '원제목',
          initialBodyMd: '원본문',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 태그는 수정 대상이 아니다 — 편집 가능한 것처럼 보이면 저장 후 사라진 것처럼 읽힌다.
    expect(find.byKey(const ValueKey('post-tags-field')), findsNothing);
  });

  testWidgets('작성 모드에서는 태그 입력이 보인다 — 대조군', (tester) async {
    await tester.pumpWidget(
      _host(_container(), const PostCreatePage(board: 'FREE')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('post-tags-field')), findsOneWidget);
  });

  testWidgets('저장하면 postUpdate 를 부른다(create 가 아니라)', (tester) async {
    int? sentId;
    String? sentTitle;
    String? sentBody;
    await tester.pumpWidget(
      _host(
        _container(
          update: ({required id, required title, required bodyMd}) async {
            sentId = id;
            sentTitle = title;
            sentBody = bodyMd;
            return const CommunityPostDetail(
              id: 9,
              boardType: 'FREE',
              title: '원제목',
              bodyMd: '원본문',
            );
          },
        ),
        const PostCreatePage(
          board: 'FREE',
          editPostId: 9,
          initialTitle: '원제목',
          initialBodyMd: '원본문',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('post-submit')));
    await tester.pumpAndSettle();

    expect(sentId, 9);
    expect(sentTitle, '원제목');
    // 초기 본문이 에디터에 실렸다가 마크다운으로 되돌아 나온다 — 역변환이 실제로 걸렸다는 증거.
    expect(sentBody, contains('원본문'));
  });

  testWidgets('403 은 전용 문구로 안내한다', (tester) async {
    await tester.pumpWidget(
      _host(
        _container(
          update: ({required id, required title, required bodyMd}) async =>
              throw const ApiException(
                code: ApiErrorCode.forbidden,
                message: 'nope',
              ),
        ),
        const PostCreatePage(
          board: 'FREE',
          editPostId: 9,
          initialTitle: '원제목',
          initialBodyMd: '원본문',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('post-submit')));
    await tester.pumpAndSettle();

    expect(find.text('내가 쓴 글만 수정할 수 있어요'), findsOneWidget);
  });
}
