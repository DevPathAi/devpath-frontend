enum PathAnalyticsBranch { generated, existing }

class PathAnalyticsHandoff {
  const PathAnalyticsHandoff({
    required this.branch,
    required this.userId,
    this.assessmentId,
    this.guestId,
  });

  final PathAnalyticsBranch branch;
  final String userId;
  final int? assessmentId;
  final String? guestId;
}

/// Keeps the diagnostic-to-path analytics context in memory until the exact
/// path load succeeds. Diagnostic continuation storage deliberately remains
/// free of analytics-only identifiers.
class PathAnalyticsHandoffStore {
  PathAnalyticsHandoff? _pending;

  void stage(PathAnalyticsHandoff handoff) {
    _pending = handoff;
  }

  PathAnalyticsHandoff? takeForUser(String userId) {
    final pending = _pending;
    _pending = null;
    if (pending?.userId != userId) return null;
    return pending;
  }

  void clear() {
    _pending = null;
  }
}
