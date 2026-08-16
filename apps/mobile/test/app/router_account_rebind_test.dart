import 'dart:async';

import 'package:devpath_mobile/src/app/router.dart';
import 'package:devpath_mobile/src/data/key_value_store.dart';
import 'package:devpath_mobile/src/data/owner_data_store.dart';
import 'package:devpath_mobile/src/features/auth/application/auth_controller.dart';
import 'package:devpath_mobile/src/features/auth/state/auth_state.dart';
import 'package:devpath_mobile/src/features/community/data/community_source.dart';
import 'package:devpath_mobile/src/features/community/presentation/community_page.dart';
import 'package:devpath_mobile/src/features/learning/presentation/content_viewer_page.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:devpath_mobile/src/services/connectivity_service.dart';
import 'package:devpath_mobile/src/services/push_service.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('actual router keeps mounted Learn bound to owner B', (
    tester,
  ) async {
    final api = _QueuedLearningApi();
    final container = _container(learningApi: api);
    final router = container.read(routerProvider)..go('/learn');

    await tester.pumpWidget(_host(container, router));
    await _pumpUntil(tester, () => api.requests.length == 1);
    api.requests[0].complete(_path('A path'));
    await _pumpUntil(tester, () => find.text('A path').evaluate().isNotEmpty);

    _auth(container).switchTo(_user('owner-b'));
    await _pumpUntil(tester, () => api.requests.length == 2);
    expect(find.text('A path'), findsNothing);
    api.requests[1].complete(_path('B path'));
    await _pumpUntil(tester, () => find.text('B path').evaluate().isNotEmpty);

    expect(find.text('B path'), findsOneWidget);
    expect(api.requests, hasLength(2));
  });

  testWidgets(
    'actual router rebinds mounted Content and B completion notifier',
    (tester) async {
      final api = _QueuedContentApi();
      final container = _container(contentApi: api);
      final router = container.read(routerProvider)
        ..go('/learn/content/future-async-await');

      await tester.pumpWidget(_host(container, router));
      expect(router.state.matchedLocation, '/learn/content/future-async-await');
      expect(find.byType(ContentViewerPage), findsOneWidget);
      expect(identical(container.read(apiClientProvider), api), isTrue);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 25));
      await _pumpUntil(tester, () => api.getRequests.length == 1);
      api.getRequests[0].complete(_content('A content'));
      await _pumpUntil(
        tester,
        () => find.text('A content').evaluate().isNotEmpty,
      );

      _auth(container).switchTo(_user('owner-b'));
      await _pumpUntil(tester, () => api.getRequests.length == 2);
      expect(find.text('A content'), findsNothing);
      api.getRequests[1].complete(_content('B content'));
      await _pumpUntil(
        tester,
        () => find.text('B content').evaluate().isNotEmpty,
      );

      await tester.tap(find.text('완료로 표시'));
      await _pumpUntil(tester, () => api.postCalls == 1);
      expect(find.text('B content'), findsWidgets);
      expect(api.postCalls, 1);
    },
  );

  testWidgets('actual router keeps mounted Community bound to owner B', (
    tester,
  ) async {
    final requests = <Completer<List<CommunityPostSummary>>>[];
    final container = _container(
      communityList: () {
        final request = Completer<List<CommunityPostSummary>>();
        requests.add(request);
        return request.future;
      },
    );
    final router = container.read(routerProvider)..go('/community');

    await tester.pumpWidget(_host(container, router));
    expect(find.byType(CommunityPage), findsOneWidget);
    await _pumpUntil(tester, () => requests.length == 1);
    requests[0].complete([
      const CommunityPostSummary(id: 1, title: 'A question'),
    ]);
    await _pumpUntil(
      tester,
      () => find.text('A question').evaluate().isNotEmpty,
    );

    _auth(container).switchTo(_user('owner-b'));
    await _pumpUntil(tester, () => requests.length == 2);
    expect(find.text('A question'), findsNothing);
    requests[1].complete([
      const CommunityPostSummary(id: 2, title: 'B question'),
    ]);
    await _pumpUntil(
      tester,
      () => find.text('B question').evaluate().isNotEmpty,
    );

    expect(find.text('B question'), findsOneWidget);
    expect(requests, hasLength(2));
  });
}

ProviderContainer _container({
  LearningPathApi? learningApi,
  ApiClient? contentApi,
  CommunityList? communityList,
}) {
  final container = ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(_HarnessAuthController.new),
      keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
      ownerDataStoreProvider.overrideWithValue(InMemoryOwnerDataStore()),
      pushServiceProvider.overrideWithValue(StubPushService()),
      connectivityProvider.overrideWith((_) => const Stream.empty()),
      if (learningApi != null)
        learningPathApiProvider.overrideWithValue(learningApi),
      if (contentApi != null) apiClientProvider.overrideWithValue(contentApi),
      if (communityList != null)
        communityListProvider.overrideWithValue(communityList),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Widget _host(ProviderContainer container, GoRouter router) =>
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: DpTheme.light(), routerConfig: router),
    );

_HarnessAuthController _auth(ProviderContainer container) =>
    container.read(authControllerProvider.notifier) as _HarnessAuthController;

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 40 && !condition(); i++) {
    await tester.pump(const Duration(milliseconds: 25));
  }
  expect(condition(), isTrue);
}

final class _HarnessAuthController extends AuthController {
  @override
  AuthState build() => AuthAuthenticated(_user('owner-a'));

  void switchTo(User user) => state = AuthAuthenticated(user);
}

User _user(String id) => User(
  id: id,
  email: '$id@example.com',
  nickname: id,
  role: UserRole.learner,
  onboardingStatus: OnboardingStatus.done,
  consentStatus: ConsentStatus.done,
);

LearningPath _path(String title) => LearningPath.fromJson({
  'pathId': 1,
  'track': 'BACKEND',
  'totalWeeks': 1,
  'rationale': 'r',
  'milestones': [
    {
      'weekNum': 1,
      'title': title,
      'goalDescription': 'g',
      'targetSkills': <String>[],
      'estimatedHours': 1,
      'whyThisOrder': 'w',
      'expectedOutcome': 'o',
      'locked': false,
      'tasks': <Map<String, dynamic>>[],
    },
  ],
});

Map<String, dynamic> _content(String title) => {
  'id': 1,
  'slug': 'future-async-await',
  'title': title,
  'track': 'BACKEND',
  'markdown': '# $title',
  'conceptTags': <String>[],
  'progress': {
    'scrollPct': 0.2,
    'dwellSec': 12,
    'completed': false,
    'completedAt': null,
  },
};

final class _QueuedLearningApi extends LearningPathApi {
  _QueuedLearningApi() : super(ApiClient(Dio()));

  final requests = <Completer<LearningPath>>[];

  @override
  Future<LearningPath> currentPath() {
    final request = Completer<LearningPath>();
    requests.add(request);
    return request.future;
  }
}

final class _QueuedContentApi extends ApiClient {
  _QueuedContentApi() : super(Dio());

  final getRequests = <Completer<Map<String, dynamic>>>[];
  var postCalls = 0;

  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? query}) async {
    final request = Completer<Map<String, dynamic>>();
    getRequests.add(request);
    return await request.future as T;
  }

  @override
  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    postCalls += 1;
    return <String, dynamic>{
          'scrollPct': 1.0,
          'dwellSec': 60,
          'completed': true,
          'completedAt': '2026-08-16T00:00:00Z',
        }
        as T;
  }
}
