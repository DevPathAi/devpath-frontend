import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/api_providers.dart';
import '../../dashboard/application/current_mission_controller.dart';
import '../../sandbox/presentation/sandbox_page.dart';
import '../state/mission_workspace_key.dart';

typedef MissionSandboxBuilder =
    Widget Function(BuildContext context, MissionWorkspaceKey key);

Widget canonicalMissionSandboxBuilder(
  BuildContext context,
  MissionWorkspaceKey key,
) => SandboxPage(key: ValueKey(key), workspaceKey: key);

/// Verifies a task-only Sandbox deep link against the authenticated owner's
/// server-owned Today projection before constructing a workspace.
class MissionSandboxRouteResolver extends ConsumerStatefulWidget {
  const MissionSandboxRouteResolver({
    super.key,
    required this.taskId,
    this.sandboxBuilder = canonicalMissionSandboxBuilder,
  });

  final String? taskId;
  final MissionSandboxBuilder sandboxBuilder;

  @override
  ConsumerState<MissionSandboxRouteResolver> createState() =>
      _MissionSandboxRouteResolverState();
}

class _MissionSandboxRouteResolverState
    extends ConsumerState<MissionSandboxRouteResolver> {
  bool _loadScheduled = false;

  @override
  void didUpdateWidget(covariant MissionSandboxRouteResolver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taskId != widget.taskId) _loadScheduled = false;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(
      appConfigProvider.select((config) => config.missionSpineEnabled),
    );
    if (!enabled) return const _MissionSandboxRecovery.disabled();

    final taskId = MissionWorkspaceKey.tryParseTaskId(widget.taskId);
    if (taskId == null) return const _MissionSandboxRecovery.invalid();

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
      return Scaffold(
        body: DpError(
          title: '현재 미션을 불러오지 못했어요',
          message: '${state.failureMessage!} 학습 기록은 그대로예요.',
          onRetry: () => unawaited(
            ref
                .read(currentMissionControllerProvider.notifier)
                .invalidateAndRefetch(),
          ),
        ),
      );
    }
    if (mission.outcome != CurrentMissionOutcome.available) {
      return const _MissionSandboxRecovery.mismatch();
    }

    final matching = mission.tasks.where((task) => task.taskId == taskId);
    if (matching.length != 1 || matching.single.contentId == null) {
      return const _MissionSandboxRecovery.mismatch();
    }
    final key = MissionWorkspaceKey(
      taskId: taskId,
      contentId: matching.single.contentId!,
    );
    return widget.sandboxBuilder(context, key);
  }
}

class _MissionSandboxRecovery extends StatelessWidget {
  const _MissionSandboxRecovery._({required this.title, required this.message});

  const _MissionSandboxRecovery.invalid()
    : this._(
        title: '미션 실습 링크가 올바르지 않아요',
        message: '과제 식별자를 확인할 수 없어 실습 환경을 열지 않았어요.',
      );

  const _MissionSandboxRecovery.mismatch()
    : this._(
        title: '이 실습 링크는 현재 미션과 일치하지 않아요',
        message: '서버가 확인한 오늘의 미션에서 다시 시작해 주세요.',
      );

  const _MissionSandboxRecovery.disabled()
    : this._(
        title: '미션 실습 환경이 아직 활성화되지 않았어요',
        message: '현재 버전의 오늘 화면으로 돌아가 학습을 계속해 주세요.',
      );

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DpEmpty(
      title: title,
      message: message,
      actionLabel: '오늘로 돌아가기',
      onAction: () => context.go('/dashboard'),
    ),
  );
}
