import 'package:devpath_web/src/features/community/state/community_state.dart';
import 'package:devpath_web/src/features/shell/presentation/app_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('커뮤니티 보드는 자유게시판, Q/A, 피드백 순서와 명칭을 쓴다', () {
    expect(CommunityBoard.values.map((board) => board.label), [
      '전체',
      '자유게시판',
      'Q/A',
      '피드백',
    ]);
  });

  test('셸은 게시판이 아니라 커뮤니티를 최상위 목적지로 노출한다', () {
    expect(
      kShellDestinations.singleWhere((item) => item.path == '/community').label,
      '커뮤니티',
    );
  });

  test('커뮤니티 브레드크럼은 중복 게시판 계층을 만들지 않는다', () {
    expect(breadcrumbFor('/community'), const [(label: '커뮤니티', path: null)]);
    expect(breadcrumbFor('/community/12'), const [
      (label: '커뮤니티', path: '/community'),
      (label: 'Q/A', path: null),
    ]);
  });
}
