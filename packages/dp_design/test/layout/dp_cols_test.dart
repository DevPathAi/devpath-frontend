import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(body: child),
);

/// `context.windowClass` 는 `MediaQuery.sizeOf` 를 읽고 `MaterialApp` 이 뷰에서
/// 자기 MediaQuery 를 만든다 — 바깥에 MediaQuery 를 씌우면 덮인다. 그래서 뷰의
/// 물리 크기를 직접 정한다.
void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('DpCols: expanded 이상에서 2:1 두 열로 배치한다', (tester) async {
    _size(tester, const Size(1280, 800));
    await tester.pumpWidget(
      _host(
        const DpCols(
          main: SizedBox(key: ValueKey('cols-main'), height: 10),
          side: SizedBox(key: ValueKey('cols-side'), height: 10),
        ),
      ),
    );

    final mainW = tester.getSize(find.byKey(const ValueKey('cols-main'))).width;
    final sideW = tester.getSize(find.byKey(const ValueKey('cols-side'))).width;
    expect(mainW, closeTo(sideW * 2, 1));
  });

  testWidgets('DpCols: compact 에서 main 다음에 side 한 열로 접는다', (tester) async {
    _size(tester, const Size(390, 800));
    await tester.pumpWidget(
      _host(
        const DpCols(
          main: SizedBox(key: ValueKey('cols-main'), height: 10),
          side: SizedBox(key: ValueKey('cols-side'), height: 10),
        ),
      ),
    );

    final mainRect = tester.getRect(find.byKey(const ValueKey('cols-main')));
    final sideRect = tester.getRect(find.byKey(const ValueKey('cols-side')));
    expect(mainRect.width, sideRect.width);
    expect(sideRect.top, greaterThan(mainRect.bottom));
  });

  testWidgets('DpCols: medium(840 미만) 도 한 열이다 — 사이드가 눌리면 2열이 읽히지 않는다', (
    tester,
  ) async {
    _size(tester, const Size(800, 800));
    await tester.pumpWidget(
      _host(
        const DpCols(
          main: SizedBox(key: ValueKey('cols-main'), height: 10),
          side: SizedBox(key: ValueKey('cols-side'), height: 10),
        ),
      ),
    );

    final mainRect = tester.getRect(find.byKey(const ValueKey('cols-main')));
    final sideRect = tester.getRect(find.byKey(const ValueKey('cols-side')));
    expect(sideRect.top, greaterThan(mainRect.bottom));
  });

  testWidgets('DpCols(stretch): 2열에서 두 칼럼이 부모 높이를 채운다', (tester) async {
    _size(tester, const Size(1280, 800));
    await tester.pumpWidget(
      _host(
        const SizedBox(
          height: 400,
          child: DpCols(
            stretch: true,
            main: ColoredBox(
              key: ValueKey('cols-main'),
              color: Color(0xFF000000),
            ),
            side: ColoredBox(
              key: ValueKey('cols-side'),
              color: Color(0xFF000000),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const ValueKey('cols-main'))).height, 400);
    expect(tester.getSize(find.byKey(const ValueKey('cols-side'))).height, 400);
  });

  testWidgets('DpCols(stretch): 1열에서 main 이 남은 높이를 받는다', (tester) async {
    _size(tester, const Size(390, 800));
    await tester.pumpWidget(
      _host(
        const SizedBox(
          height: 400,
          child: DpCols(
            stretch: true,
            main: ColoredBox(
              key: ValueKey('cols-main'),
              color: Color(0xFF000000),
            ),
            side: SizedBox(key: ValueKey('cols-side'), height: 60),
          ),
        ),
      ),
    );

    final mainRect = tester.getRect(find.byKey(const ValueKey('cols-main')));
    final sideRect = tester.getRect(find.byKey(const ValueKey('cols-side')));
    // main 이 Expanded 라 남은 높이(400 - 간격 24 - side 60)를 받는다.
    expect(mainRect.height, 400 - DpSpacing.xl - 60);
    expect(sideRect.top, greaterThan(mainRect.bottom - 1));
  });

  testWidgets('DpCols: stretch 기본값은 false — 사이드가 본문 높이만큼 늘지 않는다', (
    tester,
  ) async {
    _size(tester, const Size(1280, 800));
    await tester.pumpWidget(
      _host(
        const DpCols(
          main: SizedBox(key: ValueKey('cols-main'), height: 200),
          side: SizedBox(key: ValueKey('cols-side'), height: 40),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(const ValueKey('cols-side'))).height, 40);
  });

  testWidgets('DpSide: 자식 사이에 lg 간격을 넣는다', (tester) async {
    _size(tester, const Size(1280, 800));
    await tester.pumpWidget(
      _host(
        const DpSide(
          children: [
            SizedBox(key: ValueKey('side-a'), height: 10),
            SizedBox(key: ValueKey('side-b'), height: 10),
          ],
        ),
      ),
    );

    final a = tester.getRect(find.byKey(const ValueKey('side-a')));
    final b = tester.getRect(find.byKey(const ValueKey('side-b')));
    expect(b.top - a.bottom, DpSpacing.lg);
  });
}
