import 'package:dp_core/src/models/assessment.dart';
import 'package:test/test.dart';

void main() {
  test('NextQuestion 역직렬화', () {
    final n = NextQuestion.fromJson({
      'question': {
        'id': 7,
        'type': 'MCQ',
        'content': '스프링 빈 스코프?',
        'options': '["singleton","prototype"]',
        'bloomLevel': 'UNDERSTAND',
        'difficulty': 0.3,
      },
      'index': 3,
      'total': 15,
    });
    expect(n.question.id, 7);
    expect(n.total, 15);
    expect(n.question.bloomLevel, 'UNDERSTAND');
  });

  test('AssessmentResult 역직렬화', () {
    final r = AssessmentResult.fromJson({
      'diagnosedLevel': 'MID',
      'confidenceWeight': 0.8,
    });
    expect(r.diagnosedLevel, 'MID');
    expect(r.confidenceWeight, 0.8);
  });
}
