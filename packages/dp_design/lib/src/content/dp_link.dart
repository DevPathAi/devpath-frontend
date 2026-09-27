import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';

enum _DpLinkVariant { title, inline }

/// 웹 문법 링크(시안 `.ttl`·`.lk`).
///
/// - [DpLink.title] = `.ttl`: 목록·표의 제목. 평소엔 본문색 600 에 밑줄이 없고,
///   hover 에서만 강조색 + 밑줄이 된다(표 한 화면에 제목이 수십 개라 항상
///   밑줄이면 지면이 시끄럽다).
/// - [DpLink.inline] = `.lk`: 문장 안 링크. 밑줄이 항상 있어야 색만으로
///   링크를 구분하지 않게 된다(WCAG 1.4.1).
class DpLink extends StatefulWidget {
  const DpLink._({
    super.key,
    required this.text,
    required this.variant,
    this.onTap,
    this.maxLines,
  });

  const DpLink.title({
    Key? key,
    required String text,
    VoidCallback? onTap,
    int? maxLines,
  }) : this._(
         key: key,
         text: text,
         variant: _DpLinkVariant.title,
         onTap: onTap,
         maxLines: maxLines,
       );

  const DpLink.inline({Key? key, required String text, VoidCallback? onTap})
    : this._(
        key: key,
        text: text,
        variant: _DpLinkVariant.inline,
        onTap: onTap,
      );

  final String text;
  final _DpLinkVariant variant;
  final VoidCallback? onTap;
  final int? maxLines;

  @override
  State<DpLink> createState() => _DpLinkState();
}

class _DpLinkState extends State<DpLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final base = Theme.of(context).textTheme.bodyMedium;
    final inline = widget.variant == _DpLinkVariant.inline;
    final emphasised = inline || _hovered;

    final style = (base ?? const TextStyle()).copyWith(
      color: emphasised ? c.primaryText : c.textPrimary,
      fontWeight: inline ? FontWeight.w400 : FontWeight.w600,
      decoration: emphasised ? TextDecoration.underline : TextDecoration.none,
      decorationColor: emphasised ? c.primaryText : null,
    );

    final label = Text(
      widget.text,
      style: style,
      maxLines: widget.maxLines,
      overflow: widget.maxLines == null ? null : TextOverflow.ellipsis,
    );

    // `excludeSemantics: true` 로 자식 subtree 를 통째로 가린다. 안 그러면
    // GestureDetector 가 자기 tap 노드를 따로 만들어, 라벨과 link 플래그를 가진
    // 바깥 노드와 **두 겹**이 된다 — 스크린리더가 같은 링크를 두 번 만난다.
    if (widget.onTap == null) {
      return Semantics(
        label: widget.text,
        excludeSemantics: true,
        child: label,
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(
        link: true,
        label: widget.text,
        onTap: widget.onTap,
        excludeSemantics: true,
        child: GestureDetector(onTap: widget.onTap, child: label),
      ),
    );
  }
}
