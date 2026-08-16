import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../learning/presentation/content_viewer_page.dart';
import '../../today/application/today_controller.dart';
import '../../today/presentation/today_page.dart';
import '../state/mobile_mission_route.dart';

class MobileTodayRouteResolver extends ConsumerStatefulWidget {
  const MobileTodayRouteResolver({super.key, required this.pathId});

  final String? pathId;

  @override
  ConsumerState<MobileTodayRouteResolver> createState() =>
      _MobileTodayRouteResolverState();
}

class _MobileTodayRouteResolverState
    extends ConsumerState<MobileTodayRouteResolver> {
  bool _scheduled = false;

  @override
  Widget build(BuildContext context) {
    final route = MobileMissionRoute.tryParse('/path/${widget.pathId}/today');
    if (route == null) return const _InvalidMissionLink();
    _scheduleLoad();
    final state = ref.watch(todayControllerProvider);
    final mission = state.mission;
    if (mission == null) return const TodayPage();
    if ((mission.outcome == CurrentMissionOutcome.available ||
            mission.outcome == CurrentMissionOutcome.pathCompleted) &&
        mission.pathId != route.pathId) {
      return const _MissionMismatch(
        message: '이 경로 링크는 현재 계정의 학습 경로와 일치하지 않아요.',
      );
    }
    return const TodayPage();
  }

  void _scheduleLoad() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(todayControllerProvider.notifier).load());
    });
  }
}

class MobileMissionContentRouteResolver extends ConsumerStatefulWidget {
  const MobileMissionContentRouteResolver({
    super.key,
    required this.taskId,
    required this.contentId,
  });

  final String? taskId;
  final String? contentId;

  @override
  ConsumerState<MobileMissionContentRouteResolver> createState() =>
      _MobileMissionContentRouteResolverState();
}

class _MobileMissionContentRouteResolverState
    extends ConsumerState<MobileMissionContentRouteResolver> {
  bool _scheduled = false;

  @override
  Widget build(BuildContext context) {
    final route = MobileMissionRoute.tryParse(
      '/mission/${widget.taskId}/content/${widget.contentId}',
    );
    if (route == null) return const _InvalidMissionLink();
    _scheduleLoad();
    final state = ref.watch(todayControllerProvider);
    final mission = state.mission;
    if (mission == null) {
      if (state.isLoading || state.failureMessage == null) {
        return const Scaffold(body: DpLoading(label: '현재 미션을 확인하는 중'));
      }
      return Scaffold(
        body: DpError(
          title: '현재 미션을 불러오지 못했어요',
          message: '${state.failureMessage} 콘텐츠는 열지 않았어요.',
          onRetry: () => unawaited(
            ref.read(todayControllerProvider.notifier).invalidateAndRefetch(),
          ),
        ),
      );
    }
    if (mission.outcome != CurrentMissionOutcome.available) {
      return const _MissionMismatch(
        message: '현재 열 수 있는 미션이 없어요. Today에서 다시 확인해 주세요.',
      );
    }
    final matching = mission.tasks.where(
      (task) =>
          task.taskId == route.taskId && task.contentId == route.contentId,
    );
    if (matching.length != 1) {
      return const _MissionMismatch(
        message: '과제와 콘텐츠가 현재 서버 경로와 일치하지 않아 열지 않았어요.',
      );
    }
    return ContentViewerPage(
      key: ValueKey(route.location),
      slug: route.contentId.toString(),
    );
  }

  void _scheduleLoad() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(ref.read(todayControllerProvider.notifier).load());
    });
  }
}

class _InvalidMissionLink extends StatelessWidget {
  const _InvalidMissionLink();

  @override
  Widget build(BuildContext context) =>
      _MissionMismatch(message: '미션 링크의 식별자를 확인할 수 없어 콘텐츠를 열지 않았어요.');
}

class _MissionMismatch extends StatelessWidget {
  const _MissionMismatch({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DpEmpty(
      title: '미션 링크를 다시 확인해 주세요',
      message: message,
      actionLabel: '오늘로 돌아가기',
      onAction: () => context.go('/home'),
    ),
  );
}
