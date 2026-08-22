import 'dart:async';

import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/today_controller.dart';
import 'mobile_today_projection.dart';

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
        TodayState(:final mission?) => MobileTodayProjection(
          mission: mission,
          isOffline: state.isOffline,
          isStale: state.isStale,
          cachedAt: state.cachedAt,
          failureMessage: state.failureMessage,
          completingTaskId: state.completingTaskId,
          onOpenContent: (task) =>
              context.push('/mission/${task.taskId}/content/${task.contentId}'),
          onCompleteContentlessTask: (taskId) => unawaited(
            ref
                .read(todayControllerProvider.notifier)
                .completeContentlessTask(taskId),
          ),
          onRefresh: () => unawaited(
            ref.read(todayControllerProvider.notifier).invalidateAndRefetch(),
          ),
        ),
      },
    );
  }
}
