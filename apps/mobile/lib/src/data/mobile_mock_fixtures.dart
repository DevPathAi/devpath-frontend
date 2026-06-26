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
  // 학습 경로(PATH-001 결과) — 학습 뷰어 진입 목록.
  'GET /learning-paths/me': (200, mockLearningPath()),
  // 학습 콘텐츠(CNT-001).
  'GET /contents/future-async-await': (200, mockContent('future-async-await')),
  'GET /contents/stream-subscription': (
    200,
    mockContent('stream-subscription'),
  ),
  'POST /contents/future-async-await/progress': (
    200,
    {
      'scrollPct': 1.0,
      'dwellSec': 60,
      'completed': true,
      'completedAt': '2026-06-27T10:00:00Z',
    },
  ),
  'POST /contents/stream-subscription/progress': (
    200,
    {
      'scrollPct': 1.0,
      'dwellSec': 60,
      'completed': true,
      'completedAt': '2026-06-27T10:00:00Z',
    },
  ),
  // 커뮤니티 Q&A 목록(COM-001) — bare 배열(PostSummaryView).
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
      {
        'id': 2,
        'title': 'Stream 구독 해제는?',
        'authorId': 17,
        'solved': false,
        'upvoteCount': 1,
        'answerCount': 1,
      },
    ],
  ),
  // 퀵 캡처 → 질문 즉시 게시(QuestionDetailView; AI 시드는 비동기라 답변 빈 채 시작).
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

/// 12주 경로 목 데이터(week1만 과제, 나머지는 제목·locked).
Map<String, dynamic> mockLearningPath() => {
  'pathId': 101,
  'track': 'BACKEND',
  'totalWeeks': 12,
  'rationale': '진단 결과 비동기·테스트 역량 보강이 필요해 12주 경로를 구성했어요.',
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
      'whyThisOrder': '진단에서 비동기 흐름 보강이 먼저 필요하다고 나왔어요.',
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
