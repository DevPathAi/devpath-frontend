import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('초기 상태는 미인증', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
  });

  test('login 성공 시 Authenticated + 토큰 저장', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(authControllerProvider.notifier).login();

    final state = container.read(authControllerProvider);
    expect(state, isA<AuthAuthenticated>());
    expect((state as AuthAuthenticated).user.nickname, '지수');
    expect(state.user.onboardingStatus, OnboardingStatus.pending);
    expect(
      await container.read(tokenStoreProvider).readAccess(),
      'mock-access',
    );
  });

  test('logout은 토큰을 비우고 미인증으로 전환', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final ctrl = container.read(authControllerProvider.notifier);
    await ctrl.login();
    await ctrl.logout();

    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
    expect(await container.read(tokenStoreProvider).readAccess(), isNull);
  });
}
