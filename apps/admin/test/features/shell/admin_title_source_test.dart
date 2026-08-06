import 'package:devpath_admin/src/features/shell/presentation/admin_shell.dart';
import 'package:flutter_test/flutter_test.dart';

/// admin 화면 제목의 **단일 출처** 계약.
///
/// 이전에는 셸의 private `_headerTitleFor`와 5화면의 문자열 리터럴이 따로
/// 존재해, 한쪽만 고치면 브레드크럼과 페이지 헤더가 조용히 어긋났다.
/// 각 화면 테스트도 리터럴 대신 [adminHeaderTitleFor]를 기대값으로 쓰므로,
/// 상수만 바꾸고 화면을 안 고치면(또는 그 반대면) 그쪽에서 red가 난다.
void main() {
  test('모든 admin 목적지가 headerTitle을 갖는다', () {
    for (final d in kAdminDestinations) {
      expect(d.headerTitle, isNotEmpty, reason: '${d.path}에 headerTitle이 없다');
    }
  });

  test('경로로 headerTitle을 조회할 수 있다', () {
    expect(adminHeaderTitleFor('/dashboard'), '운영 대시보드');
    expect(adminHeaderTitleFor('/users'), '사용자 관리');
    expect(adminHeaderTitleFor('/reports'), '신고 처리');
    expect(adminHeaderTitleFor('/support'), '오류 신고·문의');
    expect(adminHeaderTitleFor('/ads'), '광고 관리');
  });

  test('하위 경로도 상위 목적지의 제목으로 해석된다', () {
    // _index와 같은 startsWith 규칙이어야 브레드크럼과 헤더가 함께 움직인다.
    expect(adminHeaderTitleFor('/reports/42'), '신고 처리');
  });

  test('알 수 없는 경로는 대시보드로 폴백한다', () {
    expect(adminHeaderTitleFor('/unknown'), '운영 대시보드');
    expect(
      adminHeaderTitleFor('/unknown'),
      kAdminDestinations.first.headerTitle,
    );
  });

  test('제목이 목적지 사이에서 중복되지 않는다', () {
    // 중복이 있으면 어느 화면을 보고 있는지 브레드크럼으로 구분할 수 없다.
    final titles = kAdminDestinations.map((d) => d.headerTitle).toList();
    expect(titles.toSet().length, titles.length);
  });
}
