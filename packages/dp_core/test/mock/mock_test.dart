import 'package:dio/dio.dart';
import 'package:dp_core/src/error/api_error_code.dart';
import 'package:dp_core/src/error/api_exception.dart';
import 'package:dp_core/src/mock/mock_http_adapter.dart';
import 'package:dp_core/src/mock/mock_sse_source.dart';
import 'package:test/test.dart';

void main() {
  test('MockHttpAdapter는 등록된 픽스처를 반환한다', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://mock/api/v1'))
      ..httpClientAdapter = MockHttpAdapter({
        'GET /users/me': (200, {'id': 'u1', 'nickname': 'jisoo'}),
      });
    final res = await dio.get<Map<String, dynamic>>('/users/me');
    expect(res.data!['nickname'], 'jisoo');
  });

  test('MockSseSource는 단계를 지연 emit한다', () async {
    final source = MockSseSource(
      stages: const ['ANALYZE', 'MAP', 'BUILD', 'DONE'],
      delay: Duration.zero,
    );
    final got = await source.stream().map((e) => e.data).toList();
    expect(got.length, 4);
    expect(got.last, contains('DONE'));
  });

  test('failAfter는 N단계 emit 후 ApiException(network)로 중단한다', () async {
    final source = MockSseSource(
      stages: const ['ANALYZE', 'MAP', 'BUILD', 'DONE'],
      delay: Duration.zero,
      failAfter: 2,
    );
    final got = <String>[];
    await expectLater(
      source.stream().map((e) => e.data).forEach(got.add),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.network)),
    );
    expect(got.length, 2); // 2단계까지 보존
  });

  test('fromStep으로 끊긴 지점부터 이어한다(전체 재시작 아님)', () async {
    final resumed = MockSseSource(
      stages: const ['ANALYZE', 'MAP', 'BUILD', 'DONE'],
      delay: Duration.zero,
      fromStep: 2, // 완료 2단계 이후부터
    ).stream().map((e) => e.data);
    final got = await resumed.toList();
    expect(got.length, 2); // BUILD, DONE만
    expect(got.last, contains('DONE'));
  });
}
