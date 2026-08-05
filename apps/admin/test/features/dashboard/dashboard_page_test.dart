import 'package:devpath_admin/src/features/dashboard/presentation/dashboard_page.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('KPI 카드(DAU·신규·신고) 렌더', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const AdminDashboardPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('1280'), findsWidgets); // DAU
    expect(find.textContaining('신고'), findsWidgets);
  });

  testWidgets('DpPageHeader 제목은 "운영 대시보드"', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const AdminDashboardPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final header = tester.widget<DpPageHeader>(find.byType(DpPageHeader));
    expect(header.title, '운영 대시보드');
  });
}
