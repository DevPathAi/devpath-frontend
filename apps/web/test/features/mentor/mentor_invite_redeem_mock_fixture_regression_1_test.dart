import 'package:devpath_web/src/data/web_mock_fixtures.dart';
import 'package:devpath_web/src/features/mentor/state/mentor_access_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Regression: ISSUE-004 — mock invite redemption fell through to terminal 404.
  // Found by /qa on 2026-09-08.
  // Report: .gstack/qa-reports/qa-report-127.0.0.1-2026-09-08.md
  test('기본 목 픽스처는 파싱 가능한 초대 교환 성공 응답을 제공한다', () {
    final fixture = webMockFixtures['POST /mentor-access/redeem'];

    expect(fixture, isNotNull);
    final (status, body) = fixture!;
    expect(status, inInclusiveRange(200, 299));

    final access = MentorAccessReady.fromJson(
      (body as Map).cast<String, dynamic>(),
    );
    expect(access.status, 'ACTIVE');
    expect(access.source, 'INVITE_CODE');
    expect(access.isActive, isTrue);
    expect(access.activatedAt, isNotNull);
  });
}
