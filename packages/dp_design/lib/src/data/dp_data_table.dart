import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';

// 소비 화면이 dp_design만 import하도록 테이블 셀/컬럼 타입을 re-export.
export 'package:data_table_2/data_table_2.dart' show DataColumn2, DataRow2;

/// 데이터 테이블(Layer 2). data_table_2를 래핑해 헤더 고정·가로 스크롤바·최소 폭·
/// 토큰 테마를 기본 제공한다. go_router·Riverpod 비의존 순수 표현부.
class DpDataTable extends StatelessWidget {
  const DpDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.minWidth,
    this.fixedLeftColumns = 0,
    this.empty,
  });

  final List<DataColumn2> columns;
  final List<DataRow2> rows;
  final double? minWidth;
  final int fixedLeftColumns;
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    return DataTable2(
      columns: columns,
      rows: rows,
      minWidth: minWidth,
      fixedLeftColumns: fixedLeftColumns,
      isHorizontalScrollBarVisible: true,
      empty: empty,
      headingRowColor: WidgetStatePropertyAll(c.surface),
      border: TableBorder.all(color: c.border, width: 1),
    );
  }
}
