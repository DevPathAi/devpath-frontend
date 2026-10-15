import 'package:web/web.dart' as web;

import 'session_hint.dart';

/// 탭을 닫아도 남아야 하므로 localStorage 를 쓴다. 저장소가 막히면(사생활 보호
/// 모드 등) [SessionHint.unknown] 으로 돌아가 예전처럼 매번 확인한다.
class _WebSessionHintStore implements SessionHintStore {
  const _WebSessionHintStore();

  @override
  SessionHint read() {
    try {
      return switch (web.window.localStorage.getItem(sessionHintStorageKey)) {
        '1' => SessionHint.present,
        '0' => SessionHint.absent,
        _ => SessionHint.unknown,
      };
    } catch (_) {
      return SessionHint.unknown;
    }
  }

  @override
  void write(SessionHint hint) {
    try {
      final storage = web.window.localStorage;
      switch (hint) {
        case SessionHint.present:
          storage.setItem(sessionHintStorageKey, '1');
        case SessionHint.absent:
          storage.setItem(sessionHintStorageKey, '0');
        case SessionHint.unknown:
          storage.removeItem(sessionHintStorageKey);
      }
    } catch (_) {
      // 힌트는 최적화일 뿐이다. 저장소 거부가 인증을 막으면 안 된다.
    }
  }
}

SessionHintStore createSessionHintStore() => const _WebSessionHintStore();
