import 'package:devpath_mobile/src/features/learning/presentation/learn_page.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/mock_api.dart';

final Map<String, MockFixture> _fx = {
  'GET /learning-paths/me': (
    200,
    {
      'pathId': 101,
      'track': 'BACKEND',
      'totalWeeks': 12,
      'rationale': '경로 설명',
      'milestones': [
        {
          'weekNum': 1,
          'title': '비동기 기초',
          'goalDescription': 'g',
          'targetSkills': <String>[],
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

void main() {
  testWidgets('학습 경로 로드 → 마일스톤·과제 표시', (tester) async {
    final c = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(mockApiClient(_fx))],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(theme: DpTheme.light(), home: const LearnPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('비동기 기초'), findsOneWidget);
    expect(find.text('Future/async-await 정리'), findsOneWidget);
  });
}
