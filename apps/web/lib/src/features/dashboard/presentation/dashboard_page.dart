import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/dashboard_controller.dart';
import '../state/dashboard_state.dart';

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
      appBar: AppBar(title: const Text('대시보드')),
      body: switch (s) {
        DashLoading() => const DpLoading(),
        DashFailed(:final message) => DpError(
          message: message,
          onRetry: () => ref.read(dashboardControllerProvider.notifier).load(),
        ),
        DashLoaded(:final summary) => _Body(summary: summary),
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;

    Widget card(Widget child) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: DpSpacing.md),
      padding: const EdgeInsets.all(DpSpacing.lg),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(DpRadius.card),
      ),
      child: child,
    );

    return ListView(
      padding: const EdgeInsets.all(DpSpacing.lg),
      children: [
        // 1) 스트릭
        card(
          Row(
            children: [
              Text(
                '${summary.streakDays}',
                style: text.displaySmall?.copyWith(color: c.primaryText),
              ),
              const SizedBox(width: DpSpacing.sm),
              Text('일 연속 학습 중 🔥', style: text.titleMedium),
            ],
          ),
        ),
        // 2) 진행률
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('전체 진행률', style: text.titleMedium),
              const SizedBox(height: DpSpacing.sm),
              LinearProgressIndicator(value: summary.progressPercent / 100),
              const SizedBox(height: DpSpacing.xs),
              Text('${summary.progressPercent}%', style: text.bodySmall),
            ],
          ),
        ),
        // 3) 다음 과제 단일 CTA
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('다음 과제', style: text.titleMedium),
              const SizedBox(height: DpSpacing.xs),
              Text(
                summary.nextTaskTitle ?? '경로를 생성해 보세요',
                style: text.bodyMedium?.copyWith(color: c.textSecondary),
              ),
              const SizedBox(height: DpSpacing.md),
              FilledButton(
                onPressed: () => context.go('/path'),
                child: const Text('이어서 학습'),
              ),
            ],
          ),
        ),
        // 4) 배지
        if (summary.badges.isNotEmpty)
          card(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('배지', style: text.titleMedium),
                const SizedBox(height: DpSpacing.sm),
                Wrap(
                  spacing: DpSpacing.sm,
                  children: [
                    for (final b in summary.badges) Chip(label: Text('🏅 $b')),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
