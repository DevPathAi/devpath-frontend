import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/learn_controller.dart';
import '../state/learn_state.dart';

/// 학습 탭 — 학습 경로의 주차/과제 목록. 콘텐츠 과제 탭 → 학습 뷰어로 이동.
class LearnPage extends ConsumerStatefulWidget {
  const LearnPage({super.key});

  @override
  ConsumerState<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends ConsumerState<LearnPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(learnControllerProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(learnControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('학습')),
      body: switch (s) {
        LearnLoading() => const DpLoading(),
        LearnFailed(:final message) => DpError(
          message: message,
          onRetry: () => ref.read(learnControllerProvider.notifier).load(),
        ),
        LearnLoaded(:final path) => _PathView(path: path),
      },
    );
  }
}

class _PathView extends StatelessWidget {
  const _PathView({required this.path});

  final LearningPath path;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${path.track} · ${path.totalWeeks}주',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(path.rationale, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        for (final m in path.milestones) _MilestoneCard(milestone: m),
      ],
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({required this.milestone});

  final PathMilestone milestone;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: milestone.locked
                ? const Icon(Icons.lock_outline)
                : Text(
                    'W${milestone.weekNum}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
            title: Text(milestone.title),
            subtitle: Text(milestone.goalDescription),
          ),
          if (!milestone.locked)
            for (final t in milestone.tasks)
              ListTile(
                dense: true,
                leading: const Icon(DpIcons.content),
                title: Text(t.title),
                trailing: t.completed
                    ? const Icon(DpIcons.stepDone)
                    : const Icon(Icons.chevron_right),
                onTap: t.contentSlug == null
                    ? null
                    : () => context.push('/learn/content/${t.contentSlug}'),
              ),
        ],
      ),
    );
  }
}
