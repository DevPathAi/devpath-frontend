import 'package:devpath_mobile/src/auth/secure_storage_token_store.dart';
import 'package:devpath_mobile/src/data/key_value_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SecureStorageTokenStore', () {
    late InMemoryKeyValueStore kv;
    late SecureStorageTokenStore store;

    setUp(() {
      kv = InMemoryKeyValueStore();
      store = SecureStorageTokenStore(kv);
    });

    test('초기 상태는 토큰 없음', () async {
      expect(await store.readAccess(), isNull);
      expect(await store.readRefresh(), isNull);
    });

    test('save → read 라운드트립', () async {
      await store.save(access: 'a1', refresh: 'r1');
      expect(await store.readAccess(), 'a1');
      expect(await store.readRefresh(), 'r1');
    });

    test('save 덮어쓰기', () async {
      await store.save(access: 'a1', refresh: 'r1');
      await store.save(access: 'a2', refresh: 'r2');
      expect(await store.readAccess(), 'a2');
      expect(await store.readRefresh(), 'r2');
    });

    test('clear 후 토큰 제거', () async {
      await store.save(access: 'a1', refresh: 'r1');
      await store.clear();
      expect(await store.readAccess(), isNull);
      expect(await store.readRefresh(), isNull);
    });
  });
}
