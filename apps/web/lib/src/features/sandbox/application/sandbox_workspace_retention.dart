import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dashboard/application/current_mission_controller.dart';
import '../../mission/state/mission_workspace_key.dart';
import '../../review/application/review_controller.dart';
import 'run_controller.dart';
import 'sandbox_workspace_controller.dart';

/// Retains only the current and immediately previous canonical Sandbox state.
/// Legacy `/sandbox` uses the null-key providers and is deliberately outside
/// this Mission workspace lifecycle.
class SandboxWorkspaceRetentionController
    extends Notifier<List<MissionWorkspaceKey>> {
  static const maxRetained = 2;
  String? _ownerKey;
  final _activeKeys = <MissionWorkspaceKey>{};

  @override
  List<MissionWorkspaceKey> build() {
    _ownerKey = ref.read(currentMissionOwnerKeyProvider);
    ref.listen(currentMissionOwnerKeyProvider, (_, nextOwner) {
      if (nextOwner == _ownerKey) return;
      _ownerKey = nextOwner;
      _clear();
    });
    return const [];
  }

  void touch(MissionWorkspaceKey key) {
    final next = [...state.where((candidate) => candidate != key), key];
    while (next.length > maxRetained) {
      _evict(next.removeAt(0));
    }
    state = List.unmodifiable(next);
  }

  void activate(MissionWorkspaceKey key) {
    _activeKeys.add(key);
    touch(key);
  }

  void deactivate(MissionWorkspaceKey key) {
    _activeKeys.remove(key);
  }

  void _clear() {
    final previous = state;
    state = const [];
    for (final key in previous) {
      // Active controllers clear themselves through their owner listener and
      // stay mounted long enough to restore the new owner's same-route state.
      if (_activeKeys.contains(key)) continue;
      _evict(key);
    }
  }

  void _evict(MissionWorkspaceKey key) {
    ref.invalidate(runControllerFamilyProvider(key));
    ref.invalidate(sandboxWorkspaceControllerProvider(key));
    ref.invalidate(reviewControllerFamilyProvider(key));
  }
}

final sandboxWorkspaceRetentionProvider =
    NotifierProvider<
      SandboxWorkspaceRetentionController,
      List<MissionWorkspaceKey>
    >(SandboxWorkspaceRetentionController.new);
