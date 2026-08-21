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
  // OAuth 콜백 후 세션 복원(`AdminAuthController.bootstrapFromCallback`).
  //
  // **목 모드에서는 이 픽스처가 유일한 진입 경로다.** 로그인 화면의 버튼은
  // 외부 OAuth 제공자로 나가므로 목 환경에서는 끝까지 갈 수 없고,
  // `#/auth/callback` 으로 직접 들어와 여기서 세션을 복원해야 한다.
  // 이것이 없으면 `/login` 에서 더 나아갈 수 없어 admin 화면을 하나도 볼 수 없다.
  //
  // ★키가 snake_case다★ — 위 `POST /admin/auth/login` 은 camelCase(accessToken)라
  // 그대로 베끼면 `data['access_token']` 파싱이 깨진다. 계약은
  // `bootstrap_callback_test.dart` 가 잠근다.
  'POST /auth/refresh': (
    200,
    {
      'access_token': 'admin-access',
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
          'id': '1',
          'nickname': '지수',
          'email': 'a@x.com',
          'role': 'LEARNER',
          'status': 'BETA_PENDING',
        },
        {
          'id': '2',
          'nickname': '민준',
          'email': 'b@x.com',
          'role': 'PRO',
          'status': 'ACTIVE',
        },
        {
          'id': '3',
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
  'POST /admin/users/1/approve': (204, <String, dynamic>{}),
  'POST /admin/users/2/sanction': (200, {'ok': true}),
  'POST /admin/users/bulk-approve': (204, <String, dynamic>{}),
  'POST /admin/ads/bulk-delete': (204, <String, dynamic>{}),
  // 콘텐츠 내리기·수정 이력 — 목 모드에서도 모더레이션 흐름이 끊기지 않게 한다.
  // ★204 라도 본문은 Object 다★ — MockFixture 는 (int, Object) 라 null 을 넣을 수 없다.
  'DELETE /community/admin/posts/1': (204, <String, dynamic>{}),
  'DELETE /community/admin/answers/11': (204, <String, dynamic>{}),
  'DELETE /community/admin/comments/5': (204, <String, dynamic>{}),
  'GET /community/admin/revisions?targetId=1&targetType=POST': (
    200,
    <dynamic>[],
  ),
  // 신고(A-006). 경로가 /admin/reports 가 아니라 /community/admin/reports 인 이유는
  // 게이트웨이가 /admin/** 를 platform-svc 로 선점하기 때문이다(community-svc 계약).
  'GET /community/admin/reports': (
    200,
    {
      'items': [
        {
          'id': 1,
          'targetType': 'POST',
          'targetId': 10,
          'targetTitle': '스팸 의심 글',
          'targetExcerpt': '지금 가입하면 무료…',
          'targetAuthorId': 42,
          'targetPath': '/community/post/10',
          'reporterId': 7,
          'category': 'AD',
          'reason': '광고글입니다',
          'reportCount': 3,
          'status': 'OPEN',
          'createdAt': '2026-08-02T09:00:00Z',
        },
        {
          'id': 2,
          'targetType': 'COMMENT',
          'targetId': 55,
          'targetTitle': '자유글 제목',
          'targetExcerpt': '심한 표현이 담긴 댓글…',
          'targetAuthorId': 8,
          'targetPath': '/community/post/9',
          'reporterId': 3,
          'category': 'ABUSE',
          'reason': null,
          'reportCount': 1,
          'status': 'OPEN',
          'createdAt': '2026-08-02T08:30:00Z',
        },
        {
          // 대상이 지워진 신고 — "삭제된 콘텐츠"로 표시되는 경로를 목에서도 재현한다.
          'id': 3,
          'targetType': 'POST',
          'targetId': 99,
          'targetTitle': null,
          'targetExcerpt': null,
          'targetAuthorId': null,
          'targetPath': null,
          'reporterId': 5,
          'category': 'SPAM',
          'reason': '스팸입니다',
          'reportCount': 1,
          'status': 'OPEN',
          'createdAt': '2026-08-01T12:00:00Z',
        },
      ],
      'total': 3,
      'page': 0,
      'size': 50,
    },
  ),
  'POST /community/admin/reports/1/resolve': (
    200,
    {'id': 1, 'status': 'RESOLVED'},
  ),
  'POST /community/admin/reports/2/resolve': (
    200,
    {'id': 2, 'status': 'RESOLVED'},
  ),
  'POST /community/admin/reports/3/resolve': (
    200,
    {'id': 3, 'status': 'RESOLVED'},
  ),
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
