import 'package:dp_design/src/layout/dp_max_width.dart';
import 'package:dp_design/src/layout/dp_scrollbar.dart';
import 'package:dp_design/src/layout/dp_selectable.dart';
import 'package:dp_design/src/theme/dp_theme.dart';
import 'package:dp_design/src/theme/dp_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) =>
    MaterialApp(theme: DpTheme.light(), home: Scaffold(body: child));

void main() {
  testWidgets('DpMaxWidth는 maxWidth 미지정 시 contentMaxWidth로 제약', (tester) async {
    await tester.pumpWidget(_host(const DpMaxWidth(child: Text('본문'))));
    final box = tester.widget<ConstrainedBox>(
      find
          .descendant(
            of: find.byType(DpMaxWidth),
            matching: find.byType(ConstrainedBox),
          )
          .first,
    );
    expect(box.constraints.maxWidth, AppTokens.standard.contentMaxWidth);
    expect(find.text('본문'), findsOneWidget);
  });

  testWidgets('DpMaxWidth는 명시 maxWidth를 우선한다', (tester) async {
    await tester.pumpWidget(
      _host(const DpMaxWidth(maxWidth: 600, child: Text('좁게'))),
    );
    final box = tester.widget<ConstrainedBox>(
      find
          .descendant(
            of: find.byType(DpMaxWidth),
            matching: find.byType(ConstrainedBox),
          )
          .first,
    );
    expect(box.constraints.maxWidth, 600);
  });

  testWidgets('DpSelectable은 SelectionArea로 감싼다', (tester) async {
    await tester.pumpWidget(_host(const DpSelectable(child: Text('선택가능'))));
    expect(find.byType(SelectionArea), findsOneWidget);
    expect(find.text('선택가능'), findsOneWidget);
  });

  testWidgets('DpScrollbar는 thumbVisibility=true로 Scrollbar를 구성', (tester) async {
    final ctrl = ScrollController();
    addTearDown(ctrl.dispose);
    await tester.pumpWidget(
      _host(
        DpScrollbar(
          controller: ctrl,
          child: ListView(
            controller: ctrl,
            children: const [SizedBox(height: 2000)],
          ),
        ),
      ),
    );
    final bar = tester.widget<Scrollbar>(find.byType(Scrollbar));
    expect(bar.thumbVisibility, isTrue);
    expect(bar.controller, same(ctrl));
  });
}
