import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';

/// [DpOptionRow] 의 시맨틱스 역할.
///
/// - [radio]: 고른 것이 **상태로 남고** 별도 확정 버튼이 뒤에 온다(트랙 선택).
/// - [button]: 누르는 즉시 행동이 일어나고 화면이 바뀐다(진단 문항 답변).
///   라디오로 선언하면 스크린리더가 「고른 뒤 확정」을 약속하는데, 그 화면에는
///   확정 단계가 없고 정상 흐름에서 아무것도 checked 가 되지 않는다.
enum DpOptionRole { radio, button }

/// 하나만 고르는 선택 행(시안 `.opt` / `.opt.sel`).
///
/// 라디오 버튼만 타깃으로 두지 않고 **행 전체가 타깃**이다(시안도 `label` 이
/// 감싼다). 시맨틱스는 라디오 그룹(`inMutuallyExclusiveGroup` + `checked`)으로
/// 알린다 — `Radio` 를 직접 쓰면 라벨과 노드가 갈라진다.
///
/// 키보드 도달은 `FocusableActionDetector` 가 맡는다. `MouseRegion` +
/// `GestureDetector` 만으로는 Tab 이 건너뛰고 Enter 도 먹지 않는다(P3 실측,
/// `DpLink` 와 같은 결함). 라벨·설명이 여러 노드로 갈라지지 않도록
/// `MergeSemantics` 로 한 노드에 모은다 — 스크린리더가 "무엇을 고르는지"와
/// "골랐는지"를 한 번에 읽어야 한다.
class DpOptionRow extends StatefulWidget {
  const DpOptionRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelect,
    this.description,
    this.role = DpOptionRole.radio,
  });

  final Widget label;
  final Widget? description;
  final bool selected;

  /// null 이면 잠긴다(제출 중·답변 실패 등). 포커스 순회에서도 빠진다 —
  /// 누를 수 없는 보기에 탭이 멈추면 사용자가 원인을 알 수 없다.
  final VoidCallback? onSelect;

  /// 시맨틱스 역할. 시각은 두 역할이 같다(시안 `.opt` 는 어느 쪽이든 원을 그린다).
  final DpOptionRole role;

  @override
  State<DpOptionRow> createState() => _DpOptionRowState();
}

class _DpOptionRowState extends State<DpOptionRow> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;
    final selected = widget.selected;
    final onSelect = widget.onSelect;
    final enabled = onSelect != null;
    final radio = widget.role == DpOptionRole.radio;

    final body = Container(
      key: const ValueKey('dp-option-row'),
      padding: const EdgeInsets.symmetric(
        vertical: 10,
        horizontal: DpSpacing.md,
      ),
      decoration: BoxDecoration(
        color: selected
            ? c.accentSoft
            : (_hovered && enabled ? c.surfaceMuted : c.surface),
        border: Border.all(color: selected ? c.primary : c.border),
        borderRadius: BorderRadius.circular(DpRadius.button),
      ),
      // 시안 `:focus-visible{outline:2px solid}` — 레이아웃을 밀지 않게 전경으로.
      foregroundDecoration: _focused
          ? BoxDecoration(
              border: Border.all(color: c.primaryText, width: 2),
              borderRadius: BorderRadius.circular(DpRadius.button),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            size: 18,
            color: enabled
                ? (selected ? c.primary : c.textSecondary)
                : c.textSecondary,
          ),
          const SizedBox(width: DpSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                DefaultTextStyle.merge(
                  style: text.bodyMedium?.copyWith(
                    color: enabled ? c.textPrimary : c.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  child: widget.label,
                ),
                if (widget.description != null) ...[
                  const SizedBox(height: 2),
                  DefaultTextStyle.merge(
                    style: TextStyle(fontSize: 13, color: c.textSecondary),
                    child: widget.description!,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    return MergeSemantics(
      child: Semantics(
        // 역할에 따라 checked(라디오) 와 selected(버튼) 중 하나만 선언한다 —
        // 둘을 함께 주면 스크린리더가 같은 상태를 두 번 읽는다.
        inMutuallyExclusiveGroup: radio,
        button: !radio,
        checked: radio ? selected : null,
        selected: radio ? null : selected,
        enabled: enabled,
        onTap: onSelect,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: FocusableActionDetector(
            enabled: enabled,
            onFocusChange: (v) => setState(() => _focused = v),
            actions: <Type, Action<Intent>>{
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  widget.onSelect?.call();
                  return null;
                },
              ),
            },
            child: GestureDetector(
              onTap: onSelect,
              // 이 제스처의 노드가 라벨 조각을 흡수하지 않게 뺀다(P3 실측).
              excludeFromSemantics: true,
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}
