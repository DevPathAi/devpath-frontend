import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void _noop(bool _) {}

Widget _host(Widget child) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('DpCheckRow: 체크 상태를 시맨틱스로 알리고 라벨을 함께 읽는다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        DpCheckRow(
          label: const Text('서비스 이용약관 동의'),
          description: const Text('서비스 이용에 필요한 기본 약관입니다.'),
          value: true,
          onChanged: (_) {},
        ),
      ),
    );

    expect(
      tester.getSemantics(find.text('서비스 이용약관 동의')),
      isSemantics(hasCheckedState: true, isChecked: true),
    );
    handle.dispose();
  });

  testWidgets('DpCheckRow: 우측 보조 요소는 체크 노드 밖에 남는다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        DpCheckRow(
          label: const Text('서비스 이용약관 동의'),
          value: false,
          onChanged: (_) {},
          trailing: DpLink.inline(text: '전문 보기', onTap: () {}),
        ),
      ),
    );

    // 「전문 보기」가 체크 행 노드에 흡수되면 스크린리더가 링크를 놓친다.
    expect(
      tester.getSemantics(find.text('전문 보기')),
      isSemantics(isLink: true, hasCheckedState: false),
    );
    handle.dispose();
  });

  testWidgets('DpCheckRow: 마지막 행은 하단 구분선을 그리지 않는다', (tester) async {
    await tester.pumpWidget(
      _host(
        DpCheckRow(
          label: const Text('마케팅 정보 수신'),
          value: false,
          onChanged: (_) {},
          last: true,
        ),
      ),
    );

    final box = tester.widget<Container>(
      find.byKey(const ValueKey('dp-check-row')),
    );
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.border, isNull);
  });

  testWidgets('DpCheckRow: onChanged 가 null 이면 눌러도 바뀌지 않는다', (tester) async {
    await tester.pumpWidget(
      _host(
        const DpCheckRow(label: Text('필수 항목'), value: true, onChanged: null),
      ),
    );

    await tester.tap(find.text('필수 항목'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('DpCheckRow: 행 어디를 눌러도 토글되고 Tab·Enter 로도 토글된다', (tester) async {
    var value = false;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => DpCheckRow(
            label: const Text('마케팅 정보 수신'),
            description: const Text('새 트랙·이벤트 소식을 받습니다.'),
            value: value,
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('새 트랙·이벤트 소식을 받습니다.'));
    await tester.pumpAndSettle();
    expect(value, isTrue, reason: '설명 줄을 눌러도 같은 행 제스처가 받는다');

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.context?.widget,
      isNot(isA<FocusScope>()),
      reason: '동의 체크가 순회 대상이 아니면 포커스는 라우트 스코프에 머문다',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(value, isFalse, reason: '키보드로도 토글돼야 한다');
  });

  testWidgets('DpCheckRow: 390px·200% 배율에서 trailing 이 라벨을 짜부수지 않는다', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      _host(
        // 실제 동의 화면의 행 폭과 같게 좁힌다 — 390px 화면에서 페이지 패딩과
        // 패널 테두리를 빼면 행이 340 이다. 뷰포트만 390 으로 두면 행이 전폭을
        // 받아 이 결함이 재현되지 않는다(판별력 없는 테스트가 된다).
        const Center(
          child: SizedBox(
            width: 340,
            child: DpCheckRow(
              label: Text('개인정보 수집·이용 동의'),
              description: Text('학습 진단·경로 제공을 위한 최소한의 정보를 수집합니다.'),
              value: false,
              onChanged: _noop,
              trailing: DpLink.inline(text: '전문 보기'),
            ),
          ),
        ),
      ),
    );

    // `takeException` 은 이 결함을 보지 못한다 — RenderFlex 오버플로 없이 라벨이
    // 글자당 한 줄로 눌린다(실측: `Row` 형태에서 폭 38.25 · 높이 495).
    final label = tester.getRect(find.text('개인정보 수집·이용 동의'));
    expect(
      label.width,
      greaterThan(150),
      reason: 'non-flex trailing 이 주축 무한 제약으로 측정되면 라벨이 글자당 한 줄이 된다',
    );
  });

  // 체크박스는 `ExcludeFocus` 로 포커스에서 빠져 있고 행 래퍼가 정지를 소유한다.
  // 그 `ExcludeFocus` 를 지워도 기존 테스트는 전부 통과했다 — 정지 **개수**를
  // 고정해야 회귀를 잡는다(P4 독립 리뷰 M11).
  testWidgets('DpCheckRow: 행 두 개의 탭 정지는 정확히 두 개다', (tester) async {
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            DpCheckRow(label: const Text('첫째'), value: false, onChanged: _noop),
            DpCheckRow(
              label: const Text('둘째'),
              value: false,
              onChanged: _noop,
              last: true,
            ),
          ],
        ),
      ),
    );

    final stops = <int>[];
    for (var i = 0; i < 5; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final node = FocusManager.instance.primaryFocus;
      if (node != null) stops.add(identityHashCode(node));
    }
    // 5번 Tab 을 눌러도 서로 다른 정지는 두 개뿐이어야 한다(그 뒤 순환).
    expect(stops.toSet().length, 2);
  });
}
