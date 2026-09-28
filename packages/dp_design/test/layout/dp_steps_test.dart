import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(body: child),
);

/// `context.windowClass` 는 `MediaQuery.sizeOf` 를 읽고 `MaterialApp` 이 뷰에서
/// 자기 MediaQuery 를 만든다 — 바깥에 MediaQuery 를 씌우면 덮인다. 그래서 뷰의
/// 물리 크기를 직접 정한다(`dp_cols_test.dart` 와 같은 관례).
void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('DpSteps: 현재 단계를 시맨틱스로 알린다', (tester) async {
    _size(tester, const Size(1280, 800));
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        const DpSteps(
          labels: ['1 트랙 선택', '2 실력 진단', '3 학습 경로'],
          currentIndex: 1,
        ),
      ),
    );

    expect(find.text('1 트랙 선택'), findsOneWidget);
    expect(find.text('2 실력 진단'), findsOneWidget);
    // `SemanticsFlag` 는 이 Flutter 에 없고, `flagsCollection`+`ui.Tristate` 는
    // 로컬 3.47 전용이다(CI 는 3.44.1 핀). 비전수 매처 `isSemantics` 를 쓴다.
    expect(
      tester.getSemantics(find.text('2 실력 진단')),
      isSemantics(isSelected: true),
    );
    expect(
      tester.getSemantics(find.text('1 트랙 선택')),
      isSemantics(isSelected: false),
    );
    handle.dispose();
  });

  testWidgets('DpSteps: compact 에서 세로로 쌓인다', (tester) async {
    _size(tester, const Size(390, 800));
    await tester.pumpWidget(
      _host(
        const DpSteps(
          labels: ['1 트랙 선택', '2 실력 진단', '3 학습 경로'],
          currentIndex: 0,
        ),
      ),
    );

    final first = tester.getRect(find.text('1 트랙 선택'));
    final second = tester.getRect(find.text('2 실력 진단'));
    expect(second.top, greaterThan(first.bottom - 1));
  });
}
