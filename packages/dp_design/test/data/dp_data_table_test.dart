import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DpDataTable: 헤더·행 셀 렌더', (tester) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: Scaffold(
          body: DpDataTable(
            minWidth: 400,
            columns: [
              DataColumn2(label: const Text('이름')),
              DataColumn2(label: const Text('상태')),
            ],
            rows: [
              DataRow2(
                cells: [
                  DataCell(const Text('홍길동')),
                  DataCell(const Text('ACTIVE')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('이름'), findsOneWidget);
    expect(find.text('홍길동'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
  });

  testWidgets('DpDataTable: showCheckboxColumn 시 체크박스 렌더', (tester) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: Scaffold(
          body: DpDataTable(
            minWidth: 400,
            showCheckboxColumn: true,
            columns: [DataColumn2(label: const Text('이름'))],
            rows: [
              DataRow2(
                selected: true,
                onSelectChanged: (_) {},
                cells: [DataCell(const Text('홍길동'))],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox), findsWidgets);
  });
}
