import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:dp_core/src/error/api_error_code.dart';
import 'package:dp_core/src/error/api_exception.dart';
import 'package:dp_core/src/sse/sse_client.dart';
import 'package:test/test.dart';

class _StreamAdapter implements HttpClientAdapter {
  _StreamAdapter(this.body);
  final String body;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? rs,
    Future<void>? cf,
  ) async {
    final stream = Stream<Uint8List>.fromIterable([
      Uint8List.fromList(utf8.encode(body)),
    ]);
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

SseClient _client(String body) {
  final dio = Dio(BaseOptions(baseUrl: 'http://x'))
    ..httpClientAdapter = _StreamAdapter(body);
  return SseClient(dio);
}

void main() {
  test('event:error 프레임에서 ApiException(code)을 throw한다', () async {
    const body =
        'event:token\ndata:hello\n\n'
        'event:error\n'
        'data:{"error":{"code":"AI_KILL_SWITCH_ACTIVE","message":"멈춤","trace_id":"t1"}}\n\n';
    final events = <String>[];
    Object? caught;
    try {
      await for (final e in _client(body).connect('/x')) {
        events.add('${e.event}:${e.data}');
      }
    } catch (e) {
      caught = e;
    }
    // 선행 token은 보존되어 전달됨
    expect(events, ['token:hello']);
    // error 프레임은 ApiException으로 throw
    expect(caught, isA<ApiException>());
    final ex = caught as ApiException;
    expect(ex.code, ApiErrorCode.aiKillSwitchActive);
    expect(ex.message, '멈춤');
    expect(ex.traceId, 't1');
  });
}
