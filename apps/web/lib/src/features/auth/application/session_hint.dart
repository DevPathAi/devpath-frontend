import 'session_hint_web.dart' if (dart.library.io) 'session_hint_stub.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const sessionHintStorageKey = 'leva.session.hint.v1';

/// 이 브라우저가 마지막으로 확인한 로그인 세션 유무.
///
/// refresh 쿠키는 HttpOnly 라 JS 가 볼 수 없다. 그래서 앱 시작 때마다
/// `POST /auth/refresh` 를 불러 확인했고, 비로그인 방문자에게는 매번 401 이
/// 콘솔 오류로 남았다(점검 A-6). 마지막 확인 결과를 기억해 [absent] 면 시작
/// 복원을 건너뛴다. [unknown](배포 전부터 로그인해 있던 사용자 포함)은 예전처럼
/// 한 번 확인한다 — 기존 사용자를 강제로 로그아웃시키지 않는다.
enum SessionHint { unknown, present, absent }

abstract interface class SessionHintStore {
  SessionHint read();
  void write(SessionHint hint);
}

class MemorySessionHintStore implements SessionHintStore {
  MemorySessionHintStore([this._hint = SessionHint.unknown]);

  SessionHint _hint;

  @override
  SessionHint read() => _hint;

  @override
  void write(SessionHint hint) => _hint = hint;
}

final sessionHintStoreProvider = Provider<SessionHintStore>(
  (ref) => createSessionHintStore(),
);
