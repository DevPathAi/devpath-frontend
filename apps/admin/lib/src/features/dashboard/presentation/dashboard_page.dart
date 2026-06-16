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
    WidgetsBinding.instance
        .addPostFrameCallback((_) => ref.read(adminDashProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(adminDashProvider);
    const labels = {'dau': 'DAU', 'newUsers': '신규 가입', 'openReports': '미처리 신고', 'aiCalls': 'AI 호출'};
    return Scaffold(
      appBar: AppBar(title: const Text('운영 대시보드')),
      body: switch (s) {
        AdminDashLoading() => const DpLoading(),
        AdminDashFailed(:final message) =>
          DpError(message: message, onRetry: () => ref.read(adminDashProvider.notifier).load()),
        AdminDashLoaded(:final stats) => GridView.count(
            padding: const EdgeInsets.all(DpSpacing.lg),
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
                      Text('${e.value}', style: Theme.of(context).textTheme.displaySmall),
                      Text(labels[e.key] ?? e.key,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: context.dpColors.textSecondary)),
                    ],
                  ),
                ),
            ],
          ),
      },
    );
  }
}
