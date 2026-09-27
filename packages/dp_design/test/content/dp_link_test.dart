import 'package:dp_design/dp_design.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) =>
    MaterialApp(theme: DpTheme.light(), home: Scaffold(body: child));

TextStyle _styleOf(WidgetTester tester) =>
    tester.widget<Text>(find.byType(Text)).style!;

Future<void> _hover(WidgetTester tester, Finder target) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(tester.getCenter(target));
  await tester.pump();
}

void main() {
  testWidgets('title 변형은 기본 상태에서 본문색·600·밑줄 없음', (tester) async {
    await tester.pumpWidget(
      _host(DpLink.title(text: '오늘 배운 것 공유', onTap: () {})),
    );

    final s = _styleOf(tester);
    expect(s.color, DpColors.light.textPrimary);
    expect(s.fontWeight, FontWeight.w600);
    expect(s.decoration, TextDecoration.none);
  });

  testWidgets('title 변형은 hover 하면 강조색 + 밑줄이 된다', (tester) async {
    await tester.pumpWidget(
      _host(DpLink.title(text: '오늘 배운 것 공유', onTap: () {})),
    );

    await _hover(tester, find.byType(DpLink));

    final s = _styleOf(tester);
    expect(s.color, DpColors.light.primaryText);
    expect(s.decoration, TextDecoration.underline);
  });

  testWidgets('inline 변형은 hover 없이도 강조색·밑줄이다', (tester) async {
    await tester.pumpWidget(
      _host(DpLink.inline(text: '경로 전체 보기', onTap: () {})),
    );

    final s = _styleOf(tester);
    expect(s.color, DpColors.light.primaryText);
    expect(s.decoration, TextDecoration.underline);
    expect(s.decorationColor, DpColors.light.primaryText);
    // 제목 변형과 달리 굵기를 올리지 않는다 — 문장 안에 섞이는 링크다.
    expect(s.fontWeight, isNot(FontWeight.w600));
  });

  testWidgets('누르면 onTap 이 불리고 시맨틱스는 link 다', (tester) async {
    var taps = 0;
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(DpLink.inline(text: '이용약관', onTap: () => taps++)),
    );

    await tester.tap(find.byType(DpLink));
    expect(taps, 1);
    // `DpLink` 의 최외곽은 MouseRegion 이라 자체 시맨틱스 노드가 없다.
    // byType 으로 찾으면 위로 올라가 루트(scopesRoute)를 잡으므로, 노드를
    // 실제로 들고 있는 Semantics 까지 글에서부터 올라가게 한다.
    expect(
      tester.getSemantics(find.text('이용약관')),
      matchesSemantics(label: '이용약관', isLink: true, hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('onTap 이 null 이면 링크가 아니라 그냥 글이다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(DpLink.title(text: '삭제된 글')));

    expect(
      tester.getSemantics(find.text('삭제된 글')),
      matchesSemantics(label: '삭제된 글'),
    );
    handle.dispose();
  });
}
