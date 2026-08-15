import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

import '../../application/current_mission_controller.dart';

class TodayMissionSection extends StatelessWidget {
  const TodayMissionSection({
    super.key,
    required this.state,
    required this.onRetry,
    required this.onOpenPath,
    required this.onOpenContent,
    required this.onCompleteContentless,
  });

  final CurrentMissionState state;
  final VoidCallback onRetry;
  final VoidCallback onOpenPath;
  final ValueChanged<int> onOpenContent;
  final ValueChanged<int> onCompleteContentless;

  @override
  Widget build(BuildContext context) {
    final mission = state.mission;
    if (mission == null) {
      if (state.isLoading) {
        return const Padding(
          padding: EdgeInsets.all(DpSpacing.xl),
          child: DpLoading(label: '오늘의 미션을 불러오는 중'),
        );
      }
      return Padding(
        padding: const EdgeInsets.all(DpSpacing.lg),
        child: DpError(
          title: '오늘의 미션을 불러오지 못했어요',
          message: state.failureMessage ?? '학습 기록은 그대로예요. 현재 미션만 다시 확인해 주세요.',
          onRetry: onRetry,
        ),
      );
    }

    return switch (mission.outcome) {
      CurrentMissionOutcome.available => _AvailableMission(
        state: state,
        mission: mission,
        onRetry: onRetry,
        onOpenContent: onOpenContent,
        onCompleteContentless: onCompleteContentless,
      ),
      CurrentMissionOutcome.pathCompleted => _CompletedMission(
        mission: mission,
        onOpenPath: onOpenPath,
      ),
      CurrentMissionOutcome.noActivePath => Padding(
        padding: const EdgeInsets.all(DpSpacing.lg),
        child: DpEmpty(
          title: '아직 학습 경로가 없어요',
          message: '저장된 진단 결과로 경로를 만들면 오늘의 첫 미션이 여기에 표시돼요.',
          actionLabel: '경로 만들기',
          onAction: onOpenPath,
        ),
      ),
      CurrentMissionOutcome.malformedPath => Padding(
        padding: const EdgeInsets.all(DpSpacing.lg),
        child: DpError(
          title: '현재 미션을 확인할 수 없어요',
          message: '경로의 주차나 과제를 임의로 추정하지 않았어요. 서버 기록을 다시 확인해 주세요.',
          onRetry: onRetry,
        ),
      ),
    };
  }
}

class _AvailableMission extends StatelessWidget {
  const _AvailableMission({
    required this.state,
    required this.mission,
    required this.onRetry,
    required this.onOpenContent,
    required this.onCompleteContentless,
  });

  final CurrentMissionState state;
  final CurrentMission mission;
  final VoidCallback onRetry;
  final ValueChanged<int> onOpenContent;
  final ValueChanged<int> onCompleteContentless;

  @override
  Widget build(BuildContext context) {
    final task = mission.nextTask!;
    final completedCount = mission.tasks.where((task) => task.completed).length;
    final progress = mission.tasks.isEmpty
        ? 0.0
        : completedCount / mission.tasks.length;
    final contentId = task.contentId;
    final completionPending = state.completingTaskId == task.taskId;
    final completionFailed =
        state.failureKind == CurrentMissionFailureKind.completion;
    final refreshPending = state.isLoading && state.isStale;
    final refreshFailed = state.isStale && state.failureMessage != null;

    final actionState = completionPending || refreshPending
        ? DpNextActionState.pending
        : completionFailed || refreshFailed
        ? DpNextActionState.retry
        : DpNextActionState.ready;
    final retriesCompletion = completionFailed && contentId == null;

    return Padding(
      padding: const EdgeInsets.all(DpSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DpMissionHeader(
            eyebrow: '${mission.weekNum}주차 · 미션 ${task.orderNum}',
            title: task.title,
            why: '서버가 정한 이번 주의 첫 미완료 과제예요.',
            completionCriterion: contentId == null
                ? '완료 기록이 서버에 확인되면 다음 미션이 열려요.'
                : '연결된 콘텐츠의 완료 기준을 충족하면 다음 미션이 열려요.',
            progressValue: progress,
            progressLabel: '이번 주 $completedCount/${mission.tasks.length} 미션 완료',
            status: state.isStale
                ? DpMissionHeaderStatus.stale
                : DpMissionHeaderStatus.active,
          ),
          if (state.failureMessage != null) ...[
            const SizedBox(height: DpSpacing.sm),
            Semantics(
              liveRegion: true,
              child: Text(
                completionFailed
                    ? '완료를 저장하지 못했어요. 현재 미션과 진행 상태는 그대로예요.'
                    : '미션을 새로 확인하지 못했어요. 마지막으로 확인한 미션은 유지됩니다.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.dpColors.danger,
                ),
              ),
            ),
          ],
          const SizedBox(height: DpSpacing.md),
          DpNextActionBand(
            actionId: retriesCompletion
                ? 'retry_contentless_completion'
                : refreshFailed
                ? 'refresh_current_mission'
                : contentId == null
                ? 'complete_contentless_mission'
                : 'open_mission_content',
            label: contentId == null ? '미션 완료' : '미션 열기',
            expectedOutcome: retriesCompletion
                ? '완료 기록을 다시 저장하고 다음 미션을 확인합니다.'
                : refreshFailed
                ? '서버 기록에서 현재 미션을 다시 확인합니다.'
                : contentId == null
                ? '서버 확인 후 다음 미션을 불러옵니다.'
                : '콘텐츠에서 완료 조건을 확인합니다.',
            state: actionState,
            pendingLabel: completionPending ? '완료 확인 중' : '미션 확인 중',
            retryLabel: retriesCompletion ? '완료 다시 시도' : '미션 다시 확인',
            onPressed: (_) {
              if (retriesCompletion || (contentId == null && !refreshFailed)) {
                onCompleteContentless(task.taskId!);
              } else if (refreshFailed) {
                onRetry();
              } else {
                onOpenContent(contentId!);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _CompletedMission extends StatelessWidget {
  const _CompletedMission({required this.mission, required this.onOpenPath});

  final CurrentMission mission;
  final VoidCallback onOpenPath;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(DpSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DpMissionHeader(
          eyebrow: '${mission.weekNum}주차 · 경로 완료',
          title: '12주 경로를 모두 완료했어요',
          why: '서버에서 모든 미션의 완료 기록을 확인했어요.',
          completionCriterion: '모든 미션 완료',
          progressValue: 1,
          progressLabel: '경로 진행',
          status: DpMissionHeaderStatus.completed,
        ),
        const SizedBox(height: DpSpacing.md),
        DpNextActionBand(
          actionId: 'open_completed_path',
          label: '경로 돌아보기',
          expectedOutcome: '완료한 주차와 학습 기록을 확인합니다.',
          state: DpNextActionState.ready,
          onPressed: (_) => onOpenPath(),
        ),
      ],
    ),
  );
}
