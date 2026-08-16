import 'dart:async';

import 'package:devpath_mobile/src/data/key_value_store.dart';
import 'package:devpath_mobile/src/data/account_data_cleaner.dart';
import 'package:devpath_mobile/src/data/owner_data_store.dart';
import 'package:devpath_mobile/src/features/auth/application/auth_controller.dart';
import 'package:devpath_mobile/src/features/auth/application/oauth_launcher.dart';
import 'package:devpath_mobile/src/features/auth/application/pkce.dart';
import 'package:devpath_mobile/src/features/auth/state/auth_state.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLauncher implements OAuthLauncher {
  String? launched;
  @override
  Future<void> launch(String url) async => launched = url;
}

class _NoopCleaner implements AccountDataCleaner {
  @override
  Future<void> clearOwner(String ownerKey) async {}
}

ApiClient _client(Map<String, MockFixture> fx) {
  final c = ApiClient.create(const ApiConfig(baseUrl: 'http://test.local'));
  c.dio.httpClientAdapter = MockHttpAdapter(fx);
  return c;
}

const _kVerifier = 'dp.auth.pkce_verifier';

final Map<String, MockFixture> _userOk = {
  'GET /users/me': (
    200,
    {
      'id': 'u-mock',
      'email': 'learner@devpath.ai',
      'nickname': '지수',
      'role': 'LEARNER',
      'onboardingStatus': 'DONE',
      'consentStatus': 'DONE',
    },
  ),
};

