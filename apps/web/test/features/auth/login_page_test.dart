import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/presentation/login_page.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('로그인 버튼 탭 → 인증 상태로 전환', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: DpTheme.light(), home: const LoginPage()),
      ),
    );

    expect(find.text('GitHub로 계속하기 (목)'), findsOneWidget);

    await tester.tap(find.text('GitHub로 계속하기 (목)'));
    await tester.pumpAndSettle();

    expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
  });
}
