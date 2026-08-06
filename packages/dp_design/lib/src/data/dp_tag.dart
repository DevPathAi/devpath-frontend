import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';

/// 중립 태그 칩. 배경 [DpColors.tagBg] / 전경 [DpColors.tagText].
///
/// 이 위젯이 tag* 토큰의 유일한 배선 지점이다. 이전에는 맨 Material Chip
/// (M3 기본색)과 border를 배경에 쓴 Container가 섞여 있었다.
class DpTag extends StatelessWidget {
  const DpTag({super.key, required this.label, this.tone});

  final String label;

  /// 전경색만 덮는다(신고 카테고리·위험도 구분 등). 배경은 언제나 tagBg다.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    return Container(
      key: const ValueKey('dp-tag'),
      padding: const EdgeInsets.symmetric(
        horizontal: DpSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: c.tagBg,
        borderRadius: BorderRadius.circular(DpRadius.button),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: tone ?? c.tagText),
      ),
    );
  }
}
