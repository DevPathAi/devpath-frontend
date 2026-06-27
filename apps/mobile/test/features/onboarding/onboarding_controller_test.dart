import 'package:devpath_mobile/src/features/onboarding/application/onboarding_controller.dart';
import 'package:devpath_mobile/src/features/onboarding/state/onboarding_state.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
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

ProviderContainer _container(Map<String, MockFixture> fx) {
  final c = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(mockApiClient(fx)),
      // submit 성공 시 authController가 활성화되며 bootstrap이 토큰 저장소를 읽으므로
      // 실 secure_storage 대신 InMemory로 대체(미인증 경로 → 플러그인 호출 회피).
      tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('OnboardingController', () {
    test('초기 상태는 Idle', () {
      final c = _container(_ok);
      expect(c.read(onboardingControllerProvider), isA<OnboardingIdle>());
    });

    test('submit 성공 → OnboardingDone', () async {
      final c = _container(_ok);
      await c
          .read(onboardingControllerProvider.notifier)
          .submit(githubHandle: 'jisoo-dev');
      expect(c.read(onboardingControllerProvider), isA<OnboardingDone>());
    });

    test('submit 실패(POST 픽스처 없음) → OnboardingError', () async {
      final c = _container(const {});
      await c
          .read(onboardingControllerProvider.notifier)
          .submit(githubHandle: 'jisoo-dev');
      expect(c.read(onboardingControllerProvider), isA<OnboardingError>());
    });
  });
}
