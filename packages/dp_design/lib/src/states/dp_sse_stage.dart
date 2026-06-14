import 'package:flutter/material.dart';

import '../icons/dp_icons.dart';
import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';

/// SSE 단계 진행 표시(경로생성 4단계 등). 완료 단계 체크 + 현재 단계 강조.
/// DD8 이어하기 UX(중단 보존)는 사용처(P4)가 currentIndex/partial을 갱신해 구성.
class DpSseStageView extends StatelessWidget {
  const DpSseStageView({
    super.key,
    required this.stages,
    required this.currentIndex,
  });

  final List<String> stages;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    return Semantics(
      liveRegion: true, // SSE 업데이트를 스크린리더에 고지(DD7)
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < stages.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: DpSpacing.xs),
              child: Row(
                children: [
                  Icon(
                    i < currentIndex
                        ? DpIcons.stepDone
                        : (i == currentIndex
                            ? DpIcons.stepCurrent
                            : DpIcons.stepPending),
                    size: 18,
                    color: i <= currentIndex ? c.primaryText : c.textSecondary,
                  ),
                  const SizedBox(width: DpSpacing.sm),
                  Text(
                    stages[i],
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: i <= currentIndex ? c.textPrimary : c.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
