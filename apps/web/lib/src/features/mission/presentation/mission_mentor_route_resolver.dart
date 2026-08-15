import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/api_providers.dart';
import '../../dashboard/application/current_mission_controller.dart';
import '../../mentor/presentation/mentor_page.dart';
import '../../mentor/state/mentor_scope_key.dart';
import '../state/mission_workspace_key.dart';

typedef MissionMentorBuilder =
    Widget Function(
      BuildContext context,
      MentorScopeKey scopeKey,
      bool includeCurrentCode,
    );

Widget canonicalMissionMentorBuilder(
  BuildContext context,
  MentorScopeKey scopeKey,
  bool includeCurrentCode,
) => MentorPage.contextual(
  key: ValueKey(scopeKey),
  scopeKey: scopeKey,
  includeCurrentCode: includeCurrentCode,
);

/// Resolves identifiers against the authenticated owner's authoritative Today
/// projection before any contextual Mentor/LCS state is constructed.
class MissionMentorRouteResolver extends ConsumerStatefulWidget {
  const MissionMentorRouteResolver({
    super.key,
    required this.taskId,
    this.entryIntent,
    this.mentorBuilder = canonicalMissionMentorBuilder,
  });

  final String? taskId;
  final MentorEntryIntent? entryIntent;
  final MissionMentorBuilder mentorBuilder;

  @override
  ConsumerState<MissionMentorRouteResolver> createState() =>
      _MissionMentorRouteResolverState();
}

class _MissionMentorRouteResolverState
    extends ConsumerState<MissionMentorRouteResolver> {
  bool _loadScheduled = false;

  @override
  void didUpdateWidget(covariant MissionMentorRouteResolver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taskId != widget.taskId) _loadScheduled = false;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(
      appConfigProvider.select((config) => config.missionSpineEnabled),
    );
    if (!enabled) return const _MentorRouteRecovery.disabled();

    final taskId = MissionWorkspaceKey.tryParseTaskId(widget.taskId);
    if (taskId == null) return const _MentorRouteRecovery.invalid();

    final owner = ref.watch(currentMissionOwnerKeyProvider);
    if (owner == null || owner.isEmpty) {
      return const _MentorRouteRecovery.mismatch();
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
      return Scaffold(
        body: DpError(
          title: '현재 미션을 불러오지 못했어요',
          message: '${state.failureMessage!} 질문과 학습 기록은 그대로예요.',
          onRetry: () => unawaited(
            ref
                .read(currentMissionControllerProvider.notifier)
                .invalidateAndRefetch(),
          ),
        ),
      );
    }
    if (mission.outcome != CurrentMissionOutcome.available) {
      return const _MentorRouteRecovery.mismatch();
    }
    final matching = mission.tasks.where(
      (task) => task.taskId == taskId && task.contentId != null,
    );
    if (matching.length != 1) return const _MentorRouteRecovery.mismatch();
    final workspaceKey = MissionWorkspaceKey(
      taskId: taskId,
      contentId: matching.single.contentId!,
    );
    final scope = MentorScopeKey(ownerId: owner, workspaceKey: workspaceKey);
    final intent = widget.entryIntent;
    final includeCode =
        intent != null && intent.includeCurrentCode && intent.scopeKey == scope;
    return widget.mentorBuilder(context, scope, includeCode);
  }
}

class _MentorRouteRecovery extends StatelessWidget {
  const _MentorRouteRecovery._({required this.title, required this.message});

  const _MentorRouteRecovery.invalid()
    : this._(
        title: '멘토 링크가 올바르지 않아요',
        message: '과제 식별자를 확인할 수 없어 학습 맥락을 열지 않았어요.',
      );

  const _MentorRouteRecovery.mismatch()
    : this._(
        title: '이 멘토 링크는 현재 미션과 일치하지 않아요',
        message: '서버가 확인한 오늘의 미션에서 다시 시작해 주세요.',
      );

  const _MentorRouteRecovery.disabled()
    : this._(title: '미션 멘토가 아직 활성화되지 않았어요', message: '현재 버전의 멘토 화면을 이용해 주세요.');

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
