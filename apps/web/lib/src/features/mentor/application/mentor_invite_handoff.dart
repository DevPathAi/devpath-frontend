import 'mentor_invite_handoff_web.dart'
    if (dart.library.io) 'mentor_invite_handoff_stub.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const mentorInviteParameter = 'invite';
const mentorReturnToParameter = 'returnTo';
const mentorInviteStorageKey = 'leva.mentor.invite.v1';
const mentorReturnToStorageKey = 'leva.mentor.return_to.v1';

abstract interface class MentorInviteHandoffStore {
  String? peekCode();
  void writeCode(String code);
  void clearCode();
  void rememberReturnTo(String path);
  String? takeReturnTo();

  String? takeCode() {
    final value = peekCode();
    clearCode();
    return value;
  }
}

class MemoryMentorInviteHandoffStore implements MentorInviteHandoffStore {
  String? _code;
  String? _returnTo;

  @override
  String? peekCode() => _code;

  @override
  void writeCode(String code) => _code = code;

  @override
  void clearCode() => _code = null;

  @override
  String? takeCode() {
    final value = _code;
    _code = null;
    return value;
  }

  @override
  void rememberReturnTo(String path) {
    if (isSafeMentorReturnTo(path)) _returnTo = path;
  }

  @override
  String? takeReturnTo() {
    final value = _returnTo;
    _returnTo = null;
    return value;
  }
}

bool isSafeMentorReturnTo(String? value) {
  if (value == '/mentor') return true;
  return value != null && RegExp(r'^/mission/[0-9]+/mentor$').hasMatch(value);
}

bool _isValidInviteCode(String? value) =>
    value != null && RegExp(r'^[A-Za-z0-9_-]{32,128}$').hasMatch(value);

Uri _withoutSensitiveParameters(Uri uri) {
  final query = <String, dynamic>{
    for (final entry in uri.queryParametersAll.entries)
      if (entry.key != mentorInviteParameter &&
          entry.key != mentorReturnToParameter)
        entry.key: entry.value,
  };
  final fragment = <String, dynamic>{
    for (final entry in _fragmentParameters(uri).entries)
      if (entry.key != mentorInviteParameter &&
          entry.key != mentorReturnToParameter)
        entry.key: entry.value,
  };
  var clean = query.isEmpty
      ? _withoutQuery(uri)
      : uri.replace(queryParameters: query);
  clean = fragment.isEmpty
      ? _withoutFragment(clean)
      : clean.replace(fragment: Uri(queryParameters: fragment).query);
  return clean;
}

Uri _withoutQuery(Uri uri) {
  final text = uri.toString();
  final queryStart = text.indexOf('?');
  if (queryStart == -1) return uri;
  final fragmentStart = text.indexOf('#', queryStart);
  return Uri.parse(
    text.replaceRange(
      queryStart,
      fragmentStart == -1 ? text.length : fragmentStart,
      '',
    ),
  );
}

Uri _withoutFragment(Uri uri) {
  final text = uri.toString();
  final fragmentStart = text.indexOf('#');
  return fragmentStart == -1
      ? uri
      : Uri.parse(text.substring(0, fragmentStart));
}

Map<String, List<String>> _fragmentParameters(Uri uri) => uri.fragment.isEmpty
    ? const <String, List<String>>{}
    : Uri(query: uri.fragment).queryParametersAll;

void captureMentorInviteFromUri(
  Uri current, {
  required MentorInviteHandoffStore store,
  required void Function(Uri cleanUri) replaceVisibleUri,
}) {
  final fragment = _fragmentParameters(current);
  final codes = fragment[mentorInviteParameter];
  final returnPaths = fragment[mentorReturnToParameter];
  final hasLegacySensitiveQuery =
      current.queryParametersAll.containsKey(mentorInviteParameter) ||
      current.queryParametersAll.containsKey(mentorReturnToParameter);
  if (codes == null && returnPaths == null && !hasLegacySensitiveQuery) return;

  // 먼저 주소에서 지운다. sessionStorage가 거부돼도 code가 주소에 남지 않아야 한다.
  replaceVisibleUri(_withoutSensitiveParameters(current));
  if (codes?.length == 1 && _isValidInviteCode(codes!.single)) {
    store.writeCode(codes.single);
  }
  if (returnPaths?.length == 1 && isSafeMentorReturnTo(returnPaths!.single)) {
    store.rememberReturnTo(returnPaths.single);
  }
}

MentorInviteHandoffStore mentorInviteHandoffStore() =>
    createMentorInviteHandoffStore();

void captureMentorInviteHandoffFromVisibleUrl() =>
    captureVisibleMentorInviteHandoff();

final mentorInviteHandoffStoreProvider = Provider<MentorInviteHandoffStore>(
  (ref) => mentorInviteHandoffStore(),
);
