import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dp_core/src/sse/sse_client.dart';
import 'package:test/test.dart';

/// `text/event-stream` 바이트를 흘려주는 스텁 어댑터.
class _SseAdapter implements HttpClientAdapter {
  _SseAdapter(this.chunks);
  final List<String> chunks;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? rs,
    Future? cancelFuture,
  ) async {
    final stream = Stream.fromIterable(
      chunks.map((c) => Uint8List.fromList(utf8.encode(c))),
    );
    return ResponseBody(
      stream,
      200,
      headers: {
        Headers.contentTypeHeader: ['text/event-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('data: 라인을 SseEvent로 파싱한다(청크 경계 무관)', () async {
    final dio = Dio()
      ..httpClientAdapter = _SseAdapter([
        'event: stage\n',
        'data: {"step":"ANALYZE"}\n\n',
        'data: {"step":"DON', // 청크가 라인 중간에서 끊김
        'E"}\n\n',
      ]);
    final client = SseClient(dio);

    final events = await client
        .connect('/learning-paths/me/generate', body: const {})
        .toList();

    expect(events.map((e) => e.data), [
      '{"step":"ANALYZE"}',
      '{"step":"DONE"}',
    ]);
    expect(events.first.event, 'stage');
  });

  test('data: 값은 선행 스페이스 1개만 제거하고 나머지 공백은 보존한다', () async {
    // WHATWG SSE 규격: data 값에서 선행 U+0020 1개만 제거하고
    // 내부·후행·추가 선행 공백은 보존한다(LLM 토큰 스트림의 공백 보존).
    final dio = Dio()
      ..httpClientAdapter = _SseAdapter([
        'data: 비동기는 \n\n', // 후행 공백 → 보존돼야 함
        'data:  await\n\n', // 선행 스페이스 2개 → 1개만 제거(토큰 선행 공백 보존)
      ]);
    final client = SseClient(dio);

    final events = await client
        .connect('/ai-mentor/sessions', body: const {})
        .toList();

    expect(events.map((e) => e.data), [
      '비동기는 ', // 후행 공백 보존
      ' await', // 선행 1개만 제거 → 토큰 공백 보존
    ]);
  });
}
