import 'dart:convert';
import 'dart:typed_data';

import 'package:devpath_web/src/features/content/application/content_controller.dart';
import 'package:devpath_web/src/features/content/state/content_state.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _contentJson({
  double scrollPct = 0.2,
  int dwellSec = 12,
  bool completed = false,
}) => {
  'id': 1,
  'slug': 'future-async-await',
  'title': 'Future/async-await 정리',
  'track': 'BACKEND',
  'markdown': '# 비동기 기초\n\n본문',
  'estimatedMinutes': 8,
  'difficulty': 0.5,
  'bloomLevel': 'APPLY',
  'conceptTags': ['future'],
  'progress': {
    'scrollPct': scrollPct,
    'dwellSec': dwellSec,
    'completed': completed,
    'completedAt': null,
  },
};

ApiClient _client(_CaptureAdapter adapter) {
  final client = ApiClient.create(const ApiConfig(baseUrl: 'https://t/api/v1'));
  client.dio.httpClientAdapter = adapter;
  return client;
}

void main() {
  test('load는 콘텐츠 전체 응답을 담는다', () async {
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(
          _client(
            _CaptureAdapter({
              'GET /contents/future-async-await': (200, _contentJson()),
            }),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(contentControllerProvider.notifier)
        .load('future-async-await');

    final s = container.read(contentControllerProvider);
    expect(s, isA<ContentLoaded>());
    final content = (s as ContentLoaded).content;
    expect(content.title, 'Future/async-await 정리');
    expect(content.markdown, contains('#'));
    expect(content.progress.scrollPct, 0.2);
  });

  test('reportProgress는 누적 progress를 POST하고 완료 응답을 반영한다', () async {
    final adapter = _CaptureAdapter({
      'GET /contents/future-async-await': (200, _contentJson()),
      'POST /contents/future-async-await/progress': (
        200,
        {
          'scrollPct': 0.85,
          'dwellSec': 46,
          'completed': true,
          'completedAt': '2026-06-21T10:00:00Z',
        },
      ),
    });
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(_client(adapter))],
    );
    addTearDown(container.dispose);

    final controller = container.read(contentControllerProvider.notifier);
    await controller.load('future-async-await');
    final response = await controller.reportProgress(
      idOrSlug: 'future-async-await',
      scrollPct: 0.85,
      dwellSec: 46,
    );

    expect(response?.completed, isTrue);
    expect(adapter.lastPath, '/contents/future-async-await/progress');
    expect(adapter.lastBody, {'scrollPct': 0.85, 'dwellSec': 46});

    final s = container.read(contentControllerProvider) as ContentLoaded;
    expect(s.content.progress.scrollPct, 0.85);
    expect(s.content.progress.dwellSec, 46);
    expect(s.content.progress.completed, isTrue);
    expect(s.content.progress.completedAt, '2026-06-21T10:00:00Z');
  });

  test('reportProgress는 현재 progress보다 낮은 응답으로 후퇴하지 않는다', () async {
    final adapter = _CaptureAdapter({
      'GET /contents/future-async-await': (
        200,
        _contentJson(scrollPct: 0.6, dwellSec: 30),
      ),
      'POST /contents/future-async-await/progress': (
        200,
        {
          'scrollPct': 0.4,
          'dwellSec': 20,
          'completed': false,
          'completedAt': null,
        },
      ),
    });
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(_client(adapter))],
    );
    addTearDown(container.dispose);

    final controller = container.read(contentControllerProvider.notifier);
    await controller.load('future-async-await');
    await controller.reportProgress(
      idOrSlug: 'future-async-await',
      scrollPct: 0.4,
      dwellSec: 20,
    );

    final s = container.read(contentControllerProvider) as ContentLoaded;
    expect(s.content.progress.scrollPct, 0.6);
    expect(s.content.progress.dwellSec, 30);
  });

  test('API 실패는 ContentFailed가 된다', () async {
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(
          _client(
            _CaptureAdapter({
              'GET /contents/missing': (
                404,
                {
                  'error': {'code': 'RESOURCE_NOT_FOUND', 'message': '없음'},
                },
              ),
            }),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(contentControllerProvider.notifier).load('missing');

    expect(container.read(contentControllerProvider), isA<ContentFailed>());
  });
}

class _CaptureAdapter implements HttpClientAdapter {
  _CaptureAdapter(this.fixtures);

  final Map<String, (int, Object)> fixtures;
  String? lastPath;
  Object? lastBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastPath = options.path;
    lastBody = options.data;
    final fixture = fixtures['${options.method} ${options.path}'];
    if (fixture == null) {
      return _json(404, {
        'error': {
          'code': 'RESOURCE_NOT_FOUND',
          'message': 'no mock: ${options.method} ${options.path}',
        },
      });
    }
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
