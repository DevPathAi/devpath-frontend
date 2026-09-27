import 'package:dp_design/dp_design.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DpListRow: 제목·뱃지·trailing 렌더 + onTap 콜백', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: Scaffold(
          body: DpListRow(
            title: 'Riverpod 3 마이그레이션 질문',
            badges: const [Text('Q&A')],
            trailing: const Text('답변 3'),
            onTap: () => tapped = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Riverpod 3 마이그레이션 질문'), findsOneWidget);
    expect(find.text('Q&A'), findsOneWidget);
    expect(find.text('답변 3'), findsOneWidget);

    await tester.tap(find.text('Riverpod 3 마이그레이션 질문'));
    expect(tapped, isTrue);
  });

  testWidgets('DpListRow: hover/focus 베이스(FocusableActionDetector) 존재', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: Scaffold(
          body: DpListRow(title: '글', onTap: () {}),
        ),
      ),
    );
    expect(find.byType(FocusableActionDetector), findsWidgets);
  });

  testWidgets('DpListRow: preview 지정 시 hover로 미리보기 등장', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: const Scaffold(
          body: Center(
            child: DpListRow(title: '제목 행', preview: '본문 미리보기 요약 텍스트'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('본문 미리보기 요약 텍스트'), findsNothing); // 초기 미표시

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.text('제목 행')));
    await tester.pumpAndSettle();

    expect(find.text('본문 미리보기 요약 텍스트'), findsOneWidget); // hover 후 등장
  });

  testWidgets('DpListRow: subtitle 은 hover 없이 항상 보인다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: const Scaffold(
          body: DpListRow(title: '검색 결과 제목', subtitle: Text('매칭된 본문 조각')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // preview(hover 전용)와 달리 마우스를 올리지 않아도 보여야 한다 — 검색 하이라이트처럼
    // 행 자체가 근거를 드러내야 하는 용도다.
    expect(find.text('검색 결과 제목'), findsOneWidget);
    expect(find.text('매칭된 본문 조각'), findsOneWidget);
  });

  testWidgets('DpListRow: subtitle 과 preview 는 함께 쓸 수 있다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: const Scaffold(
          body: DpListRow(
            title: '제목',
            subtitle: Text('항상 보이는 부제'),
            preview: '호버해야 보이는 본문',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('항상 보이는 부제'), findsOneWidget);
    expect(find.text('호버해야 보이는 본문'), findsNothing); // hover 전이므로 미표시
  });

  testWidgets(
    'DpListRow: compact width moves trailing metadata below content',
    (tester) async {
      tester.view.physicalSize = const Size(360, 240);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: DpTheme.light(),
          home: const Scaffold(
            body: DpListRow(
              title: '모바일에서도 충분히 읽히는 긴 게시글 제목',
              subtitle: Text('본문의 핵심 내용을 보여주는 설명입니다.'),
              trailing: Text('답변 12 · 추천 24'),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('dp-list-row-mobile-layout')),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.text('답변 12 · 추천 24')).dy,
        greaterThan(tester.getTopLeft(find.text('본문의 핵심 내용을 보여주는 설명입니다.')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('카드가 아니라 하단 구분선을 가진 행이다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: const Scaffold(body: DpListRow(title: '오늘 배운 것 공유')),
      ),
    );

    expect(find.byType(DpInteractiveCard), findsNothing);
    final row = tester.widget<Container>(
      find.byKey(const ValueKey('dp-list-row')),
    );
    final d = row.decoration! as BoxDecoration;
    expect(d.border!.bottom.color, DpColors.light.border);
    expect(d.borderRadius, isNull);
  });

  testWidgets('last 면 구분선이 없다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: const Scaffold(body: DpListRow(title: '마지막 글', last: true)),
      ),
    );

    final row = tester.widget<Container>(
      find.byKey(const ValueKey('dp-list-row')),
    );
    expect((row.decoration! as BoxDecoration).border, isNull);
  });

  testWidgets('행 여백은 표와 같은 8×16 이다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: const Scaffold(body: DpListRow(title: '여백 확인')),
      ),
    );

    final row = tester.widget<Container>(
      find.byKey(const ValueKey('dp-list-row')),
    );
    expect(
      row.padding,
      const EdgeInsets.symmetric(
        vertical: DpDensity.rowPadding,
        horizontal: DpSpacing.lg,
      ),
    );
  });

  testWidgets('제목은 DpLink.title 로 그려진다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: Scaffold(
          body: DpListRow(title: '제목', onTap: () {}),
        ),
      ),
    );

    expect(find.byType(DpLink), findsOneWidget);
  });
}
