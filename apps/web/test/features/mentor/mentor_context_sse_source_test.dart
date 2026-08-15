import 'dart:convert';
import 'dart:typed_data';

import 'package:devpath_web/src/app/app_config.dart';
import 'package:devpath_web/src/features/mentor/data/mentor_sse_source.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _CapturingSseAdapter implements HttpClientAdapter {
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody(
      Stream.value(
        Uint8List.fromList(utf8.encode('event: token\ndata: 답변\n\n')),
      ),
      200,
      headers: {
        Headers.contentTypeHeader: ['text/event-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ProviderContainer _container(_CapturingSseAdapter adapter) {
  final client = ApiClient.create(const ApiConfig(baseUrl: 'https://t/api/v1'))
    ..dio.httpClientAdapter = adapter;
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(baseUrl: 'https://t/api/v1', useMock: false),
      ),
      apiClientProvider.overrideWithValue(client),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('terminal parser는 DONE과 FAILED timeout을 명시적으로 구분한다', () {
    final done = parseMentorTerminal(
      const SseEvent(event: 'terminal', data: '{"status":"DONE"}'),
    );
    final timeout = parseMentorTerminal(
      const SseEvent(
        event: 'terminal',
        data:
            '{"status":"FAILED","code":"AI_TIMEOUT",'
            '"message":"mentor response timed out"}',
      ),
    );

    expect(done?.status, MentorTerminalStatus.done);
    expect(timeout?.status, MentorTerminalStatus.failed);
    expect(timeout?.code, 'AI_TIMEOUT');
    expect(timeout?.message, 'mentor response timed out');
  });

  test('terminal parser는 additive field를 무시하고 malformed status를 실패로 닫는다', () {
    final additive = parseMentorTerminal(
      const SseEvent(
        event: 'terminal',
        data: '{"status":"DONE","futureField":{"nested":true}}',
      ),
    );
    final malformed = parseMentorTerminal(
      const SseEvent(event: 'terminal', data: '{"status":"UNKNOWN"}'),
    );

    expect(additive?.status, MentorTerminalStatus.done);
    expect(malformed?.status, MentorTerminalStatus.failed);
    expect(malformed?.code, 'MALFORMED_TERMINAL');
    expect(
      parseMentorTerminal(const SseEvent(event: 'token', data: 'x')),
      isNull,
    );
  });

  test('contextual Mentor SSE body는 committed snapshot ID만 추가한다', () async {
    final adapter = _CapturingSseAdapter();
    final container = _container(adapter);

    await container
        .read(mentorContextualSseConnectProvider)(
          '왜 실패하나요?',
          contentId: '3',
          contextSnapshotId: 71,
        )
        .toList();

    expect(adapter.request?.method, 'POST');
    expect(adapter.request?.path, '/ai-mentor/sessions');
    expect(adapter.request?.queryParameters, isEmpty);
    expect(adapter.request?.data, {
      'message': '왜 실패하나요?',
      'contentId': '3',
      'contextSnapshotId': 71,
    });
  });

  test('contextless provider는 기존 body를 유지하고 snapshot을 보내지 않는다', () async {
    final adapter = _CapturingSseAdapter();
    final container = _container(adapter);

    await container.read(mentorSseConnectProvider)('질문').toList();

    expect(adapter.request?.data, {'message': '질문', 'contentId': null});
    expect(
      (adapter.request?.data as Map<String, Object?>),
      isNot(contains('contextSnapshotId')),
    );
  });

  test('contextual no-snapshot은 명시적 null이며 raw context 필드가 없다', () async {
    final adapter = _CapturingSseAdapter();
    final container = _container(adapter);

    await container
        .read(mentorContextualSseConnectProvider)(
          '질문',
          contentId: '3',
          contextSnapshotId: null,
        )
        .toList();

    final body = adapter.request?.data as Map<String, Object?>;
    expect(body['contextSnapshotId'], isNull);
    expect(
      body.keys,
      isNot(containsAll(['code', 'recentErrors', 'recentOutput', 'snapshot'])),
    );
  });
}
