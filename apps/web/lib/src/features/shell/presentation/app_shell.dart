import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../support/presentation/support_dialog.dart';

/// 셸 목적지(경로·아이콘·라벨).
typedef ShellDestination = ({String path, IconData icon, String label});

const List<ShellDestination> kShellDestinations = [
  (path: '/dashboard', icon: DpIcons.dashboard, label: '대시보드'),
  (path: '/path', icon: DpIcons.path, label: '경로'),
  (path: '/mentor', icon: DpIcons.mentor, label: '멘토'),
  (path: '/community', icon: DpIcons.community, label: '커뮤니티'),
  (path: '/settings', icon: DpIcons.settings, label: '설정'),
];

/// 라우터 결합 셸: 위치를 읽고, 명령 팔레트로 감싸 표현부에 위임.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    return DpCommandPalette(
      commands: [
        for (final d in kShellDestinations)
          (
            id: d.path,
            label: d.label,
            icon: d.icon,
            onInvoke: () => context.go(d.path),
          ),
      ],
      child: AppShellView(
        location: loc,
        onSelect: (path) => context.go(path),
        child: child,
      ),
    );
  }
}

/// 표현부: go_router 비의존 — DpAppShell(4-클래스 반응형)로 위임.
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

  @override
  Widget build(BuildContext context) {
    return DpAppShell(
      selectedIndex: _index,
      onSelect: (i) => onSelect?.call(kShellDestinations[i].path),
      destinations: [
        for (final d in kShellDestinations)
          (icon: d.icon, label: d.label, badgeCount: 0),
      ],
      // DpAppShell.trailing 은 단일 위젯이라 두 버튼을 Row 로 묶는다.
      // DpAppShell 자체는 손대지 않는다.
      trailing: Builder(
        builder: (context) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(DpIcons.error),
              tooltip: '오류 신고·문의',
              onPressed: () => showSupportDialog(context),
            ),
            IconButton(
              icon: const Icon(DpIcons.search),
              tooltip: '명령 팔레트 (Ctrl/Cmd+K)',
              onPressed: () =>
                  Actions.invoke(context, const OpenCommandPaletteIntent()),
            ),
          ],
        ),
      ),
      accountSlot: IconButton(
        icon: const Icon(Icons.account_circle),
        tooltip: '마이페이지',
        onPressed: () => onSelect?.call('/mypage'),
      ),
      body: child,
    );
  }
}
