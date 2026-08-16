import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shell/presentation/admin_shell.dart';
import '../application/dashboard_controller.dart';
import '../state/dashboard_state.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});
  @override
  ConsumerState<AdminDashboardPage> createState() => _S();
}

class _S extends ConsumerState<AdminDashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(adminDashProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(adminDashProvider);
    if (s case AdminDashLoaded(:final stats)) {
      return AdminKpiDashboardProjection(stats: stats);
    }
    // 문서형 화면 — 헤더를 첫 sliver로 실어 본문과 함께 스크롤시킨다(DESIGN.md §9).
    // 본문은 자체 스크롤을 갖지 않는다(중첩 스크롤이면 헤더가 밀려나지 않는다).
    // users·ads·support는 DpDataTable이 자체 뷰포트를 가져 고정형으로 남는다.
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: DpPageHeader(
              // 제목은 kAdminDestinations가 유일한 출처다(admin_shell.dart).
              title: adminHeaderTitleFor('/dashboard'),
              description: '서비스 지표를 요약합니다',
            ),
          ),
          switch (s) {
            AdminDashLoading() => const SliverFillRemaining(
              hasScrollBody: false,
              child: DpLoading(),
            ),
            AdminDashFailed(:final message) => SliverFillRemaining(
              hasScrollBody: false,
              child: DpError(
                message: message,
                onRetry: () => ref.read(adminDashProvider.notifier).load(),
              ),
            ),
            AdminDashLoaded() => throw StateError('handled above'),
          },
        ],
      ),
    );
  }
}

/// Loaded production projection shared by the live dashboard and the ET13
/// browser-distribution renderer.
class AdminKpiDashboardProjection extends StatefulWidget {
  const AdminKpiDashboardProjection({super.key, required this.stats});

  final Map<String, int> stats;

  @override
  State<AdminKpiDashboardProjection> createState() =>
      _AdminKpiDashboardProjectionState();
}

class _AdminKpiDashboardProjectionState
    extends State<AdminKpiDashboardProjection> {
  static const double _keyboardScrollStep = 50;

  static const _kpis = <({String key, String label})>[
    (key: 'dau', label: 'DAU'),
    (key: 'newUsers', label: '신규 가입'),
    (key: 'openReports', label: '미처리 신고'),
    (key: 'aiCalls', label: 'AI 호출'),
  ];

  ScrollableState? _scrollableState;
  late final FocusNode _scrollFocusNode = FocusNode(
    debugLabel: 'Admin KPI dashboard scroll',
  );
  bool _hasVerticalOverflow = false;
  bool _focused = false;
  bool _metricsUpdateScheduled = false;

  @override
  void dispose() {
    _scrollFocusNode.dispose();
    _scrollableState = null;
    super.dispose();
  }

  KeyEventResult _handleScrollKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowUp => -1,
      LogicalKeyboardKey.arrowDown => 1,
      _ => 0,
    };
    final scrollable = _scrollableState;
    if (direction == 0 || scrollable == null || !scrollable.mounted) {
      return KeyEventResult.ignored;
    }
    final position = scrollable.position;
    if (!position.hasContentDimensions) return KeyEventResult.ignored;
    final next = (position.pixels + direction * _keyboardScrollStep)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    position.jumpTo(next);
    return KeyEventResult.handled;
  }

  bool _handleScrollMetrics(ScrollMetricsNotification notification) {
    if (notification.depth != 0) return false;
    final scrollable = Scrollable.maybeOf(
      notification.context,
      axis: Axis.vertical,
    );
    if (scrollable == null) return false;
    _scrollableState = scrollable;
    if (_metricsUpdateScheduled) return false;
    _metricsUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _metricsUpdateScheduled = false;
      final latestScrollable = _scrollableState;
      if (!mounted || latestScrollable == null || !latestScrollable.mounted) {
        return;
      }
      final position = latestScrollable.position;
      if (!position.hasContentDimensions) return;
      final hasOverflow = position.maxScrollExtent > position.minScrollExtent;
      if (hasOverflow == _hasVerticalOverflow) return;
      if (!hasOverflow) _scrollFocusNode.unfocus();
      setState(() {
        _hasVerticalOverflow = hasOverflow;
        if (!hasOverflow) _focused = false;
      });
    });
    return false;
  }

  Widget _buildHeader() {
    const label = '운영 대시보드. 위아래 화살표로 스크롤';
    final header = DpPageHeader(
      title: adminHeaderTitleFor('/dashboard'),
      description: '서비스 지표를 요약합니다',
    );
    if (!_hasVerticalOverflow) return header;
    return Focus(
      key: const ValueKey('admin-kpi-dashboard-scroll-focus'),
      focusNode: _scrollFocusNode,
      onFocusChange: (focused) {
        if (mounted && focused != _focused) {
          setState(() => _focused = focused);
        }
      },
      onKeyEvent: _handleScrollKey,
      child: Semantics(
        key: const ValueKey('admin-kpi-dashboard-scroll-focus-target'),
        label: label,
        child: header,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = [
      for (final kpi in _kpis)
        if (widget.stats[kpi.key] case final value?)
          (label: kpi.label, value: value),
    ];
    final columns = switch (context.windowClass) {
      DpWindowClass.compact => 1,
      DpWindowClass.medium => 2,
      DpWindowClass.expanded || DpWindowClass.large => 4,
    };
    final textScale = MediaQuery.textScalerOf(
      context,
    ).scale(1).clamp(1, 2).toDouble();
    final cardExtent = 144 + (128 * (textScale - 1));
    return Scaffold(
      body: DecoratedBox(
        key: const ValueKey('admin-kpi-dashboard-focus-ring'),
        position: DecorationPosition.foreground,
        decoration: _focused
            ? BoxDecoration(
                border: Border.all(
                  color: context.dpColors.primaryText,
                  width: 2,
                ),
              )
            : const BoxDecoration(),
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: _handleScrollMetrics,
          child: CustomScrollView(
            semanticChildCount: entries.length,
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              if (entries.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: DpEmpty(icon: DpIcons.empty, title: '표시할 운영 지표가 없어요'),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(DpSpacing.lg),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisExtent: cardExtent,
                      mainAxisSpacing: DpSpacing.md,
                      crossAxisSpacing: DpSpacing.md,
                    ),
                    delegate: SliverChildListDelegate([
                      for (final entry in entries)
                        DpKpiCard(
                          label: entry.label,
                          value: entry.value,
                          countUpDuration: Duration.zero,
                        ),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
