import 'package:flutter/material.dart';

import '../icons/dp_icons.dart';
import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';

/// 브레드크럼 세그먼트. [path]가 null이면 비클릭(섹션명 등).
///
/// 필드가 둘뿐이고 옵셔널 확장 계획이 없어 record를 유지한다
/// (DpDestination을 class로 바꾼 것과 다른 판단 — 그쪽은 section이 필요했다).
typedef DpCrumb = ({String label, String? path});

/// 얇은 상단 크롬바(로드맵 Layer 2). 라우팅 비의존.
///
/// 검색 필드는 TextField가 아니라 [onSearchTap]을 호출하는 버튼이다 —
/// 실제 입력은 기존 DpCommandPalette가 받는다. 입력 상태를 두 곳에서
/// 관리하지 않기 위한 선택이다.
class DpChromeBar extends StatelessWidget {
  const DpChromeBar({
    super.key,
    required this.breadcrumb,
    this.onCrumbTap,
    this.onSearchTap,
    this.actions = const [],
    this.account,
    this.compact = false,
  });

  static const double height = 46;

  final List<DpCrumb> breadcrumb;
  final ValueChanged<String>? onCrumbTap;
  final VoidCallback? onSearchTap;
  final List<Widget> actions;
  final Widget? account;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: DpSpacing.lg),
      child: Row(
        children: [
          Flexible(child: _crumbs(context, c)),
          const SizedBox(width: DpSpacing.lg),
          if (!compact && onSearchTap != null)
            Flexible(flex: 2, child: _search(context, c))
          else if (compact)
            IconButton(
              key: const ValueKey('chrome-search-icon'),
              icon: Icon(DpIcons.search, size: 20, color: c.textSecondary),
              tooltip: '검색 (Ctrl/Cmd+K)',
              onPressed: onSearchTap,
            ),
          const Spacer(),
          ...actions,
          if (account != null) ...[
            const SizedBox(width: DpSpacing.sm),
            account!,
          ],
        ],
      ),
    );
  }

  Widget _crumbs(BuildContext context, DpColors c) {
    final text = Theme.of(context).textTheme;
    final items = compact && breadcrumb.isNotEmpty
        ? [breadcrumb.last]
        : breadcrumb;
    final children = <Widget>[];

    for (var i = 0; i < items.length; i++) {
      final crumb = items[i];
      final isLast = i == items.length - 1;
      final style = text.labelMedium?.copyWith(
        color: c.textSecondary,
        fontWeight: isLast ? FontWeight.w600 : FontWeight.w400,
      );
      final label = Text(
        crumb.label,
        style: style,
        overflow: TextOverflow.ellipsis,
      );

      children.add(
        crumb.path == null
            ? label
            : Semantics(
                button: true,
                label: crumb.label,
                child: InkWell(
                  onTap: () => onCrumbTap?.call(crumb.path!),
                  borderRadius: BorderRadius.circular(DpRadius.button),
                  child: Padding(
                    // 크롬바 높이(46px)를 지키려 세로 44px 탭 타깃은 강제하지
                    // 않는다. 대신 인라인 텍스트 링크로서 수평 패딩을 넉넉히
                    // 주고(DpSpacing.sm) Semantics(button: true)로 스크린리더
                    // 대상성을 보강한다.
                    padding: const EdgeInsets.symmetric(
                      horizontal: DpSpacing.sm,
                      vertical: DpSpacing.xs,
                    ),
                    child: label,
                  ),
                ),
              ),
      );

      if (!isLast) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DpSpacing.xs),
            // textFaint는 대비 3.21:1 — 텍스트가 아닌 구분자 글리프에만 쓴다.
            child: Text('·', style: style?.copyWith(color: c.textFaint)),
          ),
        );
      }
    }

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _search(BuildContext context, DpColors c) {
    final text = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('chrome-search'),
          onTap: onSearchTap,
          borderRadius: BorderRadius.circular(DpRadius.input),
          child: Container(
            height: 28,
            decoration: BoxDecoration(
              color: c.surfaceMuted,
              border: Border.all(color: c.border),
              borderRadius: BorderRadius.circular(DpRadius.input),
            ),
            padding: const EdgeInsets.symmetric(horizontal: DpSpacing.sm),
            child: Row(
              children: [
                Icon(DpIcons.search, size: 16, color: c.textSecondary),
                const SizedBox(width: DpSpacing.xs),
                Text(
                  '검색',
                  style: text.labelMedium?.copyWith(color: c.textSecondary),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border.all(color: c.border),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'Ctrl K',
                    style: text.labelSmall?.copyWith(color: c.textSecondary),
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
