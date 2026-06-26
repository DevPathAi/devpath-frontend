import 'package:devpath_mobile/src/features/community/presentation/community_page.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/mock_api.dart';

final Map<String, MockFixture> _fx = {
  'GET /community/posts': (
    200,
    [
      {
        'id': 1,
        'title': 'async/await가 헷갈려요',
        'authorId': 42,
        'solved': true,
        'upvoteCount': 3,
        'answerCount': 2,
      },
      {
        'id': 2,
        'title': 'Stream 구독 해제는?',
        'authorId': 17,
        'solved': false,
        'upvoteCount': 1,
        'answerCount': 1,
      },
    ],
  ),
};

void main() {
  testWidgets('질문 목록 + 퀵 캡처 FAB 표시', (tester) async {
    final c = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(mockApiClient(_fx))],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(theme: DpTheme.light(), home: const CommunityPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('async/await가 헷갈려요'), findsOneWidget);
    expect(find.text('Stream 구독 해제는?'), findsOneWidget);
    expect(find.widgetWithText(FloatingActionButton, '퀵 캡처'), findsOneWidget);
  });
}
