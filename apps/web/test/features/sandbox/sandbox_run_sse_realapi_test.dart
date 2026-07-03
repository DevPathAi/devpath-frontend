import 'dart:convert';
import 'dart:typed_data';

import 'package:devpath_web/src/app/app_config.dart';
import 'package:devpath_web/src/features/sandbox/application/run_controller.dart';
import 'package:devpath_web/src/features/sandbox/state/run_state.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// sandbox run SSE 실계약 회귀. 백엔드 sandbox-svc `RunController`:
/// `POST /run`(text/event-stream) → `name("log").data(line)` + `name("session")
/// .data(sessionId)` → `complete()`. **실 분기(useMock=false)를 dio stream mock으로 구동.**
class _SseAdapter implements HttpClientAdapter {
  _SseAdapter(this.chunks);
  final List<String> chunks;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    return ResponseBody(
      Stream.fromIterable(
        chunks.map((c) => Uint8List.fromList(utf8.encode(c))),
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

ProviderContainer _container(List<String> chunks) {
  final client = ApiClient.create(const ApiConfig(baseUrl: 'https://t/api/v1'));
  client.dio.httpClientAdapter = _SseAdapter(chunks);
  return ProviderContainer(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(baseUrl: 'https://t/api/v1', useMock: false),
      ),
      apiClientProvider.overrideWithValue(client),
    ],
  );
}

void main() {
  test('실계약 log/session 스트림 → RunDone(sandboxSessionId·로그)', () async {
    final container = _container(const [
      'event: log\ndata: > run main\n\n',
      'event: log\ndata: 컴파일 완료\n\n',
      'event: session\ndata: 42\n\n',
    ]);
    addTearDown(container.dispose);

    await container.read(runControllerProvider.notifier).run('code', 'JAVA');

    final s = container.read(runControllerProvider);
    expect(s, isA<RunDone>());
    final done = s as RunDone;
    expect(done.sandboxSessionId, 42);
    expect(done.logs, containsAll(<String>['> run main', '컴파일 완료']));
  });
}
