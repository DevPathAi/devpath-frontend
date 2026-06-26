import 'package:devpath_web/src/features/community/data/lcs_source.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
  test('byQuestion 200 → LcsSnapshotView 파싱', () async {
    final c = _container({
      'GET /lcs/snapshots/by-question/1': (
        200,
        {
          'id': 7,
          'createdAt': '2026-06-26T10:00:00Z',
          'content': {
            'current_content': {'title': '비동기 기초'},
          },
          'renderedFor': 'answerer',
        },
      ),
    });

    final snap = await c.read(lcsByQuestionProvider)(1);

    expect(snap, isNotNull);
    expect(snap!.id, 7);
    expect(snap.content.containsKey('current_content'), isTrue);
  });

  test('byQuestion 404 → null (스냅샷 없음 우아 처리)', () async {
    final c = _container(const {}); // 미매칭 → MockHttpAdapter 404
    final snap = await c.read(lcsByQuestionProvider)(999);
    expect(snap, isNull);
  });

  test('commit → snapshotId 반환', () async {
    final c = _container({
      'POST /lcs/snapshots/snap_x/commit': (
        201,
        {'snapshotId': 42, 'status': 'committed', 'immutable': true},
      ),
    });

    final id = await c.read(lcsCommitProvider)(
      draftId: 'snap_x',
      attachedToId: 5,
      visibility: 'answerers_only',
    );

    expect(id, 42);
  });

  test('draft → LcsDraft(fieldsAvailable·fieldsUnavailable) 파싱', () async {
    final c = _container({
      'POST /lcs/snapshots/draft': (
        200,
        {
          'draftId': 'snap_x',
          'expiresAt': '2026-06-26T23:59:00Z',
          'content': {'recent_activity': <dynamic>[]},
          'fieldsAvailable': ['recent_activity'],
          'fieldsUnavailable': [
            {'field': 'current_content', 'reason': 'no_content_context'},
          ],
        },
      ),
    });

    final d = await c.read(lcsDraftProvider)(requestedFields: const []);

    expect(d.draftId, 'snap_x');
    expect(d.fieldsAvailable, contains('recent_activity'));
    expect(d.fieldsUnavailable.first.reason, 'no_content_context');
  });
}
