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

  // 시안 `.steps` 는 CSS flex 기본값인 align-items:stretch 다 — 라벨이 줄바꿈
  // 하는 폭에서도 세 단계의 높이가 같아야 배경(accentSoft)이 어긋나지 않는다.
  testWidgets('라벨이 줄바꿈하는 폭에서도 단계 높이가 같다', (tester) async {
    _size(tester, const Size(640, 400));
    // 640: compact(<600)를 넘겨 가로 배치로 두면서, 세 단계를 나란히 놓으면
    // 한 칸이 약 213px 이라 긴 라벨이 두 줄이 되는 폭이다.

    await tester.pumpWidget(
      _host(
        const Align(
          alignment: Alignment.topCenter,
          child: DpSteps(
            labels: ['1 트랙 선택', '2 실력 진단을 아주 길게 적은 라벨', '3 학습 경로'],
            currentIndex: 0,
          ),
        ),
      ),
    );

    final heights = <double>[
      for (var i = 0; i < 3; i++)
        tester.getSize(find.byKey(ValueKey('dp-step-$i'))).height,
    ];
    expect(heights[1], greaterThan(24), reason: '긴 라벨이 실제로 줄바꿈해야 판별력이 생긴다');
    expect(heights[0], heights[1]);
    expect(heights[2], heights[1]);
  });
}
