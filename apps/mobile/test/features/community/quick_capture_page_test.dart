import 'package:devpath_mobile/src/features/community/presentation/quick_capture_page.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/mock_api.dart';

final Map<String, MockFixture> _fx = {
  'POST /community/questions': (
    201,
    {
      'id': 99,
      'title': '새 질문',
      'bodyMd': '본문',
      'solved': false,
      'acceptedAnswerId': null,
      'upvoteCount': 0,
      'downvoteCount': 0,
      'tags': <String>[],
      'answers': <Map<String, dynamic>>[],
    },
  ),
  'GET /community/posts': (200, <Map<String, dynamic>>[]),
};

GoRouter _router() => GoRouter(
  initialLocation: '/community/new',
  routes: [
    GoRoute(
      path: '/community',
      builder: (_, _) => const Scaffold(body: Center(child: Text('목록화면'))),
      routes: [
        GoRoute(path: 'new', builder: (_, _) => const QuickCapturePage()),
      ],
    ),
  ],
);

Widget _host(ProviderContainer c) => UncontrolledProviderScope(
  container: c,
  child: MaterialApp.router(theme: DpTheme.light(), routerConfig: _router()),
);

void main() {
  testWidgets('빈 입력 제출 → 검증 스낵바', (tester) async {
    final c = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(mockApiClient(_fx))],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.tap(find.text('게시'));
    await tester.pump();
    expect(find.text('제목과 본문을 입력해 주세요.'), findsOneWidget);
  });

  testWidgets('정상 제출 → 게시 후 목록으로 복귀', (tester) async {
    final c = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(mockApiClient(_fx))],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '새 질문');
    await tester.enterText(find.byType(TextField).at(1), '본문 내용');
    await tester.tap(find.text('게시'));
    await tester.pumpAndSettle();

    // pop 되어 목록 화면이 보인다.
    expect(find.text('목록화면'), findsOneWidget);
  });
}
