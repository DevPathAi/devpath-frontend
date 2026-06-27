import 'package:devpath_mobile/src/features/learning/application/content_progress_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('최초 렌더 후 5초 전에는 flush하지 않는다', () {
    final tracker = ContentProgressTracker();

    final flush = tracker.record(scrollPct: 0.2, dwellSec: 4);

    expect(flush, isNull);
  });

  test('scrollPct가 마지막 전송 대비 0.1 이상 증가하면 flush한다', () {
    final tracker = ContentProgressTracker();

    final flush = tracker.record(scrollPct: 0.12, dwellSec: 5);

    expect(flush, isNotNull);
    expect(flush?.scrollPct, 0.12);
    expect(flush?.dwellSec, 5);
  });

  test('완료 임계값(스크롤 0.8 + 체류 45초)에 도달하면 flush한다', () {
    final tracker = ContentProgressTracker();

    final flush = tracker.record(scrollPct: 0.8, dwellSec: 45);

    expect(flush, isNotNull);
    expect(flush?.scrollPct, 0.8);
    expect(flush?.dwellSec, 45);
  });

  test('dispose 시 마지막 값을 flush한다', () {
    final tracker = ContentProgressTracker();
    tracker.record(scrollPct: 0.04, dwellSec: 8);

    final flush = tracker.disposeFlush();

    expect(flush, isNotNull);
    expect(flush?.scrollPct, 0.04);
    expect(flush?.dwellSec, 8);
  });

  test('이미 completed면 추가 flush하지 않는다', () {
    final tracker = ContentProgressTracker(completed: true);

    expect(tracker.record(scrollPct: 1, dwellSec: 100), isNull);
    expect(tracker.disposeFlush(), isNull);
  });
}
