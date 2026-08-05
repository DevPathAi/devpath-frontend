import 'package:devpath_web/src/features/auth/presentation/login_page.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('로그인은 AppBar 없이 헤더 + 테마 전환 버튼을 유지', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: DpTheme.light(), home: const LoginPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AppBar), findsNothing);
    final header = tester.widget<DpPageHeader>(find.byType(DpPageHeader));
    expect(header.title, '로그인');
    expect(find.byTooltip('테마 전환'), findsOneWidget);
  });
}
