import 'dart:convert';
import 'dart:typed_data';

import 'package:devpath_web/src/features/updates/application/notice_banner_controller.dart';
import 'package:devpath_web/src/features/updates/data/notice_feed_client.dart';
import 'package:devpath_web/src/features/updates/presentation/notice_banner_bar.dart';
import 'package:dio/dio.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _CountingAdapter implements HttpClientAdapter {
  _CountingAdapter(this.response);

  final ResponseBody response;
  int requests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests++;
    return response;
  }

  @override
  void close({bool force = false}) {}
}

class _FailingAdapter implements HttpClientAdapter {
  int requests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests++;
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ReadyController extends NoticeBannerController {
  @override
  NoticeBannerState build() => NoticeBannerReady(
    NoticeBanner(
      id: 'mentor-invite',
      title: 'AI 멘토 순차 초대 안내',
      summary: '담당자가 확인 후 이메일로 안내해 드립니다.',
      startsAt: DateTime.utc(2026),
      endsAt: DateTime.utc(2027),
      ctaLabel: 'AI 멘토 보기',
      ctaPath: '/mentor',
    ),
  );
}

ResponseBody _json(Map<String, dynamic> body) => ResponseBody.fromString(
  jsonEncode(body),
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

NoticeFeedClient _client(HttpClientAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return NoticeFeedClient(
    dio: dio,
    cache: MemoryNoticeFeedCache(),
    homeBaseUrl: 'https://leva.ai.kr',
  );
}

void main() {
  test('VM에서는 공지 runtime을 끄고 네트워크 요청을 만들지 않는다', () async {
    final adapter = _CountingAdapter(
      _json(const {'schemaVersion': 1, 'banners': []}),
    );
    final container = ProviderContainer(
      overrides: [noticeFeedClientProvider.overrideWithValue(_client(adapter))],
    );
    addTearDown(container.dispose);

    expect(
      container.read(noticeBannerControllerProvider),
      isA<NoticeBannerNone>(),
    );
    await Future<void>.delayed(Duration.zero);
    expect(adapter.requests, 0);
  });

  test('활성 공지가 있으면 첫 배너를 ready 상태로 만든다', () async {
    final adapter = _CountingAdapter(
      _json({
        'schemaVersion': 1,
        'banners': [
          {
            'id': 'mentor-invite',
            'title': 'AI 멘토 순차 초대 안내',
            'summary': '담당자가 확인 후 이메일로 안내해 드립니다.',
            'startsAt': '2026-01-01T00:00:00Z',
            'endsAt': '2027-01-01T00:00:00Z',
            'cta': {'label': 'AI 멘토 보기', 'href': '/mentor'},
          },
        ],
      }),
    );
    final container = ProviderContainer(
      overrides: [
        noticeFeedRuntimeEnabledProvider.overrideWithValue(true),
        noticeFeedClientProvider.overrideWithValue(_client(adapter)),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(noticeBannerControllerProvider.notifier);

    await controller.loadOnce();

    final state = container.read(noticeBannerControllerProvider);
    expect(state, isA<NoticeBannerReady>());
    expect((state as NoticeBannerReady).banner.id, 'mentor-invite');
    expect(adapter.requests, 1);
  });

  test('빈 feed와 네트워크 실패는 모두 공지 없음으로 축소한다', () async {
    final emptyAdapter = _CountingAdapter(
      _json(const {'schemaVersion': 1, 'banners': []}),
    );
    final failingAdapter = _FailingAdapter();

    for (final adapter in <HttpClientAdapter>[emptyAdapter, failingAdapter]) {
      final container = ProviderContainer(
        overrides: [
          noticeFeedRuntimeEnabledProvider.overrideWithValue(true),
          noticeFeedClientProvider.overrideWithValue(_client(adapter)),
        ],
      );
      await container.read(noticeBannerControllerProvider.notifier).loadOnce();
      expect(
        container.read(noticeBannerControllerProvider),
        isA<NoticeBannerNone>(),
      );
      container.dispose();
    }
    expect(emptyAdapter.requests, 1);
    expect(failingAdapter.requests, 1);
  });

  testWidgets('공지 배너는 CTA로 이동하고 닫기 전까지 내용을 표시한다', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: NoticeBannerBar()),
        ),
        GoRoute(
          path: '/mentor',
          builder: (_, _) => const Scaffold(body: Text('MENTOR DESTINATION')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noticeBannerControllerProvider.overrideWith(_ReadyController.new),
        ],
        child: MaterialApp.router(theme: DpTheme.light(), routerConfig: router),
      ),
    );

    expect(find.textContaining('AI 멘토 순차 초대 안내'), findsOneWidget);
    await tester.tap(find.text('AI 멘토 보기'));
    await tester.pumpAndSettle();
    expect(find.text('MENTOR DESTINATION'), findsOneWidget);
  });

  testWidgets('공지 닫기는 같은 배너를 즉시 숨긴다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noticeBannerControllerProvider.overrideWith(_ReadyController.new),
        ],
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const Scaffold(body: NoticeBannerBar()),
        ),
      ),
    );

    await tester.tap(find.byTooltip('공지 닫기'));
    await tester.pump();

    expect(find.textContaining('AI 멘토 순차 초대 안내'), findsNothing);
  });
}
