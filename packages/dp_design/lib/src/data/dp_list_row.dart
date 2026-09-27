import 'package:flutter/material.dart';

import '../content/dp_link.dart';
import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';
import '../theme/dp_tokens.dart';

/// 웹 문법 목록 행(Layer 2) — 상단 뱃지행 → 제목 → 부제, 우측 trailing 메타.
/// go_router·Riverpod 비의존 순수 표현부.
///
/// S3-P3 에서 카드(DpInteractiveCard)를 벗고 구분선 행이 됐다. 시안의 목록에는
/// 카드도 좌측 상태 표시선도 없다 — 상태는 색 막대가 아니라 [DpStatusText] 로
/// 드러낸다. hover 는 표(DpWebTable)의 행과 같은 규칙으로 배경색만 바꾼다.
class DpListRow extends StatelessWidget {
  const DpListRow({
    super.key,
    required this.title,
    this.badges = const [],
    this.trailing,
    this.onTap,
    this.preview,
    this.subtitle,
    this.last = false,
  });

  final String title;
  final List<Widget> badges;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// 지정 시 제목 hover 미리보기 본문(웹 전용). 비어있으면 미표시.
  final String? preview;

  /// 제목 아래에 **항상** 보이는 보조 영역. [preview] 가 hover 전용인 것과 대비된다 —
  /// 검색 결과의 매칭 하이라이트처럼 행 스스로 근거를 드러내야 할 때 쓴다.
  /// 서식이 필요할 수 있어 String 이 아니라 Widget 을 받는다.
  final Widget? subtitle;

  /// 목록의 마지막 행이면 하단 구분선을 그리지 않는다.
  final bool last;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _HoverRow(
      onTap: onTap,
      last: last,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;
          if (compact) {
            // 좁은 폭에서는 메타를 본문 아래로 내린다. 한 줄에 같이 두면
            // 제목이 두 글자 폭으로 눌린다.
            return Column(
              key: const ValueKey('dp-list-row-mobile-layout'),
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _content(context, text),
                if (trailing != null) ...[
                  const SizedBox(height: DpSpacing.sm),
                  DefaultTextStyle.merge(
                    style: text.bodySmall?.copyWith(
                      color: context.dpColors.textSecondary,
                    ),
                    child: trailing!,
                  ),
                ],
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _content(context, text)),
              if (trailing != null) ...[
                const SizedBox(width: DpSpacing.lg),
                DefaultTextStyle.merge(
                  style: text.bodySmall?.copyWith(
                    color: context.dpColors.textSecondary,
                  ),
                  child: trailing!,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _content(BuildContext context, TextTheme text) => Column(
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
        const SizedBox(height: DpSpacing.sm),
      ],
      (preview != null && preview!.trim().isNotEmpty)
          ? _HoverPreview(
              preview: preview!,
              child: DpLink.title(text: title, onTap: onTap),
            )
          : DpLink.title(text: title, onTap: onTap),
      if (subtitle != null) ...[
        const SizedBox(height: DpSpacing.sm),
        DefaultTextStyle.merge(
          style: text.bodySmall?.copyWith(
            color: context.dpColors.textSecondary,
          ),
          child: subtitle!,
        ),
      ],
    ],
  );
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

/// 구분선 행의 hover 배경. 표(`DpWebTable`)의 행과 같은 규칙이다 —
/// 카드 테두리·그림자를 쓰지 않고 배경색만 바꾼다.
///
/// 제스처에 `excludeFromSemantics: true` 를 주는 이유는 표와 같다: 없으면 이
/// 노드가 제목·뱃지·메타 조각을 흡수해 행 전체가 한 덩어리로 읽힌다. 접근성
/// 컨트롤은 제목의 [DpLink] 가 담당한다.
class _HoverRow extends StatefulWidget {
  const _HoverRow({required this.child, required this.last, this.onTap});

  final Widget child;
  final bool last;
  final VoidCallback? onTap;

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final body = Container(
      key: const ValueKey('dp-list-row'),
      padding: const EdgeInsets.symmetric(
        vertical: DpDensity.rowPadding,
        horizontal: DpSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: _hovered ? c.surfaceMuted : null,
        border: widget.last
            ? null
            : Border(bottom: BorderSide(color: c.border)),
      ),
      child: widget.child,
    );

    return MouseRegion(
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: widget.onTap == null
          ? body
          : GestureDetector(
              onTap: widget.onTap,
              excludeFromSemantics: true,
              child: body,
            ),
    );
  }
}
