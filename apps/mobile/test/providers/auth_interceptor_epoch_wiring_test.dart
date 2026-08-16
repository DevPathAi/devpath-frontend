import 'dart:async';

import 'package:dio/dio.dart';
import 'package:devpath_mobile/src/app/app_config.dart';
import 'package:devpath_mobile/src/data/account_data_cleaner.dart';
import 'package:devpath_mobile/src/data/key_value_store.dart';
import 'package:devpath_mobile/src/data/owner_data_store.dart';
import 'package:devpath_mobile/src/features/auth/application/account_epoch_store.dart';
import 'package:devpath_mobile/src/features/auth/application/credential_mutation_coordinator.dart';
import 'package:devpath_mobile/src/features/auth/application/auth_controller.dart';
import 'package:devpath_mobile/src/features/auth/application/pending_deep_link_controller.dart';
import 'package:devpath_mobile/src/features/auth/application/verified_session_store.dart';
import 'package:devpath_mobile/src/features/auth/state/auth_state.dart';
import 'package:devpath_mobile/src/features/notifications/application/device_registrar.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:devpath_mobile/src/services/push_service.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'mobile AuthInterceptor is bound to the durable account epoch',
    () async {
      final kv = InMemoryKeyValueStore();
      final container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(kv),
          appConfigProvider.overrideWithValue(
            const AppConfig(baseUrl: 'https://api.test', useMock: false),
          ),
        ],
      );
      addTearDown(container.dispose);

      final interceptor = container
          .read(apiClientProvider)
          .dio
          .interceptors
          .whereType<AuthInterceptor>()
          .single;
      expect(interceptor.credentialMutation, isNotNull);
      expect(await interceptor.sessionEpoch!(), (durable: 0, credential: 0));

      await container.read(accountEpochStoreProvider).advance();
      expect(await interceptor.sessionEpoch!(), (durable: 1, credential: 0));

      container.read(credentialMutationCoordinatorProvider).invalidate();
      expect(await interceptor.sessionEpoch!(), (durable: 1, credential: 1));
    },
  );

  test(
    'AuthController and AuthInterceptor share one credential tail',
    () async {
      final container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
          appConfigProvider.overrideWithValue(
            const AppConfig(baseUrl: 'https://api.test', useMock: false),
          ),
        ],
      );
      addTearDown(container.dispose);
      final interceptor = container
          .read(apiClientProvider)
          .dio
          .interceptors
          .whereType<AuthInterceptor>()
          .single;
      final controller = container.read(authControllerProvider.notifier);
      await pumpEventQueue();
      final held = Completer<void>();
      final release = Completer<void>();
      final mutation = interceptor.credentialMutation!;
      final interceptorMutation = mutation<void>(() async {
        held.complete();
        await release.future;
      });
      await held.future;

      var logoutCompleted = false;
      final logout = controller.logout().then((_) => logoutCompleted = true);
      await pumpEventQueue(times: 2);
      expect(logoutCompleted, isFalse);

      release.complete();
      await interceptorMutation;
      await logout;
      expect(logoutCompleted, isTrue);
    },
  );

  test(
    'arbitrary resource refresh rejection terminates and purges exact session',
    () async {
      final tokens = InMemoryTokenStore();
      final kv = InMemoryKeyValueStore();
      final data = InMemoryOwnerDataStore();
      final cleaner = _OwnerCleaner(data);
      final registrar = _CountingRegistrar();
      await tokens.save(access: 'access-a', refresh: 'refresh-a');
      await VerifiedSessionStore(kv).write(_user('owner-a'));
      final refreshClient = ApiClient.create(
        const ApiConfig(baseUrl: 'https://api.test'),
      );
      refreshClient.dio.httpClientAdapter = MockHttpAdapter({
        'POST /auth/refresh': (
          401,
          {
            'error': {'code': 'UNAUTHORIZED', 'message': 'refresh rejected'},
          },
        ),
      });
      final container = ProviderContainer(
        overrides: [
          tokenStoreProvider.overrideWithValue(tokens),
          keyValueStoreProvider.overrideWithValue(kv),
          ownerDataStoreProvider.overrideWithValue(data),
          accountDataCleanerProvider.overrideWithValue(cleaner),
          deviceRegistrarProvider.overrideWithValue(registrar),
          authFlowClientProvider.overrideWithValue(refreshClient),
          appConfigProvider.overrideWithValue(
            const AppConfig(baseUrl: 'https://api.test', useMock: false),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(registrar.dispose);
      final client = container.read(apiClientProvider);
      client.dio.httpClientAdapter = MockHttpAdapter({
        'GET /users/me': (200, _userJson('owner-a')),
        'GET /contents/77': (
          401,
          {
            'error': {'code': 'UNAUTHORIZED', 'message': 'access expired'},
          },
        ),
      });
      final auth = container.read(authControllerProvider.notifier);
      await auth.bootstrapSession();
      expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
      await pumpEventQueue();
      await container
          .read(pendingDeepLinkProvider.notifier)
          .capture('/path/101/today');
      await data.write('owner-a', 'test', 'secret', 'A data');
      final epochBefore = await container
          .read(accountEpochStoreProvider)
          .current();
      final generationBefore = container
          .read(credentialMutationCoordinatorProvider)
          .generation;

      await expectLater(
        client.get<Map<String, dynamic>>('/contents/77'),
        throwsA(isA<ApiException>()),
      );

      expect(
        container.read(authControllerProvider),
        isA<AuthUnauthenticated>(),
      );
      expect(await tokens.readAccess(), isNull);
      expect(await tokens.readRefresh(), isNull);
      expect(await VerifiedSessionStore(kv).read(), isNull);
      expect(container.read(pendingDeepLinkProvider), isNull);
      expect(await kv.read(PendingDeepLinkController.storageKey), isNull);
      expect(await data.list('owner-a'), isEmpty);
      expect(cleaner.owners, ['owner-a']);
      expect(registrar.owners, ['owner-a']);
      expect(
        await container.read(accountEpochStoreProvider).current(),
        epochBefore + 1,
      );
      expect(
        container.read(credentialMutationCoordinatorProvider).generation,
        generationBefore + 1,
      );
    },
  );

  test(
    'terminal cleanup cannot deadlock on same-client unregister 401',
    () async {
      final tokens = InMemoryTokenStore();
      final kv = InMemoryKeyValueStore();
      final data = InMemoryOwnerDataStore();
      await tokens.save(access: 'access-a', refresh: 'refresh-a');
      await VerifiedSessionStore(kv).write(_user('owner-a'));
      await data.write(
        'owner-a',
        'push-registration-v1',
        'ANDROID',
        'old-device-token',
      );
      final refreshClient = ApiClient.create(
        const ApiConfig(baseUrl: 'https://api.test'),
      );
      refreshClient.dio.httpClientAdapter = MockHttpAdapter({
        'POST /auth/refresh': (
          401,
          {
            'error': {'code': 'UNAUTHORIZED', 'message': 'refresh rejected'},
          },
        ),
      });
      final container = ProviderContainer(
        overrides: [
          tokenStoreProvider.overrideWithValue(tokens),
          keyValueStoreProvider.overrideWithValue(kv),
          ownerDataStoreProvider.overrideWithValue(data),
          pushServiceProvider.overrideWithValue(StubPushService()),
          authFlowClientProvider.overrideWithValue(refreshClient),
          appConfigProvider.overrideWithValue(
            const AppConfig(baseUrl: 'https://api.test', useMock: false),
          ),
        ],
      );
      addTearDown(container.dispose);
      final client = container.read(apiClientProvider);
      client.dio.httpClientAdapter = MockHttpAdapter({
        'GET /users/me': (200, _userJson('owner-a')),
        'GET /contents/77': (
          401,
          {
            'error': {'code': 'UNAUTHORIZED', 'message': 'access expired'},
          },
        ),
        'DELETE /notifications/devices': (
          401,
          {
            'error': {'code': 'UNAUTHORIZED', 'message': 'already expired'},
          },
        ),
      });
      final auth = container.read(authControllerProvider.notifier);
      await auth.bootstrapSession();
      final terminal = Completer<void>();
      final subscription = container.listen(authControllerProvider, (_, next) {
        if (next is AuthUnauthenticated && !terminal.isCompleted) {
          terminal.complete();
        }
      });
      addTearDown(subscription.close);

      await expectLater(
        client
            .get<Map<String, dynamic>>('/contents/77')
            .timeout(const Duration(seconds: 1)),
        throwsA(isA<ApiException>()),
      );
      await terminal.future.timeout(const Duration(seconds: 1));
      await pumpEventQueue(times: 8);

      expect(await VerifiedSessionStore(kv).read(), isNull);
      expect(await data.list('owner-a'), isEmpty);
    },
  );

  test(
    'terminal rejection during retry Loading supersedes late users-me success',
    () async {
      final tokens = InMemoryTokenStore();
      final kv = InMemoryKeyValueStore();
      final registrar = _CountingRegistrar();
      await tokens.save(access: 'access-a', refresh: 'refresh-a');
      await VerifiedSessionStore(kv).write(_user('owner-a'));
      final refreshClient = ApiClient.create(
        const ApiConfig(baseUrl: 'https://api.test'),
      );
      refreshClient.dio.httpClientAdapter = MockHttpAdapter({
        'POST /auth/refresh': (
          401,
          {
            'error': {'code': 'UNAUTHORIZED', 'message': 'refresh rejected'},
          },
        ),
      });
      final container = ProviderContainer(
        overrides: [
          tokenStoreProvider.overrideWithValue(tokens),
          keyValueStoreProvider.overrideWithValue(kv),
          ownerDataStoreProvider.overrideWithValue(InMemoryOwnerDataStore()),
          accountDataCleanerProvider.overrideWithValue(
            _OwnerCleaner(InMemoryOwnerDataStore()),
          ),
          deviceRegistrarProvider.overrideWithValue(registrar),
          authFlowClientProvider.overrideWithValue(refreshClient),
          appConfigProvider.overrideWithValue(
            const AppConfig(baseUrl: 'https://api.test', useMock: false),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(registrar.dispose);
      final client = container.read(apiClientProvider);
      client.dio.httpClientAdapter = MockHttpAdapter({
        'GET /users/me': (200, _userJson('owner-a')),
        'GET /contents/77': (
          401,
          {
            'error': {'code': 'UNAUTHORIZED', 'message': 'access expired'},
          },
        ),
      });
      final auth = container.read(authControllerProvider.notifier);
      await auth.bootstrapSession();
      final retryStarted = Completer<void>();
      final releaseRetry = Completer<void>();
      client.dio.interceptors.insert(
        1,
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            if (options.path == '/users/me') {
              retryStarted.complete();
              await releaseRetry.future;
            }
            handler.next(options);
          },
        ),
      );

      final retrying = auth.retrySession();
      await retryStarted.future;
      expect(container.read(authControllerProvider), isA<AuthLoading>());
      await expectLater(
        client.get<Map<String, dynamic>>('/contents/77'),
        throwsA(isA<ApiException>()),
      );
      await pumpEventQueue(times: 4);
      releaseRetry.complete();
      await retrying;
      await pumpEventQueue(times: 4);

      expect(
        container.read(authControllerProvider),
        isA<AuthUnauthenticated>(),
      );
      expect(await tokens.readAccess(), isNull);
    },
  );
}

class _OwnerCleaner implements AccountDataCleaner {
  _OwnerCleaner(this.data);

  final OwnerDataStore data;
  final owners = <String>[];

  @override
  Future<void> clearOwner(String ownerKey) async {
    owners.add(ownerKey);
    await data.clearOwner(ownerKey);
  }
}

class _CountingRegistrar extends DeviceRegistrar {
  _CountingRegistrar()
    : super(
        ApiClient.create(const ApiConfig(baseUrl: 'https://api.test')),
        StubPushService(),
        'ANDROID',
        InMemoryOwnerDataStore(),
      );

  final owners = <String>[];

  @override
  Future<void> unregister(String ownerKey) async => owners.add(ownerKey);
}

User _user(String id) => User.fromJson(_userJson(id));

Map<String, dynamic> _userJson(String id) => {
  'id': id,
  'email': '$id@example.com',
  'nickname': id,
  'role': 'LEARNER',
  'onboardingStatus': 'DONE',
  'consentStatus': 'DONE',
};
