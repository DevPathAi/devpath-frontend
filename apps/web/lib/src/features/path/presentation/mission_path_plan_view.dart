import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

import '../../dashboard/application/current_mission_controller.dart';
import '../../mission/state/mission_workspace_key.dart';
import 'path_panels.dart';

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

    final compact = context.windowClass == DpWindowClass.compact;
    final band = DpNextActionBand(
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
            MissionWorkspaceKey(taskId: task.taskId!, contentId: contentId!),
          );
        }
      },
    );
    // 위계: 다음 행동(헤더 안 band) → 완료 조건 → 진행(헤더 바 + spine) → 보조 맥락.
    final primary = Column(
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
          variant: compact
              ? DpMissionHeaderVariant.compact
              : DpMissionHeaderVariant.standard,
          action: band,
        ),
        if (!detailMatches && plan != null) ...[
          const SizedBox(height: DpSpacing.sm),
          const DpInlineNotice(
            message: '현재 미션과 경로 상세가 아직 맞지 않아요.',
            tone: DpInlineNoticeTone.warning,
          ),
        ],
        if (missionState.failureMessage != null) ...[
          const SizedBox(height: DpSpacing.sm),
          DpInlineNotice(
            message: completionFailed
                ? '완료를 저장하지 못했어요. 현재 미션은 그대로예요.'
                : '마지막으로 확인한 미션을 표시하고 있어요.',
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
          layout: compact
              ? DpProgressSpineLayout.text
              : DpProgressSpineLayout.vertical,
          label: '${mission.weekNum}주차 미션 순서',
        ),
        if (matchingPlan != null) ...[
          const SizedBox(height: DpSpacing.xl),
          // 주차 상세 라우트가 없으므로 onOpenWeek 를 넘기지 않는다 — 표의 제목이
          // 링크처럼 보이지 않게 한다(빈 콜백 금지).
          PathWeeksPanel(
            plan: matchingPlan,
            currentWeek: mission.weekNum,
            onOpenWeek: null,
          ),
        ] else if (isPlanLoading || planFailureMessage != null) ...[
          const SizedBox(height: DpSpacing.xl),
          _PlanEnrichmentStatus(
            isLoading: isPlanLoading,
            failureMessage: planFailureMessage,
            onRetry: onRetryPlan,
          ),
        ],
      ],
    );
    final supporting = DpSide(
      children: [
        // 상세가 없어도 그린다 — 「다음 잠금 해제」는 서버 미션만으로 계산된다.
        PathWeekOutcomePanel(
          milestone: currentMilestone,
          nextUnlock: nextUnlock,
        ),
        if (matchingPlan != null) PathDiagnosisPanel(plan: matchingPlan),
        if (matchingPlan != null) PathRationalePanel(plan: matchingPlan),
      ],
    );

    // 폭 분기는 `DpCols` 가 한다 — 화면에서 `wide` 를 다시 계산하지 않는다.
    // 좌우 패딩도 주지 않는다(셸이 준다). 아래 여백만 화면이 준다 — `/dashboard`
    // 의 `.cols` 와 같은 값이다.
    return Padding(
      padding: const EdgeInsets.only(bottom: DpSpacing.xl),
      child: DpCols(main: primary, side: supporting),
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
    // 좌우는 셸이 준다 — 화면은 아래 여백만 준다.
    padding: const EdgeInsets.only(bottom: DpSpacing.xl),
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
          DpInlineNotice(
            message: '마지막으로 확인한 완료 결과예요.',
            actionLabel: '완료 상태 다시 확인',
            onAction: onRetryMission,
          ),
        ],
        const SizedBox(height: DpSpacing.md),
        DpPanel(
          title: const DpPanelTitle('완료한 미션'),
          child: DpListLines(
            children: [
              for (final task in mission.tasks)
                Row(
                  children: [
                    Icon(DpIcons.stepDone, color: context.dpColors.success),
                    const SizedBox(width: DpSpacing.sm),
                    Expanded(child: Text(task.title)),
                    Text(
                      '완료 기록 확인됨 · ${task.completedAt!.toLocal()}',
                      style: TextStyle(color: context.dpColors.textSecondary),
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (plan != null) ...[
          const SizedBox(height: DpSpacing.xl),
          PathWeeksPanel(
            plan: plan!,
            currentWeek: mission.weekNum,
            onOpenWeek: null,
          ),
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
