import 'package:dp_core/dp_core.dart';
import 'package:test/test.dart';

void main() {
  test('byType이 있는 응답을 파싱한다', () {
    final p = ProgressPoint.fromJson(const {
      'date': '2026-08-07',
      'percent': 50,
      'byType': {'READ': 50, 'PRACTICE': 0},
    });
    expect(p.date, '2026-08-07');
    expect(p.percent, 50);
    expect(p.byType['READ'], 50);
    expect(p.byType['PRACTICE'], 0);
  });

  test('byType이 없는 옛 응답도 깨지지 않는다', () {
    // 백엔드가 먼저 배포되지 않은 상태에서도 웹이 살아 있어야 한다.
    final p = ProgressPoint.fromJson(const {
      'date': '2026-08-07',
      'percent': 50,
    });
    expect(p.byType, isEmpty);
  });
}
