import 'package:devpath_admin/src/app/router.dart';
import 'package:devpath_admin/src/features/auth/state/auth_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_test/flutter_test.dart';

User _u(UserRole r) => User(
  id: 'x',
  email: 'e',
  nickname: 'n',
  role: r,
  onboardingStatus: OnboardingStatus.done,
);

void main() {
  group('adminGuard', () {
    test('미인증 → /login', () {
      expect(adminGuard(const AdminUnauthed(), '/dashboard'), '/login');
    });
    test('비관리자(LEARNER) → /forbidden', () {
      expect(
        adminGuard(AdminAuthed(_u(UserRole.learner)), '/dashboard'),
        '/forbidden',
      );
    });
    test('ADMIN → 통과', () {
      expect(adminGuard(AdminAuthed(_u(UserRole.admin)), '/dashboard'), isNull);
    });
    test('OWNER → 통과', () {
      expect(adminGuard(AdminAuthed(_u(UserRole.owner)), '/users'), isNull);
    });
    test('인증·관리자 + /login → /dashboard', () {
      expect(
        adminGuard(AdminAuthed(_u(UserRole.admin)), '/login'),
        '/dashboard',
      );
    });
  });
}
