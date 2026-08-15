import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

import '../../dashboard/application/current_mission_controller.dart';
import '../../mission/state/mission_workspace_key.dart';

/// Authoritative current-mission projection을 전경에 두고 전체 12주 문서를
/// 보조 detail로 낮춘 Path 화면입니다. 현재 주차나 task는 [LearningPath]의
/// 배열 순서로 추론하지 않습니다.
class MissionPathPlanView extends StatelessWidget {
  const MissionPathPlanView({
    super.key,
    required this.missionState,
    required this.plan,
    this.isPlanLoading = false,
    this.planFailureMessage,
    required this.onRetryMission,
    this.onRetryPlan,
    required this.onOpenContent,
    required this.onCompleteContentless,
  });

  final CurrentMissionState missionState;
  final LearningPath? plan;
  final bool isPlanLoading;
  final String? planFailureMessage;
  final VoidCallback onRetryMission;
  final VoidCallback? onRetryPlan;
  final ValueChanged<MissionWorkspaceKey> onOpenContent;
  final ValueChanged<int> onCompleteContentless;

  @override
  Widget build(BuildContext context) {
    final mission = missionState.mission;
    if (mission == null) {
      return missionState.isLoading
          ? const Padding(
              padding: EdgeInsets.all(DpSpacing.xl),
              child: DpLoading(label: '현재 주차를 불러오는 중'),
            )
          : Padding(
              padding: const EdgeInsets.all(DpSpacing.lg),
              child: DpError(
                title: '현재 주차를 불러오지 못했어요',
                message:
                    missionState.failureMessage ??
                    '전체 경로를 임의로 현재 주차로 사용하지 않았어요. 다시 확인해 주세요.',
                onRetry: onRetryMission,
              ),
            );
    }

    return switch (mission.outcome) {
      CurrentMissionOutcome.available => _AvailablePath(
        missionState: missionState,
        mission: mission,
        plan: plan,
        isPlanLoading: isPlanLoading,
        planFailureMessage: planFailureMessage,
        onRetryPlan: onRetryPlan,
        onRetryMission: onRetryMission,
        onOpenContent: onOpenContent,
        onCompleteContentless: onCompleteContentless,
      ),
      CurrentMissionOutcome.pathCompleted => _CompletedPath(
        missionState: missionState,
        mission: mission,
        plan: _matchingPlan(mission, plan) ? plan : null,
        onRetryMission: onRetryMission,
      ),
      CurrentMissionOutcome.noActivePath => Padding(
        padding: const EdgeInsets.all(DpSpacing.lg),
        child: DpEmpty(
          title: missionState.isStale && missionState.failureMessage != null
              ? '경로 상태를 새로 확인하지 못했어요'
              : '아직 학습 경로가 없어요',
          message: missionState.isStale && missionState.failureMessage != null
              ? '마지막으로 확인한 결과에는 활성 경로가 없어요. 서버 상태를 다시 확인해 주세요.'
              : '경로 생성이 끝나면 서버가 확인한 첫 미션을 여기에 표시합니다.',
          actionLabel: '현재 경로 다시 확인',
          onAction: onRetryMission,
        ),
      ),
      CurrentMissionOutcome.malformedPath => Padding(
        padding: const EdgeInsets.all(DpSpacing.lg),
        child: DpError(
          title: '현재 주차를 확인할 수 없어요',
          message: '주차나 과제 순서를 화면에서 추정하지 않았어요. 서버 기록을 다시 확인해 주세요.',
          onRetry: onRetryMission,
        ),
      ),
    };
  }
}

class _AvailablePath extends StatelessWidget {
  const _AvailablePath({
    required this.missionState,
    required this.mission,
    required this.plan,
    required this.isPlanLoading,
    required this.planFailureMessage,
    required this.onRetryPlan,
    required this.onRetryMission,
    required this.onOpenContent,
    required this.onCompleteContentless,
  });

  final CurrentMissionState missionState;
  final CurrentMission mission;
  final LearningPath? plan;
  final bool isPlanLoading;
  final String? planFailureMessage;
  final VoidCallback? onRetryPlan;
  final VoidCallback onRetryMission;
  final ValueChanged<MissionWorkspaceKey> onOpenContent;
  final ValueChanged<int> onCompleteContentless;

