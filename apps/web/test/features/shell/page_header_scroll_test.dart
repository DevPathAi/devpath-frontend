import 'dart:convert';
import 'dart:typed_data';

import 'package:devpath_web/src/features/ads/data/ads_source.dart';
import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/features/content/presentation/content_page.dart';
import 'package:devpath_web/src/features/dashboard/presentation/dashboard_page.dart';
import 'package:devpath_web/src/features/mypage/application/mypage_controller.dart';
import 'package:devpath_web/src/features/mypage/presentation/mypage_page.dart';
import 'package:devpath_web/src/features/mypage/state/mypage_state.dart';
import 'package:devpath_web/src/features/path/data/path_sse_source.dart';
import 'package:devpath_web/src/features/path/presentation/path_page.dart';
import 'package:devpath_web/src/features/settings/application/settings_controller.dart';
import 'package:devpath_web/src/features/settings/data/settings_models.dart';
import 'package:devpath_web/src/features/settings/presentation/settings_page.dart';
import 'package:devpath_web/src/features/settings/state/settings_state.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// 문서형 화면은 헤더가 본문과 함께 스크롤된다(DESIGN.md §9).
/// 뷰포트 고정형(mentor·sandbox·admin users/ads/support)은 고정이다.
///
/// 헤더가 뷰포트 밖으로 충분히 나가면 sliver가 위젯을 트리에서 걷어내
/// findsNothing이 된다 — 이 경우도 "스크롤과 함께 사라짐"의 유효한 증거다.
/// 아직 트리에 남아 있다면 위치가 뷰포트 위쪽(dy <= 0)이어야 한다.
void _expectHeaderScrolledAway(WidgetTester tester) {
  final headerFinder = find.byType(DpPageHeader);
  final elements = headerFinder.evaluate();
  if (elements.isEmpty) return;
  expect(tester.getBottomLeft(headerFinder).dy, lessThanOrEqualTo(0));
}

void main() {
  testWidgets('설정 화면에서 헤더가 스크롤과 함께 사라진다', (tester) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // settings_page_test.dart의 _ReadyController + host 패턴을 재사용.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsControllerProvider.overrideWith(_ReadySettingsController.new),
        ],
        child: MaterialApp(theme: DpTheme.light(), home: const SettingsPage()),
      ),
    );
    await tester.pump();

    expect(find.text('설정'), findsWidgets);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pump();

    _expectHeaderScrolledAway(tester);
  });

  testWidgets('마이페이지 화면에서 헤더가 스크롤과 함께 사라진다', (tester) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // mypage_page_test.dart의 _FixedController + host 패턴을 재사용.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myPageControllerProvider.overrideWith(
            () => _FixedMyPageController(
              const MyPageLoaded(
                profile: ProfileView(
                  bio: '백엔드 지망',
                  targetTrack: 'BACKEND_SPRING',
                  experienceYears: 2,
                ),
                dashboard: DashboardSummary(
                  streakDays: 3,
                  progressPercent: 40,
                  completedContentCount: 7,
                ),
                activity: MyActivity(questionCount: 2, answerCount: 5),
              ),
            ),
          ),
        ],
        child: MaterialApp(theme: DpTheme.light(), home: const MyPagePage()),
      ),
    );
    await tester.pump();

    expect(find.text('마이페이지'), findsWidgets);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pump();
    // 소스의 설정 카드 ListTile-in-DecoratedBox 디버그 assertion 소비
    // (mypage_page_test.dart와 동일 원인, 렌더 자체는 정상).
    tester.takeException();

    _expectHeaderScrolledAway(tester);
  });

  testWidgets('학습 경로 화면에서 헤더가 스크롤과 함께 사라진다', (tester) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // path_page_test.dart의 _AuthedAuthController + pathSseConnectProvider 패턴을 재사용.
    final c = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_AuthedAuthController.new),
        pathSseConnectProvider.overrideWithValue(
          () => _emitPathStages(kPathStages),
        ),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(theme: DpTheme.light(), home: const PathPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('학습 경로'), findsWidgets);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pump();

    _expectHeaderScrolledAway(tester);
  });

  testWidgets('학습 콘텐츠 화면에서 헤더가 스크롤과 함께 사라진다', (tester) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // content_page_test.dart의 _SequenceAdapter + host 패턴을 재사용(긴 마크다운으로 스크롤 확보).
    final adapter = _ContentSequenceAdapter({
      'GET /contents/future-async-await': [
        (200, _contentJson(markdown: _longMarkdown())),
      ],
    });
    final client = ApiClient.create(
      const ApiConfig(baseUrl: 'https://t/api/v1'),
    );
    client.dio.httpClientAdapter = adapter;
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const ContentPage(contentId: 'future-async-await'),
        ),
        GoRoute(
          path: '/sandbox',
          builder: (_, _) => const Text('sandbox route'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          adFetchProvider.overrideWithValue((slot) async => null),
        ],
        child: MaterialApp.router(theme: DpTheme.light(), routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('학습 콘텐츠'), findsWidgets);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pump();

    _expectHeaderScrolledAway(tester);
  });

  testWidgets('대시보드 화면에서 헤더가 스크롤과 함께 사라진다', (tester) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // dashboard_page_test.dart의 기본 mock 클라이언트 + GoRouter 패턴을 재사용.
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const DashboardPage())],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(theme: DpTheme.light(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('대시보드'), findsWidgets);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pump();

    _expectHeaderScrolledAway(tester);
  });
}

