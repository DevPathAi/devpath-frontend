import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/content_controller.dart';
import '../state/content_state.dart';

class ContentPage extends ConsumerStatefulWidget {
  const ContentPage({super.key, required this.contentId});
  final String contentId;

  @override
  ConsumerState<ContentPage> createState() => _ContentPageState();
}

class _ContentPageState extends ConsumerState<ContentPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) =>
          ref.read(contentControllerProvider.notifier).load(widget.contentId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(contentControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('학습 콘텐츠'),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/sandbox'),
            icon: const Icon(DpIcons.code),
            label: const Text('실습'),
          ),
        ],
      ),
      body: switch (s) {
        ContentLoading() => const DpLoading(),
        ContentFailed(:final message) => DpError(
          message: message,
          onRetry: () => ref
              .read(contentControllerProvider.notifier)
              .load(widget.contentId),
        ),
        ContentLoaded(:final markdown) => SingleChildScrollView(
          padding: const EdgeInsets.all(DpSpacing.lg),
          child: DpMarkdown(data: markdown),
        ),
      },
    );
  }
}
