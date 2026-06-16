import 'package:devpath_admin/src/features/auth/application/auth_controller.dart';
import 'package:devpath_admin/src/features/auth/state/auth_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('로그인 시 ADMIN 유저로 인증', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await c.read(adminAuthProvider.notifier).login();
    final s = c.read(adminAuthProvider);
    expect(s, isA<AdminAuthed>());
    expect((s as AdminAuthed).user.role, UserRole.admin);
  });
}
