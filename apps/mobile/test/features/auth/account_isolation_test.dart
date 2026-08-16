import 'dart:async';

import 'package:dio/dio.dart';
import 'package:devpath_mobile/src/data/account_data_cleaner.dart';
import 'package:devpath_mobile/src/data/key_value_store.dart';
import 'package:devpath_mobile/src/data/owner_data_store.dart';
import 'package:devpath_mobile/src/features/auth/application/auth_controller.dart';
import 'package:devpath_mobile/src/features/auth/application/account_epoch_store.dart';
import 'package:devpath_mobile/src/features/auth/application/credential_mutation_coordinator.dart';
import 'package:devpath_mobile/src/features/auth/application/pending_deep_link_controller.dart';
import 'package:devpath_mobile/src/features/auth/application/verified_session_store.dart';
import 'package:devpath_mobile/src/features/auth/state/auth_state.dart';
import 'package:devpath_mobile/src/features/notifications/application/device_registrar.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:devpath_mobile/src/services/push_service.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Cleaner implements AccountDataCleaner {
  _Cleaner([this.events]);

  final List<String>? events;
  final owners = <String>[];

  @override
  Future<void> clearOwner(String ownerKey) async {
    owners.add(ownerKey);
    events?.add('clear:$ownerKey');
  }
}

class _SwitchRegistrar extends DeviceRegistrar {
  _SwitchRegistrar(
    this.events, {
    this.fail = false,
    List<bool?>? credentialProofs,
  }) : credentialProofs = credentialProofs ?? <bool?>[],
       super(
         _client(const {}),
         StubPushService(),
         'ANDROID',
         InMemoryOwnerDataStore(),
       );

  final List<String> events;
  final bool fail;
  final List<bool?> credentialProofs;

  @override
  Future<void> unregister(
    String ownerKey, {
    bool? credentialOwnerConfirmed,
  }) async {
    events.add('revoke:$ownerKey');
    credentialProofs.add(credentialOwnerConfirmed);
    if (fail) throw StateError('local FCM invalidation failed');
  }
}

class _ReentrantCredentialRegistrar extends DeviceRegistrar {
  _ReentrantCredentialRegistrar(this.coordinator)
    : super(
        _client(const {}),
        StubPushService(),
        'ANDROID',
        InMemoryOwnerDataStore(),
      );

  final CredentialMutationCoordinator coordinator;

  @override
  Future<void> unregister(String ownerKey, {bool? credentialOwnerConfirmed}) {
    // Models a device-unregister 401 whose AuthInterceptor refresh must enter
    // the same credential mutation boundary.
    return coordinator.run(() async {});
  }
}

ApiClient _client(Map<String, MockFixture> fixtures) {
  final client = ApiClient.create(
    const ApiConfig(baseUrl: 'https://api.example.test'),
  );
  client.dio.httpClientAdapter = MockHttpAdapter(fixtures);
  return client;
}

