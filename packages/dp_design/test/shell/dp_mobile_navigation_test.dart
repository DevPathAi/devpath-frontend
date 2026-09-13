import 'dart:ui' as ui;

import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _destinations = [
  DpDestination(icon: Icons.home_rounded, label: '오늘'),
  DpDestination(icon: Icons.route_rounded, label: '학습 경로'),
  DpDestination(icon: Icons.chat_bubble_rounded, label: 'AI 멘토'),
  DpDestination(icon: Icons.groups_rounded, label: '게시판'),
];

Widget _host({int? selectedIndex = 0, ValueChanged<int>? onSelect}) =>
    MaterialApp(
      theme: DpTheme.light(),
      home: Scaffold(
        bottomNavigationBar: DpMobileNavigation(
          destinations: _destinations,
          selectedIndex: selectedIndex,
          onSelect: onSelect ?? (_) {},
        ),
      ),
    );

void main() {
  testWidgets(
    'mobile navigation is a Leva-owned surface, not stock NavigationBar',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host());

      expect(find.byType(DpMobileNavigation), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byKey(const ValueKey('mobile-nav-surface')), findsOneWidget);
      expect(find.byKey(const ValueKey('mobile-nav-item-0')), findsOneWidget);
    },
  );

  testWidgets(
    'nullable selection is represented without a fake selected item',
    (tester) async {
      await tester.pumpWidget(_host(selectedIndex: null));

      for (var i = 0; i < _destinations.length; i++) {
        final semantics = tester.getSemantics(
          find.byKey(ValueKey('mobile-nav-item-$i')),
        );
        expect(semantics.flagsCollection.isSelected, ui.Tristate.isFalse);
      }
    },
  );

  testWidgets('selection invokes the destination callback', (tester) async {
    int? picked;
    await tester.pumpWidget(_host(onSelect: (index) => picked = index));

    await tester.tap(find.text('AI 멘토'));
    expect(picked, 2);
  });
}
