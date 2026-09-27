import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {double width = 720}) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(body: Center(child: SizedBox(width: width, child: child))),
);

void main() {
  testWidgets('라벨·설명·우측 컨트롤을 모두 그린다', (tester) async {
    await tester.pumpWidget(
      _host(
        DpRowLine(
          label: const Text('학습 알림'),
          description: const Text('선호 시간대에 학습 알림을 받아요.'),
          trailing: Switch(value: true, onChanged: (_) {}),
        ),
      ),
    );

    expect(find.text('학습 알림'), findsOneWidget);
    expect(find.text('선호 시간대에 학습 알림을 받아요.'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('last 가 아니면 하단 구분선이 있다', (tester) async {
    await tester.pumpWidget(_host(const DpRowLine(label: Text('로그아웃'))));

    final box = tester.widget<Container>(
      find.byKey(const ValueKey('dp-row-line')),
    );
    final d = box.decoration! as BoxDecoration;
    expect(d.border!.bottom.color, DpColors.light.border);
  });

  testWidgets('last 면 구분선이 없다', (tester) async {
    await tester.pumpWidget(
      _host(const DpRowLine(label: Text('계정 삭제'), last: true)),
    );

    final box = tester.widget<Container>(
      find.byKey(const ValueKey('dp-row-line')),
    );
    expect((box.decoration! as BoxDecoration).border, isNull);
  });

  testWidgets('설명은 13px 보조색이다', (tester) async {
    await tester.pumpWidget(
      _host(
        const DpRowLine(
          label: Text('주간 리포트'),
          description: Text('월요일에 보내 드려요.'),
        ),
      ),
    );

    final style = DefaultTextStyle.of(
      tester.element(find.text('월요일에 보내 드려요.')),
    ).style;
    expect(style.fontSize, 13);
    expect(style.color, DpColors.light.textSecondary);
  });

  testWidgets('390px 에서 라벨과 컨트롤이 겹치거나 넘치지 않는다', (tester) async {
    await tester.pumpWidget(
      _host(
        DpRowLine(
          label: const Text('오류 진단 로그 수집 동의'),
          description: const Text('오류가 나면 진단 로그를 수집해 품질 개선에 씁니다.'),
          trailing: Switch(value: false, onChanged: (_) {}),
        ),
        width: 390,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const ValueKey('dp-row-line'))).width,
      lessThanOrEqualTo(390),
    );
  });
}
