import 'dart:convert';

import 'package:dio/dio.dart';

import '../error/api_error_code.dart';
import '../error/api_exception.dart';
import 'sse_event.dart';

/// dio stream 위에서 `text/event-stream`을 파싱해 [SseEvent]를 방출.
class SseClient {
  SseClient(this.dio);
  final Dio dio;

  Stream<SseEvent> connect(
    String path, {
    Object? body,
    Map<String, Object?> requestHeaders = const {},
    Map<String, String> responseHeaderEvents = const {},
    Duration? receiveTimeout,
  }) async* {
    final ResponseBody res;
    final Headers responseHeaders;
    try {
      final r = await dio.post<ResponseBody>(
        path,
        data: body,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: receiveTimeout,
          headers: {
            Headers.acceptHeader: 'text/event-stream',
            ...requestHeaders,
          },
        ),
      );
      res = r.data!;
      responseHeaders = r.headers;
    } on DioException catch (e) {
      // get/post 헬퍼와 동일하게 실패를 ApiException으로 정규화.
      throw (e.error is ApiException)
          ? e.error as ApiException
          : ApiException.fromDio(e);
    }

    // Some accepted streaming operations expose their durable identity in the
    // HTTP headers before the first SSE frame. Project only explicitly mapped
    // headers into synthetic SSE events so existing consumers remain unchanged.
    for (final mapping in responseHeaderEvents.entries) {
      final value = responseHeaders.value(mapping.key);
      if (value != null && value.isNotEmpty) {
        yield SseEvent(event: mapping.value, data: value);
      }
    }

    final lines = res.stream
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    String? event;
    final dataBuf = StringBuffer();

    await for (final line in lines) {
      if (line.isEmpty) {
        // 빈 줄 = 이벤트 경계
        if (dataBuf.isNotEmpty) {
          final ev = SseEvent(event: event, data: dataBuf.toString());
          dataBuf.clear();
          final name = event;
          event = null;
          if (name == 'error') {
            throw _sseError(ev.data);
          }
          yield ev;
        }
        continue;
      }
      if (line.startsWith('event:')) {
        final e = line.substring(6);
        // SSE 규격: 선행 스페이스 1개만 제거(내부·후행 공백 보존, data와 일관).
        event = e.startsWith(' ') ? e.substring(1) : e;
      } else if (line.startsWith('data:')) {
        if (dataBuf.isNotEmpty) dataBuf.write('\n');
        final v = line.substring(5);
        // SSE 규격: 선행 스페이스 1개만 제거 — LLM 토큰의 앞뒤 공백을 보존한다.
        dataBuf.write(v.startsWith(' ') ? v.substring(1) : v);
      }
      // 'id:'/'retry:' 등은 P2 범위 밖(필요 시 feature에서 확장).
    }
    // 스트림 종료 시 버퍼에 남은 이벤트를 flush(마지막 DONE에 빈 줄이 없는 서버 대비).
    if (dataBuf.isNotEmpty) {
      final ev = SseEvent(event: event, data: dataBuf.toString());
      if (event == 'error') throw _sseError(ev.data);
      yield ev;
    }
  }

  ApiException _sseError(String data) {
    try {
      final decoded = json.decode(data);
      if (decoded is Map) {
        return ApiException.fromEnvelope(decoded.cast<String, dynamic>());
      }
    } catch (_) {}
    return const ApiException(
      code: ApiErrorCode.unknown,
      message: '스트림 오류가 발생했습니다.',
    );
  }
}