  @override
  Widget build(BuildContext context) {
    final task = mission.nextTask!;
    final matchingPlan = _matchingPlan(mission, plan) ? plan : null;
    final currentMilestone = matchingPlan?.milestones
        .where((milestone) => milestone.weekNum == mission.weekNum)
        .firstOrNull;
    final detailMatches = currentMilestone != null;
    final completedCount = mission.tasks.where((task) => task.completed).length;
    final progress = completedCount / mission.tasks.length;
    final contentId = task.contentId;
    final completionPending = missionState.completingTaskId == task.taskId;
    final completionFailed =
        missionState.failureKind == CurrentMissionFailureKind.completion;
    final refreshPending = missionState.isLoading && missionState.isStale;
    final refreshFailed =
        missionState.isStale && missionState.failureMessage != null;
    final actionState = completionPending || refreshPending
        ? DpNextActionState.pending
        : completionFailed || refreshFailed
        ? DpNextActionState.retry
        : DpNextActionState.ready;
    final retriesCompletion = completionFailed && contentId == null;
    final nextUnlock = _nextUnlock(mission, matchingPlan);

    return Padding(
      padding: const EdgeInsets.all(DpSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DpMissionHeader(
            eyebrow: '${mission.weekNum}주차 · 미션 ${task.orderNum}',
            title: task.title,
            why: currentMilestone?.whyThisOrder ?? '서버가 정한 이번 주의 첫 미완료 과제예요.',
            completionCriterion: contentId == null
                ? '완료 기록이 서버에 확인되면 다음 미션이 열려요.'
                : '연결된 콘텐츠의 완료 기준을 충족하면 다음 미션이 열려요.',
            progressValue: progress,
            progressLabel: '이번 주 $completedCount/${mission.tasks.length} 미션 완료',
            status: missionState.isStale
                ? DpMissionHeaderStatus.stale
                : DpMissionHeaderStatus.active,
          ),
          const SizedBox(height: DpSpacing.md),
          Text(
            '다음 잠금 해제 · $nextUnlock',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.dpColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!detailMatches && plan != null) ...[
            const SizedBox(height: DpSpacing.sm),
            Semantics(
              liveRegion: true,
              child: Text(
                '현재 미션과 경로 상세가 아직 맞지 않아요.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.dpColors.warning,
                ),
              ),
            ),
          ],
          if (missionState.failureMessage != null) ...[
            const SizedBox(height: DpSpacing.sm),
            Semantics(
              liveRegion: true,
              child: Text(
                completionFailed
                    ? '완료를 저장하지 못했어요. 현재 미션은 그대로예요.'
                    : '마지막으로 확인한 미션을 표시하고 있어요.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.dpColors.danger,
                ),
              ),
            ),
          ],
          const SizedBox(height: DpSpacing.lg),
          DpProgressSpine(
            steps: [
              for (final item in mission.tasks)
                DpProgressStep(
                  id: 'task-${item.taskId}',
                  label: item.title,
                  state: item.completed
                      ? DpProgressStepState.completed
                      : item.taskId == task.taskId
                      ? DpProgressStepState.current
                      : DpProgressStepState.upcoming,
                ),
            ],
            currentStepId: 'task-${task.taskId}',
            layout: DpProgressSpineLayout.vertical,
            label: '${mission.weekNum}주차 미션 순서',
          ),
          const SizedBox(height: DpSpacing.lg),
          DpNextActionBand(
            actionId: retriesCompletion
                ? 'retry_path_contentless_completion'
                : refreshFailed
                ? 'refresh_path_current_mission'
                : contentId == null
                ? 'complete_path_contentless_mission'
                : 'open_path_mission_content',
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
                onRetryMission();
              } else {
                onOpenContent(
                  MissionWorkspaceKey(
                    taskId: task.taskId!,
                    contentId: contentId!,
                  ),
                );
              }
            },
          ),
          if (currentMilestone != null) ...[
            const SizedBox(height: DpSpacing.xl),
            _CurrentWeekDetail(milestone: currentMilestone),
          ],
          if (matchingPlan != null) ...[
            const SizedBox(height: DpSpacing.xl),
            _RoadmapDetails(plan: matchingPlan, currentWeek: mission.weekNum!),
          ] else if (isPlanLoading || planFailureMessage != null) ...[
            const SizedBox(height: DpSpacing.xl),
            _PlanEnrichmentStatus(
              isLoading: isPlanLoading,
              failureMessage: planFailureMessage,
              onRetry: onRetryPlan,
            ),
          ],
        ],
      ),
    );
  }
}

class _CompletedPath extends StatelessWidget {
  const _CompletedPath({
    required this.missionState,
    required this.mission,
    required this.plan,
    required this.onRetryMission,
  });

  final CurrentMissionState missionState;
  final CurrentMission mission;
  final LearningPath? plan;
  final VoidCallback onRetryMission;

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
        Text(
          '마지막 주차 ${mission.tasks.length}개 미션 완료',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (missionState.isStale && missionState.failureMessage != null) ...[
          const SizedBox(height: DpSpacing.sm),
          Semantics(
            liveRegion: true,
            child: Text(
              '마지막으로 확인한 완료 결과예요.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: context.dpColors.danger),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onRetryMission,
              child: const Text('완료 상태 다시 확인'),
            ),
          ),
        ],
        const SizedBox(height: DpSpacing.sm),
        for (final task in mission.tasks)
          ListTile(
            dense: true,
            leading: Icon(DpIcons.stepDone, color: context.dpColors.success),
            title: Text(task.title),
            subtitle: Text('완료 기록 확인됨 · ${task.completedAt!.toLocal()}'),
          ),
        if (plan != null) ...[
          const SizedBox(height: DpSpacing.xl),
          _RoadmapDetails(plan: plan!, currentWeek: mission.weekNum!),
        ],
      ],
    ),
  );
}

