import 'dart:async';

import 'package:devpath_web/src/app/app_config.dart';
import 'package:devpath_web/src/data/web_mock_fixtures.dart';
import 'package:devpath_web/src/features/content/presentation/content_page.dart';
import 'package:devpath_web/src/features/dashboard/application/current_mission_controller.dart';
import 'package:devpath_web/src/features/mission/presentation/mission_content_route_resolver.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final class _MissionApi extends LearningPathApi {
  _MissionApi(this.response) : super(ApiClient(Dio()));

  final Future<CurrentMission> response;
  var calls = 0;

  @override
  Future<CurrentMission> currentMission() {
    calls += 1;
    return response;
  }
}

final class _ContentSpyClient implements ApiClient {
  var contentGets = 0;

  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? query}) async {
    if (path == '/contents/77') {
      contentGets += 1;
      return mockContent('async-error-handling') as T;
    }
    throw StateError('unexpected GET $path');
  }

  @override
  Future<T> post<T>(String path, {Object? body, Map<String, dynamic>? query}) =>
      throw UnimplementedError();

  @override
  Future<T> put<T>(String path, {Object? body, Map<String, dynamic>? query}) =>
      throw UnimplementedError();

  @override
  Future<T> delete<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) => throw UnimplementedError();

  @override
  Stream<SseEvent> sse(String path, {Object? body}) =>
      throw UnimplementedError();

  @override
  Future<T> postMultipart<T>(
    String path, {
    required List<int> bytes,
    required String filename,
    String field = 'file',
    String? contentType,
  }) => throw UnimplementedError();

  @override
  Dio get dio => throw UnimplementedError();
}

CurrentMission _available({int taskId = 302, int contentId = 77}) {
  final task = <String, Object?>{
    'taskId': taskId,
    'orderNum': 1,
    'taskType': 'READ',
    'title': '에러 처리 패턴 적용',
    'required': true,
    'contentId': contentId,
    'contentSlug': 'async-error-handling',
    'completed': false,
    'completedAt': null,
  };
  return CurrentMission.fromJson({
    'outcome': 'AVAILABLE',
    'pathId': 301,
    'weekNum': 4,
    'tasks': [task],
    'nextTask': task,
    'pathCompleted': false,
  });
}

CurrentMission _outcome(String outcome) => CurrentMission.fromJson(
  outcome == 'NO_ACTIVE_PATH'
      ? {
          'outcome': outcome,
          'pathId': null,
          'weekNum': null,
          'tasks': <Object?>[],
          'nextTask': null,
          'pathCompleted': false,
        }
      : {'outcome': outcome},
);

Future<GoRouter> _pumpRoute(
  WidgetTester tester, {
  required String initialLocation,
  required bool enabled,
  required _MissionApi missionApi,
  required _ContentSpyClient contentClient,
}) async {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/mission/:taskId/content/:contentId',
        builder: (_, state) => MissionContentRouteResolver(
          taskId: state.pathParameters['taskId'],
          contentId: state.pathParameters['contentId'],
        ),
      ),
      GoRoute(path: '/dashboard', builder: (_, _) => const Text('TODAY')),
      GoRoute(path: '/path', builder: (_, _) => const Text('PATH')),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          AppConfig(
            baseUrl: 'https://mock.devpath.ai',
            useMock: true,
            missionSpineEnabled: enabled,
          ),
        ),
        learningPathApiProvider.overrideWithValue(missionApi),
        apiClientProvider.overrideWithValue(contentClient),
        currentMissionOwnerKeyProvider.overrideWithValue('route-user'),
      ],
      child: MaterialApp.router(theme: DpTheme.light(), routerConfig: router),
    ),
  );
  await tester.pump();
  return router;
}

void main() {
  testWidgets(
    'ON direct open은 authoritative mission 응답 전 Content GET을 시작하지 않는다',
    (tester) async {
      final pending = Completer<CurrentMission>();
      final missionApi = _MissionApi(pending.future);
      final contentClient = _ContentSpyClient();

      await _pumpRoute(
        tester,
        initialLocation: '/mission/302/content/77',
        enabled: true,
        missionApi: missionApi,
        contentClient: contentClient,
      );

      expect(missionApi.calls, 1);
      expect(contentClient.contentGets, 0);
      expect(find.byType(ContentPage), findsNothing);

      pending.complete(_available());
      await tester.pump();
      await tester.pump();

      expect(find.byType(ContentPage), findsOneWidget);
      expect(contentClient.contentGets, 1);
    },
  );

  testWidgets('같은 canonical URL reload도 검증 후에만 콘텐츠를 연다', (tester) async {
    for (var reload = 0; reload < 2; reload++) {
      final missionApi = _MissionApi(Future.value(_available()));
      final contentClient = _ContentSpyClient();
      await _pumpRoute(
        tester,
        initialLocation: '/mission/302/content/77',
        enabled: true,
        missionApi: missionApi,
        contentClient: contentClient,
      );
      await tester.pump();
      await tester.pump();

      expect(missionApi.calls, 1);
      expect(contentClient.contentGets, 1);
      expect(find.byType(ContentPage), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('task/content mismatch는 콘텐츠 GET 없이 Today 복구를 제시한다', (
    tester,
  ) async {
    final missionApi = _MissionApi(Future.value(_available(contentId: 78)));
    final contentClient = _ContentSpyClient();
    await _pumpRoute(
      tester,
      initialLocation: '/mission/302/content/77',
      enabled: true,
      missionApi: missionApi,
      contentClient: contentClient,
    );
    await tester.pump();

    expect(contentClient.contentGets, 0);
    expect(find.text('이 미션 링크는 더 이상 현재 미션과 일치하지 않아요'), findsOneWidget);
    expect(find.text('오늘로 돌아가기'), findsOneWidget);
  });

  testWidgets('no-active와 malformed는 콘텐츠 GET 없이 각각 안전한 복구를 제시한다', (
    tester,
  ) async {
    for (final outcome in ['NO_ACTIVE_PATH', 'MALFORMED_PATH']) {
      final missionApi = _MissionApi(Future.value(_outcome(outcome)));
      final contentClient = _ContentSpyClient();
      await _pumpRoute(
        tester,
        initialLocation: '/mission/302/content/77',
        enabled: true,
        missionApi: missionApi,
        contentClient: contentClient,
      );
      await tester.pump();

      expect(contentClient.contentGets, 0);
      expect(
        find.text(outcome == 'NO_ACTIVE_PATH' ? '경로 확인하기' : '오늘로 돌아가기'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('malformed route ID는 API를 하나도 호출하지 않고 복구한다', (tester) async {
    final missionApi = _MissionApi(Future.value(_available()));
    final contentClient = _ContentSpyClient();
    await _pumpRoute(
      tester,
      initialLocation: '/mission/0/content/77',
      enabled: true,
      missionApi: missionApi,
      contentClient: contentClient,
    );

    expect(missionApi.calls, 0);
    expect(contentClient.contentGets, 0);
    expect(find.text('미션 링크가 올바르지 않아요'), findsOneWidget);
  });

  testWidgets('OFF는 current mission 요청 없이 기존 ContentPage 동작을 유지한다', (
    tester,
  ) async {
    final missionApi = _MissionApi(Future.value(_available()));
    final contentClient = _ContentSpyClient();
    await _pumpRoute(
      tester,
      initialLocation: '/mission/302/content/77',
      enabled: false,
      missionApi: missionApi,
      contentClient: contentClient,
    );
    await tester.pump();

    expect(missionApi.calls, 0);
    expect(contentClient.contentGets, 1);
    expect(find.byType(ContentPage), findsOneWidget);
  });
}
