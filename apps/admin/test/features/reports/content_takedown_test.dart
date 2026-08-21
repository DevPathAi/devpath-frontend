import 'package:devpath_admin/src/features/reports/data/reports_source.dart';
import 'package:devpath_admin/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// 실제 ApiClient + MockHttpAdapter 로 경로·파싱을 검증한다(web 의 데이터 계층 테스트와
// 같은 패턴). 픽스처 키는 '<METHOD> <path>' 이고 쿼리가 있으면 키를 정렬해 덧붙인다.
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
  test('내리기: 대상 종류가 경로를 가른다', () async {
    final c = _container({
      'DELETE /community/admin/posts/7': (204, <String, dynamic>{}),
      'DELETE /community/admin/answers/11': (204, <String, dynamic>{}),
      'DELETE /community/admin/comments/5': (204, <String, dynamic>{}),
    });

    await c.read(contentTakedownProvider)('POST', 7);
    await c.read(contentTakedownProvider)('ANSWER', 11);
    await c.read(contentTakedownProvider)('COMMENT', 5);
  });

  test('내리기: 경로가 틀리면 실패한다 — 측정법 유효성', () async {
    final c = _container({
      'DELETE /community/admin/posts/7': (204, <String, dynamic>{}),
    });
    await expectLater(
      c.read(contentTakedownProvider)('POST', 8),
      throwsA(isA<ApiException>()),
    );
  });

  test('리비전 조회: 최신순 목록을 파싱한다', () async {
    final c = _container({
      'GET /community/admin/revisions?targetId=7&targetType=POST': (
        200,
        [
          {
            'targetType': 'POST',
            'targetId': 7,
            'title': '두번째',
            'bodyMd': '두번째본문',
            'editedBy': 3,
            'createdAt': '2026-08-21T01:00:00Z',
          },
          {
            'targetType': 'POST',
            'targetId': 7,
            'title': '원제목',
            'bodyMd': '원본문',
            'editedBy': 3,
            'createdAt': '2026-08-21T00:00:00Z',
          },
        ],
      ),
    });

    final list = await c.read(revisionsFetchProvider)('POST', 7);
    expect(list, hasLength(2));
    expect(list.first.title, '두번째');
    expect(list.first.editedBy, 3);
  });

  test('리비전 조회: 답변 리비전은 제목이 없다', () async {
    final c = _container({
      'GET /community/admin/revisions?targetId=11&targetType=ANSWER': (
        200,
        [
          {
            'targetType': 'ANSWER',
            'targetId': 11,
            'title': null,
            'bodyMd': '옛 답변',
            'editedBy': 5,
            'createdAt': '2026-08-21T00:00:00Z',
          },
        ],
      ),
    });

    final list = await c.read(revisionsFetchProvider)('ANSWER', 11);
    expect(list.single.title, isNull);
    expect(list.single.bodyMd, '옛 답변');
  });
}
