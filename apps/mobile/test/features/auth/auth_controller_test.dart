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
  final client = _client(fixtures ?? _userOk);
  final c = ProviderContainer(
    overrides: [
      tokenStoreProvider.overrideWithValue(store ?? InMemoryTokenStore()),
      apiClientProvider.overrideWithValue(client),
      authFlowClientProvider.overrideWithValue(client),
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

    test(
      'OAuth code exchange uses the un-intercepted auth-flow client',
      () async {
        final store = InMemoryTokenStore();
        final kv = InMemoryKeyValueStore();
        await kv.write(_kVerifier, 'the-verifier');
        var interceptedExchangeCalls = 0;
        var authFlowExchangeCalls = 0;
        final intercepted = _client(_userOk);
        intercepted.dio.interceptors.insert(
          0,
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path == '/auth/oauth/token') {
                interceptedExchangeCalls += 1;
                handler.reject(
                  DioException(
                    requestOptions: options,
                    response: Response<void>(
                      requestOptions: options,
                      statusCode: 401,
                    ),
                    type: DioExceptionType.badResponse,
                  ),
                );
                return;
              }
              handler.next(options);
            },
          ),
        );
        final authFlow = _client(const {});
        authFlow.dio.interceptors.insert(
          0,
          InterceptorsWrapper(
            onRequest: (options, handler) {
              authFlowExchangeCalls += 1;
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: const {
                    'access_token': 'deep-a',
                    'refresh_token': 'deep-r',
                  },
                ),
              );
            },
          ),
        );
        final c = ProviderContainer(
          overrides: [
            tokenStoreProvider.overrideWithValue(store),
            apiClientProvider.overrideWithValue(intercepted),
            authFlowClientProvider.overrideWithValue(authFlow),
            keyValueStoreProvider.overrideWithValue(kv),
            accountDataCleanerProvider.overrideWithValue(_NoopCleaner()),
            ownerDataStoreProvider.overrideWithValue(InMemoryOwnerDataStore()),
          ],
        );
        addTearDown(c.dispose);
        final controller = c.read(authControllerProvider.notifier);
        await pumpEventQueue();

        await controller.completeFromCode('the-code');

        expect(interceptedExchangeCalls, 0);
        expect(authFlowExchangeCalls, 1);
        expect(c.read(authControllerProvider), isA<AuthAuthenticated>());
        expect(await store.readAccess(), 'deep-a');
      },
    );

    test('동일 OAuth code의 concurrent callback은 정확히 한 번 교환한다', () async {
      final store = InMemoryTokenStore();
      final kv = InMemoryKeyValueStore();
      await kv.write(_kVerifier, 'the-verifier');
      final exchangeStarted = Completer<void>();
      final releaseExchange = Completer<void>();
      var exchangeCalls = 0;
      final client = _client(_userOk);
      client.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            if (options.path != '/auth/oauth/token') {
              handler.next(options);
              return;
            }
            exchangeCalls += 1;
            if (exchangeCalls == 1) {
              exchangeStarted.complete();
              await releaseExchange.future;
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: const {
                    'access_token': 'deep-a',
                    'refresh_token': 'deep-r',
                  },
                ),
              );
              return;
            }
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 401,
                  data: const {
                    'error': {
                      'code': 'UNAUTHORIZED',
                      'message': 'code already consumed',
                    },
                  },
                ),
                type: DioExceptionType.badResponse,
              ),
            );
          },
        ),
      );
      final c = ProviderContainer(
        overrides: [
          tokenStoreProvider.overrideWithValue(store),
          apiClientProvider.overrideWithValue(client),
          authFlowClientProvider.overrideWithValue(client),
          keyValueStoreProvider.overrideWithValue(kv),
          accountDataCleanerProvider.overrideWithValue(_NoopCleaner()),
          ownerDataStoreProvider.overrideWithValue(InMemoryOwnerDataStore()),
        ],
      );
      addTearDown(c.dispose);
      final controller = c.read(authControllerProvider.notifier);
      await pumpEventQueue();

      final first = controller.completeFromCode('one-use-code');
      await exchangeStarted.future;
      final duplicate = controller.completeFromCode('one-use-code');
      await pumpEventQueue();
      releaseExchange.complete();
      await Future.wait([first, duplicate]);

      expect(exchangeCalls, 1);
      expect(c.read(authControllerProvider), isA<AuthAuthenticated>());
      expect(await store.readAccess(), 'deep-a');
      expect(await kv.read(_kVerifier), isNull);
    });

    test(
      'stale callback is rejected before a distinct current callback runs',
      () async {
        final store = InMemoryTokenStore();
        final kv = InMemoryKeyValueStore();
        final launcher = _FakeLauncher();
        final exchangeStarted = Completer<void>();
        final releaseExchange = Completer<void>();
        final exchanges = <Map<String, dynamic>>[];
        final client = _client(_userOk);
        client.dio.interceptors.insert(
          0,
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              if (options.path != '/auth/oauth/token') {
                handler.next(options);
                return;
              }
              final body = (options.data as Map).cast<String, dynamic>();
              exchanges.add(body);
              if (body['code'] == 'stale-code') {
                if (!exchangeStarted.isCompleted) exchangeStarted.complete();
                await releaseExchange.future;
                handler.reject(
                  DioException(
                    requestOptions: options,
                    response: Response<Map<String, dynamic>>(
                      requestOptions: options,
                      statusCode: 401,
                      data: const {
                        'error': {
                          'code': 'UNAUTHORIZED',
                          'message': 'PKCE mismatch',
                        },
                      },
                    ),
                    type: DioExceptionType.badResponse,
                  ),
                );
                return;
              }
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: const {
                    'access_token': 'current-access',
                    'refresh_token': 'current-refresh',
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
            authFlowClientProvider.overrideWithValue(client),
            oauthLauncherProvider.overrideWithValue(launcher),
            keyValueStoreProvider.overrideWithValue(kv),
            accountDataCleanerProvider.overrideWithValue(_NoopCleaner()),
            ownerDataStoreProvider.overrideWithValue(InMemoryOwnerDataStore()),
          ],
        );
        addTearDown(c.dispose);
        final controller = c.read(authControllerProvider.notifier);
        await pumpEventQueue();
        await controller.login();
        await controller.login();
        final currentVerifier = await kv.read(_kVerifier);
        expect(currentVerifier, isNotNull);

        final stale = controller.completeFromCode('stale-code');
        await exchangeStarted.future;
        final duplicateStale = controller.completeFromCode('stale-code');
        final current = controller.completeFromCode('current-code');
        releaseExchange.complete();
        await Future.wait([stale, duplicateStale, current]);

        expect(exchanges, [
          {'code': 'stale-code', 'code_verifier': currentVerifier},
          {'code': 'current-code', 'code_verifier': currentVerifier},
        ]);
        expect(c.read(authControllerProvider), isA<AuthAuthenticated>());
        expect(await store.readAccess(), 'current-access');
        expect(await kv.read(_kVerifier), isNull);
      },
    );

    test(
      'accepted current callback prevents a later stale code from exchanging',
      () async {
        final store = InMemoryTokenStore();
        final kv = InMemoryKeyValueStore();
        final launcher = _FakeLauncher();
        final exchanges = <Map<String, dynamic>>[];
        final client = _client(_userOk);
        client.dio.interceptors.insert(
          0,
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path != '/auth/oauth/token') {
                handler.next(options);
                return;
              }
              exchanges.add((options.data as Map).cast<String, dynamic>());
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: const {
                    'access_token': 'current-access',
                    'refresh_token': 'current-refresh',
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
            authFlowClientProvider.overrideWithValue(client),
            oauthLauncherProvider.overrideWithValue(launcher),
            keyValueStoreProvider.overrideWithValue(kv),
            accountDataCleanerProvider.overrideWithValue(_NoopCleaner()),
            ownerDataStoreProvider.overrideWithValue(InMemoryOwnerDataStore()),
          ],
        );
        addTearDown(c.dispose);
        final controller = c.read(authControllerProvider.notifier);
        await pumpEventQueue();
        await controller.login();
        await controller.login();
        final verifier = await kv.read(_kVerifier);

        await controller.completeFromCode('current-code');
        await controller.completeFromCode('stale-code');

        expect(exchanges, [
          {'code': 'current-code', 'code_verifier': verifier},
        ]);
        expect(await store.readAccess(), 'current-access');
        expect(c.read(authControllerProvider), isA<AuthAuthenticated>());
      },
    );

    test('OAuth callback candidates are bounded per login flow', () async {
      final kv = InMemoryKeyValueStore();
      await kv.write(_kVerifier, 'bounded-verifier');
      var exchangeCalls = 0;
      final client = _client(_userOk);
      client.dio.interceptors.insert(
        0,
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.path != '/auth/oauth/token') {
              handler.next(options);
              return;
            }
            exchangeCalls += 1;
            handler.reject(
              DioException(
                requestOptions: options,
                response: Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 401,
                  data: const {
                    'error': {
                      'code': 'UNAUTHORIZED',
                      'message': 'PKCE mismatch',
                    },
                  },
                ),
                type: DioExceptionType.badResponse,
              ),
            );
          },
        ),
      );
      final c = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(client),
          authFlowClientProvider.overrideWithValue(client),
          keyValueStoreProvider.overrideWithValue(kv),
          accountDataCleanerProvider.overrideWithValue(_NoopCleaner()),
          ownerDataStoreProvider.overrideWithValue(InMemoryOwnerDataStore()),
        ],
      );
      addTearDown(c.dispose);
      final controller = c.read(authControllerProvider.notifier);
      await pumpEventQueue();

      await Future.wait(
        List.generate(
          20,
          (index) => controller.completeFromCode('candidate-$index'),
        ),
      );

      expect(exchangeCalls, 16);
      expect(await kv.read(_kVerifier), 'bounded-verifier');
    });

    test(
      'late prior-flow mismatch preserves current verifier and verified session',
      () async {
        final store = InMemoryTokenStore();
        final kv = InMemoryKeyValueStore();
        final launcher = _FakeLauncher();
        final client = _client(_userOk);
        client.dio.interceptors.insert(
          0,
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path != '/auth/oauth/token') {
                handler.next(options);
                return;
              }
              handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 401,
                    data: const {
                      'error': {
                        'code': 'UNAUTHORIZED',
                        'message': 'PKCE mismatch',
                      },
                    },
                  ),
                  type: DioExceptionType.badResponse,
                ),
              );
            },
          ),
        );
        final c = ProviderContainer(
          overrides: [
            tokenStoreProvider.overrideWithValue(store),
            apiClientProvider.overrideWithValue(client),
            authFlowClientProvider.overrideWithValue(client),
            oauthLauncherProvider.overrideWithValue(launcher),
            keyValueStoreProvider.overrideWithValue(kv),
            accountDataCleanerProvider.overrideWithValue(_NoopCleaner()),
            ownerDataStoreProvider.overrideWithValue(InMemoryOwnerDataStore()),
          ],
        );
        addTearDown(c.dispose);
        final controller = c.read(authControllerProvider.notifier);
        await pumpEventQueue();
        await controller.mockLogin();
        expect(c.read(authControllerProvider), isA<AuthAuthenticated>());

        await controller.login();
        await controller.login();
        final currentVerifier = await kv.read(_kVerifier);
        await controller.completeFromCode('late-prior-code');

        expect(await kv.read(_kVerifier), currentVerifier);
        expect(await store.readAccess(), 'mock-access');
        expect(await store.readRefresh(), 'mock-refresh');
        expect(c.read(authControllerProvider), isA<AuthAuthenticated>());
      },
    );

    test(
      'a new login flow retires a stalled callback from the previous verifier',
      () async {
        final store = InMemoryTokenStore();
        final kv = InMemoryKeyValueStore();
        await kv.write(_kVerifier, 'verifier-one');
        final launcher = _FakeLauncher();
        final oldExchangeStarted = Completer<void>();
        final releaseOldExchange = Completer<void>();
        final exchanges = <Map<String, dynamic>>[];
        final client = _client(_userOk);
        client.dio.interceptors.insert(
          0,
          InterceptorsWrapper(
            onRequest: (options, handler) async {
              if (options.path != '/auth/oauth/token') {
                handler.next(options);
                return;
              }
              final body = (options.data as Map).cast<String, dynamic>();
              exchanges.add(body);
              if (body['code'] == 'code-one') {
                oldExchangeStarted.complete();
                await releaseOldExchange.future;
                handler.resolve(
                  Response<Map<String, dynamic>>(
                    requestOptions: options,
                    statusCode: 200,
                    data: const {
                      'access_token': 'old-access',
                      'refresh_token': 'old-refresh',
                    },
                  ),
                );
                return;
              }
              handler.resolve(
                Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 200,
                  data: const {
                    'access_token': 'new-access',
                    'refresh_token': 'new-refresh',
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
            authFlowClientProvider.overrideWithValue(client),
            oauthLauncherProvider.overrideWithValue(launcher),
            keyValueStoreProvider.overrideWithValue(kv),
            accountDataCleanerProvider.overrideWithValue(_NoopCleaner()),
            ownerDataStoreProvider.overrideWithValue(InMemoryOwnerDataStore()),
          ],
        );
        addTearDown(c.dispose);
        final controller = c.read(authControllerProvider.notifier);
        await pumpEventQueue();

        final oldCompletion = controller.completeFromCode('code-one');
        await oldExchangeStarted.future;
        await controller.login();
        final verifierTwo = await kv.read(_kVerifier);
        expect(verifierTwo, isNotNull);
        expect(verifierTwo, isNot('verifier-one'));
        final newCompletion = controller.completeFromCode('code-two');
        addTearDown(() async {
          if (!releaseOldExchange.isCompleted) releaseOldExchange.complete();
          await Future.wait([oldCompletion, newCompletion]);
        });

        await pumpEventQueue();
        expect(exchanges, hasLength(2));
        expect(exchanges[0], {
          'code': 'code-one',
          'code_verifier': 'verifier-one',
        });
        expect(exchanges[1], {
          'code': 'code-two',
          'code_verifier': verifierTwo,
        });
        await newCompletion;
        releaseOldExchange.complete();
        await oldCompletion;

        expect(await store.readAccess(), 'new-access');
        expect(await store.readRefresh(), 'new-refresh');
        expect(c.read(authControllerProvider), isA<AuthAuthenticated>());
      },
    );

    test(
      'completed OAuth callback replay preserves the authenticated session',
      () async {
        final store = InMemoryTokenStore();
        final kv = InMemoryKeyValueStore();
        await kv.write(_kVerifier, 'the-verifier');
        var exchangeCalls = 0;
        final client = _client({
          ..._userOk,
          'POST /auth/oauth/token': (
            200,
            {'access_token': 'deep-a', 'refresh_token': 'deep-r'},
          ),
        });
        client.dio.interceptors.insert(
          0,
          InterceptorsWrapper(
            onRequest: (options, handler) {
              if (options.path == '/auth/oauth/token') exchangeCalls += 1;
              handler.next(options);
            },
          ),
        );
        final c = ProviderContainer(
          overrides: [
            tokenStoreProvider.overrideWithValue(store),
            apiClientProvider.overrideWithValue(client),
            authFlowClientProvider.overrideWithValue(client),
            keyValueStoreProvider.overrideWithValue(kv),
            accountDataCleanerProvider.overrideWithValue(_NoopCleaner()),
            ownerDataStoreProvider.overrideWithValue(InMemoryOwnerDataStore()),
          ],
        );
        addTearDown(c.dispose);
        final controller = c.read(authControllerProvider.notifier);
        await pumpEventQueue();

        await controller.completeFromCode('one-use-code');
        await controller.completeFromCode('one-use-code');

        expect(exchangeCalls, 1);
        expect(c.read(authControllerProvider), isA<AuthAuthenticated>());
        expect(await store.readAccess(), 'deep-a');
      },
    );

    test('completeFromCode: 실패 후보는 current verifier를 보존한다', () async {
      // 딥링크 code에는 flow correlation이 없으므로 이 401은 이전 flow의 code와
      // current verifier를 조합한 PKCE mismatch일 수 있다. 성공한 교환만 verifier를
      // 소비해야 뒤이어 도착한 current callback을 처리할 수 있다.
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
        'the-verifier',
        reason: '실패 후보는 뒤이은 current callback의 verifier를 지우지 않음',
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
        expect(
          await kv.read(_kVerifier),
          'the-verifier',
          reason: 'malformed 2xx도 유효한 token exchange 성공으로 간주하지 않음',
        );
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
          authFlowClientProvider.overrideWithValue(client),
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
