import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/dashboard_controller.dart';
import '../state/dashboard_state.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});
  @override
  ConsumerState<AdminDashboardPage> createState() => _S();
}

class _S extends ConsumerState<AdminDashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(adminDashProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(adminDashProvider);
    const labels = {
      'dau': 'DAU',
      'newUsers': '신규 가입',
      'openReports': '미처리 신고',
      'aiCalls': 'AI 호출',
    };
    // 문서형 화면 — 헤더를 첫 sliver로 실어 본문과 함께 스크롤시킨다(DESIGN.md §9).
    // 본문은 자체 스크롤을 갖지 않는다(중첩 스크롤이면 헤더가 밀려나지 않는다).
    // users·ads·support는 DpDataTable이 자체 뷰포트를 가져 고정형으로 남는다.
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: DpPageHeader(title: '운영 대시보드', description: '서비스 지표를 요약합니다'),
          ),
          switch (s) {
            AdminDashLoading() => const SliverFillRemaining(
              hasScrollBody: false,
              child: DpLoading(),
            ),
            AdminDashFailed(:final message) => SliverFillRemaining(
              hasScrollBody: false,
              child: DpError(
                message: message,
                onRetry: () => ref.read(adminDashProvider.notifier).load(),
              ),
            ),
            AdminDashLoaded(:final stats) => SliverPadding(
              padding: const EdgeInsets.all(DpSpacing.lg),
              sliver: SliverGrid.count(
                crossAxisCount: 4,
                childAspectRatio: 1.6,
                mainAxisSpacing: DpSpacing.md,
                crossAxisSpacing: DpSpacing.md,
                children: [
                  for (final e in stats.entries)
                    Container(
                      padding: const EdgeInsets.all(DpSpacing.lg),
                      decoration: BoxDecoration(
                        color: context.dpColors.surface,
                        border: Border.all(color: context.dpColors.border),
                        borderRadius: BorderRadius.circular(DpRadius.card),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${e.value}',
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                          Text(
                            labels[e.key] ?? e.key,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: context.dpColors.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          },
        ],
      ),
    );
  }
}
