import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: brightness == Brightness.light ? DpTheme.light() : DpTheme.dark(),
      home: Scaffold(body: child),
    );

BoxDecoration _decorationOf(WidgetTester tester) {
  final container = tester.widget<Container>(
    find
        .descendant(of: find.byType(DpPanel), matching: find.byType(Container))
        .first,
  );
  return container.decoration! as BoxDecoration;
}

void main() {
  testWidgets('표면색·1px 테두리·반경 8 의 컨테이너다', (tester) async {
    await tester.pumpWidget(_host(const DpPanel(child: Text('본문'))));

    final d = _decorationOf(tester);
    const c = DpColors.light;
    expect(d.color, c.surface);
    expect((d.border! as Border).top.width, 1);
    expect((d.border! as Border).top.color, c.border);
    expect(d.borderRadius, BorderRadius.circular(DpRadius.card));
  });

  testWidgets('title 이 없으면 제목행을 그리지 않는다', (tester) async {
    await tester.pumpWidget(_host(const DpPanel(child: Text('본문'))));

    expect(find.byKey(const ValueKey('dp-panel-title')), findsNothing);
    expect(find.text('본문'), findsOneWidget);
  });

  testWidgets('title 이 있으면 제목행과 하단 구분선을 그린다', (tester) async {
    await tester.pumpWidget(
      _host(const DpPanel(title: Text('이번 주 과제'), child: Text('본문'))),
    );

    final header = tester.widget<Container>(
      find.byKey(const ValueKey('dp-panel-title')),
    );
    final d = header.decoration! as BoxDecoration;
    expect(d.border!.bottom.width, 1);
    expect(d.border!.bottom.color, DpColors.light.border);
    expect(
      header.padding,
      const EdgeInsets.symmetric(
        vertical: DpSpacing.md,
        horizontal: DpSpacing.lg,
      ),
    );
    expect(find.text('이번 주 과제'), findsOneWidget);
  });

  testWidgets('제목은 시맨틱스에서 헤더로 노출된다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(const DpPanel(title: Text('진행'), child: Text('본문'))),
    );

    expect(
      tester.getSemantics(find.text('진행')),
      matchesSemantics(label: '진행', isHeader: true),
    );
    handle.dispose();
  });

  testWidgets('다크 테마에서도 표면·테두리가 각 테마 토큰을 쓴다', (tester) async {
    await tester.pumpWidget(
      _host(const DpPanel(child: Text('본문')), brightness: Brightness.dark),
    );

    final d = _decorationOf(tester);
    expect(d.color, DpColors.dark.surface);
    expect((d.border! as Border).top.color, DpColors.dark.border);
    // 라이트 값이 새어 들어오지 않았는지 못 박는다.
    expect(d.color, isNot(DpColors.light.surface));
  });
}
