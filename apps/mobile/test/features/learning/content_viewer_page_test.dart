import 'package:devpath_mobile/src/features/learning/presentation/content_viewer_page.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/mock_api.dart';

Map<String, dynamic> _contentJson({
  required String markdown,
  double scrollPct = 0.2,
  int dwellSec = 12,
}) => {
  'id': 1,
  'slug': 'future-async-await',
  'title': 'Future/async-await 정리',
  'track': 'BACKEND',
  'markdown': markdown,
  'estimatedMinutes': 8,
  'conceptTags': <String>[],
  'progress': {
    'scrollPct': scrollPct,
    'dwellSec': dwellSec,
    'completed': false,
    'completedAt': null,
  },
};

const _progressDone = (
  200,
  {
    'scrollPct': 1.0,
    'dwellSec': 60,
    'completed': true,
    'completedAt': '2026-06-27T10:00:00Z',
  },
);

String _longMarkdown() => [
  '# 비동기 기초',
  for (var i = 0; i < 80; i++)
    '문단 $i: Future와 async/await 흐름을 충분히 길게 설명하는 본문입니다.',
].join('\n\n');

Widget _host(ProviderContainer c) => UncontrolledProviderScope(
  container: c,
  child: MaterialApp(
    theme: DpTheme.light(),
    home: const ContentViewerPage(slug: 'future-async-await'),
  ),
);

ProviderContainer _container(Map<String, MockFixture> fx) {
  final c = ProviderContainer(
    overrides: [apiClientProvider.overrideWithValue(mockApiClient(fx))],
  );
  addTearDown(c.dispose);
  return c;
}

/// Timer.periodic이 있어 pumpAndSettle은 settle되지 않으므로 pump로 진행한다.
Future<void> _pumpLoad(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('콘텐츠 로드 → 제목·진척바·완료 버튼, 수동 탭 시 완료됨', (tester) async {
    final c = _container({
      'GET /contents/future-async-await': (
        200,
        _contentJson(markdown: '# 짧은 본문'),
      ),
      'POST /contents/future-async-await/progress': _progressDone,
    });

    await tester.pumpWidget(_host(c));
    await _pumpLoad(tester);

    expect(find.text('Future/async-await 정리'), findsWidgets);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('완료로 표시'), findsOneWidget);

    await tester.tap(find.text('완료로 표시'));
    await _pumpLoad(tester);

    expect(find.text('완료됨'), findsOneWidget);
  });

  testWidgets('스크롤 끝까지 + 체류 45초↑ → 자동 완료', (tester) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final c = _container({
      'GET /contents/future-async-await': (
        200,
        _contentJson(markdown: _longMarkdown(), scrollPct: 0, dwellSec: 0),
      ),
      'POST /contents/future-async-await/progress': _progressDone,
    });

    await tester.pumpWidget(_host(c));
    await _pumpLoad(tester);

    // 체류 46초 누적(Timer.periodic 발화) 후 본문 끝까지 스크롤.
    await tester.pump(const Duration(seconds: 46));
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -6000),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('완료됨'), findsOneWidget);
  });

  testWidgets('로드 실패 → 에러 + 재시도', (tester) async {
    final c = _container(const {});

    await tester.pumpWidget(_host(c));
    await _pumpLoad(tester);

    expect(find.byType(DpError), findsOneWidget);
  });
}
