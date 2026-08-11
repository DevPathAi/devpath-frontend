import 'package:devpath_web/src/data/web_mock_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';

/// 목 데이터의 12주가 전부 0%라, 진행분이 있는 막대를 화면 캡처로 확인할 수
/// 없었다(3-B 보고서 §6). 위젯 테스트는 100/50/0%를 자체 헬퍼로 덮고 있으므로
/// 이건 동작이 아니라 **목 데이터의 표현력** 문제다.
///
/// 진행률 계산은 `완료 과제 수 / 전체 과제 수`이므로, 과제가 없는 주차는 0%다.
double _percentOf(Map<String, dynamic> milestone) {
  final tasks = (milestone['tasks'] as List).cast<Map<String, dynamic>>();
  if (tasks.isEmpty) return 0;
  final done = tasks.where((t) => t['completed'] == true).length;
  return done * 100.0 / tasks.length;
}

void main() {
  final milestones = mockLearningPath()['milestones'] as List;
  final percents = milestones
      .cast<Map<String, dynamic>>()
      .map(_percentOf)
      .toList();

  test('진행분이 있는 주차가 있다', () {
    expect(
      percents.any((p) => p > 0),
      isTrue,
      reason: '전부 0%면 막대가 하나도 그려지지 않아 캡처로 확인할 수 없다: $percents',
    );
  });

  test('서로 다른 높이의 막대가 나온다', () {
    expect(
      percents.toSet().length,
      greaterThan(1),
      reason: '값이 하나뿐이면 막대 차이를 볼 수 없다: $percents',
    );
  });

  // 「이번 주 과제」에서 눌러 콘텐츠로 이동하는 시나리오가 이 과제에 걸려 있다
  // (픽스처 GET /contents/async-error-handling 주석 참조). 완료로 바꾸면 그
  // 시나리오를 목으로 재현할 수 없으므로 미완료로 남긴다.
  test('1주차 퀴즈 과제는 미완료로 남는다', () {
    final week1 = milestones.first as Map<String, dynamic>;
    final quiz = (week1['tasks'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((t) => t['contentSlug'] == 'async-error-handling');

    expect(quiz['completed'], isFalse);
  });
}
