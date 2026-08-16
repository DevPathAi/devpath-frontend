import 'package:dp_design/dp_design.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('학습 track/task/status wire 값은 사용자 label로만 노출한다', () {
    expect(DpLearningLabels.track('BACKEND_SPRING'), '백엔드 · Spring');
    expect(DpLearningLabels.taskType('READ'), '읽기');
    expect(DpLearningLabels.taskType('PRACTICE'), '실습');
    expect(DpLearningLabels.taskType('QUIZ'), '확인');
    expect(DpLearningLabels.syncStatus('SYNC_PENDING'), '동기화 대기');
    expect(DpLearningLabels.track('NEW_TRACK'), '학습 경로');
  });

  test('Bloom/difficulty wire values never leak into learner copy', () {
    expect(DpLearningLabels.bloomLevel('APPLY'), '적용하기');
    expect(DpLearningLabels.bloomLevel('FUTURE_VALUE'), '학습하기');
    expect(DpLearningLabels.difficulty(0.2), '입문');
    expect(DpLearningLabels.difficulty(0.5), '중급');
    expect(DpLearningLabels.difficulty(0.9), '심화');
  });
}
