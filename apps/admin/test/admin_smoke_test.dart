import 'package:devpath_admin/src/app/app.dart';
import 'package:devpath_admin/src/features/auth/application/oauth_launcher.dart';
import 'package:devpath_admin/src/features/auth/presentation/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLauncher implements OAuthLauncher {
  String? launched;
  @override
  void launch(String url) => launched = url;
}

void main() {
  testWidgets('미인증 시 로그인 페이지 표시 + GitHub/Google 버튼 렌더', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fake = _FakeLauncher();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [oauthLauncherProvider.overrideWithValue(fake)],
        child: const DevPathAdminApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AdminLoginPage), findsOneWidget);
    expect(find.text('GitHub로 관리자 로그인'), findsOneWidget);
    expect(find.text('Google로 관리자 로그인'), findsOneWidget);

    // GitHub 버튼 탭 → OAuth 런처 호출 확인
    await tester.tap(find.text('GitHub로 관리자 로그인'));
    await tester.pumpAndSettle();
    expect(fake.launched, contains('/oauth2/authorization/github?client_type=admin'));
  });
}
