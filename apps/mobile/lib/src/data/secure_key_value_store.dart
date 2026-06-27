import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'key_value_store.dart';

/// flutter_secure_storage 백엔드 [KeyValueStore] 구현(Android Keystore / iOS Keychain).
class SecureKeyValueStore implements KeyValueStore {
  const SecureKeyValueStore(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
