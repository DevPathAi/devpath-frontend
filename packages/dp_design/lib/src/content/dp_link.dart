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
    required _DpLinkVariant variant,
    this.onTap,
    this.maxLines,
    this.semanticsLabel,
    // 초기화 형식 매개변수(`this._variant`)를 쓸 수 없다 — Dart 는 밑줄로
    // 시작하는 명명 매개변수를 금지한다. 필드를 공개로 되돌리면 이번에는
    // 비공개 타입이 공개 API 에 새는 library_private_types_in_public_api 가 뜬다.
    // ignore: prefer_initializing_formals
  }) : _variant = variant;

  const DpLink.title({
    Key? key,
    required String text,
    VoidCallback? onTap,
    int? maxLines,
    String? semanticsLabel,
  }) : this._(
         key: key,
         text: text,
         variant: _DpLinkVariant.title,
         onTap: onTap,
         maxLines: maxLines,
         semanticsLabel: semanticsLabel,
       );

  const DpLink.inline({
    Key? key,
    required String text,
    VoidCallback? onTap,
    String? semanticsLabel,
  }) : this._(
         key: key,
         text: text,
         variant: _DpLinkVariant.inline,
         onTap: onTap,
         semanticsLabel: semanticsLabel,
       );

  final String text;
  final _DpLinkVariant _variant;
  final VoidCallback? onTap;
  final int? maxLines;

  /// 스크린리더가 읽을 라벨. 같은 문구의 링크가 한 화면에 여럿 있을 때
  /// 무엇의 링크인지 구분한다(동의 화면의 「전문 보기」 2개). null 이면 [text].
  final String? semanticsLabel;

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
    final inline = widget._variant == _DpLinkVariant.inline;
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
        label: widget.semanticsLabel ?? widget.text,
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
      label: widget.semanticsLabel ?? widget.text,
      onTap: widget.onTap,
      focusable: true,
      focused: _focused,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: FocusableActionDetector(
          // `onShowFocusHighlight` 는 `FocusManager.highlightMode` 가
          // traditional 일 때만 불린다(터치 기본값에서는 조용하다). 이 위젯의
          // `Semantics.focused` 는 자식 subtree 를 `excludeSemantics` 로 가린 뒤
          // **직접 선언하는 유일한 진실**이므로 하이라이트 정책이 아니라 실제
          // 포커스를 따라야 한다(실측: touch 모드에서 isFocused 가 false 였다).
          //
          // 대가: 포인터 클릭으로 포커스를 받아도 2px 링이 보인다 — 시안의
          // `:focus-visible` 과 어긋나지만, 링과 시맨틱스가 `_focused` 하나를
          // 공유하므로 **시맨틱스 정확성을 택했다.**
          onFocusChange: (v) => setState(() => _focused = v),
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
