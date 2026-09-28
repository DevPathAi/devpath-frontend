import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';

/// 동의 체크 행(시안 `.chk`) — 체크박스 + 라벨·설명 + 우측 보조 링크.
///
/// `CheckboxListTile` 을 쓰지 않는 이유: 시안의 행은 우측에 「전문 보기」 링크를
/// 두는데 `CheckboxListTile` 의 `secondary`·`trailing` 은 체크박스와 자리를
/// 다투고, 라벨·설명·링크 셋이 한 노드로 병합돼 스크린리더가 링크를 놓친다.
///
/// 탭 정지는 **행 하나**다. Material [Checkbox] 는 시각만 남기고 포커스·시맨틱스·
/// 포인터에서 빼고, 행 래퍼(`FocusableActionDetector`)가 포커스와 활성화를
/// 소유한다 — 체크박스와 행이 각자 탭 정지를 가지면 같은 항목에 두 번 멈춘다.
class DpCheckRow extends StatefulWidget {
  const DpCheckRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
    this.trailing,
    this.last = false,
  });

  final Widget label;
  final Widget? description;
  final bool value;

  /// null 이면 읽기 전용이다(필수 동의 등).
  final ValueChanged<bool>? onChanged;

  /// 우측 보조 요소(「전문 보기」 링크 등). 체크 상태와 별개의 노드로 남는다.
  final Widget? trailing;

  final bool last;

  @override
  State<DpCheckRow> createState() => _DpCheckRowState();
}

class _DpCheckRowState extends State<DpCheckRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;
    final onChanged = widget.onChanged;
    final enabled = onChanged != null;

    final inner = Container(
      // 시안 `:focus-visible{outline:2px solid}` — 레이아웃을 밀지 않게 전경으로.
      foregroundDecoration: _focused
          ? BoxDecoration(
              border: Border.all(color: c.primaryText, width: 2),
              borderRadius: BorderRadius.circular(DpRadius.chip),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 시각만 남긴다 — 포인터는 행 제스처가 받고, 포커스·시맨틱스는 행이 갖는다.
          IgnorePointer(
            child: ExcludeFocus(
              child: ExcludeSemantics(
                child: Checkbox(
                  value: widget.value,
                  onChanged: enabled ? (_) {} : null,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
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

    return Container(
      key: const ValueKey('dp-check-row'),
      padding: const EdgeInsets.symmetric(
        vertical: 10,
        horizontal: DpSpacing.lg,
      ),
      decoration: BoxDecoration(
        border: widget.last
            ? null
            : Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 체크 상태와 라벨을 한 노드로 묶는다 — 체크박스만 읽히면 무엇에
          // 동의하는지 알 수 없다. 우측 `trailing` 은 이 노드 밖에 남는다.
          Expanded(
            child: MergeSemantics(
              child: Semantics(
                checked: widget.value,
                enabled: enabled,
                onTap: enabled ? () => onChanged(!widget.value) : null,
                child: MouseRegion(
                  cursor: enabled
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.basic,
                  child: FocusableActionDetector(
                    enabled: enabled,
                    onFocusChange: (v) => setState(() => _focused = v),
                    actions: <Type, Action<Intent>>{
                      ActivateIntent: CallbackAction<ActivateIntent>(
                        onInvoke: (_) {
                          onChanged?.call(!widget.value);
                          return null;
                        },
                      ),
                    },
                    child: GestureDetector(
                      onTap: enabled ? () => onChanged(!widget.value) : null,
                      // 제스처 노드가 라벨 조각을 흡수하지 않게 뺀다(P3 실측).
                      excludeFromSemantics: true,
                      child: inner,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.trailing != null) ...[
            const SizedBox(width: DpSpacing.sm),
            widget.trailing!,
          ],
        ],
      ),
    );
  }
}
