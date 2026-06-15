import 'package:devpath_web/src/features/sandbox/state/run_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('append는 로그 라인을 누적한다', () {
    const s = RunRunning(logs: ['a']);
    expect(s.appended('b').logs, ['a', 'b']);
  });
}
