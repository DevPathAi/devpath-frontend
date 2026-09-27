import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';

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
  bool _focused = false;

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

    // 시안 `:focus-visible{outline:2px solid var(--ptext);outline-offset:2px}`.
    // 레이아웃을 밀지 않도록 전경 장식으로 그린다.
    final ringed = _focused
        ? Container(
            key: const ValueKey('dp-link-focus-ring'),
            foregroundDecoration: BoxDecoration(
              border: Border.all(color: c.primaryText, width: 2),
              borderRadius: BorderRadius.circular(DpRadius.chip),
            ),
            child: label,
          )
        : label;

    // 링크는 키보드로 도달·활성화돼야 한다. `MouseRegion` + `GestureDetector`
    // 만으로는 Tab 이 이 위젯을 건너뛰고 Enter 도 먹지 않는다(실측 2026-09-27:
    // 포커스가 라우트 스코프에 머물렀다). `FocusableActionDetector` 가 순회
    // 대상 등록·hover·focus 하이라이트·ActivateIntent 를 한 번에 맡는다.
    // hover 는 `MouseRegion` 이 직접 본다. `FocusableActionDetector` 의
    // `onShowHoverHighlight` 는 `FocusManager.highlightMode` 가 traditional 일
    // 때만 불리는데, 테스트·터치 환경의 기본은 touch 라 마우스를 올려도 조용하다
    // (실측 2026-09-27: 색이 그대로였다).
    // 노드는 하나로 유지한다. `MergeSemantics` 로 합치면 빈 자식 조각이 라벨에
    // 붙어 '이용약관\n' 이 된다(실측). 대신 포커스 상태를 이 Semantics 가 직접
    // 선언하고 자식 subtree 는 통째로 가린다.
    return Semantics(
      link: true,
      label: widget.text,
      onTap: widget.onTap,
      focusable: true,
      focused: _focused,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: FocusableActionDetector(
          onShowFocusHighlight: (v) => setState(() => _focused = v),
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onTap?.call();
                return null;
              },
            ),
          },
          child: GestureDetector(
            onTap: widget.onTap,
            excludeFromSemantics: true,
            child: ringed,
          ),
        ),
      ),
    );
  }
}
