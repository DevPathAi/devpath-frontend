import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';

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
  });

  final Widget label;
  final Widget? description;
  final bool selected;
  final VoidCallback onSelect;

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

    final body = Container(
      key: const ValueKey('dp-option-row'),
      padding: const EdgeInsets.symmetric(
        vertical: 10,
        horizontal: DpSpacing.md,
      ),
      decoration: BoxDecoration(
        color: selected
            ? c.accentSoft
            : (_hovered ? c.surfaceMuted : c.surface),
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
            color: selected ? c.primary : c.textSecondary,
          ),
          const SizedBox(width: DpSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                DefaultTextStyle.merge(
                  style: text.bodyMedium?.copyWith(
                    color: c.textPrimary,
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
        inMutuallyExclusiveGroup: true,
        checked: selected,
        onTap: widget.onSelect,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: FocusableActionDetector(
            onFocusChange: (v) => setState(() => _focused = v),
            actions: <Type, Action<Intent>>{
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  widget.onSelect();
                  return null;
                },
              ),
            },
            child: GestureDetector(
              onTap: widget.onSelect,
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
