import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('DpOptionRow: 선택 상태를 라디오 시맨틱스로 알린다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        DpOptionRow(
          label: const Text('백엔드 (Spring)'),
          description: const Text('Java · Spring Boot · JPA · 테스트'),
          selected: true,
          onSelect: () {},
        ),
      ),
    );

    expect(
      tester.getSemantics(find.text('백엔드 (Spring)')),
      isSemantics(
        isInMutuallyExclusiveGroup: true,
        hasCheckedState: true,
        isChecked: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('DpOptionRow: 고르지 않은 행은 checked 가 아니다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        DpOptionRow(
          label: const Text('백엔드 (Python)'),
          selected: false,
          onSelect: () {},
        ),
      ),
    );

    expect(
      tester.getSemantics(find.text('백엔드 (Python)')),
      isSemantics(
        isInMutuallyExclusiveGroup: true,
        hasCheckedState: true,
        isChecked: false,
      ),
    );
    handle.dispose();
  });

  testWidgets('DpOptionRow: 행 어디를 눌러도 선택된다', (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      _host(
        DpOptionRow(
          label: const Text('백엔드 (Python)'),
          description: const Text('Django · FastAPI'),
          selected: false,
          onSelect: () => selected++,
        ),
      ),
    );

    // 라벨이 아니라 설명 줄을 눌러도 같은 행 제스처가 받는다.
    await tester.tap(find.text('Django · FastAPI'));
    await tester.pump();
    expect(selected, 1);
  });

  testWidgets('DpOptionRow: Tab 으로 포커스를 받고 Enter 로 선택된다', (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      _host(
        DpOptionRow(
          label: const Text('백엔드 (Spring)'),
          selected: false,
          onSelect: () => selected++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.context?.widget,
      isNot(isA<FocusScope>()),
      reason: '옵션 행이 순회 대상이 아니면 포커스는 라우트 스코프에 머문다',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, 1, reason: '라디오 폼 컨트롤은 키보드로 활성화돼야 한다');
  });

  testWidgets('DpOptionRow: onSelect 가 null 이면 눌러도·Tab 해도 반응하지 않는다', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        const DpOptionRow(
          label: Text('백엔드 (Spring)'),
          selected: false,
          onSelect: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('백엔드 (Spring)'));
    await tester.pump();
    expect(tester.takeException(), isNull);

    // 잠긴 보기는 순회 대상이 아니다 — 제출 중에 탭이 멈출 곳이 아니다.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.context?.widget,
      isA<FocusScope>(),
      reason: '비활성 보기는 포커스를 받지 않는다',
    );

    expect(
      tester.getSemantics(find.text('백엔드 (Spring)')),
      isSemantics(hasEnabledState: true, isEnabled: false),
    );
    handle.dispose();
  });

  testWidgets('DpOptionRow: 누르는 즉시 행동인 묶음은 버튼 역할로 선언한다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        DpOptionRow(
          role: DpOptionRole.button,
          label: const Text('singleton'),
          selected: false,
          onSelect: () {},
        ),
      ),
    );

    // 라디오는 「고른 뒤 확정」을 약속한다 — 누르면 바로 제출되는 보기는 버튼이다.
    expect(
      tester.getSemantics(find.text('singleton')),
      isSemantics(
        isButton: true,
        isInMutuallyExclusiveGroup: false,
        hasCheckedState: false,
      ),
    );
    handle.dispose();
  });

  testWidgets('DpOptionRow: 기본 역할은 라디오다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        DpOptionRow(
          label: const Text('백엔드 (Spring)'),
          selected: true,
          onSelect: () {},
        ),
      ),
    );

    expect(
      tester.getSemantics(find.text('백엔드 (Spring)')),
      isSemantics(
        isInMutuallyExclusiveGroup: true,
        hasCheckedState: true,
        isChecked: true,
        isButton: false,
      ),
    );
    handle.dispose();
  });
}
