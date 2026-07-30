import 'package:dp_core/dp_core.dart';
import 'package:test/test.dart';

void main() {
  test('CommunityPostSummary.fromJson: boardType/replyCount 파싱', () {
    final s = CommunityPostSummary.fromJson({
      'id': 1,
      'boardType': 'FREE',
      'title': '자유글',
      'authorId': 42,
      'solved': false,
      'upvoteCount': 2,
      'replyCount': 3,
    });
    expect(s.boardType, 'FREE');
    expect(s.replyCount, 3);
  });

  test('CommunityPostDetail.fromJson: 댓글 스레드 파싱', () {
    final d = CommunityPostDetail.fromJson({
      'id': 5,
      'boardType': 'FEEDBACK',
      'title': '피드백',
      'bodyMd': '# 본문',
      'authorId': 7,
      'upvoteCount': 1,
      'downvoteCount': 0,
      'tags': ['dart'],
      'comments': [
        {
          'id': 10,
          'authorId': 8,
          'bodyMd': '댓글1',
          'upvoteCount': 0,
          'createdAt': '2026-07-29T00:00:00Z',
        },
      ],
    });
    expect(d.boardType, 'FEEDBACK');
    expect(d.tags, ['dart']);
    expect(d.comments.single.bodyMd, '댓글1');
  });
}
