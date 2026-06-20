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
      stages: const ['collecting', 'generating', 'matching', 'done'],
      delay: Duration.zero,
    );
    final got = await source.stream().map((e) => e.data).toList();
    expect(got.length, 4);
    expect(got.first, contains('"stage":"collecting"'));
    expect(got.last, contains('"stage":"done"'));
    expect(got.last, contains('"pathId":101'));
  });

  test('failAfter는 N단계 emit 후 ApiException(network)로 중단한다', () async {
    final source = MockSseSource(
      stages: const ['collecting', 'generating', 'matching', 'done'],
      delay: Duration.zero,
      failAfter: 2,
    );
    final got = <String>[];
    await expectLater(
      source.stream().map((e) => e.data).forEach(got.add),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.network),
      ),
    );
    expect(got.length, 2); // 2단계까지 보존
  });

  test('재시작은 항상 첫 stage부터 다시 emit한다', () async {
    final restarted = MockSseSource(
      stages: const ['collecting', 'generating', 'matching', 'done'],
      delay: Duration.zero,
    ).stream().map((e) => e.data);

    final got = await restarted.toList();

    expect(got, hasLength(4));
    expect(got.first, contains('"stage":"collecting"'));
  });
}
