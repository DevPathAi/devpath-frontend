import 'package:dp_core/dp_core.dart';

/// web 프로토 목 REST 픽스처: `'METHOD /path'` → (status, jsonBody).
/// 로그인 user.onboardingStatus=PENDING → 게이트가 로그인 후 온보딩으로 보냄(시연).
const Map<String, MockFixture> webMockFixtures = {
  'POST /auth/login': (
    200,
    {
      'accessToken': 'mock-access',
      'refreshToken': 'mock-refresh',
      'user': {
        'id': 'u-mock',
        'email': 'learner@devpath.ai',
        'nickname': '지수',
        'role': 'LEARNER',
        'onboardingStatus': 'PENDING',
      },
    },
  ),
  'POST /auth/refresh': (
    200,
    {'accessToken': 'mock-access-2', 'refreshToken': 'mock-refresh-2'},
  ),
};
