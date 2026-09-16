import 'package:dp_design/src/states/dp_empty.dart';
import 'package:dp_design/src/states/dp_error.dart';
import 'package:dp_design/src/states/dp_loading.dart';
import 'package:dp_design/src/theme/dp_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('DpEmpty는 카피 + 1차 행동을 노출한다', (tester) async {
    var acted = false;
    await tester.pumpWidget(
      _host(
        DpEmpty(
          title: '첫 질문을 남겨보세요',
          actionLabel: '질문 작성',
          onAction: () => acted = true,
        ),
      ),
    );
    expect(find.text('첫 질문을 남겨보세요'), findsOneWidget);
    await tester.tap(find.text('질문 작성'));
    expect(acted, isTrue);
  });

  testWidgets('DpError는 재시도를 호출한다', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      _host(DpError(message: '문제가 발생했어요', onRetry: () => retried = true)),
    );
    await tester.tap(find.text('다시 시도'));
    expect(retried, isTrue);
  });

  testWidgets('DpLoading은 진행 표시를 렌더한다', (tester) async {
    await tester.pumpWidget(_host(const DpLoading()));
    expect(find.byType(DpLoading), findsOneWidget);
  });

  testWidgets('empty and error states use the shared focused state surface', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const DpEmpty(title: '아직 기록이 없어요')));
    expect(find.byKey(const ValueKey('dp-state-surface')), findsOneWidget);

    await tester.pumpWidget(
      _host(const DpError(title: '불러오지 못했어요', message: '잠시 후 다시 시도해 주세요.')),
    );
    expect(find.byKey(const ValueKey('dp-state-surface')), findsOneWidget);
  });

  testWidgets('short mobile viewport keeps the state surface scrollable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 250));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _host(
        DpError(
          title: '검색 결과를 불러오지 못했어요',
          message: '네트워크 상태를 확인한 뒤 다시 시도해 주세요.',
          onRetry: () {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('다시 시도'), findsOneWidget);
  });

  testWidgets('DpLoading은 라벨 유무와 무관하게 liveRegion 시맨틱을 가진다', (tester) async {
    await tester.pumpWidget(_host(const DpLoading()));
    expect(find.bySemanticsLabel('불러오는 중'), findsOneWidget);
    await tester.pumpWidget(_host(const DpLoading(label: '오늘의 미션을 불러오는 중')));
    final node = tester.getSemantics(find.bySemanticsLabel('오늘의 미션을 불러오는 중'));
    expect(node.flagsCollection.isLiveRegion, isTrue);
  });
}
