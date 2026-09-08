import 'package:web/web.dart' as web;

import 'mentor_invite_handoff.dart';

class _WebMentorInviteHandoffStore implements MentorInviteHandoffStore {
  const _WebMentorInviteHandoffStore();

  String? _read(String key) {
    try {
      return web.window.sessionStorage.getItem(key);
    } catch (_) {
      return null;
    }
  }

  void _write(String key, String value) {
    try {
      web.window.sessionStorage.setItem(key, value);
    } catch (_) {
      // 초대 handoff는 선택 기능이다. 저장소 거부가 인증을 막으면 안 된다.
    }
  }

  void _remove(String key) {
    try {
      web.window.sessionStorage.removeItem(key);
    } catch (_) {
      // best-effort cleanup
    }
  }

  @override
  String? peekCode() => _read(mentorInviteStorageKey);

  @override
  void writeCode(String code) => _write(mentorInviteStorageKey, code);

  @override
  void clearCode() => _remove(mentorInviteStorageKey);

  @override
  String? takeCode() {
    final value = peekCode();
    clearCode();
    return value;
  }

  @override
  void rememberReturnTo(String path) {
    if (isSafeMentorReturnTo(path)) {
      _write(mentorReturnToStorageKey, path);
    }
  }

  @override
  String? takeReturnTo() {
    final value = _read(mentorReturnToStorageKey);
    _remove(mentorReturnToStorageKey);
    return isSafeMentorReturnTo(value) ? value : null;
  }

  @override
  void clearReturnTo() => _remove(mentorReturnToStorageKey);

  @override
  void clear() {
    clearCode();
    clearReturnTo();
  }
}

MentorInviteHandoffStore createMentorInviteHandoffStore() =>
    const _WebMentorInviteHandoffStore();

void captureVisibleMentorInviteHandoff() {
  try {
    captureMentorInviteFromUri(
      Uri.parse(web.window.location.href),
      store: createMentorInviteHandoffStore(),
      replaceVisibleUri: (uri) =>
          web.window.history.replaceState(null, '', uri.toString()),
    );
  } catch (_) {
    // URL 또는 sessionStorage 권한 거부가 앱 시작을 막아서는 안 된다.
  }
}
