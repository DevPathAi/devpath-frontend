import 'package:dp_core/dp_core.dart';
import 'package:test/test.dart';

void main() {
  test('APPROVED + provider 파싱', () {
    final s = BetaStatus.fromJson({'status': 'APPROVED', 'provider': 'github'});
    expect(s.status, BetaStatusKind.approved);
    expect(s.provider, 'github');
  });

  test('PENDING 파싱(provider 없음)', () {
    final s = BetaStatus.fromJson({'status': 'PENDING'});
    expect(s.status, BetaStatusKind.pending);
    expect(s.provider, isNull);
  });

  test('EXPIRED 및 알 수 없는 값 → expired', () {
    expect(
      BetaStatus.fromJson({'status': 'EXPIRED'}).status,
      BetaStatusKind.expired,
    );
    expect(
      BetaStatus.fromJson({'status': '???'}).status,
      BetaStatusKind.expired,
    );
  });
}
