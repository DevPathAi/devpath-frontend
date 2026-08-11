import 'package:web/web.dart' as web;

import 'support_context_collector.dart';

class _WebUserAgentReader implements UserAgentReader {
  const _WebUserAgentReader();

  @override
  String read() => web.window.navigator.userAgent;
}

/// 조건부 임포트에서 호출하는 팩토리 함수.
UserAgentReader createUserAgentReader() => const _WebUserAgentReader();
