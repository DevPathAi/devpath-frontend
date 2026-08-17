import 'dart:async';

import 'package:devpath_mobile/src/features/learning/presentation/content_viewer_page.dart';
import 'package:devpath_mobile/src/features/auth/application/auth_controller.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/mock_api.dart';

Map<String, dynamic> _contentJson({
  required String markdown,
  int id = 1,
  String slug = 'future-async-await',
  String title = 'Future/async-await 정리',
  double scrollPct = 0.2,
  int dwellSec = 12,
}) => {
  'id': id,
  'slug': slug,
  'title': title,
  'track': 'BACKEND',
  'markdown': markdown,
  'estimatedMinutes': 8,
  'difficulty': 0.5,
  'bloomLevel': 'APPLY',
  'conceptTags': ['future', 'async'],
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

Widget _host(ProviderContainer c, {String slug = 'future-async-await'}) =>
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: DpTheme.light(),
        home: ContentViewerPage(
          key: const ValueKey('content-viewer'),
          slug: slug,
        ),
      ),
    );

Widget _switchHost(ProviderContainer c, ValueNotifier<String> slug) =>
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: DpTheme.light(),
        home: ValueListenableBuilder<String>(
          valueListenable: slug,
          builder: (_, value, _) => ContentViewerPage(
            key: const ValueKey('content-viewer'),
            slug: value,
          ),
        ),
      ),
    );

ProviderContainer _container(Map<String, MockFixture> fx) {
  final c = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(mockApiClient(fx)),
      currentOwnerKeyProvider.overrideWithValue(null),
    ],
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

  testWidgets('메타데이터(예상시간·블룸·난이도) + 개념 태그 표시', (tester) async {
    final c = _container({
      'GET /contents/future-async-await': (200, _contentJson(markdown: '# 본문')),
      'POST /contents/future-async-await/progress': _progressDone,
    });

    await tester.pumpWidget(_host(c));
    await _pumpLoad(tester);

    expect(find.textContaining('8분'), findsOneWidget);
    expect(find.textContaining('적용하기'), findsOneWidget);
    expect(find.byType(DpContextCapsule), findsOneWidget);
    expect(find.textContaining('난이도'), findsOneWidget);
    expect(find.text('#future'), findsOneWidget);
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

  testWidgets(
    'same mounted route A late progress cannot release B progress flight',
    (tester) async {
      final api = _RouteSwitchApi();
      final c = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          currentOwnerKeyProvider.overrideWithValue(null),
        ],
      );
      addTearDown(c.dispose);
      final slug = ValueNotifier('content-a');
      addTearDown(slug.dispose);
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );

      await tester.pumpWidget(_switchHost(c, slug));
      await _pumpLoad(tester);
      expect(find.text('A content'), findsWidgets);
      await tester.pump(const Duration(seconds: 1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(api.progressRequests, hasLength(1));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      slug.value = 'content-b';
      await tester.pump();
      for (
        var i = 0;
        i < 10 && find.text('B content').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 25));
      }
      expect(find.text('A content'), findsNothing);
      expect(find.text('B content'), findsWidgets);
      await tester.pump(const Duration(seconds: 1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(api.progressRequests, hasLength(2));

      api.progressRequests.first.complete(_progressJson(0.4, 13));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(
        api.progressRequests,
        hasLength(2),
        reason: 'late A completion must not clear B posting generation',
      );

      api.progressRequests.last.complete(_progressJson(0.4, 13));
      await tester.pump();
    },
  );
}

Map<String, dynamic> _progressJson(double scrollPct, int dwellSec) => {
  'scrollPct': scrollPct,
  'dwellSec': dwellSec,
  'completed': false,
  'completedAt': null,
};

final class _RouteSwitchApi extends ApiClient {
  _RouteSwitchApi() : super(Dio());

  final progressRequests = <Completer<Map<String, dynamic>>>[];

  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? query}) async {
    return switch (path) {
          '/contents/content-a' => _contentJson(
            id: 1,
            slug: 'content-a',
            title: 'A content',
            markdown: '# A',
          ),
          '/contents/content-b' => _contentJson(
            id: 2,
            slug: 'content-b',
            title: 'B content',
            markdown: '# B',
          ),
          _ => throw StateError('unexpected GET $path'),
        }
        as T;
  }

  @override
  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    if (!path.endsWith('/progress')) {
      throw StateError('unexpected POST $path');
    }
    final request = Completer<Map<String, dynamic>>();
    progressRequests.add(request);
    return await request.future as T;
  }
}
