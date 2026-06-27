import 'package:devpath_mobile/src/features/auth/application/auth_controller.dart';
import 'package:devpath_mobile/src/features/auth/application/oauth_launcher.dart';
import 'package:devpath_mobile/src/features/auth/state/auth_state.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLauncher implements OAuthLauncher {
  String? launched;
  @override
  Future<void> launch(String url) async => launched = url;
}

ApiClient _client(Map<String, MockFixture> fx) {
  final c = ApiClient.create(const ApiConfig(baseUrl: 'http://test.local'));
  c.dio.httpClientAdapter = MockHttpAdapter(fx);
  return c;
}

final Map<String, MockFixture> _userOk = {
  'GET /users/me': (
    200,
    {
      'id': 'u-mock',
      'email': 'learner@devpath.ai',
      'nickname': '지수',
      'role': 'LEARNER',
      'onboardingStatus': 'DONE',
    },
  ),
};

ProviderContainer _container({
  Map<String, MockFixture>? fixtures,
  TokenStore? store,
  OAuthLauncher? launcher,
}) {
  final c = ProviderContainer(
    overrides: [
      tokenStoreProvider.overrideWithValue(store ?? InMemoryTokenStore()),
      apiClientProvider.overrideWithValue(_client(fixtures ?? _userOk)),
      oauthLauncherProvider.overrideWithValue(launcher ?? _FakeLauncher()),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('AuthController', () {
    test('토큰 없음 → 부팅 시 미인증', () async {
      final c = _container();
      c.read(authControllerProvider.notifier);
      await pumpEventQueue();
      expect(c.read(authControllerProvider), isA<AuthUnauthenticated>());
    });

    test('mockLogin → 인증 + 토큰 저장', () async {
      final store = InMemoryTokenStore();
      final c = _container(store: store);
      final n = c.read(authControllerProvider.notifier);
      await pumpEventQueue();
      await n.mockLogin();

      final s = c.read(authControllerProvider);
      expect(s, isA<AuthAuthenticated>());
      expect((s as AuthAuthenticated).user.nickname, '지수');
      expect(await store.readAccess(), 'mock-access');
      expect(await store.readRefresh(), 'mock-refresh');
    });

    test('completeFromDeepLink → 딥링크 토큰 저장 + 인증', () async {
      final store = InMemoryTokenStore();
      final c = _container(store: store);
      final n = c.read(authControllerProvider.notifier);
      await pumpEventQueue();
      await n.completeFromDeepLink(
        const TokenPair(access: 'deep-a', refresh: 'deep-r'),
      );

      expect(c.read(authControllerProvider), isA<AuthAuthenticated>());
      expect(await store.readAccess(), 'deep-a');
      expect(await store.readRefresh(), 'deep-r');
    });

    test('logout → 미인증 + 토큰 제거', () async {
      final store = InMemoryTokenStore();
      final c = _container(store: store);
      final n = c.read(authControllerProvider.notifier);
      await pumpEventQueue();
      await n.mockLogin();
      await n.logout();

      expect(c.read(authControllerProvider), isA<AuthUnauthenticated>());
      expect(await store.readAccess(), isNull);
    });

    test('login() → GitHub OAuth 인가 URL(모바일 식별 client_type=mobile) 실행', () async {
      final launcher = _FakeLauncher();
      final c = _container(launcher: launcher);
      final n = c.read(authControllerProvider.notifier);
      await pumpEventQueue();
      await n.login();
      // 백엔드가 이 플로우를 모바일로 식별해 devpath://callback 딥링크로 토큰을 회신하도록
      // client_type=mobile을 붙인다(없으면 웹 쿠키 플로우로 처리됨).
      expect(
        launcher.launched,
        'https://mock.devpath.ai/oauth2/authorization/github?client_type=mobile',
      );
    });

    test('/users/me 실패 → 미인증', () async {
      final store = InMemoryTokenStore();
      await store.save(access: 'x', refresh: 'y');
      final c = _container(store: store, fixtures: const {});
      final n = c.read(authControllerProvider.notifier);
      await n.bootstrapSession();
      expect(c.read(authControllerProvider), isA<AuthUnauthenticated>());
    });

    test('onboardingCompleted → 인증 사용자 교체(갱신 반영)', () async {
      final c = _container();
      final n = c.read(authControllerProvider.notifier);
      await pumpEventQueue();
      await n.mockLogin();

      n.onboardingCompleted(
        const User(
          id: 'u-mock',
          email: 'learner@devpath.ai',
          nickname: '완료된지수',
          role: UserRole.learner,
          onboardingStatus: OnboardingStatus.done,
        ),
      );

      final s = c.read(authControllerProvider);
      expect(s, isA<AuthAuthenticated>());
      expect((s as AuthAuthenticated).user.nickname, '완료된지수');
    });
  });
}
