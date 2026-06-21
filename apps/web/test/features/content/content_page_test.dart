import 'dart:convert';
import 'dart:typed_data';

import 'package:devpath_web/src/data/web_mock_fixtures.dart';
import 'package:devpath_web/src/features/content/presentation/content_page.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('title, meta, progress, markdown, sandbox button을 렌더한다', (
    tester,
  ) async {
    final adapter = _SequenceAdapter({
      'GET /contents/future-async-await': [
        (200, _contentJson(markdown: '# 비동기 기초\n\n본문')),
      ],
    });

    await tester.pumpWidget(_host(adapter));
    await _pumpLoad(tester);

    expect(find.text('Future/async-await 정리'), findsOneWidget);
    expect(find.textContaining('8분'), findsOneWidget);
    expect(find.text('20% 진행'), findsOneWidget);
    expect(find.textContaining('비동기 기초'), findsWidgets);
    expect(find.text('실습'), findsOneWidget);

    await tester.tap(find.text('실습'));
    await tester.pumpAndSettle();

    expect(find.text('sandbox route'), findsOneWidget);
  });

  testWidgets('scroll 후 progress POST와 완료 refresh를 수행한다', (tester) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final adapter = _SequenceAdapter({
      'GET /contents/future-async-await': [
        (200, _contentJson(markdown: _longMarkdown(), scrollPct: 0)),
      ],
      'POST /contents/future-async-await/progress': [
        (
          200,
          {
            'scrollPct': 0.9,
            'dwellSec': 46,
            'completed': true,
            'completedAt': '2026-06-21T10:00:00Z',
          },
        ),
      ],
      'GET /learning-paths/me': [(200, mockLearningPath())],
      'GET /dashboard': [
        (
          200,
          {
            'streakDays': 7,
            'progressPercent': 62,
            'nextTaskTitle': '다음 과제',
            'badges': <String>[],
          },
        ),
      ],
    });

    await tester.pumpWidget(_host(adapter));
    await _pumpLoad(tester);
    await tester.pump(const Duration(seconds: 6));
    await tester.dragUntilVisible(
      find.textContaining('문단 70'),
      find.byType(SingleChildScrollView),
      const Offset(0, -500),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(adapter.postBodies, isNotEmpty);
    expect(adapter.postBodies.last, containsPair('dwellSec', 6));
    expect(adapter.count('GET /learning-paths/me'), 1);
    expect(adapter.count('GET /dashboard'), 1);
  });

  testWidgets('retry button reloads', (tester) async {
    final adapter = _SequenceAdapter({
      'GET /contents/future-async-await': [
        (
          500,
          {
            'error': {'code': 'INTERNAL_ERROR', 'message': '일시 오류'},
          },
        ),
        (200, _contentJson(markdown: '# 재시도 성공')),
      ],
    });

    await tester.pumpWidget(_host(adapter));
    await _pumpLoad(tester);

    expect(find.text('다시 시도'), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    await _pumpLoad(tester);

    expect(find.text('Future/async-await 정리'), findsOneWidget);
    expect(find.textContaining('재시도 성공'), findsWidgets);
  });
}

Widget _host(_SequenceAdapter adapter) {
  final client = ApiClient.create(const ApiConfig(baseUrl: 'https://t/api/v1'));
  client.dio.httpClientAdapter = adapter;
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const ContentPage(contentId: 'future-async-await'),
      ),
      GoRoute(path: '/sandbox', builder: (_, _) => const Text('sandbox route')),
    ],
  );

  return ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(client)],
    child: MaterialApp.router(theme: DpTheme.light(), routerConfig: router),
  );
}

Future<void> _pumpLoad(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Map<String, dynamic> _contentJson({
  required String markdown,
  double scrollPct = 0.2,
}) => {
  'id': 1,
  'slug': 'future-async-await',
  'title': 'Future/async-await 정리',
  'track': 'BACKEND',
  'markdown': markdown,
  'estimatedMinutes': 8,
  'difficulty': 0.5,
  'bloomLevel': 'APPLY',
  'conceptTags': ['future', 'async-await'],
  'progress': {
    'scrollPct': scrollPct,
    'dwellSec': 0,
    'completed': false,
    'completedAt': null,
  },
};

String _longMarkdown() => [
  '# 비동기 기초',
  for (var i = 0; i < 80; i++) '문단 $i: Future와 async/await 흐름을 충분히 길게 설명합니다.',
].join('\n\n');

class _SequenceAdapter implements HttpClientAdapter {
  _SequenceAdapter(this.fixtures);

  final Map<String, List<(int, Object)>> fixtures;
  final List<Object?> postBodies = [];
  final Map<String, int> _counts = {};

  int count(String key) => _counts[key] ?? 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    _counts[key] = count(key) + 1;
    if (options.method == 'POST') postBodies.add(options.data);

    final sequence = fixtures[key];
    if (sequence == null || sequence.isEmpty) {
      return _json(404, {
        'error': {'code': 'RESOURCE_NOT_FOUND', 'message': 'no mock: $key'},
      });
    }
    final fixture = sequence.length == 1
        ? sequence.first
        : sequence.removeAt(0);
    final (status, body) = fixture;
    return _json(status, body);
  }

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}
