import 'sandbox_funnel_store_stub.dart'
    if (dart.library.js_interop) 'sandbox_funnel_store_web.dart';

import '../../../analytics/analytics_contract.dart';
import '../../mission/state/mission_workspace_key.dart';

/// Session-scoped, reload-safe claims for Sandbox funnel events.
///
/// Claims contain only opaque/database identifiers. Editor code, output and
/// review content never cross this storage boundary.
abstract class SandboxFunnelStore {
  bool claimFirstPractice({
    required String userId,
    required MissionWorkspaceKey workspaceKey,
    required int runId,
  }) {
    _validateUser(userId);
    _validateWorkspace(workspaceKey);
    _validateDatabaseId(runId, 'runId');
    return claimStorageKey(
      sandboxFirstPracticeClaimKey(userId, workspaceKey.taskId),
    );
  }

  bool claimContextualReview({
    required String userId,
    required MissionWorkspaceKey workspaceKey,
    required int sandboxSessionId,
    required int reviewId,
  }) {
    _validateUser(userId);
    _validateWorkspace(workspaceKey);
    _validateDatabaseId(sandboxSessionId, 'sandboxSessionId');
    _validateDatabaseId(reviewId, 'reviewId');
    return claimStorageKey(
      sandboxContextualReviewClaimKey(userId, workspaceKey.taskId, reviewId),
    );
  }

  bool claimStorageKey(String key);
}

final class MemorySandboxFunnelStore extends SandboxFunnelStore {
  MemorySandboxFunnelStore([Set<String>? values])
    : _values = values ?? <String>{};

  final Set<String> _values;

  @override
  bool claimStorageKey(String key) => _values.add(key);
}

String sandboxFirstPracticeClaimKey(String userId, int taskId) =>
    'leva.sandbox.funnel.v1.first-practice.$userId.$taskId';

String sandboxContextualReviewClaimKey(
  String userId,
  int taskId,
  int reviewId,
) => 'leva.sandbox.funnel.v1.review-view.$userId.$taskId.$reviewId';

void _validateUser(String value) {
  if (!isPlatformUserId(value)) {
    throw ArgumentError.value(value, 'userId', 'must be a platform user ID');
  }
}

void _validateWorkspace(MissionWorkspaceKey value) {
  _validateDatabaseId(value.taskId, 'taskId');
  _validateDatabaseId(value.contentId, 'contentId');
}

void _validateDatabaseId(int value, String name) {
  if (value <= 0 || value > MissionWorkspaceKey.maxSafeInteger) {
    throw ArgumentError.value(value, name, 'must be a positive JS-safe ID');
  }
}

SandboxFunnelStore sandboxFunnelStore() => createSandboxFunnelStore();
