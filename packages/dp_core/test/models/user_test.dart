import 'package:dp_core/src/models/enums.dart';
import 'package:dp_core/src/models/user.dart';
import 'package:test/test.dart';

void main() {
  test('User JSON 역직렬화 + 알 수 없는 role/consent는 unknown', () {
    final user = User.fromJson({
      'id': 'u1',
      'email': 'a@b.com',
      'nickname': 'jisoo',
      'role': 'LEARNER',
      'onboardingStatus': 'DONE',
      'consentStatus': 'DONE',
    });
    expect(user.id, 'u1');
    expect(user.role, UserRole.learner);
    expect(user.onboardingStatus, OnboardingStatus.done);
    expect(user.consentStatus, ConsentStatus.done);

    final weird = User.fromJson({
      'id': 'u2',
      'email': 'x@y.com',
      'nickname': 'z',
      'role': 'GALACTIC_ADMIN', // 백엔드가 새 역할 추가해도 깨지지 않음
      'onboardingStatus': 'PENDING',
      'consentStatus': 'FUTURE_STATE', // 알 수 없는 consent 값도 unknown으로 방어
    });
    expect(weird.role, UserRole.unknown);
    expect(weird.onboardingStatus, OnboardingStatus.pending);
    expect(weird.consentStatus, ConsentStatus.unknown);
  });

  test('필수 동의 미완(consentStatus=PENDING) 사용자도 역직렬화된다', () {
    final user = User.fromJson({
      'id': 'u5',
      'email': 'p@q.com',
      'nickname': 'pending',
      'role': 'LEARNER',
      'onboardingStatus': 'PENDING',
      'consentStatus': 'PENDING',
    });
    expect(user.consentStatus, ConsentStatus.pending);
  });

  test('email 미반환(GitHub 비공개) 사용자도 역직렬화된다 — email=null', () {
    final user = User.fromJson({
      'id': 'u3',
      // 'email' 누락: GitHub이 이메일을 반환하지 않는 경우
      'nickname': 'noemail',
      'role': 'LEARNER',
      'onboardingStatus': 'PENDING',
      'consentStatus': 'DONE',
    });
    expect(user.email, isNull);
    expect(user.nickname, 'noemail');
  });

  test('email이 명시적 null이어도 역직렬화된다', () {
    final user = User.fromJson({
      'id': 'u4',
      'email': null,
      'nickname': 'n',
      'role': 'LEARNER',
      'onboardingStatus': 'PENDING',
      'consentStatus': 'DONE',
    });
    expect(user.email, isNull);
  });
}
