import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';
import '../theme/dp_tokens.dart';

enum DpMissionHeaderVariant { compact, standard }

enum DpMissionHeaderStatus { loading, stale, active, completed }

/// 현재 미션을 설명하는 표현 전용 헤더.
///
/// 값의 출처나 현재 task를 계산하지 않는다. feature 계층이 만든 week/title/why/
/// completion/progress projection만 표시한다.
class DpMissionHeader extends StatelessWidget {
  const DpMissionHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.why,
    required this.completionCriterion,
    required this.progressValue,
    required this.progressLabel,
    this.variant = DpMissionHeaderVariant.standard,
    this.status = DpMissionHeaderStatus.active,
    this.headingFocusNode,
  }) : assert(progressValue >= 0 && progressValue <= 1);

  final String eyebrow;
  final String title;
  final String why;
  final String completionCriterion;
  final double progressValue;
  final String progressLabel;
  final DpMissionHeaderVariant variant;
  final DpMissionHeaderStatus status;

  /// 라우트 이동 뒤 feature 계층이 제목에 프로그램 포커스를 둘 때 사용한다.
  /// 제목은 일반 tab traversal에는 참여하지 않는다.
  final FocusNode? headingFocusNode;

  @override
  Widget build(BuildContext context) {
    final colors = context.dpColors;
    final textTheme = Theme.of(context).textTheme;
    final compact = variant == DpMissionHeaderVariant.compact;
    final padding = compact ? DpSpacing.md : DpSpacing.xl;
    final gap = compact ? DpSpacing.sm : DpSpacing.md;
    final percent = (progressValue * 100).round();

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        key: const ValueKey('dp-mission-header-surface'),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(context.appTokens.panelRadius),
          border: Border.all(color: colors.border),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(color: colors.primary),
                child: const SizedBox(width: 3),
              ),
            ),
            Padding(
              key: const ValueKey('dp-mission-header-padding'),
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: DpSpacing.sm,
                    runSpacing: DpSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        eyebrow,
                        style: textTheme.labelMedium?.copyWith(
                          color: colors.primaryTextStrong,
                        ),
                      ),
                      _MissionStatusLabel(status: status),
                    ],
                  ),
                  SizedBox(height: gap),
                  Focus(
                    key: const ValueKey('dp-mission-header-heading-focus'),
                    focusNode: headingFocusNode,
                    skipTraversal: true,
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        key: const ValueKey('dp-mission-header-title'),
                        style:
                            (compact
                                    ? textTheme.titleLarge
                                    : textTheme.headlineSmall)
                                ?.copyWith(color: colors.textPrimary),
                      ),
                    ),
                  ),
                  SizedBox(height: gap),
                  Text(
                    why,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: gap),
                  Text(
                    '완료 조건 · $completionCriterion',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: gap),
                  Semantics(
                    label: '$progressLabel, $percent%',
                    value: '$percent%',
                    excludeSemantics: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$progressLabel · $percent%',
                          style: textTheme.labelMedium?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: DpSpacing.xs),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(DpRadius.chip),
                          child: LinearProgressIndicator(
                            value: progressValue,
                            minHeight: 6,
                            color: status == DpMissionHeaderStatus.completed
                                ? colors.success
                                : colors.primary,
                            backgroundColor: colors.border,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissionStatusLabel extends StatelessWidget {
  const _MissionStatusLabel({required this.status});

  final DpMissionHeaderStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.dpColors;
    final (label, foreground, background, liveRegion) = switch (status) {
      DpMissionHeaderStatus.loading => (
        '미션 정보를 불러오는 중',
        colors.textSecondary,
        colors.surfaceMuted,
        true,
      ),
      DpMissionHeaderStatus.stale => (
        '마지막으로 확인한 미션',
        colors.warning,
        colors.surfaceMuted,
        false,
      ),
      DpMissionHeaderStatus.active => (
        '진행 중',
        colors.primaryTextStrong,
        colors.accentSoft,
        false,
      ),
      DpMissionHeaderStatus.completed => (
        '완료됨',
        colors.success,
        colors.surfaceMuted,
        true,
      ),
    };

    return Semantics(
      liveRegion: liveRegion,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(DpRadius.chip),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DpSpacing.sm,
            vertical: DpSpacing.xs,
          ),
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: foreground),
          ),
        ),
      ),
    );
  }
}
