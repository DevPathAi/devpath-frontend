/// 키-값 저장 추상화. 프로덕션=secure_storage 백엔드([SecureKeyValueStore]),
/// 테스트=인메모리([InMemoryKeyValueStore]). 플랫폼 채널 의존을 토큰 저장소에서 분리한다.
abstract interface class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// 테스트/프로토용 인메모리 구현(앱 재시작 시 소실).
class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _m = {};

  @override
  Future<String?> read(String key) async => _m[key];

  @override
  Future<void> write(String key, String value) async => _m[key] = value;

  @override
  Future<void> delete(String key) async => _m.remove(key);
}
