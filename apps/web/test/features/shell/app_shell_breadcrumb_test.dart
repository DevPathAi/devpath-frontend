import 'package:devpath_web/src/features/shell/presentation/app_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('최상위 화면은 [섹션, 페이지]', () {
    expect(breadcrumbFor('/dashboard'), const [
      (label: '학습', path: null),
      (label: '오늘', path: null),
    ]);
  });

  test('canonical Today와 mission child는 Today 위치를 유지한다', () {
    expect(breadcrumbFor('/path/301/today'), const [
      (label: '학습', path: null),
      (label: '오늘', path: null),
    ]);
    expect(breadcrumbFor('/mission/302/content/77'), const [
      (label: '학습', path: null),
      (label: '오늘', path: '/dashboard'),
      (label: '학습 콘텐츠', path: null),
    ]);
    expect(breadcrumbFor('/mission/302/sandbox'), const [
      (label: '학습', path: null),
      (label: '오늘', path: '/dashboard'),
      (label: '실습 샌드박스', path: null),
    ]);
  });

  test('커뮤니티 하위 화면은 게시판 세그먼트가 클릭 가능', () {
    expect(breadcrumbFor('/community/post/12'), const [
      (label: '커뮤니티', path: null),
      (label: '게시판', path: '/community'),
      (label: '게시글', path: null),
    ]);
  });

  test('커뮤니티 홈 자신은 게시판 세그먼트가 마지막', () {
    expect(breadcrumbFor('/community'), const [
      (label: '커뮤니티', path: null),
      (label: '게시판', path: '/community'),
    ]);
  });

  test('계정 화면은 라우트 없는 섹션을 쓴다', () {
    expect(breadcrumbFor('/settings'), const [
      (label: '계정', path: null),
      (label: '설정', path: null),
    ]);
  });

  test('알 수 없는 경로는 빈 브레드크럼(크롬바 렌더 여부는 셸이 chromeActions 등과 함께 결정)', () {
    expect(breadcrumbFor('/unknown'), isEmpty);
  });

  test('/community/new/post는 /community/new보다 먼저 매칭된다', () {
    expect(breadcrumbFor('/community/new/post').last.label, '새 글');
    expect(breadcrumbFor('/community/new').last.label, '질문하기');
  });
}
