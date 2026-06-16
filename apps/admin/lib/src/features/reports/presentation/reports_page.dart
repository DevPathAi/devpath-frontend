import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/reports_controller.dart';
import '../state/reports_state.dart';

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(reportsProvider);
    final n = ref.read(reportsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('신고 처리')),
      body: switch (s) {
        ReportsLoading() => const DpLoading(),
        ReportsFailed(:final message) => DpError(message: message),
        ReportsLoaded(:final reports) when reports.isEmpty => const DpEmpty(
          icon: DpIcons.empty,
          title: '미처리 신고가 없어요',
        ),
        ReportsLoaded(:final reports) => ListView(
          padding: const EdgeInsets.all(DpSpacing.lg),
          children: [
            for (final r in reports)
              Card(
                child: ListTile(
                  title: Text(r.targetTitle),
                  subtitle: Text('${r.type} · ${r.reason}'),
                  trailing: FilledButton(
                    onPressed: () => n.resolve(r.id),
                    child: const Text('처리'),
                  ),
                ),
              ),
          ],
        ),
      },
    );
  }
}
