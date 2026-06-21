import 'dart:typed_data';

import 'package:devpath_web/src/data/web_mock_fixtures.dart';
import 'package:devpath_web/src/features/content/presentation/content_page.dart';
import 'package:devpath_web/src/features/path/presentation/path_plan_view.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('path task -> content -> progress POST smoke', (tester) async {
    final adapter = _CountingAdapter(webMockFixtures);

    await tester.pumpWidget(_host(adapter, initialLocation: '/path'));
    await tester.pump();

    await tester.tap(find.text('Future/async-await 정리'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Future/async-await 정리'), findsWidgets);
    expect(find.textContaining('비동기 기초'), findsWidgets);

    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(milliseconds: 100));

    expect(adapter.count('POST /contents/future-async-await/progress'), 1);
    expect(adapter.count('GET /learning-paths/me'), greaterThanOrEqualTo(1));
    expect(adapter.count('GET /dashboard'), 1);
  });

  testWidgets('missing content shows retry UI', (tester) async {
    final adapter = _CountingAdapter(webMockFixtures);

    await tester.pumpWidget(
      _host(adapter, initialLocation: '/content/missing'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('다시 시도'), findsOneWidget);
  });
}

Widget _host(_CountingAdapter adapter, {required String initialLocation}) {
  final client = ApiClient.create(const ApiConfig(baseUrl: 'https://t/api/v1'));
  client.dio.httpClientAdapter = adapter;
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/path',
        builder: (_, _) => Scaffold(
          body: PathPlanView(plan: LearningPath.fromJson(mockLearningPath())),
        ),
      ),
      GoRoute(
        path: '/content/:id',
        builder: (_, state) =>
            ContentPage(contentId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/sandbox', builder: (_, _) => const Text('sandbox')),
    ],
  );

  return ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(client)],
    child: MaterialApp.router(theme: DpTheme.light(), routerConfig: router),
  );
}

class _CountingAdapter implements HttpClientAdapter {
  _CountingAdapter(Map<String, MockFixture> fixtures)
    : _inner = MockHttpAdapter(fixtures);

  final MockHttpAdapter _inner;
  final Map<String, int> _counts = {};

  int count(String key) => _counts[key] ?? 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final key = '${options.method} ${options.path}';
    _counts[key] = count(key) + 1;
    return _inner.fetch(options, requestStream, cancelFuture);
  }

  @override
  void close({bool force = false}) => _inner.close(force: force);
}
