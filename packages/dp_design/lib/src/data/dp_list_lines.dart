import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';

/// 구분선 목록(시안 `.list`) — 사이드 패널의 짧은 목록.
///
/// 세로 여백 10 은 시안 `.list li` 값 그대로이며 표 행(8)보다 조금 넓다.
/// 표는 칼럼 정렬로도 행을 가르지만 이 목록은 구분선과 여백만으로 가르기
/// 때문에 같은 값을 쓰면 답답해진다. 토큰 상수가 없는 유일한 치수다.
class DpListLines extends StatelessWidget {
  const DpListLines({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++)
          _Line(last: i == children.length - 1, child: children[i]),
      ],
    );
  }
}

/// 항목 하나. 별도 위젯으로 빼는 이유는 키 때문이다 — 같은 `ValueKey` 를 단
/// Container 들을 Column 의 **형제**로 두면 `Duplicate keys found` 로 죽는다.
/// 이 래퍼가 한 겹 끼면 키를 가진 Container 들은 서로 형제가 아니게 된다.
class _Line extends StatelessWidget {
  const _Line({required this.child, required this.last});

  final Widget child;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    return Container(
      key: const ValueKey('dp-list-line'),
      padding: const EdgeInsets.symmetric(
        vertical: DpWebDensity.rowVerticalPadding,
        horizontal: DpSpacing.lg,
      ),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: c.border)),
      ),
      child: child,
    );
  }
}
