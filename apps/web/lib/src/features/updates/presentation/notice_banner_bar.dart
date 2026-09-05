import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/notice_banner_controller.dart';

class NoticeBannerBar extends ConsumerStatefulWidget {
  const NoticeBannerBar({super.key});

  @override
  ConsumerState<NoticeBannerBar> createState() => _NoticeBannerBarState();
}

class _NoticeBannerBarState extends ConsumerState<NoticeBannerBar> {
  String? _dismissedId;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(noticeBannerControllerProvider);
    if (state is! NoticeBannerReady || state.banner.id == _dismissedId) {
      return const SizedBox.shrink();
    }
    final banner = state.banner;
    final colors = context.dpColors;
    return Material(
      color: colors.accentSoft,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DpSpacing.lg,
          vertical: DpSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${banner.title} · ${banner.summary}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => context.go(banner.ctaPath),
              child: Text(banner.ctaLabel),
            ),
            IconButton(
              tooltip: '공지 닫기',
              onPressed: () => setState(() => _dismissedId = banner.id),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}
