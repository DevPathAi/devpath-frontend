import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../mission/state/mission_workspace_key.dart';
import '../../review/state/review_state.dart';
import '../data/sandbox_funnel_store.dart';
import '../state/run_state.dart';

final sandboxFunnelStoreProvider = Provider<SandboxFunnelStore>(
  (ref) => sandboxFunnelStore(),
);

int? parseSandboxDatabaseId(String? value) {
  if (value == null || !RegExp(r'^[1-9][0-9]*$').hasMatch(value)) return null;
  final parsed = int.tryParse(value);
  if (parsed == null || parsed > MissionWorkspaceKey.maxSafeInteger) {
    return null;
  }
  return parsed;
}

int? persistedCompletedRunId(RunState run) =>
    run is RunCompleted && run.persisted ? run.sandboxSessionId : null;

int? contextualReviewId({required RunState run, required ReviewState review}) {
  if (run is! RunCompleted ||
      run.approvedContextFieldCount != 1 ||
      review is! ReviewLoaded ||
      review.sandboxSessionId != run.sandboxSessionId) {
    return null;
  }
  return parseSandboxDatabaseId(review.review.id);
}
