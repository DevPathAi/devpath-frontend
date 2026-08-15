/// Canonical Mission workspace identity carried by task/content routes.
///
/// Route parsing is intentionally strict: IDs must be positive decimal integers
/// that remain exact when Flutter web crosses a JavaScript boundary.
final class MissionWorkspaceKey {
  const MissionWorkspaceKey({required this.taskId, required this.contentId})
    : assert(taskId > 0 && taskId <= maxSafeInteger),
      assert(contentId > 0 && contentId <= maxSafeInteger);

  static const int maxSafeInteger = 9007199254740991;

  final int taskId;
  final int contentId;

  factory MissionWorkspaceKey.parse({
    required String taskId,
    required String contentId,
  }) {
    final key = tryParse(taskId: taskId, contentId: contentId);
    if (key == null) {
      throw FormatException(
        'Mission workspace IDs must be positive canonical JS-safe integers.',
      );
    }
    return key;
  }

  static MissionWorkspaceKey? tryParse({
    required String? taskId,
    required String? contentId,
  }) {
    final parsedTaskId = _parseCanonicalId(taskId);
    final parsedContentId = _parseCanonicalId(contentId);
    if (parsedTaskId == null || parsedContentId == null) return null;
    return MissionWorkspaceKey(
      taskId: parsedTaskId,
      contentId: parsedContentId,
    );
  }

  String get contentLocation => '/mission/$taskId/content/$contentId';

  String get sandboxLocation => '/mission/$taskId/sandbox';

  static int? _parseCanonicalId(String? value) {
    if (value == null || !RegExp(r'^[1-9][0-9]*$').hasMatch(value)) {
      return null;
    }
    final parsed = int.tryParse(value);
    if (parsed == null || parsed > maxSafeInteger) return null;
    return parsed;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MissionWorkspaceKey &&
          taskId == other.taskId &&
          contentId == other.contentId;

  @override
  int get hashCode => Object.hash(taskId, contentId);

  @override
  String toString() =>
      'MissionWorkspaceKey(taskId: $taskId, contentId: $contentId)';
}
