import 'package:devpath_admin/src/app/app.dart';
import 'package:devpath_admin/src/features/auth/presentation/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('미인증→로그인, 관리자 로그인→대시보드', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: DevPathAdminApp()));
    await tester.pumpAndSettle();
    expect(find.byType(AdminLoginPage), findsOneWidget);

    await tester.tap(find.text('관리자 로그인 (목)'));
    await tester.pumpAndSettle();
    expect(find.text('운영 대시보드'), findsOneWidget); // 대시보드 AppBar
  });
}
