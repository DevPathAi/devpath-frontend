import 'package:devpath_mobile/src/app/app_config.dart';
import 'package:devpath_mobile/src/data/key_value_store.dart';
import 'package:devpath_mobile/src/features/auth/application/account_epoch_store.dart';
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
      expect(await interceptor.sessionEpoch!(), 0);

      await container.read(accountEpochStoreProvider).advance();
      expect(await interceptor.sessionEpoch!(), 1);
    },
  );
}
