import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/api_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/state/auth_state.dart';
import '../../dashboard/application/current_mission_controller.dart';
import '../../support/presentation/supportable_error.dart';
import '../application/path_controller.dart';
import '../data/path_sse_source.dart';
import 'mission_path_plan_view.dart';
import 'path_plan_view.dart';

/// PATH-001. 진입 시 기존 경로를 먼저 조회하고, 없으면 생성한다.
class PathPage extends ConsumerStatefulWidget {
  const PathPage({super.key});

  @override
  ConsumerState<PathPage> createState() => _PathPageState();
}

class _PathPageState extends ConsumerState<PathPage> {
  LearningPath? _missionRefetchedForPlan;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWhenAuthenticated(ref.read(authControllerProvider));
    });
  }

  void _loadWhenAuthenticated(AuthState auth) {
    if (auth is! AuthAuthenticated) return;
    if (ref.read(appConfigProvider).missionSpineEnabled) {
      unawaited(ref.read(currentMissionControllerProvider.notifier).load());
    }
    if (ref.read(pathControllerProvider).phase == PathPhase.idle) {
      unawaited(ref.read(pathControllerProvider.notifier).loadOrStart());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(
      authControllerProvider,
      (_, next) => _loadWhenAuthenticated(next),
    );
    final missionSpineEnabled = ref.watch(
      appConfigProvider.select((config) => config.missionSpineEnabled),
    );
    final s = ref.watch(pathControllerProvider);
    final notifier = ref.read(pathControllerProvider.notifier);
    final missionState = missionSpineEnabled
        ? ref.watch(currentMissionControllerProvider)
        : null;

    if (missionSpineEnabled) {
      _scheduleMissionRefreshForReadyPath(s, missionState!);
    }

    // 완료(PathPlanView)는 자체 콘텐츠를 SliverList로 헤더와 함께 스크롤한다.
    // 그 외 상태(진행·중단·실패)는 화면 중앙에 고정하는 SliverFillRemaining.
    final legacyBodySliver = switch (s.phase) {
      PathPhase.complete when s.result != null => SliverPadding(
        padding: const EdgeInsets.all(DpSpacing.lg),
        sliver: SliverList.list(
          children: PathPlanView.children(context, s.result!),
        ),
      ),
      // F4: killSwitch/failed는 이어하기 불가 → SupportableError로(전용 DpKillSwitch/DpQuota 렌더는 P4c).
      PathPhase.failed || PathPhase.killSwitch => SliverFillRemaining(
        hasScrollBody: false,
        child: SupportableError(
          message: s.error ?? '경로 생성에 실패했어요',
          onRetry: notifier.start,
        ),
      ),
      PathPhase.partial => SliverFillRemaining(
        hasScrollBody: false,
        child: _Progress(
          completed: s.completed,
          current: s.current,
          note: s.error ?? '연결이 끊겼어요',
          onRestart: notifier.start,
        ),
      ),
      _ => SliverFillRemaining(
        hasScrollBody: false,
        child: _Progress(completed: s.completed, current: s.current),
      ),
    };
    final bodySliver = missionSpineEnabled
        ? _missionBodySliver(
            context,
            pathState: s,
            pathNotifier: notifier,
            missionState: missionState!,
          )
        : legacyBodySliver;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: DpPageHeader(
              title: '학습 경로',
              description: missionSpineEnabled
                  ? '현재 미션을 먼저 보고, 필요할 때 12주 계획을 펼쳐보세요'
                  : '진단 결과로 만든 12주 계획입니다',
            ),
          ),
          bodySliver,
        ],
      ),
    );
  }

  Widget _missionBodySliver(
    BuildContext context, {
    required PathState pathState,
    required PathController pathNotifier,
    required CurrentMissionState missionState,
  }) {
    final outcome = missionState.mission?.outcome;
    final pathGenerationOwnsSurface =
        (outcome == null || outcome == CurrentMissionOutcome.noActivePath) &&
        pathState.phase != PathPhase.complete;

    if (pathGenerationOwnsSurface) {
      return switch (pathState.phase) {
        PathPhase.failed || PathPhase.killSwitch => SliverFillRemaining(
          hasScrollBody: false,
          child: SupportableError(
            message: pathState.error ?? '경로 생성에 실패했어요',
            onRetry: pathNotifier.start,
          ),
        ),
        PathPhase.partial => SliverFillRemaining(
          hasScrollBody: false,
          child: _Progress(
            completed: pathState.completed,
            current: pathState.current,
            note: pathState.error ?? '연결이 끊겼어요',
            onRestart: pathNotifier.start,
          ),
        ),
        PathPhase.streaming => SliverFillRemaining(
          hasScrollBody: false,
          child: _Progress(
            completed: pathState.completed,
            current: pathState.current,
          ),
        ),
        _ => SliverToBoxAdapter(
          child: MissionPathPlanView(
            missionState: missionState,
            plan: null,
            onRetryMission: () => unawaited(
              ref
                  .read(currentMissionControllerProvider.notifier)
                  .invalidateAndRefetch(),
            ),
            onOpenContent: (contentId) => context.go('/content/$contentId'),
            onCompleteContentless: (taskId) => unawaited(
              ref
                  .read(currentMissionControllerProvider.notifier)
                  .completeContentlessTask(taskId),
            ),
          ),
        ),
      };
    }

    return SliverToBoxAdapter(
      child: MissionPathPlanView(
        missionState: missionState,
        plan: pathState.phase == PathPhase.complete ? pathState.result : null,
        isPlanLoading:
            pathState.phase == PathPhase.idle ||
            pathState.phase == PathPhase.streaming,
        planFailureMessage: switch (pathState.phase) {
          PathPhase.partial => pathState.error ?? '경로 상세 생성이 중단됐어요.',
          PathPhase.failed ||
          PathPhase.killSwitch => pathState.error ?? '경로 상세를 불러오지 못했어요.',
          _ => null,
        },
        onRetryPlan: pathNotifier.loadOrStart,
        onRetryMission: () => unawaited(
          ref
              .read(currentMissionControllerProvider.notifier)
              .invalidateAndRefetch(),
        ),
        onOpenContent: (contentId) => context.go('/content/$contentId'),
        onCompleteContentless: (taskId) => unawaited(
          ref
              .read(currentMissionControllerProvider.notifier)
              .completeContentlessTask(taskId),
        ),
      ),
    );
  }

  void _scheduleMissionRefreshForReadyPath(
    PathState pathState,
    CurrentMissionState missionState,
  ) {
    final plan = pathState.phase == PathPhase.complete
        ? pathState.result
        : null;
    if (plan == null) {
      _missionRefetchedForPlan = null;
      return;
    }
    if (missionState.mission?.outcome != CurrentMissionOutcome.noActivePath ||
        identical(_missionRefetchedForPlan, plan)) {
      return;
    }

    // A completed plan may already exist on first paint, or arrive through
    // idle/streaming -> complete. Record the exact projection before scheduling
    // so a failed NO_ACTIVE_PATH refresh cannot create a rebuild loop.
    _missionRefetchedForPlan = plan;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentPathState = ref.read(pathControllerProvider);
      if (currentPathState.phase != PathPhase.complete ||
          !identical(currentPathState.result, plan) ||
          ref.read(currentMissionControllerProvider).mission?.outcome !=
              CurrentMissionOutcome.noActivePath) {
        return;
      }
      unawaited(
        ref
            .read(currentMissionControllerProvider.notifier)
            .invalidateAndRefetch(),
      );
    });
  }
}

/// SSE 진행/부분 공통: 단계 표시 + (중단 시) 처음부터 다시 생성.
class _Progress extends StatelessWidget {
  const _Progress({
    required this.completed,
    this.current,
    this.note,
    this.onRestart,
  });

  final List<String> completed;
  final String? current;
  final String? note;
  final VoidCallback? onRestart;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    // ENG-REVIEW(§9.2 PARTIAL): 완료 단계만 그리지 않고 kPathStageLabels 전체를 항상
    // 표시한다 — 완료 단계는 채우고, 남은(미완) 단계는 스켈레톤으로 보여줘 "무엇이 남았는지"를
    // 드러낸다. currentIndex=완료 수가 곧 미완 단계의 시작 경계.
    final stages = List<String>.from(kPathStageLabels);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DpSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DpSseStageView(stages: stages, currentIndex: completed.length),
            if (note != null) ...[
              const SizedBox(height: DpSpacing.lg),
              Text(
                note!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: c.textSecondary),
              ),
            ],
            if (onRestart != null) ...[
              const SizedBox(height: DpSpacing.md),
              FilledButton(onPressed: onRestart, child: const Text('다시 생성')),
            ],
          ],
        ),
      ),
    );
  }
}
