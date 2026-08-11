import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// community_source_posts_test.dart 패턴 승계 — 실제 ApiClient + MockHttpAdapter(픽스처).
//
// MockHttpAdapter 는 'METHOD /path?k=v&...'(키 **정렬**)를 먼저 찾고 없으면 'METHOD /path'
// 로 폴백한다. 따라서 정렬 키 픽스처만 두고 base 키를 두지 않으면 "쿼리를 정확히 그대로
// 보냈는가"가 검증된다 — 다르게 보내면 폴백 키도 없어 404 → throw 로 드러난다.
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
  test('communitySearch: q·board·page·size 를 그대로 쿼리로 보낸다', () async {
    final c = _container({
      // 정렬 키만 등록 — base 폴백이 없으므로 쿼리가 하나라도 다르면 404 로 실패한다.
      'GET /community/search?board=QNA&page=1&q=Riverpod&size=5': (
        200,
        {'items': <dynamic>[], 'total': 0, 'page': 1, 'size': 5},
      ),
    });

    final result = await c.read(communitySearchProvider)(
      q: 'Riverpod',
      board: 'QNA',
      page: 1,
      size: 5,
    );

    expect(result.page, 1);
    expect(result.size, 5);
  });

  test('communitySearch: items·total·page·size 를 파싱한다', () async {
    final c = _container({
      'GET /community/search': (
        200,
        {
          'items': [
            {
              'id': 1,
              'title': 'async/await가 헷갈려요',
              'boardType': 'QNA',
              'authorId': 7,
              'solved': false,
              'upvoteCount': 3,
              'replyCount': 2,
              'excerpt': 'async/await에서 예외는 어디서 잡나요?',
              'highlight': 'async/await에서 <em>예외</em>는 어디서 잡나요?',
            },
            {
              'id': 10,
              'title': '배포 자동화 팁 공유',
              'boardType': 'FREE',
              'solved': false,
              'upvoteCount': 5,
              'replyCount': 1,
              'excerpt': 'GitHub Actions로 배포를 자동화했습니다.',
              'highlight': '',
            },
          ],
          'total': 42,
          'page': 0,
          'size': 20,
        },
      ),
    });

    final result = await c.read(communitySearchProvider)(q: '예외');

    expect(result.items.length, 2);
    expect(result.total, 42);
    expect(result.page, 0);
    expect(result.size, 20);
    expect(result.items.first.id, 1);
    expect(result.items.first.boardType, 'QNA');
    expect(result.items.last.boardType, 'FREE');
  });

  test('communitySearch: highlight 를 파싱한다', () async {
    final c = _container({
      'GET /community/search': (
        200,
        {
          'items': [
            {'id': 1, 'title': '제목', 'highlight': '본문에 <em>검색어</em>가 있다'},
          ],
          'total': 1,
          'page': 0,
          'size': 20,
        },
      ),
    });

    final result = await c.read(communitySearchProvider)(q: '검색어');

    expect(result.items.single.highlight, '본문에 <em>검색어</em>가 있다');
  });

  test('communitySearch: highlight 가 없으면 빈 문자열이다', () async {
    final c = _container({
      'GET /community/search': (
        200,
        {
          'items': [
            {'id': 2, 'title': '하이라이트 없는 결과'},
          ],
          'total': 1,
          'page': 0,
          'size': 20,
        },
      ),
    });

    final result = await c.read(communitySearchProvider)(q: '검색어');

    expect(result.items.single.highlight, '');
  });
}
