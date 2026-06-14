import 'package:dio/dio.dart';
import 'package:dp_core/src/mock/mock_http_adapter.dart';
import 'package:test/test.dart';

void main() {
  test('cursor 쿼리가 다르면 다른 페이지 픽스처를 반환한다', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://mock/api/v1'))
      ..httpClientAdapter = MockHttpAdapter({
        'GET /community/posts': (
          200,
          {
            'data': [
              {'id': '1'},
            ],
            'nextCursor': 'c2',
          },
        ),
        'GET /community/posts?cursor=c2': (
          200,
          {
            'data': [
              {'id': '2'},
            ],
            'nextCursor': null,
          },
        ),
      });
    final p1 = await dio.get<Map<String, dynamic>>('/community/posts');
    expect(p1.data!['nextCursor'], 'c2');
    final p2 = await dio.get<Map<String, dynamic>>(
      '/community/posts',
      queryParameters: {'cursor': 'c2'},
    );
    expect((p2.data!['data'] as List).first['id'], '2');
    expect(p2.data!['nextCursor'], isNull);
  });

  test('query 픽스처가 없으면 path-only로 폴백한다(하위호환)', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://mock/api/v1'))
      ..httpClientAdapter = MockHttpAdapter({
        'GET /users/me': (200, {'id': 'u1'}),
      });
    final res = await dio.get<Map<String, dynamic>>(
      '/users/me',
      queryParameters: {'x': '1'},
    );
    expect(res.data!['id'], 'u1'); // query 있어도 path-only 폴백
  });
}
