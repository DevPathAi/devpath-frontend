import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 셸 목적지(경로·아이콘·라벨).
typedef _Dest = ({String path, IconData icon, String label});

const List<_Dest> kShellDestinations = [
  (path: '/dashboard', icon: DpIcons.dashboard, label: '대시보드'),
  (path: '/path', icon: DpIcons.path, label: '경로'),
  (path: '/mentor', icon: DpIcons.mentor, label: '멘토'),
  (path: '/community', icon: DpIcons.community, label: '커뮤니티'),
];

/// 라우터 결합 셸: 현재 위치를 읽고 표현부에 위임.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    return AppShellView(
      location: loc,
      onSelect: (path) => context.go(path),
      child: child,
    );
  }
}

/// 표현부: go_router 비의존 — 폭에 따라 NavigationBar/Rail 전환(§9.3).
class AppShellView extends StatelessWidget {
  const AppShellView({
    super.key,
    required this.location,
    required this.child,
    this.onSelect,
  });

  final String location;
  final Widget child;
  final void Function(String path)? onSelect;

  int get _index {
    final i = kShellDestinations.indexWhere((d) => location.startsWith(d.path));
    return i < 0 ? 0 : i;
  }

  void _select(int i) => onSelect?.call(kShellDestinations[i].path);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in kShellDestinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: [
          for (final d in kShellDestinations)
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
    );
  }
}
