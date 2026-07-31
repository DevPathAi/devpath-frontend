import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/dashboard_controller.dart';
import '../state/dashboard_state.dart';
import 'widgets/dashboard_body.dart';

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
        DashLoaded(:final summary) => DashboardBody(summary: summary),
      },
    );
  }
}
