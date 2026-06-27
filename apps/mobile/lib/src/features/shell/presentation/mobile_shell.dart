import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../notifications/application/notification_controller.dart';

/// 하단탭 목적지(라벨·아이콘). 브랜치 순서와 1:1 정합.
typedef MobileTab = ({IconData icon, String label});

const List<MobileTab> kMobileTabs = [
  (icon: DpIcons.home, label: '홈'),
  (icon: DpIcons.content, label: '학습'),
  (icon: DpIcons.community, label: '커뮤니티'),
  (icon: DpIcons.notifications, label: '알림'),
];

/// 알림 탭 인덱스 — 미읽음 배지 대상(브랜치 순서와 1:1).
const int kNotificationsTabIndex = 3;

/// StatefulShellRoute 결합 셸 — 하단 NavigationBar로 브랜치 전환(상태 보존).
/// 알림 탭에는 미읽음 푸시 개수를 배지로 표시한다.
class MobileShell extends ConsumerWidget {
  const MobileShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) => navigationShell.goBranch(
    index,
    // 이미 선택된 탭 재탭 시 해당 브랜치 초기 위치로 복귀(go_router 권장 패턴).
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(
      notificationControllerProvider.select((s) => s.unreadCount),
    );
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        destinations: [
          for (var i = 0; i < kMobileTabs.length; i++)
            NavigationDestination(
              icon: _tabIcon(kMobileTabs[i], i, unread),
              label: kMobileTabs[i].label,
            ),
        ],
      ),
    );
  }

  /// 알림 탭만 미읽음 배지로 감싼다(미읽음 0이면 라벨 숨김).
  Widget _tabIcon(MobileTab tab, int index, int unread) {
    final icon = Icon(tab.icon);
    if (index != kNotificationsTabIndex) return icon;
    return Badge.count(count: unread, isLabelVisible: unread > 0, child: icon);
  }
}
