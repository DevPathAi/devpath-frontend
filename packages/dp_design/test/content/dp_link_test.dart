import 'package:dp_design/dp_design.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(body: child),
);

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
    //
    // 전수 매처(`matchesSemantics`) 대신 핵심 플래그만 본다 — 링크가 키보드
    // 순회 대상이라 isFocusable 같은 플래그가 함께 붙고, 그것들은 결함이 아니라
    // 요구사항이다.
    final data = tester.getSemantics(find.text('이용약관')).getSemanticsData();
    expect(data.label, '이용약관');
    expect(data.flagsCollection.isLink, isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
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

  testWidgets('Tab 으로 포커스를 받고 Enter 로 활성화된다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(DpLink.title(text: '링크', onTap: () => taps++)),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.context?.widget,
      isNot(isA<FocusScope>()),
      reason: '링크가 순회 대상이 아니면 포커스는 라우트 스코프에 머문다',
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('포커스를 받으면 시안의 2px 외곽선이 보인다', (tester) async {
    await tester.pumpWidget(_host(DpLink.inline(text: '이용약관', onTap: () {})));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('dp-link-focus-ring')), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('dp-link-focus-ring')), findsOneWidget);
  });

  testWidgets('하이라이트 모드가 touch 여도 focused 가 실제 포커스를 따른다', (tester) async {
    // `onShowFocusHighlight` 는 highlightMode 가 traditional 일 때만 불린다.
    // 이 위젯의 `Semantics.focused` 는 자식 subtree 를 excludeSemantics 로 가린
    // 뒤 **직접 선언하는 유일한 진실**이므로, 하이라이트 정책이 아니라 실제
    // 포커스를 따라야 한다.
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTouch;
    addTearDown(() {
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic;
    });

    await tester.pumpWidget(_host(DpLink.title(text: '제목 링크', onTap: () {})));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    // 포커스 링과 `Semantics.focused` 는 같은 `_focused` 를 공유한다. 링을 보는
    // 쪽이 시맨틱스 플래그 타입(버전마다 bool/Tristate 로 갈린다)에 의존하지 않는다.
    expect(find.byKey(const ValueKey('dp-link-focus-ring')), findsOneWidget);
  });

  testWidgets('onTap 이 null 이면 순회 대상이 아니다', (tester) async {
    await tester.pumpWidget(_host(DpLink.title(text: '삭제된 글')));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('dp-link-focus-ring')), findsNothing);
  });
}
