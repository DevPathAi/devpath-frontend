import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/community_controller.dart';
import '../state/community_state.dart';

/// 커뮤니티 탭 — 질문 목록 + 퀵 캡처 FAB.
class CommunityPage extends ConsumerStatefulWidget {
  const CommunityPage({super.key});

  @override
  ConsumerState<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends ConsumerState<CommunityPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(communityControllerProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(communityControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('커뮤니티')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/community/new'),
        icon: const Icon(DpIcons.edit),
        label: const Text('퀵 캡처'),
      ),
      body: switch (s) {
        CommunityLoading() => const DpLoading(),
        CommunityFailed(:final message) => DpError(
          message: message,
          onRetry: () => ref.read(communityControllerProvider.notifier).load(),
        ),
        CommunityLoaded(:final posts) => _PostList(posts: posts),
      },
    );
  }
}

class _PostList extends StatelessWidget {
  const _PostList({required this.posts});

  final List<CommunityPostSummary> posts;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const DpEmpty(title: '아직 질문이 없어요');
    }
    return ListView.builder(
      itemCount: posts.length,
      itemBuilder: (context, i) {
        final p = posts[i];
        return ListTile(
          title: Text(p.title),
          subtitle: Text('답변 ${p.answerCount} · 추천 ${p.upvoteCount}'),
          trailing: p.solved
              ? const Icon(DpIcons.stepDone)
              : const Icon(Icons.chevron_right),
          onTap: () => context.push('/community/posts/${p.id}'),
        );
      },
    );
  }
}
