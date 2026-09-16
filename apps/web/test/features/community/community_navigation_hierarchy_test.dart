import 'package:devpath_web/src/features/shell/presentation/app_shell.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void _setWidth(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Widget _host(Widget child) => MaterialApp(theme: DpTheme.light(), home: child);

void main() {
  test('데스크톱 커뮤니티 섹션은 세 게시판을 직접 목적지로 노출한다', () {
    final community = kShellDestinations
        .where((destination) => destination.section == '커뮤니티')
        .toList();

    expect(community.map((destination) => destination.label), [
      '자유게시판',
      'Q/A',
      '피드백',
    ]);
    expect(community.map((destination) => destination.path), [
      '/community?board=FREE',
      '/community?board=QNA',
      '/community?board=FEEDBACK',
    ]);
  });

  test('URL의 board 값이 데스크톱 게시판 선택 상태를 결정한다', () {
    expect(shellDestinationIndexFor('/community'), 3);
    expect(shellDestinationIndexFor('/community?board=FREE'), 3);
    expect(shellDestinationIndexFor('/community?board=QNA'), 4);
    expect(shellDestinationIndexFor('/community?board=FEEDBACK'), 5);
  });

  testWidgets('데스크톱 레일에는 커뮤니티 아래 세 게시판이 모두 보인다', (tester) async {
    _setWidth(tester, 1200);
    await tester.pumpWidget(
      _host(
        const AppShellView(location: '/community?board=QNA', child: Text('본문')),
      ),
    );

    final rail = tester.widget<DpNavRail>(find.byType(DpNavRail));
    expect(rail.destinations.map((destination) => destination.label), [
      '오늘',
      '학습 경로',
      'AI 멘토',
      '자유게시판',
      'Q/A',
      '피드백',
    ]);
    expect(rail.selectedIndex, 4);
  });

  testWidgets('모바일 하단 내비는 네 개 핵심 목적지만 유지한다', (tester) async {
    _setWidth(tester, 390);
    await tester.pumpWidget(
      _host(
        const AppShellView(
          location: '/community?board=FEEDBACK',
          child: Text('본문'),
        ),
      ),
    );

    final nav = tester.widget<DpMobileNavigation>(
      find.byType(DpMobileNavigation),
    );
    expect(nav.destinations.map((destination) => destination.label), [
      '오늘',
      '학습 경로',
      'AI 멘토',
      '커뮤니티',
    ]);
    expect(nav.selectedIndex, 3);
  });
}
