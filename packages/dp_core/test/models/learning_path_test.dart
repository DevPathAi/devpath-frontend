import 'package:dp_core/src/models/learning_path.dart';
import 'package:test/test.dart';

void main() {
  test('LearningPath JSON 역직렬화(주차·과제·rationale)', () {
    final path = LearningPath.fromJson({
      'rationale': 'GitHub 분석 결과 비동기 보강 필요',
      'weeks': [
        {
          'week': 1,
          'title': '비동기 기초',
          'tasks': [
            {'title': 'Future 정리', 'done': false},
            {'title': 'Stream 실습', 'done': true},
          ],
        },
        {'week': 2, 'title': '주차 2', 'tasks': <Map<String, dynamic>>[]},
      ],
    });

    expect(path.rationale, contains('비동기'));
    expect(path.weeks, hasLength(2));
    expect(path.weeks.first.week, 1);
    expect(path.weeks.first.tasks, hasLength(2));
    expect(path.weeks.first.tasks[1].done, isTrue);
    expect(path.weeks[1].tasks, isEmpty); // 기본값
  });
}
