import 'package:devpath_web/src/data/web_mock_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mockCommunityPosts 는 게시판별 결정적 게시글을 GET /community/posts 픽스처에서 만든다', () {
    final free = mockCommunityPosts('FREE');
    final qna = mockCommunityPosts('QNA');
    final feedback = mockCommunityPosts('FEEDBACK');
    expect(free.map((p) => p.id), [10]);
    expect(qna.map((p) => p.id), [1]);
    expect(feedback.map((p) => p.id), [20]);
    expect(qna.single.solved, isTrue);
    expect(free.single.boardType, 'FREE');
    expect(mockCommunityPosts('NOPE'), isEmpty);
  });
}
