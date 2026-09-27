import 'package:flutter/material.dart';

import '../layout/dp_scrollbar.dart';
import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';

/// 표의 칼럼 정의.
///
/// [width] 가 null 이면 남는 폭을 다른 유연 칼럼과 나눠 갖는다.
/// [numeric] 이면 우측 정렬 + 등폭 숫자 + 보조 텍스트색이고 줄바꿈하지 않는다.
typedef DpTableColumn = ({String label, double? width, bool numeric});

/// 표의 한 행. [cells] 길이는 칼럼 수와 같아야 한다.
typedef DpTableRowSpec = ({List<Widget> cells, VoidCallback? onTap});

/// 웹 문법 표(시안 `<table>`) — 헤더행 + 가로 구분선 + hover 배경.
///
/// `DpDataTable`(admin 이 쓰는 `data_table_2` 래퍼)과 **다른 위젯**이다.
/// 그쪽은 `TableBorder.all` 로 세로 테두리를 그리지만 시안의 표에는
/// 세로선이 없다.
///
/// hover 배경은 `surfaceMuted` 다 — 시안 `tbody tr:hover{background:var(--muted)}`
/// 와 같은 값이다. 그 대비는 `surface` 위에서 1.12:1, `bg` 위에서 1.046:1 이라
/// **이 위젯은 `DpPanel` 안에서만 쓴다.** 행을 클릭할 수 있다는 어포던스는
/// hover 배경이 아니라 제목의 `DpLink.title` hover 밑줄이 담당한다.
class DpWebTable extends StatefulWidget {
  DpWebTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.empty,
    this.minWidth = 640,
  }) : assert(
         // doc 에만 있던 계약을 코드로 올린다. 어기면 배치 중 RangeError 로
         // 터지고, 그 스택에는 원인이 칼럼 정의에 있다는 단서가 남지 않는다.
         // `rows.every` 를 부르므로 이 생성자는 더 이상 const 가 아니다 —
         // 표는 화면당 한두 개라 비용이 무의미하다.
         rows.every((row) => row.cells.length == columns.length),
         'DpTableRowSpec.cells 길이는 columns 길이와 같아야 한다.',
       );

  final List<DpTableColumn> columns;
  final List<DpTableRowSpec> rows;

  /// 이 폭보다 좁으면 표만 가로로 스크롤한다(페이지 본문은 넘치지 않는다).
  final double minWidth;

  /// 행이 없을 때 표 대신 보여 줄 것. **필수다** — 헤더만 남은 표는 「목록이
  /// 비었다」를 전달하지 못한다(기본값이 곧 실패 상태였다).
  final Widget empty;

  @override
  State<DpWebTable> createState() => _DpWebTableState();
}

class _DpWebTableState extends State<DpWebTable> {
  final _horizontal = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final columns = widget.columns;
    final rows = widget.rows;
    final minWidth = widget.minWidth;
    if (rows.isEmpty) return widget.empty;

    final table = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Header(columns: columns),
        for (var i = 0; i < rows.length; i++)
          _Row(columns: columns, spec: rows[i], last: i == rows.length - 1),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || constraints.maxWidth >= minWidth) {
          return table;
        }
        // 잘렸다는 표시가 없으면 숨은 칼럼에 도달할 방법을 찾지 못한다
        // (Flutter 는 shift+휠에만 가로 스크롤을 준다). `DpScrollbar` 가
        // 레포에서 정확히 이 용도로 있는 프리미티브다.
        return DpScrollbar(
          controller: _horizontal,
          child: SingleChildScrollView(
            key: const ValueKey('dp-web-table-scroll'),
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: minWidth, child: table),
          ),
        );
      },
    );
  }
}

// `numeric` 은 칼럼 폭과 무관한 약속이다(`DpTableColumn` doc). 고정폭 분기에만
// 정렬을 넣으면 유연 칼럼에서 조용히 좌측 정렬이 된다(실측: `Align` 조상 자체가
// 없었다).
List<Widget> _cells(List<DpTableColumn> columns, List<Widget> children) => [
  for (var i = 0; i < columns.length; i++)
    if (columns[i].width == null)
      Expanded(
        child: Align(
          alignment: columns[i].numeric
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: children[i],
        ),
      )
    else
      SizedBox(
        width: columns[i].width,
        child: Align(
          alignment: columns[i].numeric
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: children[i],
        ),
      ),
];

class _Header extends StatelessWidget {
  const _Header({required this.columns});

  final List<DpTableColumn> columns;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    return Container(
      key: const ValueKey('dp-web-table-header'),
      padding: const EdgeInsets.symmetric(
        vertical: DpSpacing.sm,
        horizontal: DpSpacing.lg,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: _cells(columns, [
          for (final col in columns)
            Text(
              col.label,
              softWrap: false,
              overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                // 시안 `th` 는 `--faint` 지만 그 토큰은 라이트에서 3.52:1 이라
                // WCAG AA(4.5:1) 에 못 미치고, `DpColors` 자신이 "본문 텍스트로
                // 쓰지 않는다"고 못 박았다. 칼럼 라벨은 「이 열이 무엇인가」를
                // 전달하는 유일한 수단이라 장식 글리프가 아니다.
                color: c.textSecondary,
              ),
            ),
        ]),
      ),
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({required this.columns, required this.spec, required this.last});

  final List<DpTableColumn> columns;
  final DpTableRowSpec spec;
  final bool last;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final body = Container(
      key: const ValueKey('dp-web-table-row'),
      padding: const EdgeInsets.symmetric(
        vertical: DpDensity.rowPadding,
        horizontal: DpSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: _hovered ? c.surfaceMuted : null,
        border: widget.last
            ? null
            : Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _cells(widget.columns, [
          for (var i = 0; i < widget.columns.length; i++)
            if (widget.columns[i].numeric)
              DefaultTextStyle.merge(
                style: TextStyle(
                  color: c.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                softWrap: false,
                overflow: TextOverflow.clip,
                child: widget.spec.cells[i],
              )
            else
              widget.spec.cells[i],
        ]),
      ),
    );

    return MouseRegion(
      cursor: widget.spec.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: widget.spec.onTap == null
          ? body
          // `excludeFromSemantics: true` 가 없으면 이 제스처의 시맨틱스 노드가
          // 셀 조각들을 **흡수해** 행 전체가 '제목\n7\n어제' 한 덩어리가 된다
          // (실측 2026-09-27: 같은 표의 헤더는 그 노드가 없어 셋으로 남았다).
          // 그러면 스크린리더가 칼럼 값을 따로 읽지 못한다.
          //
          // 행 클릭은 **포인터 사용자를 위한 보조 수단**이다 — 시안의 표도
          // 행이 아니라 제목 `a.ttl` 만 링크다. 접근성 컨트롤은 제목 셀에 넣는
          // `DpLink.title` 이 담당하므로, 제스처를 시맨틱스에서 빼는 것이
          // 라벨 없는 탭 대상을 만드는 것보다 낫다.
          : GestureDetector(
              onTap: widget.spec.onTap,
              excludeFromSemantics: true,
              child: body,
            ),
    );
  }
}
