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

  test('CommunityPostSummary 역직렬화(목록 메타·authorId 논리참조)', () {
    final p = CommunityPostSummary.fromJson({
      'id': 1,
      'title': 'async 질문',
      'authorId': 42,
      'solved': false,
      'upvoteCount': 3,
      'answerCount': 2,
    });
    expect(p.id, 1);
    expect(p.title, 'async 질문');
    expect(p.authorId, 42);
    expect(p.solved, isFalse);
    expect(p.upvoteCount, 3);
    expect(p.answerCount, 2);
  });

  test('CommunityQuestionDetail 역직렬화(답변 스레드·AI 뱃지 플래그)', () {
    final q = CommunityQuestionDetail.fromJson({
      'id': 1,
      'title': 'async 질문',
      'bodyMd': '# 본문',
      'solved': true,
      'acceptedAnswerId': 11,
      'upvoteCount': 5,
      'downvoteCount': 1,
      'tags': ['dart', 'async'],
      'answers': [
        {
          'id': 10,
          'authorId': null,
          'bodyMd': 'AI 초안 답변',
          'aiGenerated': true,
          'accepted': false,
          'upvoteCount': 0,
        },
        {
          'id': 11,
          'authorId': 7,
          'bodyMd': '사람 답변',
          'aiGenerated': false,
          'accepted': true,
          'upvoteCount': 4,
        },
      ],
    });
    expect(q.id, 1);
    expect(q.bodyMd, '# 본문');
    expect(q.solved, isTrue);
    expect(q.acceptedAnswerId, 11);
    expect(q.tags, ['dart', 'async']);
    expect(q.answers, hasLength(2));
    // AI 시드 답변: authorId=null + aiGenerated=true
    expect(q.answers[0].aiGenerated, isTrue);
    expect(q.answers[0].authorId, isNull);
    // 채택된 인간 답변
    expect(q.answers[1].accepted, isTrue);
    expect(q.answers[1].authorId, 7);
  });

  test('CommunityQuestionDetail: tags/answers 누락 시 빈 목록 기본값', () {
    final q = CommunityQuestionDetail.fromJson({
      'id': 2,
      'title': '태그 없는 질문',
      'bodyMd': '본문',
    });
    expect(q.tags, isEmpty);
    expect(q.answers, isEmpty);
    expect(q.solved, isFalse);
    expect(q.acceptedAnswerId, isNull);
  });

  test('SimilarQuestion 역직렬화(questionId)', () {
    final s = SimilarQuestion.fromJson({'questionId': 9, 'title': '비슷한 질문'});
    expect(s.questionId, 9);
    expect(s.title, '비슷한 질문');
  });

  test('CommunityTag 역직렬화(postCount)', () {
    final t = CommunityTag.fromJson({
      'id': 3,
      'name': 'spring',
      'postCount': 12,
    });
    expect(t.id, 3);
    expect(t.name, 'spring');
    expect(t.postCount, 12);
  });
}
