import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// community_search_source_test.dart 패턴 승계 — 실제 ApiClient + MockHttpAdapter(픽스처).
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
  test('communityReport: POST /community/reports 로 접수하고 결과를 파싱한다', () async {
    final c = _container({
      'POST /community/reports': (201, {'id': 5, 'status': 'OPEN'}),
    });

    final r = await c.read(communityReportProvider)(
      targetType: 'POST',
      targetId: 1,
      category: CommunityReportCategory.spam,
      reason: '광고글입니다',
    );

    expect(r.id, 5);
    expect(r.status, 'OPEN');
  });

  test('communityReport: 사유 없이도 접수된다', () async {
    final c = _container({
      'POST /community/reports': (201, {'id': 6, 'status': 'OPEN'}),
    });

    final r = await c.read(communityReportProvider)(
      targetType: 'COMMENT',
      targetId: 9,
      category: CommunityReportCategory.abuse,
    );

    expect(r.id, 6);
  });

  test('CommunityReportCategory: 서버 enum 값과 한글 라벨이 대응한다', () {
    // wire 는 DB CHECK 제약(chk_community_reports_category)과 일치해야 한다.
    expect(CommunityReportCategory.spam.wire, 'SPAM');
    expect(CommunityReportCategory.abuse.wire, 'ABUSE');
    expect(CommunityReportCategory.ad.wire, 'AD');
    expect(CommunityReportCategory.duplicate.wire, 'DUPLICATE');
    expect(CommunityReportCategory.inappropriate.wire, 'INAPPROPRIATE');
    expect(CommunityReportCategory.etc.wire, 'ETC');

    expect(CommunityReportCategory.spam.label, '스팸');
    expect(CommunityReportCategory.abuse.label, '욕설');
    expect(CommunityReportCategory.values.length, 6);
  });
}
