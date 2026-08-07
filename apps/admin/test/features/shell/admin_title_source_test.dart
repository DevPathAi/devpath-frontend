import 'dart:io';

import 'package:devpath_admin/src/features/shell/presentation/admin_shell.dart';
import 'package:flutter_test/flutter_test.dart';

/// admin 화면 제목의 **단일 출처** 계약.
///
/// 이전에는 셸의 private `_headerTitleFor`와 5화면의 문자열 리터럴이 따로
/// 존재해, 한쪽만 고치면 브레드크럼과 페이지 헤더가 조용히 어긋났다.
///
/// **방어의 두 방향은 담당이 다르다:**
/// - *상수를 바꾸고 화면을 안 고치는* 방향 → 각 화면 테스트의 **리터럴** 기대값이
///   red를 낸다(`expect(header.title, '광고 관리')`).
/// - *화면이 상수 대신 리터럴을 다시 박는* 방향 → 위젯 출력만 보는 단언으로는
///   **잡히지 않는다.** 리터럴 값이 상수와 같으면 `header.title`과
///   `adminHeaderTitleFor(...)`가 같은 값이라 두 단언 모두 green이다
///   (실측: `ads_page`의 `title`을 `'광고 관리'` 리터럴로 되돌려도 `ads_page_test` 5/5 통과).
///   이 방향은 아래 「화면 소스가 제목 리터럴을 직접 쓰지 않는다」가 소스 텍스트로 막는다.
///
/// **소스 검사의 범위는 5개 화면 파일이다.** `admin_shell.dart`는 `kAdminDestinations`
/// 정의부라 리터럴을 당연히 가지므로 스캔 대상이 아니고, 따라서 **셸의 브레드크럼
/// 조립부(`AdminShellView.build`)는 이 가드가 덮지 않는다** — 그쪽은 `admin_shell_view_test`의
/// 리터럴 단언(값 변경 방향)만 걸려 있다.
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

  // ★배선 회귀 가드★ — 위 doc 주석 참조. 화면이 `adminHeaderTitleFor` 대신 같은
  // 값의 리터럴을 다시 박으면 위젯 단언들은 전부 green이므로, 소스 텍스트에서 막는다.
  test('화면 소스가 헤더 제목 리터럴을 직접 쓰지 않는다', () {
    const pageSources = <String, String>{
      '/dashboard':
          'lib/src/features/dashboard/presentation/dashboard_page.dart',
      '/users': 'lib/src/features/users/presentation/users_page.dart',
      '/reports': 'lib/src/features/reports/presentation/reports_page.dart',
      '/support': 'lib/src/features/support/presentation/support_page.dart',
      '/ads': 'lib/src/features/ads/presentation/ads_page.dart',
    };

    // 목적지가 늘었는데 검사 대상을 안 늘리면 새 화면이 무방비로 남는다.
    expect(
      pageSources.keys.toSet(),
      kAdminDestinations.map((d) => d.path).toSet(),
      reason: '검사 대상 화면 목록이 kAdminDestinations와 어긋난다',
    );

    final titles = kAdminDestinations.map((d) => d.headerTitle).toList();
    for (final e in pageSources.entries) {
      final file = File(e.value);
      // 경로가 틀리면 아무것도 검사하지 못한 채 통과한다 — 전제부터 잠근다.
      expect(file.existsSync(), isTrue, reason: '${e.value}를 찾지 못했다');
      final src = file.readAsStringSync();
      for (final t in titles) {
        // 작은따옴표만 보면 `"광고 관리"`로 재도입했을 때 조용히 통과한다.
        // `prefer_single_quotes`는 이 레포에서 비활성이고(admin·web·mobile 모두
        // analysis_options.yaml에서 주석 처리) `dart format`도 따옴표를 정규화하지
        // 않으므로, 그 경로는 실제로 열려 있다. 둘 다 막는다.
        expect(
          src.contains("'$t'") || src.contains('"$t"'),
          isFalse,
          reason: "${e.value}가 제목 리터럴 '$t'을 직접 쓴다 — adminHeaderTitleFor를 써라",
        );
      }
    }
  });

  test('제목이 목적지 사이에서 중복되지 않는다', () {
    // 중복이 있으면 어느 화면을 보고 있는지 브레드크럼으로 구분할 수 없다.
    final titles = kAdminDestinations.map((d) => d.headerTitle).toList();
    expect(titles.toSet().length, titles.length);
  });
}
