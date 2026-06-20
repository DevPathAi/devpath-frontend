import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/state/auth_state.dart';
import '../application/path_controller.dart';
import '../data/path_sse_source.dart';
import 'path_plan_view.dart';

/// PATH-001. 진입 시 기존 경로를 먼저 조회하고, 없으면 생성한다.
class PathPage extends ConsumerStatefulWidget {
  const PathPage({super.key});

  @override
  ConsumerState<PathPage> createState() => _PathPageState();
}

class _PathPageState extends ConsumerState<PathPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWhenAuthenticated(ref.read(authControllerProvider));
    });
  }

  void _loadWhenAuthenticated(AuthState auth) {
    if (auth is! AuthAuthenticated) return;
    if (ref.read(pathControllerProvider).phase != PathPhase.idle) return;
    ref.read(pathControllerProvider.notifier).loadOrStart();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(
      authControllerProvider,
      (_, next) => _loadWhenAuthenticated(next),
    );
    final s = ref.watch(pathControllerProvider);
    final notifier = ref.read(pathControllerProvider.notifier);

    final body = switch (s.phase) {
      PathPhase.complete when s.result != null => PathPlanView(plan: s.result!),
      // F4: killSwitch/failed는 이어하기 불가 → DpError로(전용 DpKillSwitch/DpQuota 렌더는 P4c).
      PathPhase.failed || PathPhase.killSwitch => DpError(
        message: s.error ?? '경로 생성에 실패했어요',
        onRetry: notifier.start,
      ),
      PathPhase.partial => _Progress(
        completed: s.completed,
        current: s.current,
        note: s.error ?? '연결이 끊겼어요',
        onRestart: notifier.start,
      ),
      _ => _Progress(completed: s.completed, current: s.current),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('학습 경로 생성')),
      body: body,
    );
  }
}

/// SSE 진행/부분 공통: 단계 표시 + (중단 시) 처음부터 다시 생성.
class _Progress extends StatelessWidget {
  const _Progress({
    required this.completed,
    this.current,
    this.note,
    this.onRestart,
  });

  final List<String> completed;
  final String? current;
  final String? note;
  final VoidCallback? onRestart;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    // ENG-REVIEW(§9.2 PARTIAL): 완료 단계만 그리지 않고 kPathStageLabels 전체를 항상
    // 표시한다 — 완료 단계는 채우고, 남은(미완) 단계는 스켈레톤으로 보여줘 "무엇이 남았는지"를
    // 드러낸다. currentIndex=완료 수가 곧 미완 단계의 시작 경계.
    final stages = List<String>.from(kPathStageLabels);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DpSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DpSseStageView(stages: stages, currentIndex: completed.length),
            if (note != null) ...[
              const SizedBox(height: DpSpacing.lg),
              Text(
                note!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: c.warning),
              ),
            ],
            if (onRestart != null) ...[
              const SizedBox(height: DpSpacing.md),
              FilledButton(onPressed: onRestart, child: const Text('다시 생성')),
            ],
          ],
        ),
      ),
    );
  }
}
