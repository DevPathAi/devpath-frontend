import 'package:dp_core/dp_core.dart';

final Map<String, MockFixture> adminMockFixtures = {
  'POST /admin/auth/login': (
    200,
    {
      'accessToken': 'admin-access',
      'refreshToken': 'admin-refresh',
      'user': {
        'id': 'admin-1',
        'email': 'admin@devpath.ai',
        'nickname': '운영자',
        'role': 'ADMIN',
        'onboardingStatus': 'DONE',
        'consentStatus': 'DONE',
      },
    },
  ),
  // 사용자 목록(A-002) — 단일 페이지(목 한계: query 무시, P4f와 동일)
  'GET /admin/users': (
    200,
    {
      'data': [
        {
          'id': 'u1',
          'nickname': '지수',
          'email': 'a@x.com',
          'role': 'LEARNER',
          'status': 'ACTIVE',
        },
        {
          'id': 'u2',
          'nickname': '민준',
          'email': 'b@x.com',
          'role': 'PRO',
          'status': 'WARNED',
        },
        {
          'id': 'u3',
          'nickname': '서연',
          'email': 'c@x.com',
          'role': 'LEARNER',
          'status': 'SUSPENDED',
        },
      ],
      'nextCursor': null,
      'limit': 20,
    },
  ),
  'POST /admin/users/u1/sanction': (200, {'ok': true}),
  'POST /admin/users/bulk-approve': (204, <String, dynamic>{}),
  'POST /admin/ads/bulk-delete': (204, <String, dynamic>{}),
  // 신고(A-006)
  'GET /admin/reports': (
    200,
    {
      'data': [
        {
          'id': 'r1',
          'type': 'POST',
          'targetTitle': '스팸 의심 글',
          'reason': '광고',
          'status': 'OPEN',
        },
        {
          'id': 'r2',
          'type': 'COMMENT',
          'targetTitle': '욕설 댓글',
          'reason': '비방',
          'status': 'OPEN',
        },
      ],
      'nextCursor': null,
      'limit': 20,
    },
  ),
  'POST /admin/reports/r1/resolve': (200, {'ok': true}),
  // 운영 대시보드(A-004)
  'GET /admin/stats': (
    200,
    {'dau': 1280, 'newUsers': 64, 'openReports': 2, 'aiCalls': 9421},
  ),
  // 광고 관리(P2) — 목 한계: query 무시(전체 목록 반환)
  'GET /admin/ads': (
    200,
    [
      {
        'id': 1,
        'title': '하우스 배너 · 부트캠프',
        'imageUrl': null,
        'linkUrl': 'https://example.com/promo',
        'slot': 'DASHBOARD_TOP',
        'weight': 3,
        'status': 'ACTIVE',
        'startsAt': null,
        'endsAt': null,
      },
      {
        'id': 2,
        'title': '커뮤니티 스폰서',
        'imageUrl': null,
        'linkUrl': 'https://example.com/sponsor',
        'slot': 'COMMUNITY_FEED',
        'weight': 1,
        'status': 'PAUSED',
        'startsAt': null,
        'endsAt': null,
      },
    ],
  ),
  'GET /admin/ads/settings': (200, {'enabled': true}),
  'PUT /admin/ads/settings': (200, {'enabled': true}),
  'GET /admin/ads/1/stats': (
    200,
    [
      {'date': '2026-07-21', 'impressions': 120, 'clicks': 4},
      {'date': '2026-07-22', 'impressions': 98, 'clicks': 7},
    ],
  ),
};
