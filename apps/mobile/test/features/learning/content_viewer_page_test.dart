import 'package:devpath_mobile/src/features/learning/presentation/content_viewer_page.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/mock_api.dart';

final Map<String, MockFixture> _fx = {
  'GET /contents/future-async-await': (
    200,
    {
      'id': 1,
      'slug': 'future-async-await',
      'title': 'Future/async-await 정리',
      'track': 'BACKEND',
      'markdown': '# 비동기 기초\n본문 내용',
      'estimatedMinutes': 8,
      'conceptTags': <String>[],
      'progress': {
        'scrollPct': 0.2,
        'dwellSec': 12,
        'completed': false,
        'completedAt': null,
      },
    },
  ),
  'POST /contents/future-async-await/progress': (
    200,
    {
      'scrollPct': 1.0,
      'dwellSec': 60,
      'completed': true,
      'completedAt': '2026-06-27T10:00:00Z',
    },
  ),
};

Widget _host(ProviderContainer c) => UncontrolledProviderScope(
  container: c,
  child: MaterialApp(
    theme: DpTheme.light(),
    home: const ContentViewerPage(slug: 'future-async-await'),
  ),
);

void main() {
  testWidgets('콘텐츠 로드 → 제목·완료 버튼, 탭 시 완료됨', (tester) async {
    final c = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(mockApiClient(_fx))],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    expect(find.text('Future/async-await 정리'), findsWidgets);
    expect(find.text('완료로 표시'), findsOneWidget);

    await tester.tap(find.text('완료로 표시'));
    await tester.pumpAndSettle();
    expect(find.text('완료됨'), findsOneWidget);
  });
}