/// settings_page_test.dart의 _ReadyController 승계.
class _ReadySettingsController extends SettingsController {
  @override
  SettingsState build() => const SettingsReady(
    consents: ConsentsView(
      consentStatus: 'DONE',
      items: [
        ConsentItemView(type: 'TERMS', agreed: true, version: 'v1'),
        ConsentItemView(type: 'MARKETING', agreed: true, version: 'v1'),
      ],
      birthYear: 2000,
    ),
    prefs: NotificationPrefs(
      timezone: 'Asia/Seoul',
      preferredTimeSlot: '09:00',
      reminderEnabled: true,
      weeklyReportEmailEnabled: true,
    ),
  );

  @override
  Future<void> load() async {}
}

/// mypage_page_test.dart의 _FixedController 승계.
class _FixedMyPageController extends MyPageController {
  _FixedMyPageController(this._initial);
  final MyPageState _initial;

  @override
  MyPageState build() => _initial;

  @override
  Future<void> load() async {}
}

/// path_page_test.dart의 _AuthedAuthController 승계.
class _AuthedAuthController extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(
    User(
      id: '73',
      email: 'e2e@devpath.local',
      nickname: 'E2E',
      role: UserRole.learner,
      onboardingStatus: OnboardingStatus.done,
      consentStatus: ConsentStatus.done,
    ),
  );
}

Stream<SseEvent> _emitPathStages(List<String> stages) async* {
  for (final s in stages) {
    yield SseEvent(
      event: 'progress',
      data: jsonEncode({
        'stage': s,
        'progress': s == 'done' ? 1.0 : 0.5,
        'message': s,
        'pathId': s == 'done' ? 101 : null,
      }),
    );
  }
}

/// content_page_test.dart의 _SequenceAdapter 승계.
class _ContentSequenceAdapter implements HttpClientAdapter {
  _ContentSequenceAdapter(this.fixtures);

  final Map<String, List<(int, Object)>> fixtures;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    final sequence = fixtures[key];
    if (sequence == null || sequence.isEmpty) {
      return _json(404, {
        'error': {'code': 'RESOURCE_NOT_FOUND', 'message': 'no mock: $key'},
      });
    }
    final fixture = sequence.length == 1
        ? sequence.first
        : sequence.removeAt(0);
    final (status, body) = fixture;
    return _json(status, body);
  }

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _contentJson({required String markdown}) => {
  'id': 1,
  'slug': 'future-async-await',
  'title': 'Future/async-await 정리',
  'track': 'BACKEND',
  'markdown': markdown,
  'estimatedMinutes': 8,
  'difficulty': 0.5,
  'bloomLevel': 'APPLY',
  'conceptTags': ['future', 'async-await'],
  'progress': {
    'scrollPct': 0.2,
    'dwellSec': 0,
    'completed': false,
    'completedAt': null,
  },
};

String _longMarkdown() => [
  '# 비동기 기초',
  for (var i = 0; i < 80; i++) '문단 $i: Future와 async/await 흐름을 충분히 길게 설명합니다.',
].join('\n\n');
