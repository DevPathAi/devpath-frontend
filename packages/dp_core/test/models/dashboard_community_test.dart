import 'package:dp_core/src/models/community_post.dart';
import 'package:dp_core/src/models/dashboard_summary.dart';
import 'package:test/test.dart';

void main() {
  test('DashboardSummary 역직렬화', () {
    final d = DashboardSummary.fromJson({
      'streakDays': 7,
      'progressPercent': 62,
      'nextTaskTitle': '비동기 기초',
      'badges': ['첫 경로'],
    });
    expect(d.streakDays, 7);
    expect(d.progressPercent, 62);
    expect(d.nextTaskTitle, '비동기 기초');
    expect(d.badges, ['첫 경로']);
  });

  test('CommunityPost 역직렬화(상세 body 옵션)', () {
    final p = CommunityPost.fromJson({
      'id': 'q1',
      'title': 'async 질문',
      'author': '지수',
      'answerCount': 3,
    });
    expect(p.id, 'q1');
    expect(p.answerCount, 3);
    expect(p.body, isNull);
  });
}
