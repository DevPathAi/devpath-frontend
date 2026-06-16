import 'package:devpath_web/src/features/dashboard/presentation/dashboard_page.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('대시보드: 스트릭·진행률·다음 과제 CTA 렌더', (tester) async {
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const DashboardPage())],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(theme: DpTheme.light(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('7'), findsWidgets); // 스트릭 7일
    expect(find.textContaining('62'), findsWidgets); // 진행률
    expect(find.text('이어서 학습'), findsOneWidget); // 단일 CTA
  });
}
