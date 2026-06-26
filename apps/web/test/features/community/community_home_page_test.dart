import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/presentation/community_home_page.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

CommunityPostSummary _p(int id, {String? title, bool solved = false}) =>
    CommunityPostSummary(
      id: id,
      title: title ?? '글 $id',
      solved: solved,
      answerCount: 1,
    );

Widget _host(ProviderContainer c) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const CommunityHomePage()),
      GoRoute(path: '/community/new', builder: (_, _) => const Text('작성 화면')),
      GoRoute(path: '/community/:id', builder: (_, _) => const Text('상세 화면')),
    ],
  );
  return UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(theme: DpTheme.light(), routerConfig: router),
  );
}

void main() {
  testWidgets('목록을 렌더한다(작성자 이름 없이 메타 표시)', (tester) async {
    final c = ProviderContainer(
      overrides: [
        communityListProvider.overrideWithValue(
          ({String? board, String? tag, String? sort}) async => [
            _p(1, title: 'async 질문'),
          ],
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();
    expect(find.text('async 질문'), findsOneWidget);
    expect(find.textContaining('답변 1'), findsOneWidget);
  });

  testWidgets('빈 목록은 작성 CTA를 보인다', (tester) async {
    final c = ProviderContainer(
      overrides: [
        communityListProvider.overrideWithValue(
          ({String? board, String? tag, String? sort}) async => const [],
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();
    expect(find.textContaining('첫 질문'), findsOneWidget);
  });

  testWidgets('첫 로드 실패는 DpError와 재시도를 보인다', (tester) async {
    var calls = 0;
    final c = ProviderContainer(
      overrides: [
        communityListProvider.overrideWithValue(({
          String? board,
          String? tag,
          String? sort,
        }) async {
          calls++;
          if (calls == 1) {
            throw const ApiException(
              code: ApiErrorCode.network,
              message: '네트워크 오류',
            );
          }
          return [_p(1, title: '복구된 글')];
        }),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();
    expect(find.byType(DpError), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('복구된 글'), findsOneWidget);
  });

  testWidgets('FAB "질문하기"는 작성 화면으로 이동한다', (tester) async {
    final c = ProviderContainer(
      overrides: [
        communityListProvider.overrideWithValue(
          ({String? board, String? tag, String? sort}) async => [_p(1)],
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.tap(find.text('질문하기'));
    await tester.pumpAndSettle();
    expect(find.text('작성 화면'), findsOneWidget);
  });

  testWidgets('항목 탭은 상세로 이동한다', (tester) async {
    final c = ProviderContainer(
      overrides: [
        communityListProvider.overrideWithValue(
          ({String? board, String? tag, String? sort}) async => [
            _p(7, title: '탭할 글'),
          ],
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.tap(find.text('탭할 글'));
    await tester.pumpAndSettle();
    expect(find.text('상세 화면'), findsOneWidget);
  });
}
