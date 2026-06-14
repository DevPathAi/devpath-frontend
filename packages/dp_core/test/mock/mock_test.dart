import 'package:dio/dio.dart';
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
}
