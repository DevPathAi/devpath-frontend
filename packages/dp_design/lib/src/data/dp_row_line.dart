import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';

/// 설정·동의 관리의 한 행(시안 `.rowline`).
///
/// 좌측 라벨(600) + 선택적 설명(13px 보조색), 우측 컨트롤. 좁은 폭에서는
/// `Wrap` 이 컨트롤을 아래 줄로 내린다 — `Row` 로 두면 390px 에서 넘친다.
class DpRowLine extends StatelessWidget {
  const DpRowLine({
    super.key,
    required this.label,
    this.description,
    this.trailing,
    this.last = false,
  });

  final Widget label;
  final Widget? description;
  final Widget? trailing;

  /// 목록의 마지막 행이면 하단 구분선을 그리지 않는다.
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;

    return Container(
      key: const ValueKey('dp-row-line'),
      padding: const EdgeInsets.symmetric(
        vertical: 10,
        horizontal: DpSpacing.lg,
      ),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: c.border)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: DpSpacing.lg,
        runSpacing: DpSpacing.sm,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              DefaultTextStyle.merge(
                style: text.bodyMedium?.copyWith(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                child: label,
              ),
              if (description != null)
                DefaultTextStyle.merge(
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                  child: description!,
                ),
            ],
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
