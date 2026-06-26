// named 파라미터를 private 필드에 대입(공유 web tracker와 동일 패턴).
// ignore_for_file: prefer_initializing_formals

/// 스크롤·체류 기반 학습 진척 추적기(순수 Dart, Flutter 무의존).
/// web `content_progress_tracker`와 동일 정책 — 다음 임계에서만 서버로 flush한다:
/// - 최초 [minInitialDwellSec]초 전에는 보고하지 않음(오발 방지)
/// - 직전 전송 대비 스크롤이 [scrollDeltaThreshold] 이상 진행
/// - 완료: 스크롤 [completionScrollThreshold] 이상 + 체류 [completionDwellSec]초 이상
library;

/// 서버로 보낼 진척 1건.
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

  /// 최신 스크롤·체류를 기록하고, 임계를 넘으면 flush 페이로드를 반환한다(아니면 null).
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

  /// 페이지 이탈 시 미전송 잔여 진척을 flush한다(변화 없으면 null).
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
