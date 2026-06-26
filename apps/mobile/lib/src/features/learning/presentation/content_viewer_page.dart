import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/content_controller.dart';
import '../state/content_state.dart';

/// 모바일 학습 뷰어 — 콘텐츠 마크다운 렌더 + 완료 표시.
class ContentViewerPage extends ConsumerStatefulWidget {
  const ContentViewerPage({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<ContentViewerPage> createState() => _ContentViewerPageState();
}

class _ContentViewerPageState extends ConsumerState<ContentViewerPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(contentControllerProvider.notifier).load(widget.slug),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(contentControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (s) {
          ContentLoaded(:final content) => content.title,
          _ => '학습',
        }),
      ),
      body: switch (s) {
        ContentLoading() => const DpLoading(),
        ContentFailed(:final message) => DpError(
          message: message,
          onRetry: () =>
              ref.read(contentControllerProvider.notifier).load(widget.slug),
        ),
        ContentLoaded(:final content) => _ContentBody(
          slug: widget.slug,
          content: content,
        ),
      },
    );
  }
}

class _ContentBody extends ConsumerWidget {
  const _ContentBody({required this.slug, required this.content});

  final String slug;
  final LearningContent content;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed = content.progress.completed;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: DpMarkdown(data: content.markdown),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: completed
                    ? null
                    : () => ref
                          .read(contentControllerProvider.notifier)
                          .markComplete(slug),
                icon: const Icon(DpIcons.stepDone),
                label: Text(completed ? '완료됨' : '완료로 표시'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
