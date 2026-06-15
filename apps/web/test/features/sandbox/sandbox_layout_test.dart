import 'package:devpath_web/src/features/sandbox/presentation/sandbox_layout.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Size size) => MediaQuery(
  data: MediaQueryData(size: size),
  child: MaterialApp(
    theme: DpTheme.light(),
    home: const Scaffold(
      body: SandboxLayout(
        editor: Text('EDITOR'),
        log: Text('LOG'),
        review: Text('REVIEW'),
      ),
    ),
  ),
);

void main() {
  testWidgets('≥1240: 3페인 동시 표시', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(const Size(1400, 900)));
    expect(find.text('EDITOR'), findsOneWidget);
    expect(find.text('LOG'), findsOneWidget);
    expect(find.text('REVIEW'), findsOneWidget);
  });

  testWidgets('<1024: 세그먼트 탭(1페인) — 기본 EDITOR만', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(const Size(800, 900)));
    expect(find.byType(SegmentedButton<int>), findsOneWidget);
    expect(find.text('EDITOR'), findsOneWidget);
    expect(find.text('REVIEW'), findsNothing); // 다른 탭은 미표시
  });

  // F5/D1 반영: 경계 4값 off-by-one 고정(<1024 / [1024,1240) / ≥1240).
  // IndexedStack(F5-b)은 전 페인을 트리에 유지하므로 가시 탭 판별은 find.text가 아닌
  // 세그먼트(1페인) 대 다중 페인(Row) 구조로 한다.
  testWidgets('경계 1023: 세그먼트 탭(1페인)', (tester) async {
    tester.view.physicalSize = const Size(1023, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(const Size(1023, 900)));
    expect(find.byType(SegmentedButton<int>), findsOneWidget);
  });

  testWidgets('경계 1024: 2페인(에디터|리뷰)+로그접이 — 세그먼트 없음', (tester) async {
    tester.view.physicalSize = const Size(1024, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(const Size(1024, 900)));
    expect(find.byType(SegmentedButton<int>), findsNothing);
    expect(find.text('실행 로그 접기'), findsOneWidget); // 로그 접이 토글
  });

  testWidgets('경계 1239: 2페인(에디터|리뷰)+로그접이', (tester) async {
    tester.view.physicalSize = const Size(1239, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(const Size(1239, 900)));
    expect(find.byType(SegmentedButton<int>), findsNothing);
    expect(find.text('실행 로그 접기'), findsOneWidget);
  });

  testWidgets('경계 1240: 3페인 동시 표시 — 로그접이 토글 없음', (tester) async {
    tester.view.physicalSize = const Size(1240, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(const Size(1240, 900)));
    expect(find.text('EDITOR'), findsOneWidget);
    expect(find.text('LOG'), findsOneWidget);
    expect(find.text('REVIEW'), findsOneWidget);
    expect(find.text('실행 로그 접기'), findsNothing); // 3페인은 접이 없음
  });

  // F5-b 반영: <1024 탭 왕복 후 에디터 입력 코드 유지(IndexedStack=전 페인 트리 유지).
  // panes[_tab]로 현재 탭만 트리에 넣으면 탭 전환 시 에디터 State가 폐기되어 입력이 소실된다.
  testWidgets('<1024: 탭 왕복(에디터→실행→에디터) 후 입력 코드 유지', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // 입력 상태를 가지는 stateful 에디터 더미(TextField)로 IndexedStack 보존을 검증.
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(800, 900)),
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const Scaffold(
            body: SandboxLayout(
              editor: TextField(key: Key('ed')),
              log: Text('LOG'),
              review: Text('REVIEW'),
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('ed')), 'final x = 1;');
    await tester.pump();

    // 실행 탭으로 → 다시 에디터 탭으로 왕복
    await tester.tap(find.text('실행'));
    await tester.pump();
    await tester.tap(find.text('에디터'));
    await tester.pump();

    expect(find.text('final x = 1;'), findsOneWidget); // 입력 유지
  });

  // P3/D1 반영: 1024–1239 2페인 로그 접이 토글 — 접으면 LOG 페인 트리에서 제거.
  testWidgets('1024–1239: 로그 접이 토글로 LOG 페인 표시/숨김', (tester) async {
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(const Size(1100, 900)));

    expect(find.text('LOG'), findsOneWidget); // 기본 펼침
    await tester.tap(find.text('실행 로그 접기'));
    await tester.pump();
    expect(find.text('LOG'), findsNothing); // 접힘
    expect(find.text('실행 로그 펼치기'), findsOneWidget);
  });
}
