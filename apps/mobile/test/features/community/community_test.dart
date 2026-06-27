import 'package:devpath_mobile/src/features/community/application/community_controller.dart';
import 'package:devpath_mobile/src/features/community/data/community_source.dart';
import 'package:devpath_mobile/src/features/community/state/community_state.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/mock_api.dart';

final Map<String, MockFixture> _postsFx = {
  'GET /community/posts': (
    200,
    [
      {
        'id': 1,
        'title': 'async/await가 헷갈려요',
        'authorId': 42,
        'solved': true,
        'upvoteCount': 3,
        'answerCount': 2,
      },
    ],
  ),
};

final Map<String, MockFixture> _createFx = {
  'POST /community/questions': (
    201,
    {
      'id': 99,
      'title': '새 질문',
      'bodyMd': '본문',
      'solved': false,
      'acceptedAnswerId': null,
      'upvoteCount': 0,
      'downvoteCount': 0,
      'tags': <String>[],
      'answers': <Map<String, dynamic>>[],
    },
  ),
};

ProviderContainer _container(Map<String, MockFixture> fx) {
  final c = ProviderContainer(
    overrides: [apiClientProvider.overrideWithValue(mockApiClient(fx))],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('CommunityController', () {
    test('load 성공 → CommunityLoaded(목록)', () async {
      final c = _container(_postsFx);
      await c.read(communityControllerProvider.notifier).load();
      final s = c.read(communityControllerProvider);
      expect(s, isA<CommunityLoaded>());
      expect((s as CommunityLoaded).posts.first.title, 'async/await가 헷갈려요');
    });

    test('load 실패 → CommunityFailed', () async {
      final c = _container(const {});
      await c.read(communityControllerProvider.notifier).load();
      expect(c.read(communityControllerProvider), isA<CommunityFailed>());
    });
  });

  group('questionCreate (퀵 캡처)', () {
    test('POST 후 생성된 질문 상세 반환', () async {
      final c = _container(_createFx);
      final create = c.read(questionCreateProvider);
      final detail = await create(title: '새 질문', bodyMd: '본문', tags: const []);
      expect(detail.id, 99);
      expect(detail.title, '새 질문');
    });
  });
}