ProviderContainer _container({
  Map<String, MockFixture>? fixtures,
  TokenStore? store,
  OAuthLauncher? launcher,
  KeyValueStore? kv,
}) {
  final c = ProviderContainer(
    overrides: [
      tokenStoreProvider.overrideWithValue(store ?? InMemoryTokenStore()),
      apiClientProvider.overrideWithValue(_client(fixtures ?? _userOk)),
      oauthLauncherProvider.overrideWithValue(launcher ?? _FakeLauncher()),
      keyValueStoreProvider.overrideWithValue(kv ?? InMemoryKeyValueStore()),
      accountDataCleanerProvider.overrideWithValue(_NoopCleaner()),
      ownerDataStoreProvider.overrideWithValue(InMemoryOwnerDataStore()),
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

    test('completeFromCode → 코드 교환 + 토큰 저장 + 인증 + verifier 삭제', () async {
      final store = InMemoryTokenStore();
      final kv = InMemoryKeyValueStore();
      await kv.write(_kVerifier, 'the-verifier');
      final c = _container(
        store: store,
        kv: kv,
        fixtures: {
          ..._userOk,
          'POST /auth/oauth/token': (
            200,
            {'access_token': 'deep-a', 'refresh_token': 'deep-r'},
          ),
        },
      );
      final n = c.read(authControllerProvider.notifier);
      await pumpEventQueue();
      await n.completeFromCode('the-code');

      expect(c.read(authControllerProvider), isA<AuthAuthenticated>());
      expect(await store.readAccess(), 'deep-a');
      expect(await store.readRefresh(), 'deep-r');
      expect(await kv.read(_kVerifier), isNull, reason: '교환 후 verifier 삭제');
    });

    test('completeFromCode: 교환 실패해도 verifier 폐기(1회용)', () async {
      // code는 교환을 시도한 순간 서버에서 소비되므로, 실패해도 verifier는 더 이상
      // 유효하지 않다. 잔존 시 secure_storage에 만료된 1회용 비밀이 남는다 → 폐기 보장.
      final store = InMemoryTokenStore();
      final kv = InMemoryKeyValueStore();
      await kv.write(_kVerifier, 'the-verifier');
      final c = _container(
        store: store,
        kv: kv,
        fixtures: {
          ..._userOk,
          'POST /auth/oauth/token': (
            401,
            {
              'error': {'code': 'UNAUTHORIZED', 'message': 'bad code'},
            },
          ),
        },
      );
      final n = c.read(authControllerProvider.notifier);
      await pumpEventQueue();
      await n.completeFromCode('the-code');

      expect(c.read(authControllerProvider), isA<AuthUnauthenticated>());
      expect(await store.readAccess(), isNull, reason: '교환 실패 → 토큰 미저장');
      expect(
        await kv.read(_kVerifier),
        isNull,
        reason: '실패해도 1회용 verifier는 폐기',
      );
    });

    test('completeFromCode: verifier 없으면 미인증', () async {
      final kv = InMemoryKeyValueStore(); // verifier 미보관
      final c = _container(kv: kv);
      final n = c.read(authControllerProvider.notifier);
      await pumpEventQueue();
      await n.completeFromCode('the-code');
      expect(c.read(authControllerProvider), isA<AuthUnauthenticated>());
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

    test('login() → PKCE challenge 포함 인가 URL + verifier 보관', () async {
      final launcher = _FakeLauncher();
      final kv = InMemoryKeyValueStore();
      final c = _container(launcher: launcher, kv: kv);
      final n = c.read(authControllerProvider.notifier);
      await pumpEventQueue();
      await n.login();

      final url = launcher.launched!;
      expect(
        url,
        startsWith(
          'https://mock.devpath.ai/oauth2/authorization/github?client_type=mobile&code_challenge=',
        ),
      );
      expect(url, contains('&code_challenge_method=S256'));
      final verifier = await kv.read(_kVerifier);
      expect(verifier, isNotNull);
      // URL의 challenge는 보관된 verifier로부터 계산된 값과 일치해야 한다.
      expect(
        Uri.parse(url).queryParameters['code_challenge'],
        PkcePair.challengeFor(verifier!),
      );
    });

    test('/users/me transport 실패 → 재시도 가능한 세션 장애', () async {
      final store = InMemoryTokenStore();
      await store.save(access: 'x', refresh: 'y');
      final c = _container(store: store, fixtures: const {});
      final n = c.read(authControllerProvider.notifier);
      await n.bootstrapSession();
      expect(c.read(authControllerProvider), isA<AuthSessionUnavailable>());
      expect(await store.readAccess(), 'x');
    });

    test(
      'malformed /users/me is terminal and never leaves AuthLoading',
      () async {
        final store = InMemoryTokenStore();
        await store.save(access: 'x', refresh: 'y');
        final c = _container(
          store: store,
          fixtures: {
            'GET /users/me': (200, <String, dynamic>{'id': 42}),
          },
        );
        final controller = c.read(authControllerProvider.notifier);

        await expectLater(controller.bootstrapSession(), completes);

        expect(c.read(authControllerProvider), isA<AuthUnauthenticated>());
        expect(await store.readAccess(), isNull);
        expect(await store.readRefresh(), isNull);
      },
    );

    test(
      'malformed OAuth token payload is terminal and stores no credential',
      () async {
        final store = InMemoryTokenStore();
        final kv = InMemoryKeyValueStore();
        await kv.write(_kVerifier, 'the-verifier');
        final c = _container(
          store: store,
          kv: kv,
          fixtures: {
            'POST /auth/oauth/token': (
              200,
              <String, dynamic>{'access_token': 7, 'refresh_token': null},
            ),
          },
        );
        final controller = c.read(authControllerProvider.notifier);
        await pumpEventQueue();

        await expectLater(controller.completeFromCode('the-code'), completes);

        expect(c.read(authControllerProvider), isA<AuthUnauthenticated>());
        expect(await store.readAccess(), isNull);
        expect(await store.readRefresh(), isNull);
        expect(await kv.read(_kVerifier), isNull);
      },
    );

    test('logout 뒤 늦은 OAuth 교환 응답은 토큰을 되살리지 않는다', () async {
      final store = InMemoryTokenStore();
      final kv = InMemoryKeyValueStore();
      await kv.write(_kVerifier, 'the-verifier');
      final exchangeStarted = Completer<void>();
      final releaseExchange = Completer<void>();
      final client = _client(_userOk);
      client.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            if (options.path != '/auth/oauth/token') {
              handler.next(options);
              return;
            }
            exchangeStarted.complete();
            await releaseExchange.future;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: const {
                  'access_token': 'late-access',
                  'refresh_token': 'late-refresh',
                },
              ),
            );
          },
        ),
      );
      final c = ProviderContainer(
        overrides: [
          tokenStoreProvider.overrideWithValue(store),
          apiClientProvider.overrideWithValue(client),
          keyValueStoreProvider.overrideWithValue(kv),
          accountDataCleanerProvider.overrideWithValue(_NoopCleaner()),
          ownerDataStoreProvider.overrideWithValue(InMemoryOwnerDataStore()),
        ],
      );
      addTearDown(c.dispose);
      final controller = c.read(authControllerProvider.notifier);
      await pumpEventQueue();

      final completing = controller.completeFromCode('late-code');
      await exchangeStarted.future;
      await controller.logout();
      releaseExchange.complete();
      await completing;

      expect(c.read(authControllerProvider), isA<AuthUnauthenticated>());
      expect(await store.readAccess(), isNull);
      expect(await store.readRefresh(), isNull);
    });
  });
}
