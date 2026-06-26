import 'package:devpath_mobile/src/features/onboarding/application/onboarding_controller.dart';
import 'package:devpath_mobile/src/features/onboarding/presentation/onboarding_page.dart';
import 'package:devpath_mobile/src/features/onboarding/state/onboarding_state.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/mock_api.dart';

final Map<String, MockFixture> _ok = {
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
};

Widget _host(ProviderContainer c) => UncontrolledProviderScope(
  container: c,
  child: MaterialApp(theme: DpTheme.light(), home: const OnboardingPage()),
);

ProviderContainer _container(Map<String, MockFixture> fx) {
  final c = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(mockApiClient(fx)),
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  testWidgets('GitHub 핸들 폼 렌더', (tester) async {
    final c = _container(_ok);
    await tester.pumpWidget(_host(c));
    await tester.pump();

    expect(find.text('GitHub 핸들'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('핸들 입력 + 제출 성공 → OnboardingDone', (tester) async {
    final c = _container(_ok);
    await tester.pumpWidget(_host(c));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'jisoo-dev');
    await tester.tap(find.text('진단 시작하기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(c.read(onboardingControllerProvider), isA<OnboardingDone>());
  });

  testWidgets('제출 실패 → 에러 메시지 표시', (tester) async {
    final c = _container(const {});
    await tester.pumpWidget(_host(c));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'x');
    await tester.tap(find.text('진단 시작하기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(c.read(onboardingControllerProvider), isA<OnboardingError>());
  });
}
