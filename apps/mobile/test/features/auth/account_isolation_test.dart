import 'package:devpath_mobile/src/data/account_data_cleaner.dart';
import 'package:devpath_mobile/src/data/key_value_store.dart';
import 'package:devpath_mobile/src/features/auth/application/auth_controller.dart';
import 'package:devpath_mobile/src/features/auth/application/account_epoch_store.dart';
import 'package:devpath_mobile/src/features/auth/application/verified_session_store.dart';
import 'package:devpath_mobile/src/features/auth/state/auth_state.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Cleaner implements AccountDataCleaner {
  final owners = <String>[];

  @override
  Future<void> clearOwner(String ownerKey) async => owners.add(ownerKey);
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
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(authControllerProvider.notifier);
    await tokens.save(access: 'access', refresh: 'refresh');
    await controller.bootstrapSession();

    await controller.logout();

    expect(cleaner.owners, ['owner-a']);
    expect(await tokens.readAccess(), isNull);
    expect(container.read(authControllerProvider), isA<AuthUnauthenticated>());
  });
}
