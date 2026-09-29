import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';
import '../theme/dp_typography.dart';
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
          key: ValueKey('dp-step-$i'),
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
          : IntrinsicHeight(
              // 시안 `.steps` 는 flex 기본 align-items:stretch 다. Row 의
              // `stretch` 만으로는 안 된다 — 세로 제약이 무한인 자리에서는
              // 무한 높이가 자식에게 넘어간다. IntrinsicHeight 가 가장 높은
              // 자식의 높이를 먼저 정해 준다.
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final item in items) Expanded(child: item)],
              ),
            ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    super.key,
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
        vertical: DpWebDensity.stepVerticalPadding,
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
          // 시안 `.steps li{font-size:13px}`. 시안은 `line-height` 를 덮지 않아
          // `body{line-height:1.6}` 을 물려받으므로 bodySmall(13 / 20)이 아니라
          // 본문에서 크기만 줄인 것이다 — context.dpBody(13) 이 그 뜻이다.
          style: context
              .dpBody(13)
              .copyWith(
                color: current ? c.primaryTextStrong : c.textSecondary,
                fontWeight: current ? FontWeight.w600 : FontWeight.w400,
              ),
        ),
      ),
    );
  }
}