class _PlanEnrichmentStatus extends StatelessWidget {
  const _PlanEnrichmentStatus({
    required this.isLoading,
    required this.failureMessage,
    required this.onRetry,
  });

  final bool isLoading;
  final String? failureMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        isLoading ? '경로 상세를 확인하는 중이에요' : '경로 상세를 불러오지 못했어요',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: DpSpacing.xs),
      Text(
        isLoading ? '현재 미션은 바로 진행할 수 있어요.' : failureMessage ?? '현재 미션은 유지됩니다.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.dpColors.textSecondary),
      ),
      if (!isLoading && onRetry != null)
        TextButton(onPressed: onRetry, child: const Text('경로 상세 다시 확인')),
    ],
  );
}

class _CurrentWeekDetail extends StatelessWidget {
  const _CurrentWeekDetail({required this.milestone});

  final PathMilestone milestone;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.dpColors.surface,
      border: Border.all(color: context.dpColors.border),
      borderRadius: BorderRadius.circular(context.appTokens.panelRadius),
    ),
    child: Padding(
      padding: const EdgeInsets.all(DpSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('이번 주 완료 근거', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: DpSpacing.sm),
          Text(milestone.goalDescription),
          const SizedBox(height: DpSpacing.xs),
          Text(
            milestone.expectedOutcome,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.dpColors.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}

class _RoadmapDetails extends StatelessWidget {
  const _RoadmapDetails({required this.plan, required this.currentWeek});

  final LearningPath plan;
  final int currentWeek;

  @override
  Widget build(BuildContext context) {
    final completed = plan.milestones
        .where((milestone) => milestone.weekNum < currentWeek)
        .toList(growable: false);
    final future = plan.milestones
        .where((milestone) => milestone.weekNum > currentWeek)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('경로 설계 근거와 진단 요약'),
          children: [
            Align(alignment: Alignment.centerLeft, child: Text(plan.rationale)),
            if (plan.diagnosis case final diagnosis?) ...[
              const SizedBox(height: DpSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('진단 수준 · ${diagnosis.diagnosedLevel}'),
              ),
            ],
          ],
        ),
        if (completed.isNotEmpty) ...[
          const SizedBox(height: DpSpacing.lg),
          Text('완료한 주차', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: DpSpacing.xs),
          for (final milestone in completed)
            _MilestoneDisclosure(
              key: ValueKey('path-week-${milestone.weekNum}'),
              milestone: milestone,
              completed: true,
            ),
        ],
        if (future.isNotEmpty) ...[
          const SizedBox(height: DpSpacing.lg),
          Text('앞으로의 주차', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: DpSpacing.xs),
          for (final milestone in future)
            _MilestoneDisclosure(
              key: ValueKey('path-week-${milestone.weekNum}'),
              milestone: milestone,
              completed: false,
            ),
        ],
      ],
    );
  }
}

class _MilestoneDisclosure extends StatelessWidget {
  const _MilestoneDisclosure({
    super.key,
    required this.milestone,
    required this.completed,
  });

  final PathMilestone milestone;
  final bool completed;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    key: ValueKey('path-week-tile-${milestone.weekNum}'),
    tilePadding: EdgeInsets.zero,
    leading: Icon(
      completed ? DpIcons.stepDone : DpIcons.stepPending,
      color: completed
          ? context.dpColors.success
          : context.dpColors.textSecondary,
    ),
    title: Text('${milestone.weekNum}주차 ${milestone.title}'),
    subtitle: Text(completed ? '완료 근거와 복습 정보' : '접힌 미래 계획'),
    childrenPadding: const EdgeInsets.only(
      left: DpSpacing.xl,
      bottom: DpSpacing.md,
    ),
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: Text(milestone.goalDescription),
      ),
      const SizedBox(height: DpSpacing.xs),
      Align(
        alignment: Alignment.centerLeft,
        child: Text(
          milestone.expectedOutcome,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: context.dpColors.textSecondary,
          ),
        ),
      ),
    ],
  );
}

bool _matchingPlan(CurrentMission mission, LearningPath? plan) {
  if (plan == null || mission.pathId != plan.pathId) return false;
  return plan.milestones.any(
    (milestone) => milestone.weekNum == mission.weekNum,
  );
}

String _nextUnlock(CurrentMission mission, LearningPath? plan) {
  final task = mission.nextTask!;
  final followingTask = mission.tasks
      .where(
        (candidate) =>
            candidate.orderNum > task.orderNum && !candidate.completed,
      )
      .firstOrNull;
  if (followingTask != null) return followingTask.title;

  final nextMilestone = plan?.milestones
      .where((milestone) => milestone.weekNum > mission.weekNum!)
      .firstOrNull;
  return nextMilestone == null
      ? '이번 주 완료 후 서버에서 다음 미션 확인'
      : '${nextMilestone.weekNum}주차 ${nextMilestone.title}';
}
