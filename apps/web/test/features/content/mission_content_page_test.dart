import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:devpath_web/src/analytics/journey_analytics.dart';
import 'package:devpath_web/src/features/ads/data/ads_source.dart';
import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/features/content/application/mission_content_controller.dart';
import 'package:devpath_web/src/features/content/presentation/content_page.dart';
import 'package:devpath_web/src/features/dashboard/application/current_mission_controller.dart';
import 'package:devpath_web/src/features/mission/state/mission_workspace_key.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _workspace = MissionWorkspaceKey(taskId: 31, contentId: 3);

void main() {
  testWidgets('canonical content는 미션 맥락과 단일 실습 행동을 표시한다', (tester) async {
    final analytics = _SpyAnalytics();
    expect(_mission().nextTask?.taskId, 31);
    await tester.pumpWidget(_host(analytics: analytics));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(DpMissionHeader), findsOneWidget);
    expect(find.text('첫 콘텐츠 미션'), findsWidgets);
    expect(find.byType(DpNextActionBand), findsOneWidget);
    expect(find.text('실습 시작'), findsOneWidget);
    expect(find.byKey(const ValueKey('content-practice-action')), findsNothing);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ContentPage)),
    );
    expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
    expect(
      container
          .read(currentMissionControllerProvider)
          .mission
          ?.nextTask
          ?.taskId,
      31,
    );

    await tester.tap(find.text('실습 시작'));
    await tester.pumpAndSettle();
    expect(find.text('canonical sandbox'), findsOneWidget);

    expect(analytics.events, hasLength(1));
    expect(analytics.events.single.$1, 'first_mission_started');
    expect(analytics.events.single.$2, {
      'user_id': '73',
      'path_id': 21,
      'week_num': 1,
      'task_id': 31,
      'first_open': true,
    });
  });

  testWidgets('rebuild는 first_mission_started를 중복 기록하지 않는다', (tester) async {
    final analytics = _SpyAnalytics();
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_host(analytics: analytics));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    tester.platformDispatcher.textScaleFactorTestValue = 1.1;
    await tester.pump();

    expect(
      analytics.events.where((event) => event.$1 == 'first_mission_started'),
      hasLength(1),
    );
  });

  testWidgets('같은 route의 owner 변경은 이전 dwell·scroll을 새 계정에 넘기지 않는다', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final adapter = _SequencedContentAdapter([
      _contentJson(scrollPct: 0.9, dwellSec: 44),
      _contentJson(scrollPct: 0, dwellSec: 0),
    ]);

    await tester.pumpWidget(
      _host(
        analytics: _SpyAnalytics(),
        adapter: adapter,
        authFactory: _SwitchingAuthController.new,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(adapter.contentGets, 1);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ContentPage)),
    );
    (container.read(authControllerProvider.notifier)
            as _SwitchingAuthController)
        .switchTo('74');
    await tester.pump();
    expect(container.read(currentMissionOwnerKeyProvider), '74');
    for (var attempt = 0; attempt < 10 && adapter.contentGets < 2; attempt++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    final missionContentState = container.read(
      missionContentControllerProvider(_workspace),
    );
    expect(missionContentState.ownerKey, '74');
    expect(adapter.contentGets, 2);

    await tester.pump(const Duration(seconds: 1));
    expect(adapter.progressPosts, 0);
  });

  testWidgets('Sandbox가 위에 있는 동안 숨은 Content dwell은 증가하지 않는다', (tester) async {
    final adapter = _SequencedContentAdapter([
      _contentJson(scrollPct: 0.9, dwellSec: 44),
    ], progressCompleted: false);
    await tester.pumpWidget(
      _host(analytics: _SpyAnalytics(), adapter: adapter),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.ensureVisible(find.text('실습 시작'));
    await tester.tap(find.text('실습 시작'));
    await tester.pumpAndSettle();
    expect(find.text('canonical sandbox'), findsOneWidget);
    final postsWhenHidden = adapter.progressPosts;

    await tester.pump(const Duration(seconds: 1));
    expect(adapter.progressPosts, postsWhenHidden);

    GoRouter.of(tester.element(find.text('canonical sandbox'))).pop();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(adapter.progressPosts, greaterThan(postsWhenHidden));
  });

  testWidgets('진행 저장 중에도 최신 dwell을 보존해 후속 요청으로 합친다', (tester) async {
    final adapter = _BlockingProgressAdapter();
    await tester.pumpWidget(
      _host(analytics: _SpyAnalytics(), adapter: adapter),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 10));
    expect(adapter.progressBodies, hasLength(1));

    await tester.pump(const Duration(seconds: 1));
    adapter.completeFirst();
    for (
      var attempt = 0;
      attempt < 10 && adapter.progressBodies.length < 2;
      attempt++
    ) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(adapter.progressBodies, hasLength(2));
    expect(
      adapter.progressBodies[1]['scrollPct'] as num,
      greaterThanOrEqualTo(adapter.progressBodies[0]['scrollPct'] as num),
    );
    expect(
      adapter.progressBodies[1]['dwellSec'] as int,
      greaterThan(adapter.progressBodies[0]['dwellSec'] as int),
    );
  });

  testWidgets('320px·200%에서도 가로 overflow 없이 primary action은 하나다', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(_host(analytics: _SpyAnalytics()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
    for (
      var attempt = 0;
      attempt < 8 && find.byType(DpNextActionBand).evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
    expect(find.byType(DpNextActionBand), findsOneWidget);
    expect(find.text('실습 시작'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

Widget _host({
  required _SpyAnalytics analytics,
  HttpClientAdapter? adapter,
  AuthController Function()? authFactory,
}) {
  final client = ApiClient.create(const ApiConfig(baseUrl: 'https://t/api/v1'));
  client.dio.httpClientAdapter = adapter ?? _ContentAdapter();
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const ContentPage.mission(workspaceKey: _workspace),
      ),
      GoRoute(
        path: '/mission/:taskId/sandbox',
        builder: (_, _) => const Text('canonical sandbox'),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(client),
      authControllerProvider.overrideWith(authFactory ?? _AuthedController.new),
      currentMissionControllerProvider.overrideWith(
        () => _ReadyMissionController(_mission()),
      ),
      journeyAnalyticsProvider.overrideWithValue(analytics),
      adFetchProvider.overrideWithValue((_) async => null),
    ],
    child: MaterialApp.router(theme: DpTheme.light(), routerConfig: router),
  );
}

class _AuthedController extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(
    User(
      id: '73',
      email: 'learner@example.com',
      nickname: '학습자',
      role: UserRole.learner,
      onboardingStatus: OnboardingStatus.done,
      consentStatus: ConsentStatus.done,
    ),
  );
}

class _SwitchingAuthController extends AuthController {
  @override
  AuthState build() => _authenticated('73');

  void switchTo(String userId) => state = _authenticated(userId);
}

AuthState _authenticated(String userId) => AuthAuthenticated(
  User(
    id: userId,
    email: 'learner$userId@example.com',
    nickname: '학습자 $userId',
    role: UserRole.learner,
    onboardingStatus: OnboardingStatus.done,
    consentStatus: ConsentStatus.done,
  ),
);

class _ReadyMissionController extends CurrentMissionController {
  _ReadyMissionController(this.ready);

  final CurrentMission ready;

  @override
  CurrentMissionState build() => CurrentMissionState(mission: ready);

  @override
  Future<CurrentMission?> load({bool force = false}) async => ready;
}

class _SpyAnalytics implements JourneyAnalytics {
  final events = <(String, Map<String, Object?>)>[];

  @override
  AnalyticsCaptureStatus capture(
    String event,
    Map<String, Object?> properties,
  ) {
    events.add((event, Map.unmodifiable(properties)));
    return AnalyticsCaptureStatus.accepted;
  }

  @override
  bool identify(String userId) => true;

  @override
  void reset() {}

  @override
  void setOptedOut(bool optedOut) {}
}

CurrentMission _mission() => CurrentMission.fromJson({
  'outcome': 'AVAILABLE',
  'pathId': 21,
  'weekNum': 1,
  'tasks': [
    {
      'taskId': 31,
      'orderNum': 1,
      'taskType': 'READ',
      'title': '첫 콘텐츠 미션',
      'required': true,
      'contentId': 3,
      'contentSlug': 'content-3',
      'completed': false,
      'completedAt': null,
    },
  ],
  'nextTask': {
    'taskId': 31,
    'orderNum': 1,
    'taskType': 'READ',
    'title': '첫 콘텐츠 미션',
    'required': true,
    'contentId': 3,
    'contentSlug': 'content-3',
    'completed': false,
    'completedAt': null,
  },
  'pathCompleted': false,
});

class _ContentAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({
      'id': 3,
      'slug': 'content-3',
      'title': '미션 콘텐츠',
      'track': 'BACKEND',
      'markdown': '# 첫 콘텐츠 미션\n\n본문',
      'conceptTags': <String>[],
      'progress': {
        'scrollPct': 0.2,
        'dwellSec': 5,
        'completed': false,
        'completedAt': null,
      },
    }),
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

class _SequencedContentAdapter implements HttpClientAdapter {
  _SequencedContentAdapter(this.contents, {this.progressCompleted = true});

  final List<Map<String, dynamic>> contents;
  final bool progressCompleted;
  var contentGets = 0;
  var progressPosts = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = switch (options.method) {
      'GET' => contents[contentGets++],
      'POST' => <String, dynamic>{
        'scrollPct': options.data['scrollPct'],
        'dwellSec': options.data['dwellSec'],
        'completed': progressCompleted,
        'completedAt': progressCompleted ? '2026-08-15T10:00:00Z' : null,
      },
      _ => throw StateError('unexpected ${options.method} ${options.path}'),
    };
    if (options.method == 'POST') progressPosts++;
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _BlockingProgressAdapter implements HttpClientAdapter {
  final _firstProgress = Completer<ResponseBody>();
  final progressBodies = <Map<String, dynamic>>[];

  void completeFirst() {
    _firstProgress.complete(_progressResponse(progressBodies.first));
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'GET') {
      return ResponseBody.fromString(
        jsonEncode(_contentJson(scrollPct: 0.9, dwellSec: 44)),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    if (options.method != 'POST') {
      throw StateError('unexpected ${options.method} ${options.path}');
    }
    progressBodies.add(Map<String, dynamic>.from(options.data as Map));
    if (progressBodies.length == 1) return _firstProgress.future;
    return _progressResponse(progressBodies.last);
  }

  ResponseBody _progressResponse(Map<String, dynamic> request) =>
      ResponseBody.fromString(
        jsonEncode({
          'scrollPct': request['scrollPct'],
          'dwellSec': request['dwellSec'],
          'completed': false,
          'completedAt': null,
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _contentJson({
  required double scrollPct,
  required int dwellSec,
}) => {
  'id': 3,
  'slug': 'content-3',
  'title': '미션 콘텐츠',
  'track': 'BACKEND',
  'markdown': '# 첫 콘텐츠 미션\n\n본문',
  'conceptTags': <String>[],
  'progress': {
    'scrollPct': scrollPct,
    'dwellSec': dwellSec,
    'completed': false,
    'completedAt': null,
  },
};
