import 'dart:convert';

import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/key_value_store.dart';
import '../../../providers/api_providers.dart';

/// The last identity successfully verified by `/users/me`.
/// It is only a display/offline ownership snapshot; the access token remains
/// the authentication credential and a server 401 always clears both.
class VerifiedSessionStore {
  VerifiedSessionStore(this._store);

  static const storageKey = 'leva.mobile.verified_session.v1';
  final KeyValueStore _store;

  Future<User?> read() async {
    final raw = await _store.read(storageKey);
    if (raw == null) return null;
    try {
      return User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      await clear();
      return null;
    }
  }

  Future<void> write(User user) =>
      _store.write(storageKey, jsonEncode(user.toJson()));

  Future<void> clear() => _store.delete(storageKey);
}

final verifiedSessionStoreProvider = Provider<VerifiedSessionStore>(
  (ref) => VerifiedSessionStore(ref.watch(keyValueStoreProvider)),
);
