import 'package:dp_core/src/models/learning_path.dart';
import 'package:test/test.dart';

void main() {
  test('LearningPath JSON 역직렬화(milestones·diagnosis·tasks)', () {
    final path = LearningPath.fromJson({
      'pathId': 101,
      'track': 'BACKEND',
      'totalWeeks': 12,
      'rationale': 'GitHub 분석 결과 비동기 보강 필요',
      'diagnosis': {
        'diagnosedLevel': 'MID',
        'strengthConcepts': ['HTTP', '테스트'],
        'weaknessConcepts': ['비동기', '트랜잭션'],
      },
      'milestones': [
        {
          'weekNum': 1,
          'title': '비동기 기초',
          'goalDescription': 'Future와 Stream의 차이를 설명하고 적용한다.',
          'targetSkills': ['Future', 'Stream'],
          'estimatedHours': 4,
          'whyThisOrder': '비동기 약점을 먼저 보강해야 합니다.',
          'expectedOutcome': '간단한 비동기 API를 안정적으로 작성할 수 있다.',
          'locked': false,
          'tasks': [
            {
              'orderNum': 1,
              'taskType': 'READ',
              'title': 'Future 정리',
              'required': true,
              'contentId': 11,
              'contentSlug': 'future-basics',
              'completed': false,
            },
            {
              'orderNum': 2,
              'taskType': 'PRACTICE',
              'title': 'Stream 실습',
              'required': true,
              'contentId': null,
              'contentSlug': null,
              'completed': true,
            },
            {
              'orderNum': 3,
              'taskType': 'QUIZ',
              'title': '비동기 퀴즈',
              'required': false,
              'contentId': 13,
              'contentSlug': 'async-quiz',
              'completed': false,
            },
          ],
        },
        {
          'weekNum': 2,
          'title': '주차 2',
          'goalDescription': '트랜잭션 경계를 이해한다.',
          'targetSkills': ['Transaction'],
          'estimatedHours': 3,
          'whyThisOrder': '기초 이후 영속성 안정성을 다룹니다.',
          'expectedOutcome': '서비스 트랜잭션 경계를 설명할 수 있다.',
          'locked': true,
          'tasks': <Map<String, dynamic>>[],
        },
      ],
    });

    expect(path.pathId, 101);
    expect(path.track, 'BACKEND');
    expect(path.totalWeeks, 12);
    expect(path.rationale, contains('비동기'));
    expect(path.diagnosis!.diagnosedLevel, 'MID');
    expect(path.diagnosis!.strengthConcepts, contains('HTTP'));
    expect(path.diagnosis!.weaknessConcepts, contains('트랜잭션'));
    expect(path.milestones, hasLength(2));
    expect(path.milestones.first.weekNum, 1);
    expect(path.milestones.first.expectedOutcome, contains('API'));
    expect(path.milestones.first.tasks, hasLength(3));
    expect(path.milestones.first.tasks[1].completed, isTrue);
    expect(path.milestones[1].locked, isTrue);
    expect(path.milestones[1].tasks, isEmpty);
  });
}
