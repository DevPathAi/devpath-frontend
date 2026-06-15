import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/qna_detail_controller.dart';
import '../state/qna_detail_state.dart';

class QnaDetailPage extends ConsumerStatefulWidget {
  const QnaDetailPage({super.key, required this.postId});
  final String postId;

  @override
  ConsumerState<QnaDetailPage> createState() => _QnaDetailPageState();
}

class _QnaDetailPageState extends ConsumerState<QnaDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(qnaDetailControllerProvider.notifier).load(widget.postId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(qnaDetailControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Q&A')),
      body: switch (s) {
        QnaLoading() => const DpLoading(),
        QnaFailed(:final message) => DpError(message: message),
        QnaLoaded(:final post) => ListView(
          padding: const EdgeInsets.all(DpSpacing.lg),
          children: [
            Text(post.title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: DpSpacing.xs),
            Text(
              '${post.author} · 답변 ${post.answerCount}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.dpColors.textSecondary,
              ),
            ),
            const SizedBox(height: DpSpacing.lg),
            if (post.body != null) DpMarkdown(data: post.body!),
          ],
        ),
      },
    );
  }
}
