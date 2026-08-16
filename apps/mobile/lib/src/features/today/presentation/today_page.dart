import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/today_controller.dart';

class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key});

  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(todayControllerProvider.notifier).load());
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(todayControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('오늘')),
      body: switch (state) {
        TodayState(isInitialLoading: true) => const DpLoading(
          label: '오늘의 미션을 확인하는 중',
        ),
        TodayState(mission: null, :final failureMessage) => DpError(
          title: '오늘의 미션을 불러오지 못했어요',
          message: failureMessage ?? '잠시 후 다시 확인해 주세요.',
          onRetry: () => unawaited(
            ref.read(todayControllerProvider.notifier).load(force: true),
          ),
        ),
        TodayState(:final mission?) => _MissionBody(
          mission: mission,
          state: state,
        ),
      },
    );
  }
}

class _MissionBody extends ConsumerWidget {
  const _MissionBody({required this.mission, required this.state});

  final CurrentMission mission;
  final TodayState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (mission.outcome) {
      CurrentMissionOutcome.available => _AvailableMission(
        mission: mission,
        state: state,
      ),
      CurrentMissionOutcome.pathCompleted => const DpEmpty(
        title: '현재 경로를 모두 완료했어요',
        message: '완료 기록은 그대로 유지됩니다. 다음 경로가 준비되면 여기에서 이어갈 수 있어요.',
      ),
      CurrentMissionOutcome.noActivePath => DpEmpty(
        title: '활성 학습 경로가 없어요',
        message: '웹에서 진단과 경로 생성을 완료하면 모바일 Today에 같은 경로가 나타납니다.',
        actionLabel: '다시 확인',
        onAction: () => unawaited(
          ref.read(todayControllerProvider.notifier).invalidateAndRefetch(),
        ),
      ),
      CurrentMissionOutcome.malformedPath => DpError(
        title: '현재 경로를 안전하게 표시할 수 없어요',
        message: '주차나 과제를 임의로 추정하지 않았어요.',
        onRetry: () => unawaited(
          ref.read(todayControllerProvider.notifier).invalidateAndRefetch(),
        ),
      ),
    };
  }
}

class _AvailableMission extends ConsumerWidget {
  const _AvailableMission({required this.mission, required this.state});

  final CurrentMission mission;
  final TodayState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = mission.nextTask!;
    final completed = mission.tasks.where((task) => task.completed).length;
    final total = mission.tasks.length;
    final progress = total == 0 ? 0.0 : completed / total;
    final syncLabel = state.cachedAt == null
        ? null
        : _syncLabel(state.cachedAt!.toLocal());
    final mutationBlocked =
        next.contentId == null && (state.isOffline || state.isStale);
    final actionState = state.completingTaskId == next.taskId
        ? DpNextActionState.pending
        : mutationBlocked
        ? DpNextActionState.disabled
        : DpNextActionState.ready;

    void activate(String _) {
      if (next.contentId != null) {
        context.push('/mission/${next.taskId}/content/${next.contentId}');
      } else {
        unawaited(
          ref
              .read(todayControllerProvider.notifier)
              .completeContentlessTask(next.taskId!),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.isOffline)
          DpOfflineBanner(
            message: '오프라인 · $syncLabel 동기화한 미션입니다. 완료는 서버 확인 뒤 반영돼요.',
          )
        else if (state.isStale || state.failureMessage != null)
          DpOfflineBanner(
            message: '마지막 미션을 유지하고 있어요. ${state.failureMessage ?? ''}',
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(DpSpacing.lg),
            children: [
              DpMissionHeader(
                variant: DpMissionHeaderVariant.compact,
                status: state.isStale
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
                      : () => context.push(
                          '/mission/${task.taskId}/content/${task.contentId}',
                        ),
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
