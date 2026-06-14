import 'dart:convert';

import 'package:dio/dio.dart';

import '../error/api_exception.dart';
import 'sse_event.dart';

/// dio stream 위에서 `text/event-stream`을 파싱해 [SseEvent]를 방출.
class SseClient {
  SseClient(this.dio);
  final Dio dio;

  Stream<SseEvent> connect(String path, {Object? body}) async* {
    final ResponseBody res;
    try {
      final r = await dio.post<ResponseBody>(
        path,
        data: body,
        options: Options(
          responseType: ResponseType.stream,
          headers: {Headers.acceptHeader: 'text/event-stream'},
        ),
      );
      res = r.data!;
    } on DioException catch (e) {
      // get/post 헬퍼와 동일하게 실패를 ApiException으로 정규화.
      throw (e.error is ApiException) ? e.error as ApiException : ApiException.fromDio(e);
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
          yield SseEvent(event: event, data: dataBuf.toString());
          dataBuf.clear();
          event = null;
        }
        continue;
      }
      if (line.startsWith('event:')) {
        event = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        if (dataBuf.isNotEmpty) dataBuf.write('\n');
        dataBuf.write(line.substring(5).trim());
      }
      // 'id:'/'retry:' 등은 P2 범위 밖(필요 시 feature에서 확장).
    }
    // 스트림 종료 시 버퍼에 남은 이벤트를 flush(마지막 DONE에 빈 줄이 없는 서버 대비).
    if (dataBuf.isNotEmpty) {
      yield SseEvent(event: event, data: dataBuf.toString());
    }
  }
}
