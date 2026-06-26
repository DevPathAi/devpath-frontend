import 'package:dp_core/dp_core.dart';

import '../data/key_value_store.dart';

/// dp_core [TokenStore]의 모바일 영속 구현. access/refresh 토큰을 [KeyValueStore]
/// (프로덕션=secure_storage)에 보관해 앱 재시작 후에도 세션을 복원한다.
class SecureStorageTokenStore implements TokenStore {
  SecureStorageTokenStore(this._kv);

  final KeyValueStore _kv;

  static const _kAccess = 'dp.auth.access';
  static const _kRefresh = 'dp.auth.refresh';

  @override
  Future<String?> readAccess() => _kv.read(_kAccess);

  @override
  Future<String?> readRefresh() => _kv.read(_kRefresh);

  @override
  Future<void> save({required String access, required String refresh}) async {
    await _kv.write(_kAccess, access);
    await _kv.write(_kRefresh, refresh);
  }

  @override
  Future<void> clear() async {
    await _kv.delete(_kAccess);
    await _kv.delete(_kRefresh);
  }
}
