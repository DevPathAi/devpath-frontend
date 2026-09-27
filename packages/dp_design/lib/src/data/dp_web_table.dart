import 'package:flutter/material.dart';

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
class DpWebTable extends StatelessWidget {
  const DpWebTable({
    super.key,
    required this.columns,
    required this.rows,
    this.minWidth = 640,
    this.empty,
  });

  final List<DpTableColumn> columns;
  final List<DpTableRowSpec> rows;

  /// 이 폭보다 좁으면 표만 가로로 스크롤한다(페이지 본문은 넘치지 않는다).
  final double minWidth;

  /// 행이 없을 때 표 대신 보여 줄 것. null 이면 헤더만 남는다.
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty && empty != null) return empty!;

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
        return SingleChildScrollView(
          key: const ValueKey('dp-web-table-scroll'),
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: minWidth, child: table),
        );
      },
    );
  }
}

List<Widget> _cells(List<DpTableColumn> columns, List<Widget> children) => [
  for (var i = 0; i < columns.length; i++)
    if (columns[i].width == null)
      Expanded(child: children[i])
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
                color: c.textFaint,
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
