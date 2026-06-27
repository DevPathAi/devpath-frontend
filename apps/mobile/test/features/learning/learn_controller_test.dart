import 'package:devpath_mobile/src/features/learning/application/learn_controller.dart';
import 'package:devpath_mobile/src/features/learning/state/learn_state.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
    overrides: [apiClientProvider.overrideWithValue(mockApiClient(fx))],
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
  });
}
