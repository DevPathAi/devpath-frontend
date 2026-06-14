import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:test/test.dart';

class _SseAdapter implements HttpClientAdapter {
  _SseAdapter(this.chunks);
  final List<String> chunks;
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? rs, Future? cf) async =>
      ResponseBody(
        Stream.fromIterable(chunks.map((c) => Uint8List.fromList(utf8.encode(c)))),
        200,
        headers: {Headers.contentTypeHeader: ['text/event-stream']},
      );
  @override
  void close({bool force = false}) {}
}

void main() {
  test('apiClient.sse()는 앱이 dio를 직접 만지지 않고 SSE를 스트림한다', () async {
    final client = ApiClient.create(const ApiConfig(baseUrl: 'https://mock/api/v1'));
    client.dio.httpClientAdapter = _SseAdapter([
      'event: stage\n', 'data: {"step":"ANALYZE"}\n\n', 'data: {"step":"DONE"}\n\n',
    ]);
    final events = await client.sse('/learning-paths/me/generate', body: const {}).toList();
    expect(events.map((e) => e.data), ['{"step":"ANALYZE"}', '{"step":"DONE"}']);
  });
}
