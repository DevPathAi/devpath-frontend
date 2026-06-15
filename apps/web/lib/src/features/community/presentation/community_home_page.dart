import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/community_controller.dart';
import '../state/community_state.dart';

class CommunityHomePage extends ConsumerStatefulWidget {
  const CommunityHomePage({super.key});

  @override
  ConsumerState<CommunityHomePage> createState() => _CommunityHomePageState();
}

class _CommunityHomePageState extends ConsumerState<CommunityHomePage> {
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
    final notifier = ref.read(communityControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('커뮤니티')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {}, // 작성(후속)
        icon: const Icon(DpIcons.edit),
        label: const Text('질문하기'),
      ),
      body: switch (s.phase) {
        CommunityPhase.loading => const DpLoading(),
        CommunityPhase.failed => DpError(
          message: s.error ?? '불러오지 못했어요',
          onRetry: notifier.load,
        ),
        CommunityPhase.loaded when s.posts.isEmpty => DpEmpty(
          icon: DpIcons.community,
          title: '첫 질문을 남겨보세요',
          message: '막힌 부분을 커뮤니티에 물어보세요.',
          actionLabel: '질문 작성',
          onAction: () {},
        ),
        CommunityPhase.loaded => ListView.separated(
          padding: const EdgeInsets.all(DpSpacing.lg),
          itemCount: s.posts.length + (s.hasMore ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: DpSpacing.sm),
          itemBuilder: (_, i) {
            if (i >= s.posts.length) {
              // 🔶 ENG-REVIEW(P2): loadMore 에러를 무음으로 두지 않는다.
              // error가 있으면 인라인 메시지 + 재시도, 없으면 더 보기 버튼.
              if (s.error != null) {
                return Column(
                  children: [
                    Text(
                      s.error!,
                      style: TextStyle(color: context.dpColors.danger),
                    ),
                    const SizedBox(height: DpSpacing.xs),
                    TextButton(
                      onPressed: s.loadingMore ? null : notifier.loadMore,
                      child: const Text('재시도'),
                    ),
                  ],
                );
              }
              return Center(
                child: TextButton(
                  onPressed: s.loadingMore ? null : notifier.loadMore,
                  child: Text(s.loadingMore ? '불러오는 중…' : '더 보기'),
                ),
              );
            }
            final p = s.posts[i];
            final c = context.dpColors;
            return Card(
              child: ListTile(
                title: Text(p.title),
                subtitle: Text(
                  '${p.author} · 답변 ${p.answerCount}',
                  style: TextStyle(color: c.textSecondary),
                ),
                onTap: () => context.go('/community/${p.id}'),
              ),
            );
          },
        ),
      },
    );
  }
}
