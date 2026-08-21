import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// community_source_posts_test.dart 패턴 승계: 실제 ApiClient + MockHttpAdapter 로
// 경로·파싱을 검증한다. 픽스처 키는 '<METHOD> <path>' 이므로 PUT·DELETE 도 그대로 걸린다.
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
  test('postUpdate: PUT /community/posts/9 → 상세 반환', () async {
    final c = _container({
      'PUT /community/posts/9': (
        200,
        {
          'id': 9,
          'boardType': 'FREE',
          'title': '새제목',
          'bodyMd': '새본문',
          'authorId': 1,
          'upvoteCount': 0,
          'downvoteCount': 0,
          'tags': <dynamic>[],
          'comments': <dynamic>[],
        },
      ),
    });

    final view = await c.read(postUpdateProvider)(
      id: 9,
      title: '새제목',
      bodyMd: '새본문',
    );
    expect(view.title, '새제목');
    expect(view.bodyMd, '새본문');
  });

  test('postDelete: DELETE /community/posts/9 → 204 를 예외 없이 통과', () async {
    final c = _container({'DELETE /community/posts/9': (204, <String, dynamic>{})});
    await c.read(postDeleteProvider)(9);
  });

  test('answerUpdate: PUT /community/answers/11 → 답변 반환', () async {
    final c = _container({
      'PUT /community/answers/11': (
        200,
        {
          'id': 11,
          'authorId': 2,
          'bodyMd': '고친답변',
          'aiGenerated': false,
          'accepted': false,
          'upvoteCount': 0,
          'deleted': false,
        },
      ),
    });

    final view = await c.read(answerUpdateProvider)(11, '고친답변');
    expect(view.bodyMd, '고친답변');
    expect(view.deleted, isFalse);
  });

  test('answerDelete: DELETE /community/answers/11', () async {
    final c = _container({'DELETE /community/answers/11': (204, <String, dynamic>{})});
    await c.read(answerDeleteProvider)(11);
  });

  test('commentUpdate: PUT /community/comments/5 → 댓글 반환', () async {
    final c = _container({
      'PUT /community/comments/5': (
        200,
        {
          'id': 5,
          'authorId': 2,
          'bodyMd': '고친댓글',
          'upvoteCount': 0,
          'createdAt': '2026-08-21T00:00:00Z',
          'deleted': false,
        },
      ),
    });

    final view = await c.read(commentUpdateProvider)(5, '고친댓글');
    expect(view.bodyMd, '고친댓글');
  });

  test('commentDelete: DELETE /community/comments/5', () async {
    final c = _container({'DELETE /community/comments/5': (204, <String, dynamic>{})});
    await c.read(commentDeleteProvider)(5);
  });

  test('경로가 틀리면 픽스처가 안 걸려 ApiException 이 난다 — 측정법 유효성', () async {
    final c = _container({'DELETE /community/posts/9': (204, <String, dynamic>{})});
    await expectLater(
      c.read(postDeleteProvider)(10),
      throwsA(isA<ApiException>()),
    );
  });
}
