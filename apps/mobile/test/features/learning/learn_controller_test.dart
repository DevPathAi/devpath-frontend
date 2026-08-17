import 'dart:async';

import 'package:devpath_mobile/src/features/auth/application/auth_controller.dart';
import 'package:devpath_mobile/src/features/learning/application/learn_controller.dart';
import 'package:devpath_mobile/src/features/learning/state/learn_state.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

import '../../support/mock_api.dart';

final Map<String, MockFixture> _pathFx = {
  'GET /learning-paths/me': (
    200,
    {
      'pathId': 101,
      'track': 'BACKEND',
      'totalWeeks': 12,
      'rationale': 'r',
      'milestones': [
        {
          'weekNum': 1,
          'title': '비동기 기초',
          'goalDescription': 'g',
          'targetSkills': ['Future'],
          'estimatedHours': 4,
          'whyThisOrder': 'w',
          'expectedOutcome': 'o',
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
          ],
        },
      ],
    },
  ),
};

ProviderContainer _container(Map<String, MockFixture> fx) {
  final c = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(mockApiClient(fx)),
      currentOwnerKeyProvider.overrideWithValue('owner-test'),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('LearnController', () {
    test('load 성공 → LearnLoaded(경로)', () async {
      final c = _container(_pathFx);
      await c.read(learnControllerProvider.notifier).load();
      final s = c.read(learnControllerProvider);
      expect(s, isA<LearnLoaded>());
      expect((s as LearnLoaded).path.milestones.first.title, '비동기 기초');
    });

    test('load 실패 → LearnFailed', () async {
      final c = _container(const {});
      await c.read(learnControllerProvider.notifier).load();
      expect(c.read(learnControllerProvider), isA<LearnFailed>());
    });

    test('mounted controller drops late A and automatically loads B', () async {
      final api = _QueuedLearningPathApi();
      final c = ProviderContainer(
        overrides: [
          currentOwnerKeyProvider.overrideWith(
            (ref) => ref.watch(_ownerProvider),
          ),
          learningPathApiProvider.overrideWithValue(api),
        ],
      );
      addTearDown(c.dispose);
      final subscription = c.listen(learnControllerProvider, (_, _) {});
      addTearDown(subscription.close);

      final aLoad = c.read(learnControllerProvider.notifier).load();
      expect(api.requests, hasLength(1));
      c.read(_ownerProvider.notifier).setOwner('owner-b');
      await pumpEventQueue();
      expect(api.requests, hasLength(2));
      expect(c.read(learnControllerProvider), isA<LearnLoading>());

      api.requests[0].complete(_path('A path'));
      await aLoad;
      expect(c.read(learnControllerProvider), isA<LearnLoading>());
      api.requests[1].complete(_path('B path'));
      await pumpEventQueue();
      expect(
        (c.read(learnControllerProvider) as LearnLoaded)
            .path
            .milestones
            .single
            .title,
        'B path',
      );
    });
  });
}

LearningPath _path(String title) => LearningPath.fromJson({
  'pathId': 101,
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

final class _QueuedLearningPathApi extends LearningPathApi {
  _QueuedLearningPathApi() : super(ApiClient(Dio()));

  final requests = <Completer<LearningPath>>[];

  @override
  Future<LearningPath> currentPath() {
    final request = Completer<LearningPath>();
    requests.add(request);
    return request.future;
  }
}

final _ownerProvider = NotifierProvider<_OwnerController, String?>(
  _OwnerController.new,
);

class _OwnerController extends Notifier<String?> {
  @override
  String? build() => 'owner-a';

  void setOwner(String? owner) => state = owner;
}
