import '../../mission/state/mission_workspace_key.dart';

/// Owner-bound identity for a contextual Mentor conversation.
final class MentorScopeKey {
  const MentorScopeKey({required this.ownerId, required this.workspaceKey})
    : assert(ownerId != '');

  final String ownerId;
  final MissionWorkspaceKey workspaceKey;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MentorScopeKey &&
          ownerId == other.ownerId &&
          workspaceKey == other.workspaceKey;

  @override
  int get hashCode => Object.hash(ownerId, workspaceKey);

  @override
  String toString() => 'MentorScopeKey(workspace: $workspaceKey)';
}

/// Navigation-only intent. It contains identifiers, the explicit CTA reason,
/// and selection defaults; never editor text, output, errors, prompts, or
/// snapshot content.
enum MentorEntryReason { sandboxEditor, review }

final class MentorEntryIntent {
  const MentorEntryIntent({
    required this.scopeKey,
    required this.entryReason,
    required this.includeCurrentCode,
    required this.includeReviewSummary,
  }) : assert(
         !includeCurrentCode || entryReason == MentorEntryReason.sandboxEditor,
       ),
       assert(!includeReviewSummary || entryReason == MentorEntryReason.review);

  final MentorScopeKey scopeKey;
  final MentorEntryReason entryReason;
  final bool includeCurrentCode;
  final bool includeReviewSummary;
}
