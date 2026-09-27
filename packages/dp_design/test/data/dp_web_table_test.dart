import 'package:dp_design/dp_design.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(
  Widget child, {
  double width = 1120,
  Brightness brightness = Brightness.light,
}) => MaterialApp(
  theme: brightness == Brightness.light ? DpTheme.light() : DpTheme.dark(),
  home: Scaffold(
    body: Center(
      child: SizedBox(width: width, child: child),
    ),
  ),
);

const _columns = <DpTableColumn>[
  (label: '제목', width: null, numeric: false),
  (label: '댓글', width: 72, numeric: true),
  (label: '작성', width: 96, numeric: true),
];

DpWebTable _table({
  List<DpTableRowSpec>? rows,
  Widget empty = const Text('아직 글이 없어요'),
  double minWidth = 640,
}) => DpWebTable(
  columns: _columns,
  minWidth: minWidth,
  empty: empty,
  rows:
      rows ??
      const [
        (cells: [Text('오늘 배운 것 공유'), Text('1'), Text('3시간 전')], onTap: null),
        (cells: [Text('배포 자동화 팁'), Text('3'), Text('어제')], onTap: null),
      ],
);

void main() {
  testWidgets('헤더 라벨과 각 행의 셀을 모두 그린다', (tester) async {
    await tester.pumpWidget(_host(_table()));

    expect(find.text('제목'), findsOneWidget);
    expect(find.text('댓글'), findsOneWidget);
    expect(find.text('오늘 배운 것 공유'), findsOneWidget);
    expect(find.text('배포 자동화 팁'), findsOneWidget);
  });

  testWidgets('행마다 하단 구분선이 있고 마지막 행에는 없다', (tester) async {
    await tester.pumpWidget(_host(_table()));

    final rows = tester
        .widgetList<Container>(find.byKey(const ValueKey('dp-web-table-row')))
        .toList();
    expect(rows.length, 2);
    final first = rows.first.decoration! as BoxDecoration;
    final last = rows.last.decoration! as BoxDecoration;
    expect(first.border!.bottom.width, 1);
    expect(first.border!.bottom.color, DpColors.light.border);
    expect(last.border, isNull);
  });

  testWidgets('행 세로 여백은 DpDensity.rowPadding, 가로는 DpSpacing.lg', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_table()));

    final row = tester.widget<Container>(
      find.byKey(const ValueKey('dp-web-table-row')).first,
    );
    expect(
      row.padding,
      const EdgeInsets.symmetric(
        vertical: DpDensity.rowPadding,
        horizontal: DpSpacing.lg,
      ),
    );
  });

  testWidgets('긴 제목은 줄바꿈하고 숫자 칼럼 폭은 그대로다', (tester) async {
    const long =
        '비전공자 백엔드 전향 6개월 회고 — 퇴근 후 하루 한 시간씩 무엇이 '
        '남았고 무엇을 버렸는지 적어 봅니다';
    await tester.pumpWidget(
      _host(
        _table(
          rows: const [
            (cells: [Text(long), Text('12'), Text('3일 전')], onTap: null),
          ],
        ),
      ),
    );

    // 제목이 두 줄 이상으로 흘러도
    expect(
      tester.getSize(find.text(long)).height,
      greaterThan(tester.getSize(find.text('12')).height),
    );
    // 숫자 칼럼은 선언한 폭을 지킨다.
    final commentCell = find.ancestor(
      of: find.text('12'),
      matching: find.byType(SizedBox),
    );
    expect(tester.widget<SizedBox>(commentCell.first).width, 72);
  });

  testWidgets('행이 없고 empty 가 있으면 표 대신 empty 를 그린다', (tester) async {
    await tester.pumpWidget(
      _host(_table(rows: const [], empty: const Text('아직 글이 없어요'))),
    );

    expect(find.text('아직 글이 없어요'), findsOneWidget);
    expect(find.byKey(const ValueKey('dp-web-table-header')), findsNothing);
  });

  testWidgets('390px 에서는 표만 가로 스크롤하고 본문은 넘치지 않는다', (tester) async {
    await tester.pumpWidget(_host(_table(), width: 390));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('dp-web-table-scroll')), findsOneWidget);
    expect(
      tester.getSize(find.byType(DpWebTable)).width,
      lessThanOrEqualTo(390),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('minWidth 이상 폭에서는 스크롤을 감싸지 않는다', (tester) async {
    await tester.pumpWidget(_host(_table(), width: 1120));

    expect(find.byKey(const ValueKey('dp-web-table-scroll')), findsNothing);
  });

  testWidgets('행의 각 셀이 시맨틱스에서 따로 읽힌다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        _table(
          rows: [
            (cells: const [Text('제목 A'), Text('7'), Text('어제')], onTap: () {}),
          ],
        ),
      ),
    );

    // 세 셀이 한 노드로 병합되면 '제목 A\n7\n어제' 하나만 남는다.
    expect(find.bySemanticsLabel('제목 A'), findsOneWidget);
    expect(find.bySemanticsLabel('7'), findsOneWidget);
    expect(find.bySemanticsLabel('어제'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('hover 하면 행 배경이 surfaceMuted 가 된다', (tester) async {
    await tester.pumpWidget(_host(_table()));

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.text('오늘 배운 것 공유')));
    await tester.pump();

    final row = tester.widget<Container>(
      find.byKey(const ValueKey('dp-web-table-row')).first,
    );
    expect(
      (row.decoration! as BoxDecoration).color,
      DpColors.light.surfaceMuted,
    );
  });

  testWidgets('다크 테마의 구분선은 dark 토큰을 쓴다', (tester) async {
    await tester.pumpWidget(_host(_table(), brightness: Brightness.dark));

    final row = tester.widget<Container>(
      find.byKey(const ValueKey('dp-web-table-row')).first,
    );
    final d = row.decoration! as BoxDecoration;
    expect(d.border!.bottom.color, DpColors.dark.border);
    expect(d.border!.bottom.color, isNot(DpColors.light.border));
  });

  testWidgets('390px 의 가로 스크롤에는 항상 보이는 스크롤바가 붙는다', (tester) async {
    await tester.pumpWidget(_host(_table(), width: 390));
    await tester.pumpAndSettle();

    // 잘렸다는 표시가 없으면 숨은 칼럼에 도달할 방법을 찾지 못한다.
    // 레포에 이미 있는 DpScrollbar 가 정확히 이 용도다.
    expect(find.byType(DpScrollbar), findsOneWidget);
  });

  testWidgets('헤더 라벨은 본문 대비(4.5:1) 를 만족하는 토큰을 쓴다', (tester) async {
    await tester.pumpWidget(_host(_table()));

    final label = tester.widget<Text>(find.text('제목'));
    // textFaint(라이트 3.52:1)는 토큰 자신이 본문 텍스트 금지로 못 박은 값이다.
    // 칼럼 라벨은 「이 열이 무엇인가」를 전달하는 유일한 수단이라 장식이 아니다.
    expect(label.style!.color, DpColors.light.textSecondary);
    expect(label.style!.color, isNot(DpColors.light.textFaint));
  });

  test('셀 개수가 칼럼 수와 다르면 assert 로 막는다', () {
    // doc 에만 있던 계약이다. 어기면 배치 중 RangeError 로 터지고, 그 스택에는
    // 원인이 칼럼 정의에 있다는 단서가 남지 않는다.
    expect(
      () => DpWebTable(
        columns: const [
          (label: '제목', width: null, numeric: false),
          (label: '추천', width: null, numeric: true),
        ],
        rows: const [
          (cells: [Text('제목만')], onTap: null),
        ],
        empty: const Text('비었다'),
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  testWidgets('numeric 유연 칼럼도 우측 정렬한다', (tester) async {
    await tester.pumpWidget(
      _host(
        DpWebTable(
          columns: const [
            (label: '제목', width: null, numeric: false),
            (label: '추천', width: null, numeric: true),
          ],
          rows: const [
            (cells: [Text('제목 A'), Text('7')], onTap: null),
          ],
          empty: const Text('비었다'),
        ),
      ),
    );

    // `numeric` 은 칼럼 폭과 무관한 약속이다(DpTableColumn doc). 고정폭 분기에만
    // 정렬이 있으면 유연 칼럼에서 조용히 좌측 정렬이 된다.
    final align = tester.widget<Align>(
      find.ancestor(of: find.text('7'), matching: find.byType(Align)).first,
    );
    expect(align.alignment, Alignment.centerRight);
  });
}
