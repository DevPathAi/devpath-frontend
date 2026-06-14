import 'package:dp_core/src/models/enums.dart';
import 'package:dp_core/src/models/user.dart';
import 'package:test/test.dart';

void main() {
  test('User JSON 역직렬화 + 알 수 없는 role은 unknown', () {
    final user = User.fromJson({
      'id': 'u1',
      'email': 'a@b.com',
      'nickname': 'jisoo',
      'role': 'LEARNER',
      'onboardingStatus': 'DONE',
    });
    expect(user.id, 'u1');
    expect(user.role, UserRole.learner);
    expect(user.onboardingStatus, OnboardingStatus.done);

    final weird = User.fromJson({
      'id': 'u2',
      'email': 'x@y.com',
      'nickname': 'z',
      'role': 'GALACTIC_ADMIN', // 백엔드가 새 역할 추가해도 깨지지 않음
      'onboardingStatus': 'PENDING',
    });
    expect(weird.role, UserRole.unknown);
    expect(weird.onboardingStatus, OnboardingStatus.pending);
  });
}
