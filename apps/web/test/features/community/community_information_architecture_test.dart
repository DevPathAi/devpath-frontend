import 'package:devpath_web/src/features/community/state/community_state.dart';
import 'package:devpath_web/src/features/shell/presentation/app_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('사용자에게 노출할 커뮤니티 보드는 자유게시판, Q/A, 피드백 순서다', () {
    expect(
      CommunityBoard.values
          .where((board) => board != CommunityBoard.all)
          .map((board) => board.label),
      ['자유게시판', 'Q/A', '피드백'],
    );
  });

  test('셸은 커뮤니티 아래 세 게시판을 드롭다운 자식으로 노출한다', () {
    expect(
      kWebNavItems
          .firstWhere((item) => item.id == '/community')
          .children
          .map((child) => child.label),
      ['자유게시판', 'Q/A', '피드백'],
    );
  });

  test('커뮤니티 브레드크럼은 현재 게시판 계층을 명시한다', () {
    expect(breadcrumbFor('/community'), const [
      (label: '커뮤니티', path: null),
      (label: '자유게시판', path: null),
    ]);
    expect(breadcrumbFor('/community/12'), const [
      (label: '커뮤니티', path: null),
      (label: 'Q/A', path: '/community?board=QNA'),
      (label: '게시글', path: null),
    ]);
  });
}
