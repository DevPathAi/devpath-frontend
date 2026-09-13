import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';
import 'dp_destination.dart';

/// Leva 소유의 모바일 하단 내비게이션.
///
/// Material [NavigationBar]의 강한 기본 형태 대신 얕게 떠 있는 제품 전용
/// 표면을 사용한다. [selectedIndex]가 null일 때 거짓 선택 상태를 만들지 않는다.
class DpMobileNavigation extends StatelessWidget {
  const DpMobileNavigation({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<DpDestination> destinations;
  final int? selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    return ColoredBox(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
          DpSpacing.md,
          DpSpacing.xs,
          DpSpacing.md,
          DpSpacing.sm,
        ),
        child: Container(
          key: const ValueKey('mobile-nav-surface'),
          height: 68,
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border),
            borderRadius: BorderRadius.circular(DpRadius.card),
            boxShadow: [
              BoxShadow(
                color: c.textPrimary.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(DpSpacing.xs),
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: _MobileDestination(
                    key: ValueKey('mobile-nav-item-$i'),
                    destination: destinations[i],
                    selected: selectedIndex == i,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileDestination extends StatelessWidget {
  const _MobileDestination({
    super.key,
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final DpDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final foreground = selected ? c.primaryText : c.textSecondary;
    final icon = Icon(destination.icon, size: 21, color: foreground);

    return Semantics(
      button: true,
      selected: selected,
      label: destination.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DpRadius.button),
          child: AnimatedContainer(
            duration: DpMotion.resolve(context, DpDurations.select),
            decoration: BoxDecoration(
              color: selected ? c.accentSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(DpRadius.button),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: DpSpacing.xs,
              vertical: 6,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                destination.badgeCount > 0
                    ? Badge(
                        label: Text('${destination.badgeCount}'),
                        child: icon,
                      )
                    : icon,
                const SizedBox(height: 2),
                Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
