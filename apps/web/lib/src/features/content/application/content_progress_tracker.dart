// ignore_for_file: prefer_initializing_formals

class ContentProgressFlush {
  const ContentProgressFlush({required this.scrollPct, required this.dwellSec});

  final double scrollPct;
  final int dwellSec;
}

class ContentProgressTracker {
  ContentProgressTracker({
    double initialScrollPct = 0,
    int initialDwellSec = 0,
    bool completed = false,
    this.minInitialDwellSec = 5,
    this.scrollDeltaThreshold = 0.1,
    this.completionScrollThreshold = 0.8,
    this.completionDwellSec = 45,
  }) : _lastSentScrollPct = initialScrollPct,
       _lastSentDwellSec = initialDwellSec,
       _latestScrollPct = initialScrollPct,
       _latestDwellSec = initialDwellSec,
       _completed = completed;

  final int minInitialDwellSec;
  final double scrollDeltaThreshold;
  final double completionScrollThreshold;
  final int completionDwellSec;

  double _lastSentScrollPct;
  int _lastSentDwellSec;
  double _latestScrollPct;
  int _latestDwellSec;
  bool _completed;

  ContentProgressFlush? record({
    required double scrollPct,
    required int dwellSec,
  }) {
    if (_completed) return null;
    _latestScrollPct = scrollPct.clamp(0, 1).toDouble();
    _latestDwellSec = dwellSec < 0 ? 0 : dwellSec;
    if (_latestDwellSec < minInitialDwellSec) return null;

    final reachedCompletion =
        _latestScrollPct >= completionScrollThreshold &&
        _latestDwellSec >= completionDwellSec;
    final advancedEnough =
        _latestScrollPct - _lastSentScrollPct >= scrollDeltaThreshold;

    if (reachedCompletion || advancedEnough) {
      return _flush();
    }
    return null;
  }

  ContentProgressFlush? disposeFlush() {
    if (_completed) return null;
    if (_latestScrollPct == _lastSentScrollPct &&
        _latestDwellSec == _lastSentDwellSec) {
      return null;
    }
    return _flush();
  }

  void markCompleted() {
    _completed = true;
  }

  ContentProgressFlush _flush() {
    _lastSentScrollPct = _latestScrollPct;
    _lastSentDwellSec = _latestDwellSec;
    return ContentProgressFlush(
      scrollPct: _lastSentScrollPct,
      dwellSec: _lastSentDwellSec,
    );
  }
}
