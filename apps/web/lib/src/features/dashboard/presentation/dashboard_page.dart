import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../providers/api_providers.dart';
import '../../ads/presentation/ad_slot_widget.dart';
import '../../support/presentation/supportable_error.dart';
import '../application/current_mission_controller.dart';
import '../application/dashboard_controller.dart';
import '../state/dashboard_state.dart';
import '../../mission/state/mission_workspace_key.dart';
import 'widgets/dashboard_body.dart';
import 'widgets/today_panels.dart';
import 'widgets/today_mission_section.dart';

/// 로딩 스켈레톤이 실제 카드 구조를 반영하도록 DashboardBody에 주입하는 자리표시 요약.
const _skeletonSummary = DashboardSummary(
  streakDays: 0,
  progressPercent: 0,
  nextTaskTitle: '불러오는 중 자리표시자 텍스트',
  badges: ['배지', '배지'],
  completedContentCount: 0,
);

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  @override
  void initState() {
    super.initState();
    ref.listenManual<String?>(
      currentMissionOwnerKeyProvider,
      (_, ownerKey) => ref
          .read(dashboardControllerProvider.notifier)
          .synchronizeOwner(ownerKey),
      fireImmediately: false,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(appConfigProvider).missionSpineEnabled) {
        unawaited(ref.read(currentMissionControllerProvider.notifier).load());
      }
      ref
          .read(dashboardControllerProvider.notifier)
          .synchronizeOwner(ref.read(currentMissionOwnerKeyProvider));
      // Today is authoritative and starts first. Metrics remain independent:
      // neither Future is awaited before the other request begins.
      unawaited(ref.read(dashboardControllerProvider.notifier).load());
    });
  }

  @override
  Widget build(BuildContext context) {
    final ownerKey = ref.watch(currentMissionOwnerKeyProvider);
    final dashboardNotifier = ref.read(dashboardControllerProvider.notifier);
    final rawDashboardState = ref.watch(dashboardControllerProvider);
    final safeDashboardState = dashboardNotifier.isBoundTo(ownerKey)
        ? rawDashboardState
        : const DashLoading();

    if (!ref.watch(appConfigProvider).missionSpineEnabled) {
      return _LegacyDashboard(
        state: safeDashboardState,
        onRetry: () => unawaited(dashboardNotifier.load()),
      );
    }

    final missionState = ref.watch(currentMissionControllerProvider);
    final s = safeDashboardState;
    final missionOutcome = missionState.mission?.outcome;
    final showSupporting =
        missionOutcome == CurrentMissionOutcome.available ||
        missionOutcome == CurrentMissionOutcome.pathCompleted;

    final missionSection = TodayMissionSection(
      state: missionState,
      onRetry: () => unawaited(
        ref
            .read(currentMissionControllerProvider.notifier)
            .invalidateAndRefetch(),
      ),
      onOpenPath: () => context.go('/path'),
      onOpenContent: (workspaceKey) =>
          context.push(workspaceKey.contentLocation),
      onCompleteContentless: (taskId) => unawaited(
        ref
            .read(currentMissionControllerProvider.notifier)
            .completeContentlessTask(taskId),
      ),
    );
    final (supportingKey, supportingSection) = switch (s) {
      DashLoading() => (
        const ValueKey('today-metrics-loading'),
        const Padding(
              padding: EdgeInsets.all(DpSpacing.lg),
              child: DpLoading(label: '보조 학습 지표를 불러오는 중'),
            )
            as Widget,
      ),
      DashFailed(:final message) => (
        const ValueKey('today-metrics-error'),
        Padding(
          padding: const EdgeInsets.all(DpSpacing.lg),
          child: _SupportingMetricsError(
            message: message,
            onRetry: () => unawaited(
              ref.read(dashboardControllerProvider.notifier).load(),
            ),
          ),
        ),
      ),
      DashLoaded(:final summary) => (
        const ValueKey('today-metrics-section'),
        DashboardBody.supportingContent(context, summary),
      ),
    };
    final mission = missionState.mission;
    final summary = switch (s) {
      DashLoaded(:final summary) => summary,
      _ => null,
    };

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: DpPageHeader(title: '오늘')),
          // 시안 `.next` — 다음 할 일 밴드. 상태 분기(로딩·실패·경로 없음)는
          // 그대로 이 위젯 안에 있다.
          SliverToBoxAdapter(
            key: const ValueKey('today-mission-section'),
            child: missionSection,
          ),
          // 시안 `.cols` — 폭 분기는 `DpCols` 가 한다(옛 `wide` 계산 제거).
          // 좌우 패딩은 셸이 준다.
          if (showSupporting && mission != null)
            SliverToBoxAdapter(
              key: const ValueKey('today-cols'),
              child: Padding(
                padding: const EdgeInsets.only(bottom: DpSpacing.xl),
                child: DpCols(
                  main: TodayTasksPanel(
                    mission: mission,
                    onOpenTask: (task) {
                      final contentId = task.contentId;
                      final taskId = task.taskId;
                      if (contentId == null || taskId == null) {
                        context.go('/path');
                        return;
                      }
                      context.push(
                        MissionWorkspaceKey(
                          taskId: taskId,
                          contentId: contentId,
                        ).contentLocation,
                      );
                    },
                  ),
                  side: DpSide(
                    children: [
                      if (summary != null)
                        TodayProgressPanel(summary: summary, mission: mission),
                      TodayWhyPanel(
                        why: '서버가 정한 이번 주의 첫 미완료 과제예요.',
                        onOpenPath: () => context.go('/path'),
                      ),
                      TodayHelpPanel(
                        onOpenMentor: () => context.go('/mentor'),
                        onOpenQna: () => context.go('/community?board=QNA'),
                      ),
                      // 지표 로딩·실패도 사이드에서 말한다(기존 분기를 잃지 않는다).
                      KeyedSubtree(
                        key: supportingKey,
                        child: supportingSection,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (showSupporting)
            SliverToBoxAdapter(key: supportingKey, child: supportingSection),
          if (showSupporting)
            const SliverToBoxAdapter(
              key: ValueKey('today-ad-section'),
              child: Padding(
                padding: EdgeInsets.only(bottom: DpSpacing.xl),
                child: AdSlotWidget(slot: 'DASHBOARD_TOP'),
              ),
            ),
        ],
      ),
    );
  }
}

class _LegacyDashboard extends StatelessWidget {
  const _LegacyDashboard({required this.state, required this.onRetry});

  final DashboardState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: DpPageHeader(
            title: '대시보드',
            description: '이번 주 학습 현황과 다음 과제를 한눈에 봅니다',
          ),
        ),
        // flag OFF는 기존 화면·요청 순서·상태 처리를 그대로 유지한다.
        switch (state) {
          DashLoading() => SliverToBoxAdapter(
            child: Skeletonizer(
              key: const ValueKey('loading'),
              child: DashboardBody.content(context, _skeletonSummary),
            ),
          ),
          DashFailed(:final message) => SliverFillRemaining(
            hasScrollBody: false,
            child: SupportableError(
              key: const ValueKey('error'),
              message: message,
              onRetry: onRetry,
            ),
          ),
          DashLoaded(:final summary) => SliverToBoxAdapter(
            child: DashboardBody.content(
              context,
              summary,
              key: const ValueKey('loaded'),
            ),
          ),
        },
      ],
    ),
  );
}

class _SupportingMetricsError extends StatelessWidget {
  const _SupportingMetricsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => DpInlineNotice(
    message: '보조 학습 지표를 불러오지 못했어요. $message',
    tone: DpInlineNoticeTone.warning,
    actionLabel: '지표 다시 보기',
    onAction: onRetry,
  );
}
