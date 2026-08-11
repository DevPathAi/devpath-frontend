import 'package:dp_core/dp_core.dart';

/// web 프로토 목 REST 픽스처: `'METHOD /path'` → (status, jsonBody).
/// 실흐름: OAuth 리다이렉트(login()) → 콜백 → POST /auth/refresh → 세션 복원.
/// user.onboardingStatus=PENDING → 게이트가 콜백 부트스트랩 후 온보딩으로 보냄(시연).
/// ※ POST /auth/login은 실흐름에 없으므로 픽스처에서 제거됨(Task 4).
final Map<String, MockFixture> webMockFixtures = {
  // ④ 오류 신고·문의 접수. 목 모드 기본값이 true 라 이 픽스처가 없으면 제보가 404로 실패한다.
  'POST /support/requests': (201, {'id': 42}),
  // 2026-08-03: 아래 셋이 없어 설정·마이페이지·학습 콘텐츠가 에러 화면으로 떴다.
  // GET /consents/me — ConsentsView.fromJson(settings_models.dart:13).
  // item.type 은 settings_page.dart 의 _consentMeta 키(TERMS/PRIVACY/MARKETING/
  // LCS_ATTACH/ERROR_LOG)와 대조해 조회된다(itemOf). 목록에 없는 타입은 그냥
  // 미동의(agreed=false)로 표시될 뿐 화면이 깨지지는 않는다.
  'GET /consents/me': (
    200,
    {
      'consentStatus': 'DONE',
      'birthYear': 1998,
      'items': [
        {
          'type': 'TERMS',
          'agreed': true,
          'version': '1.0',
          'agreedAt': '2026-07-01T09:00:00Z',
        },
        {
          'type': 'PRIVACY',
          'agreed': true,
          'version': '1.0',
          'agreedAt': '2026-07-01T09:00:00Z',
        },
        {
          'type': 'MARKETING',
          'agreed': false,
          'version': '1.0',
          'agreedAt': null,
        },
      ],
    },
  ),
  // GET /users/me/profile — ProfileView(profile_view.g.dart:9), 전부 nullable.
  // learningGoal/targetTrack 값은 mypage_page.dart 의 _goals/_tracks 드롭다운
  // 목록에 실제로 존재하는 항목으로 맞췄다(목록에 없으면 화면이 null로 되돌려
  // 드롭다운이 빈 채로 보인다 — 크래시는 아니지만 프로필 값이 반영 안 되어 보임).
  'GET /users/me/profile': (
    200,
    {
      'avatar': null,
      'bio': '백엔드로 전향 중입니다.',
      'learningGoal': 'CAREER_CHANGE',
      'targetTrack': 'BACKEND_SPRING',
      'experienceYears': 2,
    },
  ),
  // PUT /users/me/profile — mypage_source.dart:35(myProfileUpdateProvider),
  // 마이페이지 "저장" 버튼이 호출한다. 없으면 저장 시 ApiException으로
  // "저장 실패" 스낵바가 뜬다. 응답은 ProfileView.fromJson과 같은 형태
  // (전부 nullable)이며, 편집 폼 기본 선택값과 맞췄다.
  'PUT /users/me/profile': (
    200,
    {
      'avatar': null,
      'bio': '백엔드로 전향 중입니다.',
      'learningGoal': 'CAREER_CHANGE',
      'targetTrack': 'BACKEND_SPRING',
      'experienceYears': 2,
    },
  ),
  // POST /contents/c1/progress — ContentProgressUpdateResponse.fromJson은
  // scrollPct(double)·dwellSec(int)를 nullable 아닌 필수 필드로 읽는다
  // (learning_content.g.dart: `json['scrollPct'] as num`). {'ok': true}만
  // 주면 파싱 시 널체크 예외로 콘텐츠 화면이 깨지므로, 기존
  // POST /contents/future-async-await/progress 픽스처와 같은 형태로 채운다.
  'POST /contents/c1/progress': (
    200,
    {
      'scrollPct': 0.86,
      'dwellSec': 46,
      'completed': true,
      'completedAt': '2026-06-21T10:00:00Z',
    },
  ),
  // GET /notifications/prefs/me — NotificationPrefs.fromJson(settings_models.dart:68),
  // settings_source.dart:23(fetchPrefs)이 호출한다. settings_controller.load()가
  // fetchConsents()·fetchPrefs()를 한 try 블록에서 순차 호출하므로(부분 실패
  // 관용 없음), 이 픽스처가 없으면 GET /consents/me가 있어도 fetchPrefs()가
  // ApiException을 던져 설정 화면이 여전히 SettingsError로 뜬다(2026-08-03
  // 재점검에서 발견).
  // 필드는 전부 String?/bool? + 기본값(fromJson 내부 `?? ...`)이라 값이
  // 없어도 크래시는 없지만, settings_page.dart의 두 SwitchListTile(학습
  // 리마인더·주간 리포트 이메일)이 실제 값을 보여주도록 채운다.
  'GET /notifications/prefs/me': (
    200,
    {
      'timezone': 'Asia/Seoul',
      'preferredTimeSlot': '09:00',
      'reminderEnabled': true,
      'weeklyReportEmailEnabled': true,
    },
  ),
  // PUT /notifications/prefs/me — settings_source.dart:28(updatePrefs), 알림 토글
  // (학습 리마인더·주간 리포트 이메일)이 낙관적 반영 후 이 호출로 확정한다.
  // 목 모드에서 이 픽스처가 없으면 토글은 화면에 즉시 반영되는 것처럼 보이다가
  // ApiException으로 이전 값에 조용히 롤백된다. NotificationPrefs.fromJson과
  // 같은 형태(4필드 전체)로 응답한다.
  'PUT /notifications/prefs/me': (
    200,
    {
      'timezone': 'Asia/Seoul',
      'preferredTimeSlot': '09:00',
      'reminderEnabled': true,
      'weeklyReportEmailEnabled': true,
    },
  ),
  // POST /consents/{type}/revoke — settings_source.dart:37(revokeConsent).
  // MockHttpAdapter는 와일드카드 없이 'METHOD /path' 정확 일치만 지원하므로
  // {type} 자리에 실제로 호출되는 값(MARKETING, GET /consents/me 픽스처에 있는
  // 선택 동의 항목)을 그대로 키에 박아야 한다. 성공 시 컨트롤러가 load()로
  // 재조회하므로 본문은 비워도 된다.
  'POST /consents/MARKETING/revoke': (200, <String, dynamic>{}),
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
        'consentStatus': 'DONE',
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
  // mockLearningPath()의 1주차 3번째 과제(퀴즈, contentSlug='async-error-handling')가
  // 가리키는 콘텐츠. 이 픽스처가 없으면 "이번 주 과제" 목록에서 해당 항목을
  // 누를 때 GET /contents/async-error-handling이 404로 떨어진다.
  'GET /contents/async-error-handling': (
    200,
    mockContent('async-error-handling'),
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
  'POST /contents/async-error-handling/progress': (
    200,
    {
      'scrollPct': 0.86,
      'dwellSec': 46,
      'completed': true,
      'completedAt': '2026-06-21T10:00:00Z',
    },
  ),
  // 커뮤니티 통합 피드(COM-001) — 실계약: bare 배열(PostSummaryView), 페이지네이션 없음.
  // 전 보드(QNA/FREE/FEEDBACK) 혼합. boardType·replyCount(QNA=답변/일반=댓글) 포함.
  'GET /community/posts': (
    200,
    [
      {
        'id': 1,
        'boardType': 'QNA',
        'title': 'async/await가 헷갈려요',
        'authorId': 42,
        'solved': true,
        'upvoteCount': 3,
        'replyCount': 2,
        'excerpt':
            'async/await는 Future를 순차적으로 다루는 문법입니다. 이벤트 루프와 마이크로태스크 큐를 이해하면 동작이 또렷해져요…',
      },
      {
        'id': 10,
        'boardType': 'FREE',
        'title': '오늘 배운 것 공유',
        'authorId': 8,
        'solved': false,
        'upvoteCount': 5,
        'replyCount': 4,
        'excerpt':
            '오늘은 Riverpod의 Notifier와 AsyncNotifier 차이를 정리했습니다. 상태 복원과 자동 폐기(autoDispose)까지…',
      },
      {
        'id': 20,
        'boardType': 'FEEDBACK',
        'title': '제 코드 리뷰 부탁해요',
        'authorId': 17,
        'solved': false,
        'upvoteCount': 1,
        'replyCount': 1,
        'excerpt': '로그인 폼 검증 로직 리뷰 부탁드립니다. 특히 IME 전각 처리와 디바운스 부분이 고민입니다.',
      },
    ],
  ),
  // 일반 게시글(FREE) 상세 — PostDetailView(댓글 스레드).
  'GET /community/posts/10': (
    200,
    {
      'id': 10,
      'boardType': 'FREE',
      'title': '오늘 배운 것 공유',
      'bodyMd': '# 공유\n\n오늘 `Riverpod`을 배웠어요.',
      'authorId': 8,
      'upvoteCount': 5,
      'downvoteCount': 0,
      'tags': ['riverpod'],
      'comments': [
        {
          'id': 100,
          'authorId': 42,
          'bodyMd': '좋은 정리네요!',
          'upvoteCount': 0,
          'createdAt': '2026-07-29T00:00:00Z',
        },
      ],
    },
  ),
  'POST /community/posts/10/comments': (
    201,
    {
      'id': 101,
      'authorId': 1,
      'bodyMd': '새 댓글',
      'upvoteCount': 0,
      'createdAt': '2026-07-29T01:00:00Z',
    },
  ),
  'POST /community/posts/10/vote': (200, <String, dynamic>{}),
  // 일반 게시글 작성(FREE/FEEDBACK) → PostDetailView.
  'POST /community/posts': (
    201,
    {
      'id': 30,
      'boardType': 'FREE',
      'title': '새 자유글',
      'bodyMd': '본문',
      'authorId': 1,
      'upvoteCount': 0,
      'downvoteCount': 0,
      'tags': <String>[],
      'comments': <Map<String, dynamic>>[],
    },
  ),
  // 커뮤니티 Q&A 상세(COM-003) — QuestionDetailView(인간/AI 답변 스레드).
  'GET /community/questions/1': (
    200,
    {
      'id': 1,
      'title': 'async/await가 헷갈려요',
      'bodyMd':
          '# 질문\n\n`async/await`에서 예외는 어디서 잡나요?\n\n```dart\ntry { await f(); } catch (e) {}\n```',
      'solved': true,
      'acceptedAnswerId': 11,
      'upvoteCount': 3,
      'downvoteCount': 0,
      'tags': ['dart', 'async'],
      'answers': [
        {
          'id': 10,
          'authorId': null,
          'bodyMd': 'try/catch로 await 호출을 감싸면 됩니다. (AI 시드 초안)',
          'aiGenerated': true,
          'accepted': false,
          'upvoteCount': 1,
        },
        {
          'id': 11,
          'authorId': 7,
          'bodyMd': '저는 `Future.catchError`도 함께 씁니다.',
          'aiGenerated': false,
          'accepted': true,
          'upvoteCount': 4,
        },
      ],
    },
  ),
  // 질문 작성 → 즉시 게시(QuestionDetailView; AI 시드는 비동기라 답변 빈 채로 시작).
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
  // 인간 답변 작성(AnswerView).
  'POST /community/questions/1/answers': (
    201,
    {
      'id': 12,
      'authorId': 7,
      'bodyMd': '새 답변',
      'aiGenerated': false,
      'accepted': false,
      'upvoteCount': 0,
    },
  ),
  // 채택/투표 — void(200, 빈 본문).
  'POST /community/answers/11/accept': (200, <String, dynamic>{}),
  'POST /community/posts/1/vote': (200, <String, dynamic>{}),
  'POST /community/answers/11/vote': (200, <String, dynamic>{}),
  // 유사질문(폴백 키 — q 무관). 중복 안내용 top-K.
  'GET /community/questions/similar': (
    200,
    [
      {'questionId': 2, 'title': 'Stream 구독 해제는?'},
    ],
  ),
  // 태그 자동완성(폴백 키).
  'GET /community/tags': (
    200,
    [
      {'id': 1, 'name': 'dart', 'postCount': 12},
      {'id': 2, 'name': 'async', 'postCount': 8},
    ],
  ),
  // 신고 접수(폴백 키). 목 프로토에서는 항상 성공한다 — 409/400 분기는 위젯 테스트가 덮는다.
  'POST /community/reports': (201, {'id': 1, 'status': 'OPEN'}),
  // 검색(폴백 키 — q·페이지 무관). total > items.length 라 "더 보기"가 노출되는 상태다.
  // 두 번째 항목은 본문 매칭이 없어 highlight 가 비는 경우(→ excerpt 폴백)를 재현한다.
  'GET /community/search': (
    200,
    {
      'items': [
        {
          'id': 1,
          'title': 'async/await가 헷갈려요',
          'boardType': 'QNA',
          'authorId': 1,
          'solved': false,
          'upvoteCount': 3,
          'replyCount': 2,
          'excerpt': 'async/await에서 예외는 어디서 잡나요?',
          'highlight': 'async/await에서 <em>예외</em>는 어디서 잡나요?',
        },
        {
          'id': 10,
          'title': '배포 자동화 팁 공유',
          'boardType': 'FREE',
          'authorId': 2,
          'solved': false,
          'upvoteCount': 5,
          'replyCount': 1,
          'excerpt': 'GitHub Actions로 배포를 자동화했습니다.',
          'highlight': '',
        },
      ],
      'total': 3,
      'page': 0,
      'size': 20,
    },
  ),
  // LCS(학습 맥락 자동 첨부) — gateway /lcs/** → lcs-svc(슬라이스 #9).
  // draft 미리보기(작성 폼 맥락 카드). draftId=snap_mock → commit 키와 매칭.
  'POST /lcs/snapshots/draft': (
    200,
    {
      'draftId': 'snap_mock',
      'expiresAt': '2026-06-26T23:59:00Z',
      'content': {
        'recent_activity': [
          {'language': 'dart', 'status': 'SUCCESS'},
        ],
      },
      'fieldsAvailable': ['recent_activity'],
      'fieldsUnavailable': [
        {'field': 'current_content', 'reason': 'no_content_context'},
        {'field': 'current_path', 'reason': 'phase2_deferred'},
      ],
    },
  ),
  // commit(불변 영속) — 게시 후 questionId 로 호출.
  'POST /lcs/snapshots/snap_mock/commit': (
    201,
    {'snapshotId': 7, 'status': 'committed', 'immutable': true},
  ),
  // 답변자 맥락 패널 역조회(question 1 만 스냅샷 보유; 그 외는 404→패널 미표시).
  'GET /lcs/snapshots/by-question/1': (
    200,
    {
      'id': 7,
      'createdAt': '2026-06-26T10:00:00Z',
      'content': {
        'current_content': {
          'contentId': 1,
          'title': '비동기 기초',
          'track': 'BACKEND',
        },
        'recent_activity': [
          {'language': 'dart', 'status': 'SUCCESS'},
        ],
      },
      'renderedFor': 'answerer',
    },
  ),
  // 대시보드(DASH-001) — 백엔드 GET /dashboard/me (DashboardController @GetMapping("/me"))
  'GET /dashboard/me': (
    200,
    {
      'streakDays': 7,
      'progressPercent': 62,
      'nextTaskTitle': '비동기 기초',
      'badges': ['첫 경로', '7일 연속'],
      'weeklyActivity': [
        {'date': '2026-07-25', 'completedCount': 0},
        {'date': '2026-07-26', 'completedCount': 2},
        {'date': '2026-07-27', 'completedCount': 1},
        {'date': '2026-07-28', 'completedCount': 3},
        {'date': '2026-07-29', 'completedCount': 0},
        {'date': '2026-07-30', 'completedCount': 2},
        {'date': '2026-07-31', 'completedCount': 4},
      ],
      // byType은 백엔드가 실제로 보내는 필드다(learning-svc ProgressPoint).
      // 유형마다 값이 갈려 있어야 목 모드에서도 3계열 추세가 그대로 보인다 —
      // 한 유형만 넣으면 「계열이 1개인 화면」을 정상이라고 오판하게 된다.
      'progressHistory': [
        {
          'date': '2026-07-28',
          'percent': 40,
          'byType': {'READ': 55, 'PRACTICE': 28, 'QUIZ': 20},
        },
        {
          'date': '2026-07-29',
          'percent': 48,
          'byType': {'READ': 62, 'PRACTICE': 35, 'QUIZ': 30},
        },
        {
          'date': '2026-07-30',
          'percent': 55,
          'byType': {'READ': 70, 'PRACTICE': 42, 'QUIZ': 38},
        },
        {
          'date': '2026-07-31',
          'percent': 62,
          'byType': {'READ': 80, 'PRACTICE': 48, 'QUIZ': 45},
        },
      ],
    },
  ),
  // 진단 API(비회원 guest 흐름)
  // ⚠️ next 는 고정 픽스처가 아니라 webMockSequences 에 있다 — 같은 문항이 반복되면
  //    완료로 넘어가지 못하기 때문이다(파일 하단 주석 참고).
  'POST /onboarding/assessments/guest': (200, {'guestAssessmentId': 'g-mock'}),
  'POST /onboarding/assessments/guest/g-mock/answer': (
    200,
    <String, dynamic>{},
  ),
  'POST /onboarding/assessments/guest/g-mock/complete': (
    200,
    {'diagnosedLevel': 'MID', 'confidenceWeight': 0.8},
  ),
  // 진단 API(회원 흐름) — next 는 webMockSequences 참고.
  'POST /onboarding/assessments': (200, {'assessmentId': 1}),
  'POST /onboarding/assessments/1/answer': (200, <String, dynamic>{}),
  'POST /onboarding/assessments/1/complete': (
    200,
    {'diagnosedLevel': 'MID', 'confidenceWeight': 0.8},
  ),
  // 2026-08-03: assessment_api.dart의 회원 경로 중 claim()·result()가 누락돼
  // 있었다 — 게스트로 진단을 시작한 뒤 로그인하면 diagnostic_controller.dart의
  // claimAfterLogin()이 이 둘을 순서대로 호출한다(claim → assessmentId 확보 →
  // result 조회; complete()는 이미 COMPLETED라 부르지 않는다). 없으면 그 흐름만
  // 404로 끊긴다. AssessmentResult.fromJson과 같은 형태로 응답한다.
  'POST /onboarding/assessments/claim': (200, {'assessmentId': 1}),
  'GET /onboarding/assessments/1/result': (
    200,
    {'diagnosedLevel': 'MID', 'confidenceWeight': 0.8},
  ),
  // AI 코드리뷰(REV-001) — 폴링 GET /reviews?sandboxSessionId={id}(F6-e 빌드 E).
  // MockHttpAdapter query-aware: 키 정렬 → 'GET /reviews?sandboxSessionId=1'
  'GET /reviews?sandboxSessionId=1': (
    200,
    {
      'status': 'DONE',
      'confidence': 82,
      'strengths': ['목 리뷰: 코드가 간결합니다.'],
      'improvements': <Map<String, dynamic>>[],
      'security': <Map<String, dynamic>>[],
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
        // 앞의 둘을 완료로 둬 진행률이 0이 아니게 한다. 12주가 전부 0%면
        // 주차별 진행률 막대가 하나도 그려지지 않아 화면으로 확인할 수 없다
        // (3-B 보고서 §6). 마지막 퀴즈는 미완료로 남긴다 — 「이번 주 과제」에서
        // 눌러 콘텐츠로 이동하는 시나리오가 거기 걸려 있다.
        {
          'orderNum': 1,
          'taskType': 'READ',
          'title': 'Future/async-await 정리',
          'required': true,
          'contentId': 1,
          'contentSlug': 'future-async-await',
          'completed': true,
        },
        {
          'orderNum': 2,
          'taskType': 'PRACTICE',
          'title': 'Stream 구독 실습',
          'required': true,
          'contentId': 2,
          'contentSlug': 'stream-subscription',
          'completed': true,
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

/// 호출 순서에 따라 응답이 달라져야 하는 목 엔드포인트.
///
/// **왜 필요한가.** `AssessmentApi.next` 는 응답 본문이 null 일 때만 null 을 돌려주고,
/// `DiagnosticController._advance()` 는 그때만 `complete()` 로 넘어간다. 고정 픽스처는
/// 키 하나에 응답 하나라 "문항 → 문항 → 없음" 을 표현할 수 없어, 같은 문항이 무한
/// 반복되고 진단이 **완주하지 못했다**(2026-08-03 사용자 실측으로 발견. 게스트 흐름도
/// 같은 한계였다).
///
/// 목록이 소진되면 마지막 항목을 계속 돌려주므로, 마지막을 `(200, null)` 로 두면
/// 완료 상태가 유지된다.
final Map<String, MockSequence> webMockSequences = {
  // 게스트: 문항 2개 → 종료
  'GET /onboarding/assessments/guest/g-mock/next': [
    (200, _question(1, '비동기 함수의 반환 타입은 무엇인가요?', 1, 2)),
    (200, _question(2, 'Stream 구독을 해제하지 않으면 어떤 문제가 생기나요?', 2, 2)),
    (200, null),
  ],
  // 회원: 문항 2개 → 종료
  'GET /onboarding/assessments/1/next': [
    (200, _question(1, '비동기 함수의 반환 타입은 무엇인가요?', 1, 2)),
    (200, _question(2, 'Stream 구독을 해제하지 않으면 어떤 문제가 생기나요?', 2, 2)),
    (200, null),
  ],
};

/// NextQuestion.fromJson 계약에 맞춘 문항 한 건.
Map<String, dynamic> _question(int id, String content, int index, int total) =>
    {
      'question': {
        'id': id,
        'type': 'MCQ',
        'content': content,
        'options': '["A","B"]',
        'bloomLevel': 'UNDERSTAND',
        'difficulty': 0.3,
      },
      'index': index,
      'total': total,
    };
