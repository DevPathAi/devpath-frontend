import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

/// Web-safe production projection for the native content reader surface.
///
/// Progress timers, persistence, and API writes are deliberately owned by
/// [ContentViewerPage]; this widget contains the same visible production body
/// and can be held frozen while release evidence is captured.
class MobileContentProjection extends StatelessWidget {
  const MobileContentProjection({
    super.key,
    required this.content,
    required this.scrollController,
    required this.onComplete,
    this.progressFailureMessage,
    this.loadFailureMessage,
    this.fromOfflineCache = false,
  });

  final LearningContent content;
  final ScrollController scrollController;
  final VoidCallback onComplete;
  final String? progressFailureMessage;
  final String? loadFailureMessage;
  final bool fromOfflineCache;

  @override
  Widget build(BuildContext context) {
    final progress = content.progress;
    final completed = progress.completed;
    final percent = (progress.scrollPct * 100).round().clamp(0, 100);
    final meta = [
      if (content.estimatedMinutes != null) '${content.estimatedMinutes}분',
      if (content.bloomLevel != null)
        DpLearningLabels.bloomLevel(content.bloomLevel!),
      if (content.difficulty != null)
        '난이도 ${DpLearningLabels.difficulty(content.difficulty!)}',
    ];
    return Column(
      children: [
        if (loadFailureMessage != null)
          DpOfflineBanner(
            message: fromOfflineCache
                ? '오프라인에 저장된 콘텐츠예요. $loadFailureMessage'
                : '읽던 콘텐츠를 유지했어요. $loadFailureMessage',
          ),
        if (progressFailureMessage != null)
          DpOfflineBanner(
            message: '$progressFailureMessage 읽던 콘텐츠와 로컬 진행률은 유지했어요.',
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DpSpacing.lg,
            DpSpacing.sm,
            DpSpacing.lg,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: progress.scrollPct.clamp(0, 1).toDouble(),
                ),
              ),
              const SizedBox(width: DpSpacing.sm),
              Text(
                completed ? '완료' : '$percent%',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(DpSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (meta.isNotEmpty)
                  Text(
                    meta.join(' · '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.dpColors.textSecondary,
                    ),
                  ),
                if (content.conceptTags.isNotEmpty) ...[
                  const SizedBox(height: DpSpacing.sm),
                  Wrap(
                    spacing: DpSpacing.sm,
                    runSpacing: DpSpacing.sm,
                    children: [
                      for (final tag in content.conceptTags)
                        Chip(label: Text('#$tag')),
                    ],
                  ),
                ],
                if (meta.isNotEmpty || content.conceptTags.isNotEmpty)
                  const SizedBox(height: DpSpacing.lg),
                DpContextCapsule(
                  name: '이 콘텐츠의 학습 맥락',
                  mode: DpContextCapsuleMode.collapsed,
                  fields: [
                    DpContextFieldViewModel(
                      id: 'track',
                      label: '학습 경로',
                      valueSummary: DpLearningLabels.track(content.track),
                      source: '현재 콘텐츠',
                      sensitivity: DpContextSensitivity.low,
                      inclusion: DpContextInclusion.included,
                    ),
                    if (content.bloomLevel != null)
                      DpContextFieldViewModel(
                        id: 'bloom',
                        label: '학습 단계',
                        valueSummary: DpLearningLabels.bloomLevel(
                          content.bloomLevel!,
                        ),
                        source: '현재 콘텐츠',
                        sensitivity: DpContextSensitivity.low,
                        inclusion: DpContextInclusion.included,
                      ),
                  ],
                ),
                const SizedBox(height: DpSpacing.lg),
                DpMarkdown(data: content.markdown),
              ],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(DpSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: completed ? null : onComplete,
                icon: const Icon(DpIcons.stepDone),
                label: Text(completed ? '완료됨' : '완료로 표시'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
