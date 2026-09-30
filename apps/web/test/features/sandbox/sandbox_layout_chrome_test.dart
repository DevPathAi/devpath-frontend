import 'package:devpath_web/src/features/sandbox/presentation/sandbox_layout.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host() => MaterialApp(
  theme: DpTheme.light(),
  home: const Scaffold(
    body: SandboxLayout(
      editor: Text('에디터 페인'),
      log: Text('로그 페인'),
      review: Text('리뷰 페인'),
    ),
  ),
);

void _view(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('SandboxLayout: 바깥 테두리는 한 겹이고 페인마다 두르지 않는다', (tester) async {
    _view(tester, const Size(1280, 900));
    await tester.pumpWidget(_host());

    // 시안 `.ide` — 바깥 컨테이너 하나가 테두리와 반경 8 을 갖는다.
    final frame = tester.widget<Container>(
      find.byKey(const ValueKey('sandbox-ide-frame')),
    );
    final decoration = frame.decoration! as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(DpRadius.card));
    expect(decoration.border, isNotNull);

    // 프레임은 3페인에 하나뿐이다 — 페인마다 두르면 사이가 2px 로 보인다.
    expect(find.byKey(const ValueKey('sandbox-ide-frame')), findsOneWidget);
    // 페인 사이 구분선은 페인 수보다 하나 적다(3페인 → 2개).
    expect(
      find.byKey(const ValueKey('sandbox-pane-divider')),
      findsNWidgets(2),
    );
  });

  testWidgets('SandboxLayout: 1280 에서 3페인을 그린다', (tester) async {
    _view(tester, const Size(1280, 900));
    await tester.pumpWidget(_host());

    expect(find.text('에디터 페인'), findsOneWidget);
    expect(find.text('로그 페인'), findsOneWidget);
    expect(find.text('리뷰 페인'), findsOneWidget);
  });

  testWidgets('SandboxLayout: 1100 에서 2페인 + 로그 접이다', (tester) async {
    _view(tester, const Size(1100, 900));
    await tester.pumpWidget(_host());

    // 에디터|리뷰 프레임 + 펼쳐진 로그 프레임 = 프레임 둘, 각 프레임 안 구분선 1·0.
    expect(find.byKey(const ValueKey('sandbox-ide-frame')), findsNWidgets(2));
    expect(find.byKey(const ValueKey('sandbox-pane-divider')), findsOneWidget);
    expect(find.text('실행 로그 접기'), findsOneWidget);

    await tester.tap(find.text('실행 로그 접기'));
    await tester.pump();

    expect(find.text('실행 로그 펼치기'), findsOneWidget);
    expect(find.byKey(const ValueKey('sandbox-ide-frame')), findsOneWidget);
  });

  testWidgets('SandboxLayout: 390 에서 세그먼트 탭으로 한 페인만 보인다', (tester) async {
    _view(tester, const Size(390, 900));
    await tester.pumpWidget(_host());

    expect(find.byType(SegmentedButton<int>), findsOneWidget);
    // IndexedStack 이라 셋 다 트리에 있고 하나만 보인다(F5-b: 에디터 State 보존).
    expect(find.byType(IndexedStack), findsOneWidget);
    expect(find.byKey(const ValueKey('sandbox-ide-frame')), findsOneWidget);
    expect(find.byKey(const ValueKey('sandbox-pane-divider')), findsNothing);
  });
}
