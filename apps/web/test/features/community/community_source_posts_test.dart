import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// lcs_source_test.dart 패턴 승계: 실제 ApiClient + MockHttpAdapter(픽스처)로
// 소스 provider를 HTTP 없이 검증한다. 경로가 정확해야 픽스처가 매칭되며(오경로→404→throw),
// 반환값 파싱을 확인한다(MockHttpAdapter는 요청 바디를 캡처하지 않음).
ApiClient _client(Map<String, MockFixture> fixtures) {
  final client = ApiClient.create(const ApiConfig(baseUrl: 'https://t/api/v1'));
  client.dio.httpClientAdapter = MockHttpAdapter(fixtures);
  return client;
}

ProviderContainer _container(Map<String, MockFixture> fixtures) {
  final c = ProviderContainer(
    overrides: [apiClientProvider.overrideWithValue(_client(fixtures))],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('postCreate: POST /community/posts → 상세 반환', () async {
    final c = _container({
      'POST /community/posts': (
        201,
        {
          'id': 9,
          'boardType': 'FREE',
          'title': '자유글',
          'bodyMd': 'b',
          'authorId': 1,
          'upvoteCount': 0,
          'downvoteCount': 0,
          'tags': ['t'],
          'comments': <dynamic>[],
        },
      ),
    });

    final view = await c.read(postCreateProvider)(
      boardType: 'FREE',
      title: '자유글',
      bodyMd: 'b',
      tags: ['t'],
    );
    expect(view.id, 9);
    expect(view.boardType, 'FREE');
    expect(view.tags, ['t']);
  });

  test('postDetailFetch: GET /community/posts/9 → 상세(댓글 포함) 반환', () async {
    final c = _container({
      'GET /community/posts/9': (
        200,
        {
          'id': 9,
          'boardType': 'FEEDBACK',
          'title': '피드백',
          'bodyMd': '# 본문',
          'authorId': 7,
          'upvoteCount': 1,
          'downvoteCount': 0,
          'tags': <dynamic>[],
          'comments': [
            {
              'id': 100,
              'authorId': 8,
              'bodyMd': '댓글1',
              'upvoteCount': 0,
              'createdAt': '2026-07-29T00:00:00Z',
            },
          ],
        },
      ),
    });

    final view = await c.read(postDetailFetchProvider)(9);
    expect(view.id, 9);
    expect(view.comments.single.bodyMd, '댓글1');
  });

  test('commentCreate: POST /community/posts/9/comments → 댓글 반환', () async {
    final c = _container({
      'POST /community/posts/9/comments': (
        201,
        {
          'id': 30,
          'authorId': 2,
          'bodyMd': '댓글',
          'upvoteCount': 0,
          'createdAt': '2026-07-29T00:00:00Z',
        },
      ),
    });

    final view = await c.read(commentCreateProvider)(9, '댓글');
    expect(view.id, 30);
    expect(view.bodyMd, '댓글');
  });
}
