import 'dart:async';

import 'package:devpath_mobile/src/app/app_config.dart';
import 'package:devpath_mobile/src/data/key_value_store.dart';
import 'package:devpath_mobile/src/features/auth/application/account_epoch_store.dart';
import 'package:devpath_mobile/src/features/auth/application/credential_mutation_coordinator.dart';
import 'package:devpath_mobile/src/features/auth/application/auth_controller.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
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
}