void main() {
  test('users/me transport 장애는 토큰과 재시도 가능한 세션 상태를 보존한다', () async {
    final tokens = InMemoryTokenStore();
    await tokens.save(access: 'access', refresh: 'refresh');
    final container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(tokens),
        keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
        apiClientProvider.overrideWithValue(
          _client({
            'GET /users/me': (
              503,
              {
                'error': {'code': 'UNKNOWN', 'message': 'temporarily down'},
              },
            ),
          }),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.notifier).bootstrapSession();

    expect(
      container.read(authControllerProvider),
      isA<AuthSessionUnavailable>(),
    );
    expect(await tokens.readAccess(), 'access');
    expect(await tokens.readRefresh(), 'refresh');
  });

  test(
    'transport 장애는 마지막 verified owner를 offline-authenticated로 복원한다',
    () async {
      final tokens = InMemoryTokenStore();
      final kv = InMemoryKeyValueStore();
      await tokens.save(access: 'access', refresh: 'refresh');
      await VerifiedSessionStore(kv).write(
        const User(
          id: 'owner-a',
          email: 'a@example.com',
          nickname: 'A',
          role: UserRole.learner,
          onboardingStatus: OnboardingStatus.done,
          consentStatus: ConsentStatus.done,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          tokenStoreProvider.overrideWithValue(tokens),
          keyValueStoreProvider.overrideWithValue(kv),
          apiClientProvider.overrideWithValue(_client(const {})),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).bootstrapSession();

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthOfflineAuthenticated>());
      expect(state.ownerKey, 'owner-a');
      expect(await tokens.readAccess(), 'access');
    },
  );

  test(
    'users/me 401 clears exact owner data, verified session, token and advances epoch',
    () async {
      final tokens = InMemoryTokenStore();
      final kv = InMemoryKeyValueStore();
      final cleaner = _Cleaner();
      await tokens.save(access: 'access', refresh: 'refresh');
      await VerifiedSessionStore(kv).write(
        const User(
          id: 'owner-a',
          email: null,
          nickname: 'A',
          role: UserRole.learner,
          onboardingStatus: OnboardingStatus.done,
          consentStatus: ConsentStatus.done,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          tokenStoreProvider.overrideWithValue(tokens),
          keyValueStoreProvider.overrideWithValue(kv),
          accountDataCleanerProvider.overrideWithValue(cleaner),
          ownerDataStoreProvider.overrideWithValue(InMemoryOwnerDataStore()),
          apiClientProvider.overrideWithValue(
            _client({
              'GET /users/me': (
                401,
                {
                  'error': {'code': 'UNAUTHORIZED', 'message': 'expired'},
                },
              ),
            }),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).bootstrapSession();

      expect(cleaner.owners, ['owner-a']);
      expect(await VerifiedSessionStore(kv).read(), isNull);
      expect(await tokens.readAccess(), isNull);
      expect(await AccountEpochStore(kv).current(), 1);
      expect(
        container.read(authControllerProvider),
        isA<AuthUnauthenticated>(),
      );
    },
  );

  test('명시적 logout은 토큰보다 owner-scoped 데이터를 먼저 지운다', () async {
    final tokens = InMemoryTokenStore();
    final cleaner = _Cleaner();
    final credentialProofs = <bool?>[];
    final container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(tokens),
        keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
        apiClientProvider.overrideWithValue(
          _client({
            'GET /users/me': (
              200,
              {
                'id': 'owner-a',
                'email': 'a@example.com',
                'nickname': 'A',
                'role': 'LEARNER',
                'onboardingStatus': 'DONE',
                'consentStatus': 'DONE',
              },
            ),
          }),
        ),
        accountDataCleanerProvider.overrideWithValue(cleaner),
        ownerDataStoreProvider.overrideWithValue(InMemoryOwnerDataStore()),
        deviceRegistrarProvider.overrideWithValue(
          _SwitchRegistrar([], credentialProofs: credentialProofs),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(authControllerProvider.notifier);
    await tokens.save(access: 'access', refresh: 'refresh');
    await controller.bootstrapSession();

    await controller.logout();

    expect(cleaner.owners, ['owner-a']);
    expect(credentialProofs, [true]);
    expect(await tokens.readAccess(), isNull);
    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
  });

  test(
    'verified A to server B revokes A before clearing and exposing B',
    () async {
      final events = <String>[];
      final credentialProofs = <bool?>[];
      final tokens = InMemoryTokenStore();
      final kv = InMemoryKeyValueStore();
      final cleaner = _Cleaner(events);
      await tokens.save(access: 'b-access', refresh: 'b-refresh');
      await VerifiedSessionStore(kv).write(_user('owner-a'));
      final container = ProviderContainer(
        overrides: [
          tokenStoreProvider.overrideWithValue(tokens),
          keyValueStoreProvider.overrideWithValue(kv),
          accountDataCleanerProvider.overrideWithValue(cleaner),
          ownerDataStoreProvider.overrideWithValue(InMemoryOwnerDataStore()),
          deviceRegistrarProvider.overrideWithValue(
            _SwitchRegistrar(events, credentialProofs: credentialProofs),
          ),
          apiClientProvider.overrideWithValue(
            _client({'GET /users/me': (200, _userJson('owner-b'))}),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).bootstrapSession();

      expect(events, ['revoke:owner-a', 'clear:owner-a']);
      expect(credentialProofs, [false]);
      expect(container.read(authControllerProvider).ownerKey, 'owner-b');
      expect((await VerifiedSessionStore(kv).read())?.id, 'owner-b');
    },
  );

  test(
    'verified A to server B clears live and durable A pending route',
    () async {
      final tokens = InMemoryTokenStore();
      final kv = InMemoryKeyValueStore();
      await tokens.save(access: 'b-access', refresh: 'b-refresh');
      await VerifiedSessionStore(kv).write(_user('owner-a'));
      final container = ProviderContainer(
        overrides: [
          tokenStoreProvider.overrideWithValue(tokens),
          keyValueStoreProvider.overrideWithValue(kv),
          accountDataCleanerProvider.overrideWithValue(_Cleaner()),
          ownerDataStoreProvider.overrideWithValue(InMemoryOwnerDataStore()),
          deviceRegistrarProvider.overrideWithValue(_SwitchRegistrar([])),
          apiClientProvider.overrideWithValue(
            _client({'GET /users/me': (200, _userJson('owner-b'))}),
          ),
        ],
      );
      addTearDown(container.dispose);
      final pending = container.read(pendingDeepLinkProvider.notifier);
      expect(await pending.capture('/path/101/today'), isTrue);
      expect(container.read(pendingDeepLinkProvider), '/path/101/today');
      final pendingRaw = await kv.read(PendingDeepLinkController.storageKey);
      expect(pendingRaw, isNotNull);
      await kv.write(PendingDeepLinkController.consumedStorageKey, pendingRaw!);

      await container.read(authControllerProvider.notifier).bootstrapSession();

      expect(container.read(authControllerProvider).ownerKey, 'owner-b');
      expect(container.read(pendingDeepLinkProvider), isNull);
      expect(await kv.read(PendingDeepLinkController.storageKey), isNull);
      expect(
        await kv.read(PendingDeepLinkController.consumedStorageKey),
        isNull,
      );
    },
  );

  test(
    'A revoke failure still clears A and never exposes or activates B',
    () async {
      final events = <String>[];
      final tokens = InMemoryTokenStore();
      final kv = InMemoryKeyValueStore();
      final cleaner = _Cleaner(events);
      await tokens.save(access: 'b-access', refresh: 'b-refresh');
      await VerifiedSessionStore(kv).write(_user('owner-a'));
      final container = ProviderContainer(
        overrides: [
          tokenStoreProvider.overrideWithValue(tokens),
          keyValueStoreProvider.overrideWithValue(kv),
          accountDataCleanerProvider.overrideWithValue(cleaner),
          ownerDataStoreProvider.overrideWithValue(InMemoryOwnerDataStore()),
          deviceRegistrarProvider.overrideWithValue(
            _SwitchRegistrar(events, fail: true),
          ),
          apiClientProvider.overrideWithValue(
            _client({'GET /users/me': (200, _userJson('owner-b'))}),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.notifier).bootstrapSession();

      expect(events, ['revoke:owner-a', 'clear:owner-a']);
      expect(
        container.read(authControllerProvider),
        isA<AuthUnauthenticated>(),
      );
      expect(await tokens.readAccess(), isNull);
      expect(await VerifiedSessionStore(kv).read(), isNull);
    },
  );

  test(
    'OAuth replacement advances A epoch before saving B and cannot restore A offline',
    () async {
      final events = <String>[];
      final tokens = _RecordingTokenStore(events);
      final kv = InMemoryKeyValueStore();
      final cleaner = _Cleaner(events);
      await tokens.save(access: 'a-access', refresh: 'a-refresh');
      await VerifiedSessionStore(kv).write(_user('owner-a'));
      await kv.write('dp.auth.pkce_verifier', 'verifier');
      final api = _OAuthReplacementApi();
      final container = ProviderContainer(
        overrides: [
          tokenStoreProvider.overrideWithValue(tokens),
          keyValueStoreProvider.overrideWithValue(kv),
          accountDataCleanerProvider.overrideWithValue(cleaner),
          ownerDataStoreProvider.overrideWithValue(InMemoryOwnerDataStore()),
          deviceRegistrarProvider.overrideWithValue(_SwitchRegistrar(events)),
          apiClientProvider.overrideWithValue(api),
          authFlowClientProvider.overrideWithValue(api),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(authControllerProvider.notifier);
      await controller.bootstrapSession();
      expect(container.read(authControllerProvider).ownerKey, 'owner-a');
      events.clear();

      var refreshCalls = 0;
      var retryCalls = 0;
      final interceptor = AuthInterceptor(
        store: tokens,
        sessionEpoch: AccountEpochStore(kv).current,
        refresh: (_) async {
          refreshCalls += 1;
          return const TokenPair(access: 'unexpected', refresh: 'unexpected');
        },
        retry: (options) async {
          retryCalls += 1;
          return Response<dynamic>(requestOptions: options, statusCode: 200);
        },
      );
      final oldARequest = RequestOptions(
        path: '/community/questions',
        method: 'POST',
      );
      await interceptor.onRequest(oldARequest, RequestInterceptorHandler());
      expect(oldARequest.headers['Authorization'], 'Bearer a-access');

      final replacing = controller.completeFromCode('code-for-b');
      await tokens.bSaved.future;
      await api.bLookupStarted.future;
      expect(await AccountEpochStore(kv).current(), 1);

      final lateAError = DioException(
        requestOptions: oldARequest,
        response: Response<dynamic>(
          requestOptions: oldARequest,
          statusCode: 401,
        ),
        type: DioExceptionType.badResponse,
      );
      await runZonedGuarded(
        () => interceptor.onError(lateAError, ErrorInterceptorHandler()),
        (_, _) {},
      );
      expect(refreshCalls, 0);
      expect(retryCalls, 0);
      expect(await tokens.readAccess(), 'b-access');

      api.releaseBLookup.complete();
      await replacing;

      expect(
        events,
        containsAllInOrder([
          'revoke:owner-a',
          'clear:owner-a',
          'token:clear',
          'token:save:b-access',
        ]),
      );
      expect(await AccountEpochStore(kv).current(), 1);
      expect(await VerifiedSessionStore(kv).read(), isNull);
      expect(
        container.read(authControllerProvider),
        isA<AuthSessionUnavailable>(),
      );
      expect(
        container.read(authControllerProvider),
        isNot(isA<AuthOfflineAuthenticated>()),
      );
    },
  );

  test('OAuth replacement revoke failure clears A and never saves B', () async {
    final events = <String>[];
    final tokens = _RecordingTokenStore(events);
    final kv = InMemoryKeyValueStore();
    await tokens.save(access: 'a-access', refresh: 'a-refresh');
    await VerifiedSessionStore(kv).write(_user('owner-a'));
    await kv.write('dp.auth.pkce_verifier', 'verifier');
    final api = _OAuthReplacementApi();
    final container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(tokens),
        keyValueStoreProvider.overrideWithValue(kv),
        accountDataCleanerProvider.overrideWithValue(_Cleaner(events)),
        ownerDataStoreProvider.overrideWithValue(InMemoryOwnerDataStore()),
        deviceRegistrarProvider.overrideWithValue(
          _SwitchRegistrar(events, fail: true),
        ),
        apiClientProvider.overrideWithValue(api),
        authFlowClientProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(authControllerProvider.notifier);
    await controller.bootstrapSession();
    events.clear();

    await controller.completeFromCode('code-for-b');

    expect(events, containsAllInOrder(['revoke:owner-a', 'clear:owner-a']));
    expect(events, isNot(contains('token:save:b-access')));
    expect(await tokens.readAccess(), isNull);
    expect(await AccountEpochStore(kv).current(), 1);
    expect(await VerifiedSessionStore(kv).read(), isNull);
    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
  });

  test('device revoke auth refresh cannot deadlock logout cleanup', () async {
    final tokens = InMemoryTokenStore();
    final kv = InMemoryKeyValueStore();
    final coordinator = CredentialMutationCoordinator();
    await tokens.save(access: 'a-access', refresh: 'a-refresh');
    await VerifiedSessionStore(kv).write(_user('owner-a'));
    final container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(tokens),
        keyValueStoreProvider.overrideWithValue(kv),
        credentialMutationCoordinatorProvider.overrideWithValue(coordinator),
        accountDataCleanerProvider.overrideWithValue(_Cleaner()),
        ownerDataStoreProvider.overrideWithValue(InMemoryOwnerDataStore()),
        deviceRegistrarProvider.overrideWithValue(
          _ReentrantCredentialRegistrar(coordinator),
        ),
        apiClientProvider.overrideWithValue(
          _client({'GET /users/me': (200, _userJson('owner-a'))}),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(authControllerProvider.notifier);
    await controller.bootstrapSession();

    await expectLater(
      controller.logout().timeout(const Duration(milliseconds: 200)),
      completes,
    );

    expect(await tokens.readAccess(), isNull);
    expect(await AccountEpochStore(kv).current(), 1);
    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
  });
}

User _user(String id) => User(
  id: id,
  email: '$id@example.com',
  nickname: id,
  role: UserRole.learner,
  onboardingStatus: OnboardingStatus.done,
  consentStatus: ConsentStatus.done,
);

Map<String, dynamic> _userJson(String id) => {
  'id': id,
  'email': '$id@example.com',
  'nickname': id,
  'role': 'LEARNER',
  'onboardingStatus': 'DONE',
  'consentStatus': 'DONE',
};

final class _RecordingTokenStore extends InMemoryTokenStore {
  _RecordingTokenStore(this.events);

  final List<String> events;
  final bSaved = Completer<void>();

  @override
  Future<void> save({required String access, required String refresh}) async {
    events.add('token:save:$access');
    await super.save(access: access, refresh: refresh);
    if (access == 'b-access' && !bSaved.isCompleted) bSaved.complete();
  }

  @override
  Future<void> clear() async {
    events.add('token:clear');
    await super.clear();
  }
}

final class _OAuthReplacementApi extends ApiClient {
  _OAuthReplacementApi() : super(Dio());

  var userCalls = 0;
  final bLookupStarted = Completer<void>();
  final releaseBLookup = Completer<void>();

  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? query}) async {
    userCalls += 1;
    if (userCalls == 1) return _userJson('owner-a') as T;
    bLookupStarted.complete();
    await releaseBLookup.future;
    throw const ApiException(
      code: ApiErrorCode.unknown,
      message: 'B session lookup unavailable',
      status: 503,
    );
  }

  @override
  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async =>
      <String, dynamic>{
            'access_token': 'b-access',
            'refresh_token': 'b-refresh',
          }
          as T;
}
