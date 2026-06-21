import 'package:dp_core/dp_core.dart';

/// web 프로토 목 REST 픽스처: `'METHOD /path'` → (status, jsonBody).
/// 실흐름: OAuth 리다이렉트(login()) → 콜백 → POST /auth/refresh → 세션 복원.
/// user.onboardingStatus=PENDING → 게이트가 콜백 부트스트랩 후 온보딩으로 보냄(시연).
/// ※ POST /auth/login은 실흐름에 없으므로 픽스처에서 제거됨(Task 4).
final Map<String, MockFixture> webMockFixtures = {
  // OAuth 콜백 후 세션 복원 엔드포인트.
  // 최상위 필드: snake_case(access_token, refresh_token_cookie_set).
  // user 객체: camelCase(dp_core User.fromJson 기준).
  'POST /auth/refresh': (
    200,
    {
      'access_token': 'mock-access-2',
      'refresh_token_cookie_set': true,
      'user': {
        'id': 'u-mock',
        'email': 'learner@devpath.ai',
        'nickname': '지수',
        'role': 'LEARNER',
        'onboardingStatus': 'PENDING',
      },
    },
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
  'GET /contents/c1': (200, mockContent('future-async-await')),
  'GET /contents/future-async-await': (200, mockContent('future-async-await')),
  'GET /contents/stream-subscription': (
    200,
    mockContent('stream-subscription'),
  ),
  'GET /contents/missing': (
    404,
    {
      'error': {'code': 'RESOURCE_NOT_FOUND', 'message': '콘텐츠가 없어요'},
    },
  ),
  'POST /contents/future-async-await/progress': (
    200,
    {
      'scrollPct': 0.86,
      'dwellSec': 46,
      'completed': true,
      'completedAt': '2026-06-21T10:00:00Z',
    },
  ),
  // 커뮤니티(COM-001) 1페이지 — nextCursor: 'c2'로 "더 보기" 노출
  'GET /community/posts': (
    200,
    {
      'data': [
        {
          'id': 'q1',
          'title': 'async/await가 헷갈려요',
          'author': '지수',
          'answerCount': 2,
        },
        {
          'id': 'q2',
          'title': 'Stream 구독 해제는?',
          'author': '민준',
          'answerCount': 1,
        },
        {
          'id': 'q3',
          'title': 'Riverpod Notifier 패턴',
          'author': '서연',
          'answerCount': 5,
        },
      ],
      'nextCursor': 'c2', // 다음 페이지 있음 → 더 보기 활성
      'limit': 20,
    },
  ),
  // 2페이지 — query-aware 키(P2 Task 10). nextCursor: null로 마지막
  'GET /community/posts?cursor=c2': (
    200,
    {
      'data': [
        {
          'id': 'q4',
          'title': 'FutureProvider vs Notifier',
          'author': '도윤',
          'answerCount': 0,
        },
        {
          'id': 'q5',
          'title': 'go_router 가드 적용',
          'author': '하은',
          'answerCount': 3,
        },
      ],
      'nextCursor': null, // 마지막 페이지
      'limit': 20,
    },
  ),
  // 커뮤니티 Q&A 상세(COM-003)
  'GET /community/posts/q1': (
    200,
    {
      'id': 'q1',
      'title': 'async/await가 헷갈려요',
      'author': '지수',
      'answerCount': 2,
      'body':
          '# 질문\n\n`async/await`에서 예외는 어디서 잡나요?\n\n```dart\ntry { await f(); } catch (e) {}\n```',
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
  // 진단 API(비회원 guest 흐름)
  'POST /onboarding/assessments/guest': (200, {'guestAssessmentId': 'g-mock'}),
  'GET /onboarding/assessments/guest/g-mock/next': (
    200,
    {
      'question': {
        'id': 1,
        'type': 'MCQ',
        'content': '샘플 진단 문항',
        'options': '["A","B"]',
        'bloomLevel': 'UNDERSTAND',
        'difficulty': 0.3,
      },
      'index': 1,
      'total': 15,
    },
  ),
  'POST /onboarding/assessments/guest/g-mock/answer': (
    200,
    <String, dynamic>{},
  ),
  'POST /onboarding/assessments/guest/g-mock/complete': (
    200,
    {'diagnosedLevel': 'MID', 'confidenceWeight': 0.8},
  ),
  // 진단 API(회원 흐름)
  'POST /onboarding/assessments': (200, {'assessmentId': 1}),
  'GET /onboarding/assessments/1/next': (
    200,
    {
      'question': {
        'id': 1,
        'type': 'MCQ',
        'content': '샘플 진단 문항',
        'options': '["A","B"]',
        'bloomLevel': 'UNDERSTAND',
        'difficulty': 0.3,
      },
      'index': 1,
      'total': 15,
    },
  ),
  'POST /onboarding/assessments/1/answer': (200, <String, dynamic>{}),
  'POST /onboarding/assessments/1/complete': (
    200,
    {'diagnosedLevel': 'MID', 'confidenceWeight': 0.8},
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

Map<String, dynamic> mockContent(String slug) {
  final isStream = slug == 'stream-subscription';
  return {
    'id': isStream ? 2 : 1,
    'slug': slug,
    'title': isStream ? 'Stream 구독 실습' : 'Future/async-await 정리',
    'track': 'BACKEND',
    'markdown': isStream
        ? '# Stream 구독 실습\n\n`StreamSubscription`을 저장하고 필요할 때 `cancel()` 합니다.\n'
        : '# 비동기 기초\n\nDart의 `Future`와 `async`/`await`로 비동기 흐름을 다룹니다.\n\n```dart\nFuture<int> answer() async => 42;\n```\n',
    'estimatedMinutes': isStream ? 10 : 8,
    'difficulty': isStream ? 0.6 : 0.5,
    'bloomLevel': isStream ? 'APPLY' : 'UNDERSTAND',
    'conceptTags': isStream
        ? ['stream', 'subscription']
        : ['future', 'async-await'],
    'progress': {
      'scrollPct': 0.2,
      'dwellSec': 12,
      'completed': false,
      'completedAt': null,
    },
  };
}

/// 12주 경로 목 데이터(week1만 과제 3개, 나머지는 제목만).
Map<String, dynamic> mockLearningPath() => {
  'pathId': 101,
  'track': 'BACKEND',
  'totalWeeks': 12,
  'rationale': 'GitHub 분석 결과 비동기·테스트 역량 보강이 필요해 12주 경로를 구성했어요.',
  'diagnosis': {
    'diagnosedLevel': 'MID',
    'strengthConcepts': ['HTTP', '테스트'],
    'weaknessConcepts': ['비동기', '트랜잭션'],
  },
  'milestones': [
    {
      'weekNum': 1,
      'title': '비동기 기초',
      'goalDescription': 'Future와 Stream의 차이를 이해하고 작은 기능에 적용합니다.',
      'targetSkills': ['Future', 'Stream'],
      'estimatedHours': 4,
      'whyThisOrder': '진단에서 비동기 흐름과 테스트 보강이 먼저 필요하다고 나왔어요.',
      'expectedOutcome': '비동기 API 호출과 Stream 구독을 안정적으로 다룰 수 있어요.',
      'locked': false,
      'tasks': [
        {
          'orderNum': 1,
          'taskType': 'READ',
          'title': 'Future/async-await 정리',
          'required': true,
          'contentId': 1,
          'contentSlug': 'future-async-await',
          'completed': false,
        },
        {
          'orderNum': 2,
          'taskType': 'PRACTICE',
          'title': 'Stream 구독 실습',
          'required': true,
          'contentId': 2,
          'contentSlug': 'stream-subscription',
          'completed': false,
        },
        {
          'orderNum': 3,
          'taskType': 'QUIZ',
          'title': '에러 처리 패턴 적용',
          'required': false,
          'contentId': 3,
          'contentSlug': 'async-error-handling',
          'completed': false,
        },
      ],
    },
    for (var w = 2; w <= 12; w++)
      {
        'weekNum': w,
        'title': '주차 $w 학습',
        'goalDescription': '다음 단계 역량을 차근차근 확장합니다.',
        'targetSkills': ['Skill $w'],
        'estimatedHours': 3,
        'whyThisOrder': '1주차 기초 위에 순차적으로 쌓습니다.',
        'expectedOutcome': '주차 $w 핵심 역량을 설명하고 적용할 수 있어요.',
        'locked': true,
        'tasks': <Map<String, dynamic>>[],
      },
  ],
};
