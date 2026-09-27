import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';
import 'dp_window_class.dart';

/// 본문 최상단 페이지 헤더(로드맵 Layer 2).
///
/// 모바일에서는 제목과 행동을 한 열로, 넓은 화면에서는 한 행으로 배치한다.
class DpPageHeader extends StatelessWidget {
  const DpPageHeader({
    super.key,
    required this.title,
    this.description,
    this.actions = const [],
    this.filters = const [],
    this.gutter = false,
  });

  final String title;
  final String? description;
  final List<Widget> actions;

  /// 좌우 여백을 이 헤더가 **스스로** 줄지 여부.
  ///
  /// 기본값 false 는 시안 `.ph`(패딩 없음) 다 — `DpWebShell` 이 본문 전체에
  /// `.main` 의 거터(compact `lg` / 그 외 `xl`)를 주므로 헤더가 또 주면 두 겹이
  /// 되어 헤더만 본문보다 더 들여쓰인다.
  ///
  /// `apps/admin` 의 `DpAppShell` 은 본문에 좌우 패딩을 주지 않고 화면의 형제
  /// 위젯들이 각자 패딩을 갖는다(실측 2026-09-27). 그래서 admin 의 호출부는
  /// `gutter: true` 로 옛 거동을 유지한다 — 스펙 §10 「관리자 앱을 바꾸지
  /// 않는다」를 지키는 쪽이 셸에 패딩을 넣어 형제들을 이중으로 만드는 것보다 낫다.
  final bool gutter;

  /// 헤더 아래 필터 줄. 자식들은 Wrap의 형제로 배치되어 좁은 폭에서
  /// 줄바꿈한다 — Row를 통째로 받으면 줄바꿈이 일어나지 않는다.
  final List<Widget> filters;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;
    final compact = context.windowClass == DpWindowClass.compact;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        gutter ? (compact ? DpSpacing.lg : DpSpacing.xl) : 0,
        compact ? DpSpacing.xl : DpSpacing.xxl,
        gutter ? (compact ? DpSpacing.lg : DpSpacing.xl) : 0,
        DpSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final titleBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: text.headlineSmall?.copyWith(color: c.textPrimary),
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: DpSpacing.sm),
                    Text(
                      description!,
                      key: const ValueKey('page-header-description'),
                      style: text.bodyMedium?.copyWith(color: c.textSecondary),
                    ),
                  ],
                ],
              );
              final actionBlock = Wrap(
                spacing: DpSpacing.sm,
                runSpacing: DpSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: actions,
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    titleBlock,
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: DpSpacing.lg),
                      actionBlock,
                    ],
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: titleBlock),
                  if (actions.isNotEmpty) ...[
                    const SizedBox(width: DpSpacing.xl),
                    ConstrainedBox(
                      constraints: constraints.hasBoundedWidth
                          ? BoxConstraints(maxWidth: constraints.maxWidth / 2)
                          : const BoxConstraints(),
                      child: actionBlock,
                    ),
                  ],
                ],
              );
            },
          ),
          if (filters.isNotEmpty) ...[
            const SizedBox(height: DpSpacing.md),
            KeyedSubtree(
              key: const ValueKey('page-header-filters'),
              child: Wrap(
                spacing: DpSpacing.sm,
                runSpacing: DpSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: filters,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
