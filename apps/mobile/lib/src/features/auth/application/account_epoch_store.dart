import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/key_value_store.dart';
import '../../../providers/api_providers.dart';

/// Durable account boundary generation. It advances only when an established
/// account is explicitly cleared (logout/401/replacement), so a PKCE handoff
/// from unauthenticated to authenticated remains in the same epoch.
class AccountEpochStore {
  AccountEpochStore(this._store);

  static const storageKey = 'leva.mobile.account_epoch.v1';
  final KeyValueStore _store;

  Future<int> current() async =>
      int.tryParse(await _store.read(storageKey) ?? '') ?? 0;

  Future<int> advance() async {
    final next = (await current()) + 1;
    await _store.write(storageKey, next.toString());
    return next;
  }
}

final accountEpochStoreProvider = Provider<AccountEpochStore>(
  (ref) => AccountEpochStore(ref.watch(keyValueStoreProvider)),
);
