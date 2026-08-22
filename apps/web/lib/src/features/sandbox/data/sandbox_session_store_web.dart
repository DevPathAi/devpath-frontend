import 'package:web/web.dart' as web;

import '../../mission/state/mission_workspace_key.dart';
import 'sandbox_session_store.dart';

final class _WebSandboxSessionStore implements SandboxSessionStore {
  @override
  int? read(String ownerKey, MissionWorkspaceKey workspaceKey) {
    try {
      final raw = web.window.sessionStorage.getItem(
        sandboxSessionStorageKey(ownerKey, workspaceKey),
      );
      final parsed = int.tryParse(raw ?? '');
      if (parsed == null ||
          parsed <= 0 ||
          parsed > MissionWorkspaceKey.maxSafeInteger) {
        return null;
      }
      return parsed;
    } on Object {
      return null;
    }
  }

  @override
  void write(String ownerKey, MissionWorkspaceKey workspaceKey, int sessionId) {
    if (sessionId <= 0 || sessionId > MissionWorkspaceKey.maxSafeInteger) {
      throw ArgumentError.value(sessionId, 'sessionId');
    }
    try {
      web.window.sessionStorage.setItem(
        sandboxSessionStorageKey(ownerKey, workspaceKey),
        '$sessionId',
      );
    } on Object {
      // Server recovery still works in the current view when storage is denied.
    }
  }

  @override
  void clear(String ownerKey, MissionWorkspaceKey workspaceKey) {
    try {
      web.window.sessionStorage.removeItem(
        sandboxSessionStorageKey(ownerKey, workspaceKey),
      );
    } on Object {
      // Storage denial must not blank an otherwise usable workspace.
    }
  }
}

SandboxSessionStore createSandboxSessionStore() => _WebSandboxSessionStore();
