import 'package:web/web.dart' as web;

import 'mentor_invite_handoff.dart';

class _WebMentorInviteHandoffStore implements MentorInviteHandoffStore {
  const _WebMentorInviteHandoffStore();

  @override
  String? peekCode() =>
      web.window.sessionStorage.getItem(mentorInviteStorageKey);

  @override
  void writeCode(String code) =>
      web.window.sessionStorage.setItem(mentorInviteStorageKey, code);

  @override
  void clearCode() =>
      web.window.sessionStorage.removeItem(mentorInviteStorageKey);

  @override
  String? takeCode() {
    final value = peekCode();
    clearCode();
    return value;
  }

  @override
  void rememberReturnTo(String path) {
    if (isSafeMentorReturnTo(path)) {
      web.window.sessionStorage.setItem(mentorReturnToStorageKey, path);
    }
  }

  @override
  String? takeReturnTo() {
    final value = web.window.sessionStorage.getItem(mentorReturnToStorageKey);
    web.window.sessionStorage.removeItem(mentorReturnToStorageKey);
    return isSafeMentorReturnTo(value) ? value : null;
  }

  @override
  void clearReturnTo() =>
      web.window.sessionStorage.removeItem(mentorReturnToStorageKey);

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
