import 'package:dp_core/dp_core.dart';

/// 모바일 프로토 목 REST 픽스처: `'METHOD /path'` → (status, jsonBody).
///
/// 실흐름(목): mockLogin → 가짜 토큰 저장 → GET /users/me → 세션 복원.
/// 백엔드 모바일 OAuth 딥링크/토큰-바디 refresh 계약은 후속 과제이므로 목으로 대체한다.
/// 값(LEARNER/DONE/BACKEND 등 대문자 enum 와이어 표기)은 web 목 픽스처와 정합한다.
final Map<String, MockFixture> mobileMockFixtures = {
  // 부팅/딥링크 후 세션 복원 — UserSummary(platform-svc /users/me) 형태.
  // 모바일은 홈 대시보드(post-onboarding)가 진입점이므로 onboardingStatus=DONE.
  'GET /users/me': (
    200,
    {
      'id': 'u-mock',
      'email': 'learner@devpath.ai',
      'nickname': '지수',
      'role': 'LEARNER',
      'onboardingStatus': 'DONE',
    },
  ),
  // AuthInterceptor 401 refresh 경로(모바일 토큰-바디 계약, 백엔드 후속).
  'POST /auth/refresh': (
    200,
    {'access_token': 'mock-access-2', 'refresh_token': 'mock-refresh-2'},
  ),
  // 홈 대시보드(DASH-001).
  'GET /dashboard': (
    200,
    {
      'streakDays': 7,
      'progressPercent': 62,
      'nextTaskTitle': '비동기 기초',
      'badges': ['첫 경로', '7일 연속'],
    },
  ),
};
