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
    expect(breadcrumbFor('/mission/302/mentor'), const [
      (label: '학습', path: null),
      (label: '오늘', path: '/dashboard'),
      (label: 'AI 멘토', path: null),
    ]);
  });

  test('커뮤니티 하위 화면은 게시판 세그먼트가 클릭 가능', () {
    expect(breadcrumbFor('/community/post/12?board=FREE'), const [
      (label: '커뮤니티', path: null),
      (label: '자유게시판', path: '/community?board=FREE'),
      (label: '게시글', path: null),
    ]);
  });

  test('커뮤니티 홈은 현재 게시판을 두 번째 세그먼트로 쓴다', () {
    expect(breadcrumbFor('/community?board=FEEDBACK'), const [
      (label: '커뮤니티', path: null),
      (label: '피드백', path: null),
    ]);
  });

  test('계정 화면은 라우트 없는 섹션을 쓴다', () {
    expect(breadcrumbFor('/settings'), const [
      (label: '계정', path: null),
      (label: '설정', path: null),
    ]);
  });

  test('알 수 없는 경로는 빈 브레드크럼(DpBreadcrumb 이 자리를 차지하지 않는다)', () {
    expect(breadcrumbFor('/unknown'), isEmpty);
  });

  test('/community/new/post는 /community/new보다 먼저 매칭된다', () {
    expect(breadcrumbFor('/community/new/post').last.label, '새 글');
    expect(breadcrumbFor('/community/new').last.label, '질문하기');
  });
}
