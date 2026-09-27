import 'package:devpath_web/src/features/shell/presentation/app_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('게시판 사이 이동은 q 를 들고 간다', () {
    expect(
      carryCommunityQuery(
        location: '/community?board=FREE&q=stream',
        targetId: '/community?board=QNA',
      ),
      '/community?board=QNA&q=stream',
    );
  });

  test('q 가 없으면 목적지를 그대로 쓴다', () {
    expect(
      carryCommunityQuery(
        location: '/community?board=FREE',
        targetId: '/community?board=QNA',
      ),
      '/community?board=QNA',
    );
  });

  test('커뮤니티 밖으로 나가면 q 를 버린다', () {
    expect(
      carryCommunityQuery(
        location: '/community?board=FREE&q=stream',
        targetId: '/path',
      ),
      '/path',
    );
  });

  test('커뮤니티 밖에서 들어올 때는 q 가 없다', () {
    expect(
      carryCommunityQuery(location: '/path', targetId: '/community?board=QNA'),
      '/community?board=QNA',
    );
  });

  test('상세 화면에서 목록으로 갈 때도 q 를 들고 가지 않는다', () {
    // 상세(`/community/1`)에는 q 가 없으므로 붙일 것이 없다.
    expect(
      carryCommunityQuery(
        location: '/community/1',
        targetId: '/community?board=QNA',
      ),
      '/community?board=QNA',
    );
  });

  test('목적지에 이미 q 가 있으면 덮어쓰지 않는다', () {
    expect(
      carryCommunityQuery(
        location: '/community?board=FREE&q=stream',
        targetId: '/community?board=QNA&q=future',
      ),
      '/community?board=QNA&q=future',
    );
  });

  test('빈 q 는 붙이지 않는다 — 검색을 지운 상태다', () {
    expect(
      carryCommunityQuery(
        location: '/community?board=FREE&q=',
        targetId: '/community?board=QNA',
      ),
      '/community?board=QNA',
    );
  });
}
