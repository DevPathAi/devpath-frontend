import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/theme_provider.dart';
import '../application/dashboard_controller.dart';
import '../state/dashboard_state.dart';

/// 홈 대시보드 — 스트릭·진척률·다음 과제. 오프라인 시 캐시 + 배너.
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
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('홈'),
        actions: [
          IconButton(
            tooltip: '테마 전환',
            icon: Icon(isDark ? DpIcons.lightMode : DpIcons.darkMode),
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
        ],
      ),
      body: switch (s) {
        DashLoading() => const DpLoading(),
        DashFailed(:final message) => DpError(
          message: message,
          onRetry: () => ref.read(dashboardControllerProvider.notifier).load(),
        ),
        DashLoaded(:final summary, :final fromCache) => _Body(
          summary: summary,
          fromCache: fromCache,
        ),
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.summary, required this.fromCache});

  final DashboardSummary summary;
  final bool fromCache;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (fromCache) const DpOfflineBanner(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StreakCard(days: summary.streakDays),
              const SizedBox(height: 12),
              _ProgressCard(percent: summary.progressPercent),
              const SizedBox(height: 12),
              _NextTaskCard(title: summary.nextTaskTitle),
              if (summary.badges.isNotEmpty) ...[
                const SizedBox(height: 12),
                _BadgesCard(badges: summary.badges),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(DpIcons.home),
        title: const Text('연속 학습'),
        trailing: Text('$days일', style: Theme.of(context).textTheme.titleLarge),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('학습 진척률'),
                Text(
                  '$percent%',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: percent / 100),
          ],
        ),
      ),
    );
  }
}

class _NextTaskCard extends StatelessWidget {
  const _NextTaskCard({required this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(DpIcons.content),
        title: const Text('다음 과제'),
        subtitle: Text(title ?? '다음 과제가 없어요'),
      ),
    );
  }
}

class _BadgesCard extends StatelessWidget {
  const _BadgesCard({required this.badges});

  final List<String> badges;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('배지'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final b in badges) Chip(label: Text(b))],
            ),
          ],
        ),
      ),
    );
  }
}
