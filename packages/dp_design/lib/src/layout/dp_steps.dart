import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';
import 'dp_window_class.dart';

/// 진행 단계 표시(시안 `.steps`) — 테두리 한 겹 안에 단계가 나란히 놓인다.
///
/// 현재 단계는 `accentSoft` 배경 + `primaryTextStrong` + 600 이고, 스크린리더에는
/// `selected` 로 알린다(시안 `li[aria-current="step"]`). compact 에서는 세로로
/// 쌓인다 — 세 단계를 390px 에 나란히 두면 글자가 잘린다.
class DpSteps extends StatelessWidget {
  const DpSteps({super.key, required this.labels, required this.currentIndex});

  final List<String> labels;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final vertical = context.windowClass == DpWindowClass.compact;

    final items = <Widget>[
      for (var i = 0; i < labels.length; i++)
        _Step(
          label: labels[i],
          current: i == currentIndex,
          // 마지막이 아니면 다음 단계와의 사이에 구분선을 둔다.
          divider: i != labels.length - 1,
          vertical: vertical,
        ),
    ];

    return Container(
      key: const ValueKey('dp-steps'),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(DpRadius.button),
      ),
      clipBehavior: Clip.antiAlias,
      child: vertical
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: items,
            )
          : Row(children: [for (final item in items) Expanded(child: item)]),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.label,
    required this.current,
    required this.divider,
    required this.vertical,
  });

  final String label;
  final bool current;
  final bool divider;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: DpSpacing.xs,
        horizontal: DpSpacing.md,
      ),
      decoration: BoxDecoration(
        color: current ? c.accentSoft : null,
        border: divider
            ? Border(
                right: vertical ? BorderSide.none : BorderSide(color: c.border),
                bottom: vertical
                    ? BorderSide(color: c.border)
                    : BorderSide.none,
              )
            : null,
      ),
      child: Semantics(
        selected: current,
        child: Text(
          label,
          style: TextStyle(
            color: current ? c.primaryTextStrong : c.textSecondary,
            fontWeight: current ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
