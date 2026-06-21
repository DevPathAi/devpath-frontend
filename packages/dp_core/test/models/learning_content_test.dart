import 'package:dp_core/dp_core.dart';
import 'package:test/test.dart';

void main() {
  test('LearningContent는 실 API camelCase 응답을 파싱한다', () {
    final content = LearningContent.fromJson({
      'id': 1,
      'slug': 'backend-spring-transaction-boundary',
      'title': '스프링 트랜잭션 경계 잡기',
      'track': 'BACKEND_SPRING',
      'markdown': '## 트랜잭션',
      'estimatedMinutes': 8,
      'difficulty': 0.5,
      'bloomLevel': 'APPLY',
      'conceptTags': ['spring-tx'],
      'progress': {
        'scrollPct': 0.42,
        'dwellSec': 73,
        'completed': false,
        'completedAt': null,
      },
    });

    expect(content.id, 1);
    expect(content.slug, 'backend-spring-transaction-boundary');
    expect(content.title, '스프링 트랜잭션 경계 잡기');
    expect(content.markdown, contains('트랜잭션'));
    expect(content.estimatedMinutes, 8);
    expect(content.difficulty, 0.5);
    expect(content.bloomLevel, 'APPLY');
    expect(content.conceptTags, ['spring-tx']);
    expect(content.progress.scrollPct, 0.42);
    expect(content.progress.dwellSec, 73);
    expect(content.progress.completed, isFalse);
    expect(content.progress.completedAt, isNull);
  });

  test('ContentProgressUpdateResponse는 완료 응답을 파싱한다', () {
    final response = ContentProgressUpdateResponse.fromJson({
      'scrollPct': 0.82,
      'dwellSec': 50,
      'completed': true,
      'completedAt': '2026-06-21T10:00:00Z',
    });

    expect(response.scrollPct, 0.82);
    expect(response.dwellSec, 50);
    expect(response.completed, isTrue);
    expect(response.completedAt, '2026-06-21T10:00:00Z');
  });
}
