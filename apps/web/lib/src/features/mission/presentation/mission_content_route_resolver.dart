import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/api_providers.dart';
import '../../content/presentation/content_page.dart';
import '../../dashboard/application/current_mission_controller.dart';
import '../state/mission_workspace_key.dart';

typedef MissionContentBuilder =
    Widget Function(BuildContext context, MissionWorkspaceKey key);

/// Seam for the route-keyed Content page that follows this router slice.
Widget canonicalMissionContentBuilder(
  BuildContext context,
  MissionWorkspaceKey key,
) => ContentPage.mission(key: ValueKey(key), workspaceKey: key);

/// Resolves a canonical task/content deep link against the server-owned Today
/// projection before allowing the route-keyed Content controller to issue its
/// GET or progress writes.
class MissionContentRouteResolver extends ConsumerStatefulWidget {
  const MissionContentRouteResolver({
    super.key,
    required this.taskId,
    required this.contentId,
    this.contentBuilder = canonicalMissionContentBuilder,
  });

  final String? taskId;
  final String? contentId;
  final MissionContentBuilder contentBuilder;

  @override
  ConsumerState<MissionContentRouteResolver> createState() =>
      _MissionContentRouteResolverState();
}

class _MissionContentRouteResolverState
    extends ConsumerState<MissionContentRouteResolver> {
  bool _loadScheduled = false;

  @override
  void didUpdateWidget(covariant MissionContentRouteResolver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taskId != widget.taskId ||
        oldWidget.contentId != widget.contentId) {
      _loadScheduled = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(
      appConfigProvider.select((config) => config.missionSpineEnabled),
    );

    // OFF artifacts preserve the old content behavior and make no Today call.
    if (!enabled) {
      return ContentPage(contentId: widget.contentId ?? '');
    }

    final key = MissionWorkspaceKey.tryParse(
      taskId: widget.taskId,
      contentId: widget.contentId,
    );
    if (key == null) {
      return const _MissionRouteRecovery.invalidLink();
    }

    if (!_loadScheduled) {
      _loadScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(ref.read(currentMissionControllerProvider.notifier).load());
      });
    }

    final state = ref.watch(currentMissionControllerProvider);
    final mission = state.mission;
    if (mission == null) {
      if (state.isLoading || state.failureMessage == null) {
        return const Scaffold(body: DpLoading(label: '현재 미션을 확인하는 중'));
      }
      return _MissionRouteLoadFailure(
        message: state.failureMessage!,
        onRetry: () => unawaited(
          ref
              .read(currentMissionControllerProvider.notifier)
              .invalidateAndRefetch(),
        ),
      );
    }

    return switch (mission.outcome) {
      CurrentMissionOutcome.available => _resolveAvailable(
        context,
        key,
        mission,
      ),
      CurrentMissionOutcome.noActivePath =>
        const _MissionRouteRecovery.noActivePath(),
      CurrentMissionOutcome.pathCompleted =>
        const _MissionRouteRecovery.completedPath(),
      CurrentMissionOutcome.malformedPath =>
        const _MissionRouteRecovery.malformedPath(),
    };
  }

  Widget _resolveAvailable(
    BuildContext context,
    MissionWorkspaceKey key,
    CurrentMission mission,
  ) {
    final matching = mission.tasks.where(
      (task) => task.taskId == key.taskId && task.contentId == key.contentId,
    );
    if (matching.length != 1) {
      return const _MissionRouteRecovery.mismatch();
    }
    return widget.contentBuilder(context, key);
  }
}

class _MissionRouteLoadFailure extends StatelessWidget {
  const _MissionRouteLoadFailure({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DpError(
      title: '현재 미션을 불러오지 못했어요',
      message: '$message 학습 기록은 그대로예요.',
      onRetry: onRetry,
    ),
  );
}

class _MissionRouteRecovery extends StatelessWidget {
  const _MissionRouteRecovery._({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.destination,
  });

  const _MissionRouteRecovery.invalidLink()
    : this._(
        title: '미션 링크가 올바르지 않아요',
        message: '과제와 콘텐츠 식별자를 확인할 수 없어 콘텐츠를 열지 않았어요.',
        actionLabel: '오늘로 돌아가기',
        destination: '/dashboard',
      );

  const _MissionRouteRecovery.mismatch()
    : this._(
        title: '이 미션 링크는 더 이상 현재 미션과 일치하지 않아요',
        message: '오래된 링크일 수 있어요. 서버가 확인한 오늘의 미션에서 다시 시작해 주세요.',
        actionLabel: '오늘로 돌아가기',
        destination: '/dashboard',
      );

  const _MissionRouteRecovery.noActivePath()
    : this._(
        title: '활성 학습 경로가 없어요',
        message: '학습 경로를 만들거나 다시 확인한 뒤 미션을 열 수 있어요.',
        actionLabel: '경로 확인하기',
        destination: '/path',
      );

  const _MissionRouteRecovery.completedPath()
    : this._(
        title: '이미 완료된 경로의 미션이에요',
        message: '완료 기록은 유지됩니다. 오늘 화면에서 다음 행동을 확인해 주세요.',
        actionLabel: '오늘로 돌아가기',
        destination: '/dashboard',
      );

  const _MissionRouteRecovery.malformedPath()
    : this._(
        title: '현재 미션을 확인할 수 없어요',
        message: '경로의 주차나 과제를 임의로 추정하지 않았어요.',
        actionLabel: '오늘로 돌아가기',
        destination: '/dashboard',
      );

  final String title;
  final String message;
  final String actionLabel;
  final String destination;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DpEmpty(
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: () => context.go(destination),
    ),
  );
}
