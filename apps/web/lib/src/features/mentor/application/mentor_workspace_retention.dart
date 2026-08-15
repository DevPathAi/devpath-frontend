import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/mentor_scope_key.dart';
import 'mentor_controller.dart';

/// Keeps contextual Mentor conversations bounded to the two most recently
/// visited owner/workspace scopes. Eviction disposes in-flight callbacks through
/// [MentorController]'s generation guard before the key can be constructed again.
class MentorWorkspaceRetentionController
    extends Notifier<List<MentorScopeKey>> {
  static const maxRetained = 2;

  @override
  List<MentorScopeKey> build() => const [];

  void touch(MentorScopeKey scope) {
    final next = [...state.where((candidate) => candidate != scope), scope];
    while (next.length > maxRetained) {
      _evict(next.removeAt(0));
    }
    state = List.unmodifiable(next);
  }

  void activate(MentorScopeKey scope) => touch(scope);

  void deactivate(MentorScopeKey scope) {
    // Deactivation intentionally preserves the immediately previous scope so
    // browser back restores its conversation without another network request.
  }

  void _evict(MentorScopeKey scope) {
    ref.invalidate(contextualMentorControllerProvider(scope));
  }
}

final mentorWorkspaceRetentionProvider =
    NotifierProvider<MentorWorkspaceRetentionController, List<MentorScopeKey>>(
      MentorWorkspaceRetentionController.new,
    );
