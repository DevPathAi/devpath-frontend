import 'support_context_collector_web.dart'
    if (dart.library.io) 'support_context_collector_stub.dart';

/// userAgent 만 브라우저 API 가 필요하다 — dp_core(순수 Dart)에 둘 수 없어 web 앱이 소유한다.
/// pagePath·viewport 는 Flutter 위젯 트리에서 얻으므로 여기 없다(다이얼로그 호출부에서 채운다).
abstract interface class UserAgentReader {
  String read();
}

/// 조건부 임포트 팩토리. VM/테스트는 스텁('unknown')을 돌려준다.
UserAgentReader userAgentReader() => createUserAgentReader();
