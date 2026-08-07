import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../application/dashboard_controller.dart';
import '../state/dashboard_state.dart';
import 'widgets/dashboard_body.dart';
import '../../support/presentation/supportable_error.dart';

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
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(dashboardControllerProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(dashboardControllerProvider);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: DpPageHeader(
              title: '대시보드',
              description: '이번 주 학습 현황과 다음 과제를 한눈에 봅니다',
            ),
          ),
          // 헤더가 본문과 함께 스크롤되는 문서형 전환(Task 10)으로 최상위
          // 스크롤 컨테이너가 CustomScrollView가 되어 AnimatedSwitcher(box
          // 위젯)를 slivers 목록에 직접 실을 수 없다 — 로딩↔완료 전환
          // 크로스페이드는 이번 전환에서 제거한다.
          switch (s) {
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
                onRetry: () =>
                    ref.read(dashboardControllerProvider.notifier).load(),
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
}
