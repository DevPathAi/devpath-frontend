import 'package:flutter/material.dart';

import '../interaction/dp_interactive_card.dart';
import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';
import '../theme/dp_tokens.dart';

/// 리스트 행(Layer 2). 좌측 상태 표시선(accent) + 상단 뱃지행 → 제목 + 우측 trailing 메타.
/// DpInteractiveCard(hover/focus) 베이스. go_router·Riverpod 비의존 순수 표현부.
class DpListRow extends StatelessWidget {
  const DpListRow({
    super.key,
    required this.title,
    this.accentColor,
    this.badges = const [],
    this.trailing,
    this.onTap,
    this.preview,
  });

  final String title;
  final Color? accentColor;
  final List<Widget> badges;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// 지정 시 제목 hover 미리보기 본문(웹 전용). 비어있으면 미표시.
  final String? preview;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return DpInteractiveCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (accentColor != null)
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(DpRadius.card),
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(DpSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (badges.isNotEmpty) ...[
                      Wrap(
                        spacing: DpSpacing.xs,
                        runSpacing: DpSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: badges,
                      ),
                      const SizedBox(height: DpSpacing.xs),
                    ],
                    (preview != null && preview!.trim().isNotEmpty)
                        ? _HoverPreview(
                            preview: preview!,
                            child: Text(title, style: text.titleSmall),
                          )
                        : Text(title, style: text.titleSmall),
                  ],
                ),
              ),
            ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DpSpacing.md,
                  vertical: DpSpacing.md,
                ),
                child: Align(alignment: Alignment.centerRight, child: trailing),
              ),
          ],
        ),
      ),
    );
  }
}

/// 제목 hover 시 OverlayPortal로 본문 미리보기(웹 전용 — MouseRegion hover).
class _HoverPreview extends StatefulWidget {
  const _HoverPreview({required this.preview, required this.child});

  final String preview;
  final Widget child;

  @override
  State<_HoverPreview> createState() => _HoverPreviewState();
}

class _HoverPreviewState extends State<_HoverPreview> {
  final _controller = OverlayPortalController();
  final _link = LayerLink();

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        onEnter: (_) => _controller.show(),
        onExit: (_) => _controller.hide(),
        child: OverlayPortal(
          controller: _controller,
          overlayChildBuilder: (context) => Positioned(
            width: 320,
            child: CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 4),
              child: _PreviewCard(text: widget.preview),
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(DpSpacing.md),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(context.appTokens.panelRadius),
        ),
        child: Text(
          text,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: c.textSecondary),
        ),
      ),
    );
  }
}
