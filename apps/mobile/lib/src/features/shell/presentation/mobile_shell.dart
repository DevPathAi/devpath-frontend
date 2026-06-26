import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 하단탭 목적지(라벨·아이콘). 브랜치 순서와 1:1 정합.
typedef MobileTab = ({IconData icon, String label});

const List<MobileTab> kMobileTabs = [
  (icon: DpIcons.home, label: '홈'),
  (icon: DpIcons.content, label: '학습'),
  (icon: DpIcons.community, label: '커뮤니티'),
];

/// StatefulShellRoute 결합 셸 — 하단 NavigationBar로 브랜치 전환(상태 보존).
class MobileShell extends StatelessWidget {
  const MobileShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) => navigationShell.goBranch(
    index,
    // 이미 선택된 탭 재탭 시 해당 브랜치 초기 위치로 복귀(go_router 권장 패턴).
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        destinations: [
          for (final t in kMobileTabs)
            NavigationDestination(icon: Icon(t.icon), label: t.label),
        ],
      ),
    );
  }
}
