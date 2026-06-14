import 'package:flutter/material.dart';

import '../icons/dp_icons.dart';
import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';

/// 오프라인 인라인 배너 + 캐시(drift) 안내 + 재연결 자동 동기화 고지.
class DpOfflineBanner extends StatelessWidget {
  const DpOfflineBanner({super.key, this.message = '오프라인 — 캐시된 콘텐츠를 보여드려요'});
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: DpSpacing.lg,
          vertical: DpSpacing.md,
        ),
        color: c.warning.withValues(alpha: 0.12),
        child: Row(
          children: [
            Icon(DpIcons.offline, size: 18, color: c.warning),
            const SizedBox(width: DpSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
