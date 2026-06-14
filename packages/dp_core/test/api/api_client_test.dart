import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dp_core/src/api/api_client.dart';
import 'package:dp_core/src/api/api_config.dart';
import 'package:dp_core/src/error/api_exception.dart';
import 'package:dp_core/src/error/api_error_code.dart';
import 'package:test/test.dart';

/// 테스트용 최소 어댑터: 지정 status/body를 그대로 돌려준다.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.status, this.body);
  final int status;
  final Object body;
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? rs,
          Future? cancelFuture) async =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
  @override
  void close({bool force = false}) {}
}

void main() {
  test('baseUrl을 적용하고 JSON을 반환한다', () async {
    final client = ApiClient.create(const ApiConfig(baseUrl: 'https://api.test/api/v1'));
    client.dio.httpClientAdapter = _StubAdapter(200, {'ok': true});
    final res = await client.dio.get<Map<String, dynamic>>('/ping');
    expect(client.dio.options.baseUrl, 'https://api.test/api/v1');
    expect(res.data, {'ok': true});
  });

  test('badResponse는 ApiException으로 변환된다(get 헬퍼)', () async {
    final client = ApiClient.create(const ApiConfig(baseUrl: 'https://api.test/api/v1'));
    client.dio.httpClientAdapter = _StubAdapter(503, {
      'error': {'code': 'AI_KILL_SWITCH_ACTIVE', 'message': '점검 중'}
    });
    expect(
      () => client.get('/ai-mentor/sessions'),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', ApiErrorCode.aiKillSwitchActive)),
    );
  });
}
