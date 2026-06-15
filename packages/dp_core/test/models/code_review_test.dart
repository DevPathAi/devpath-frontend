import 'package:dp_core/src/models/code_review.dart';
import 'package:test/test.dart';

void main() {
  test('CodeReview JSON 역직렬화(신뢰도·잘한점·개선[라인·심각도]·보안)', () {
    final r = CodeReview.fromJson({
      'confidence': 82,
      'strengths': ['명확한 함수 분리'],
      'improvements': [
        {'line': 12, 'severity': 'warning', 'message': 'null 체크 누락'},
      ],
      'security': [
        {'severity': 'error', 'message': '입력 검증 없음'},
      ],
    });
    expect(r.confidence, 82);
    expect(r.strengths, ['명확한 함수 분리']);
    expect(r.improvements.first.line, 12);
    expect(r.improvements.first.severity, 'warning');
    expect(r.security.first.line, isNull); // 기본 nullable
  });

  test('F6-e 비동기 폴링 자리 선확보: id·status 기본 nullable', () {
    final r = CodeReview.fromJson({'confidence': 50});
    expect(r.id, isNull); // 후속 폴링 전환 대비(동기 프로토에선 미사용)
    expect(r.status, isNull);
  });
}
