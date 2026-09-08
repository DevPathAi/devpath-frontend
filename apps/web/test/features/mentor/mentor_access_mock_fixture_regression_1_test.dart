import 'package:devpath_web/src/data/web_mock_fixtures.dart';
import 'package:devpath_web/src/features/mentor/state/mentor_access_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Regression: ISSUE-001 — 기본 목 실행에서 멘토 상태 픽스처가 없어 오류 화면이 노출됨
  // Found by /qa on 2026-09-08
  // Report: .gstack/qa-reports/qa-report-127.0.0.1-2026-09-08.md
  test('기본 목 픽스처는 파싱 가능한 멘토 대기 상태를 제공한다', () {
    final fixture = webMockFixtures['GET /mentor-access/me'];

    expect(fixture, isNotNull);
    final (status, body) = fixture!;
    expect(status, inInclusiveRange(200, 299));

    final access = MentorAccessReady.fromJson(
      (body as Map).cast<String, dynamic>(),
    );
    expect(access.status, 'WAITLISTED');
    expect(access.source, 'SELF');
    expect(access.isActive, isFalse);
    expect(access.waitlistedAt, isNotNull);
    expect(access.activatedAt, isNull);
  });
}
