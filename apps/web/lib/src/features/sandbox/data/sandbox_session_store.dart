import 'sandbox_session_store_stub.dart'
    if (dart.library.js_interop) 'sandbox_session_store_web.dart';

import '../../mission/state/mission_workspace_key.dart';

abstract interface class SandboxSessionStore {
  int? read(String ownerKey, MissionWorkspaceKey workspaceKey);

  void write(String ownerKey, MissionWorkspaceKey workspaceKey, int sessionId);

  void clear(String ownerKey, MissionWorkspaceKey workspaceKey);
}

final class MemorySandboxSessionStore implements SandboxSessionStore {
  MemorySandboxSessionStore([Map<String, int>? values])
    : _values = values ?? <String, int>{};

  final Map<String, int> _values;

  @override
  int? read(String ownerKey, MissionWorkspaceKey workspaceKey) =>
      _values[_key(ownerKey, workspaceKey)];

  @override
  void write(String ownerKey, MissionWorkspaceKey workspaceKey, int sessionId) {
    if (sessionId <= 0 || sessionId > MissionWorkspaceKey.maxSafeInteger) {
      throw ArgumentError.value(sessionId, 'sessionId');
    }
    _values[_key(ownerKey, workspaceKey)] = sessionId;
  }

  @override
  void clear(String ownerKey, MissionWorkspaceKey workspaceKey) {
    _values.remove(_key(ownerKey, workspaceKey));
  }
}

String sandboxSessionStorageKey(
  String ownerKey,
  MissionWorkspaceKey workspaceKey,
) =>
    'leva.sandbox.session.v2.$ownerKey.${workspaceKey.taskId}.${workspaceKey.contentId}';

String _key(String ownerKey, MissionWorkspaceKey workspaceKey) =>
    sandboxSessionStorageKey(ownerKey, workspaceKey);

SandboxSessionStore sandboxSessionStore() => createSandboxSessionStore();
