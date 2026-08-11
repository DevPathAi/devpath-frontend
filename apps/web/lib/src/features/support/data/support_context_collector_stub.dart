import 'support_context_collector.dart';

/// VM/테스트 스텁. 제보를 막지 않도록 던지지 않고 'unknown' 을 돌려준다 —
/// 진단 정보 하나가 없다고 제보 자체가 실패하면 안 된다.
class _StubUserAgentReader implements UserAgentReader {
  const _StubUserAgentReader();

  @override
  String read() => 'unknown';
}

/// 조건부 임포트에서 호출하는 팩토리 함수.
UserAgentReader createUserAgentReader() => const _StubUserAgentReader();
