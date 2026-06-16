import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

typedef _Dest = ({String path, IconData icon, String label});

const List<_Dest> kAdminDestinations = [
  (path: '/dashboard', icon: DpIcons.dashboard, label: '대시보드'),
  (path: '/users', icon: DpIcons.community, label: '사용자'),
  (path: '/reports', icon: DpIcons.error, label: '신고'),
];

class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.child});
  final Widget child;

  int _indexOf(String loc) {
    final i = kAdminDestinations.indexWhere((d) => loc.startsWith(d.path));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    return Scaffold(
      body: Row(children: [
        NavigationRail(
          extended: true, // admin 영구 펼침 내비
          minExtendedWidth: 180,
          selectedIndex: _indexOf(loc),
          onDestinationSelected: (i) => context.go(kAdminDestinations[i].path),
          leading: const Padding(
            padding: EdgeInsets.all(DpSpacing.md),
            child: Text('운영 콘솔'),
          ),
          destinations: [
            for (final d in kAdminDestinations)
              NavigationRailDestination(icon: Icon(d.icon), label: Text(d.label)),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: child),
      ]),
    );
  }
}
