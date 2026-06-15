import 'package:dp_core/dp_core.dart';

/// web 프로토 목 REST 픽스처: `'METHOD /path'` → (status, jsonBody).
/// 로그인 user.onboardingStatus=PENDING → 게이트가 로그인 후 온보딩으로 보냄(시연).
final Map<String, MockFixture> webMockFixtures = {
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
  // 진단 제출 → DONE 유저 반환(게이트 해제)
  'POST /onboarding': (
    200,
    {
      'user': {
        'id': 'u-mock',
        'email': 'learner@devpath.ai',
        'nickname': '지수',
        'role': 'LEARNER',
        'onboardingStatus': 'DONE',
      },
    },
  ),
  // PATH 생성 완료 후 결과 조회(스펙 §3 비동기 결과 조회 패턴)
  'GET /learning-paths/me': (200, mockLearningPath()),
  // 학습 콘텐츠 조회(CNT-001)
  'GET /contents/c1': (
    200,
    {
      'markdown':
          '# 비동기 기초\n\nDart의 `Future`와 `async`/`await`로 비동기 흐름을 다룹니다.\n\n```dart\nFuture<int> answer() async => 42;\n```\n',
    },
  ),
  // 대시보드(DASH-001)
  'GET /dashboard': (
    200,
    {
      'streakDays': 7,
      'progressPercent': 62,
      'nextTaskTitle': '비동기 기초',
      'badges': ['첫 경로', '7일 연속'],
    },
  ),
  // AI 코드리뷰(REV-001)
  'POST /reviews': (
    200,
    {
      'confidence': 78,
      'strengths': ['main 함수가 간결합니다.', 'print 사용이 적절합니다.'],
      'improvements': [
        {'line': 2, 'severity': 'warning', 'message': '예외 처리를 추가하세요.'},
        {'line': 1, 'severity': 'info', 'message': '함수에 문서 주석을 권장합니다.'},
      ],
      'security': [
        {'severity': 'info', 'message': '외부 입력이 없어 위험이 낮습니다.'},
      ],
    },
  ),
};

/// 12주 경로 목 데이터(week1만 과제 3개, 나머지는 제목만).
Map<String, dynamic> mockLearningPath() => {
  'rationale': 'GitHub 분석 결과 비동기·테스트 역량 보강이 필요해 12주 경로를 구성했어요.',
  'weeks': [
    {
      'week': 1,
      'title': '비동기 기초',
      'tasks': [
        {'title': 'Future/async-await 정리', 'done': false},
        {'title': 'Stream 구독 실습', 'done': false},
        {'title': '에러 처리 패턴 적용', 'done': false},
      ],
    },
    for (var w = 2; w <= 12; w++)
      {'week': w, 'title': '주차 $w 학습', 'tasks': <Map<String, dynamic>>[]},
  ],
};
