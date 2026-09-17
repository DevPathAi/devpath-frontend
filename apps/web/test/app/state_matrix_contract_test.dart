import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// N02 상태 matrix 계약. 8개 화면 소스가 공용 상태 primitive 를 우회해
/// 원시 spinner 나 손으로 만든 danger 배너로 되돌아가지 못하게 잠근다.
/// 사람이 읽는 표는 `docs/design/app-state-matrix.md`.
const _pages = <String>[
  'lib/src/features/auth/presentation/login_page.dart',
  'lib/src/features/auth/presentation/auth_callback_page.dart',
  'lib/src/features/diagnostic/presentation/diagnostic_page.dart',
  'lib/src/features/dashboard/presentation/dashboard_page.dart',
  'lib/src/features/dashboard/presentation/widgets/today_mission_section.dart',
  'lib/src/features/path/presentation/path_page.dart',
  'lib/src/features/path/presentation/mission_path_plan_view.dart',
  'lib/src/features/community/presentation/community_home_page.dart',
  'lib/src/features/community/presentation/post_detail_page.dart',
  'lib/src/features/community/presentation/qna_detail_page.dart',
  'lib/src/features/content/presentation/content_page.dart',
  'lib/src/features/sandbox/presentation/sandbox_page.dart',
  'lib/src/features/mentor/presentation/mentor_page.dart',
];

void main() {
  test('화면 소스는 전체화면 원시 spinner 대신 DpLoading 을 쓴다', () {
    for (final path in _pages) {
      final source = File(path).readAsStringSync();
      expect(
        source.contains('Center(child: CircularProgressIndicator())'),
        isFalse,
        reason: '$path 는 전체화면 원시 spinner 를 쓰면 안 된다',
      );
    }
  });

  test('화면 소스는 손으로 만든 danger 배너 대신 DpInlineNotice 를 쓴다', () {
    for (final path in _pages) {
      final source = File(path).readAsStringSync();
      expect(
        source.contains('danger.withValues(alpha: 0.08)'),
        isFalse,
        reason: '$path 는 인라인 실패를 DpInlineNotice 로 표현해야 한다',
      );
    }
  });

  test('Q/A 상세의 전체화면 실패 상태는 재시도 행동을 가진다', () {
    final source = File(
      'lib/src/features/community/presentation/qna_detail_page.dart',
    ).readAsStringSync();
    expect(source.contains('SupportableError(message: message)'), isFalse);
  });
}
