import 'package:dp_core/dp_core.dart';
import 'package:test/test.dart';

void main() {
  group('비석 역직렬화', () {
    test('답변: bodyMd·authorId 가 명시적 null 이어도 깨지지 않는다', () {
      final a = CommunityAnswer.fromJson(const {
        'id': 11,
        'authorId': null,
        'bodyMd': null,
        'aiGenerated': false,
        'accepted': false,
        'upvoteCount': 3,
        'deleted': true,
      });

      expect(a.deleted, isTrue);
      expect(a.authorId, isNull);
      expect(a.bodyMd, '');
      // 집계는 남는다 — 작성자 삭제는 평판을 유지하기로 했으므로 일관된다.
      expect(a.upvoteCount, 3);
    });

    test('댓글: 같은 계약', () {
      final c = CommunityComment.fromJson(const {
        'id': 5,
        'authorId': null,
        'bodyMd': null,
        'upvoteCount': 0,
        'createdAt': '2026-08-21T00:00:00Z',
        'deleted': true,
      });

      expect(c.deleted, isTrue);
      expect(c.bodyMd, '');
      // 작성 시각은 남긴다 — 스레드 순서가 보이지 않으면 비석의 의미가 없다.
      expect(c.createdAt, '2026-08-21T00:00:00Z');
    });

    test('deleted 키가 없으면 false 다 — 옛 응답과 호환된다', () {
      final a = CommunityAnswer.fromJson(const {'id': 1, 'bodyMd': 'b'});
      expect(a.deleted, isFalse);
      expect(a.bodyMd, 'b');
    });

    test('질문 상세가 작성자 id 를 싣는다', () {
      final q = CommunityQuestionDetail.fromJson(const {
        'id': 1,
        'title': 't',
        'bodyMd': 'b',
        'authorId': 7,
      });
      expect(q.authorId, 7);
    });
  });
}
