import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

/// Web-safe production projection for the native Today mission surface.
///
/// Native routing, persistence, and controller ownership stay outside this
/// widget so the exact visible surface can also be rendered from a release-mode
/// Flutter Web evidence target without importing mobile storage plugins.
class MobileTodayProjection extends StatelessWidget {
  const MobileTodayProjection({
    super.key,
    required this.mission,
    required this.onOpenContent,
    required this.onCompleteContentlessTask,
    required this.onRefresh,
    this.isOffline = false,
    this.isStale = false,
    this.cachedAt,
    this.failureMessage,
    this.completingTaskId,
  });

  final CurrentMission mission;
  final ValueChanged<WeeklyTask> onOpenContent;
  final ValueChanged<int> onCompleteContentlessTask;
  final VoidCallback onRefresh;
  final bool isOffline;
  final bool isStale;
  final DateTime? cachedAt;
  final String? failureMessage;
  final int? completingTaskId;

  @override
  Widget build(BuildContext context) {
    return switch (mission.outcome) {
      CurrentMissionOutcome.available => _AvailableMission(
        mission: mission,
        onOpenContent: onOpenContent,
        onCompleteContentlessTask: onCompleteContentlessTask,
        isOffline: isOffline,
        isStale: isStale,
        cachedAt: cachedAt,
        failureMessage: failureMessage,
        completingTaskId: completingTaskId,
      ),
      CurrentMissionOutcome.pathCompleted => const DpEmpty(
        title: '현재 경로를 모두 완료했어요',
        message: '완료 기록은 그대로 유지됩니다. 다음 경로가 준비되면 여기에서 이어갈 수 있어요.',
      ),
      CurrentMissionOutcome.noActivePath => DpEmpty(
        title: '활성 학습 경로가 없어요',
        message: '웹에서 진단과 경로 생성을 완료하면 모바일 Today에 같은 경로가 나타납니다.',
        actionLabel: '다시 확인',
        onAction: onRefresh,
      ),
      CurrentMissionOutcome.malformedPath => DpError(
        title: '현재 경로를 안전하게 표시할 수 없어요',
        message: '주차나 과제를 임의로 추정하지 않았어요.',
        onRetry: onRefresh,
      ),
    };
  }
}

class _AvailableMission extends StatelessWidget {
  const _AvailableMission({
    required this.mission,
    required this.onOpenContent,
    required this.onCompleteContentlessTask,
    required this.isOffline,
    required this.isStale,
    required this.cachedAt,
    required this.failureMessage,
    required this.completingTaskId,
  });

  final CurrentMission mission;
  final ValueChanged<WeeklyTask> onOpenContent;
  final ValueChanged<int> onCompleteContentlessTask;
  final bool isOffline;
  final bool isStale;
  final DateTime? cachedAt;
  final String? failureMessage;
  final int? completingTaskId;

  @override
  Widget build(BuildContext context) {
    final next = mission.nextTask!;
    final completed = mission.tasks.where((task) => task.completed).length;
    final total = mission.tasks.length;
    final progress = total == 0 ? 0.0 : completed / total;
    final syncLabel = cachedAt == null ? null : _syncLabel(cachedAt!.toLocal());
    final mutationBlocked = next.contentId == null && (isOffline || isStale);
    final actionState = completingTaskId == next.taskId
        ? DpNextActionState.pending
        : mutationBlocked
        ? DpNextActionState.disabled
        : DpNextActionState.ready;

    void activate(String _) {
      if (next.contentId != null) {
        onOpenContent(next);
      } else {
        onCompleteContentlessTask(next.taskId!);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isOffline)
          DpOfflineBanner(
            message: '오프라인 · $syncLabel 동기화한 미션입니다. 완료는 서버 확인 뒤 반영돼요.',
          )
        else if (isStale || failureMessage != null)
          DpOfflineBanner(message: '마지막 미션을 유지하고 있어요. ${failureMessage ?? ''}'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(DpSpacing.lg),
            children: [
              DpMissionHeader(
                variant: DpMissionHeaderVariant.compact,
                status: isStale
                    ? DpMissionHeaderStatus.stale
                    : DpMissionHeaderStatus.active,
                eyebrow:
                    '${mission.weekNum}주차 · ${DpLearningLabels.taskType(next.taskType)}',
                title: next.title,
                why: '서버가 현재 경로에서 확인한 첫 미완료 미션이에요.',
                completionCriterion: next.contentId == null
                    ? '미션 완료를 서버에 확인'
                    : '콘텐츠 읽기 기준을 충족하고 진행률 동기화',
                progressValue: progress,
                progressLabel: '$completed/$total 완료',
              ),
              const SizedBox(height: DpSpacing.lg),
              for (final task in mission.tasks) ...[
                DpListRow(
                  title: task.title,
                  badges: [
                    DpTag(label: DpLearningLabels.taskType(task.taskType)),
                    if (task.required) const DpTag(label: '필수'),
                  ],
                  trailing: Icon(
                    task.completed ? DpIcons.stepDone : DpIcons.stepPending,
                  ),
                  onTap: task.contentId == null
                      ? null
                      : () => onOpenContent(task),
                ),
                const SizedBox(height: DpSpacing.sm),
              ],
              const SizedBox(height: DpSpacing.sm),
              DpNextActionBand(
                actionId: 'mobile-today-next',
                label: next.contentId == null ? '미션 완료' : '학습 계속',
                pendingLabel: '서버에 확인하는 중',
                expectedOutcome: next.contentId == null
                    ? '확인되면 다음 미션을 다시 불러옵니다.'
                    : '같은 경로의 현재 콘텐츠를 엽니다.',
                state: actionState,
                disabledReason: mutationBlocked
                    ? '최신 미션을 확인한 뒤 완료할 수 있습니다.'
                    : null,
                onPressed: actionState == DpNextActionState.ready
                    ? activate
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _syncLabel(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.month)}.${two(value.day)} ${two(value.hour)}:${two(value.minute)}';
  }
}
