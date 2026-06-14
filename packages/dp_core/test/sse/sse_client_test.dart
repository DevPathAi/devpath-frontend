import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dp_core/src/sse/sse_client.dart';
import 'package:dp_core/src/sse/sse_event.dart';
import 'package:test/test.dart';

/// `text/event-stream` 바이트를 흘려주는 스텁 어댑터.
class _SseAdapter implements HttpClientAdapter {
  _SseAdapter(this.chunks);
  final List<String> chunks;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? rs,
      Future? cancelFuture) async {
    final stream = Stream.fromIterable(
        chunks.map((c) => Uint8List.fromList(utf8.encode(c))));
    return ResponseBody(stream, 200, headers: {
      Headers.contentTypeHeader: ['text/event-stream'],
    });
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
}
