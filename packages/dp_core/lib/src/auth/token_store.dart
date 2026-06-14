/// access/refresh 쌍.
class TokenPair {
  const TokenPair({required this.access, required this.refresh});
  final String access;
  final String refresh;
}

/// 토큰 저장 추상화. web=httpOnly 쿠키/메모리, mobile=secure storage 구현으로 주입(스펙 §3).
abstract interface class TokenStore {
  Future<String?> readAccess();
  Future<String?> readRefresh();
  Future<void> save({required String access, required String refresh});
  Future<void> clear();
}

/// 테스트/프로토 기본 구현.
class InMemoryTokenStore implements TokenStore {
  String? _access;
  String? _refresh;

  @override
  Future<String?> readAccess() async => _access;
  @override
  Future<String?> readRefresh() async => _refresh;
  @override
  Future<void> save({required String access, required String refresh}) async {
    _access = access;
    _refresh = refresh;
  }

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }
}
