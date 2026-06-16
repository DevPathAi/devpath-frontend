import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/features/onboarding/application/onboarding_controller.dart';
import 'package:devpath_web/src/features/onboarding/state/onboarding_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('진단 제출 → 온보딩 완료 + auth 유저가 DONE으로 갱신', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // 선행: 로그인(PENDING)
    await container.read(authControllerProvider.notifier).login();
    expect(
      (container.read(authControllerProvider) as AuthAuthenticated)
          .user
          .onboardingStatus,
      OnboardingStatus.pending,
    );

    await container
        .read(onboardingControllerProvider.notifier)
        .submit(githubHandle: 'jisoo-dev');

    expect(container.read(onboardingControllerProvider), isA<OnboardingDone>());
    final user =
        (container.read(authControllerProvider) as AuthAuthenticated).user;
    expect(user.onboardingStatus, OnboardingStatus.done);
  });
}
