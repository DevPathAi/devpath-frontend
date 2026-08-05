import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

typedef AdminDestination = ({String path, IconData icon, String label});

const List<AdminDestination> kAdminDestinations = [
  (path: '/dashboard', icon: DpIcons.dashboard, label: '대시보드'),
  (path: '/users', icon: DpIcons.community, label: '사용자'),
  (path: '/reports', icon: DpIcons.error, label: '신고'),
  // ③ 콘텐츠 신고와 ④ 서비스 오류·문의는 별개 기능이라 메뉴도 나눈다.
  (path: '/support', icon: DpIcons.mentor, label: '문의'),
  (path: '/ads', icon: DpIcons.ads, label: '광고'),
];

/// 라우터 결합 셸: 위치를 읽고 명령 팔레트로 감싸 표현부에 위임.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    return DpCommandPalette(
      commands: [
        for (final d in kAdminDestinations)
          (
            id: d.path,
            label: d.label,
            icon: d.icon,
            onInvoke: () => context.go(d.path),
          ),
      ],
      child: AdminShellView(
        location: loc,
        onSelect: (path) => context.go(path),
        child: child,
      ),
    );
  }
}

/// 경로 → 화면 제목. 브레드크럼과 DpPageHeader가 같은 값을 쓴다.
String _headerTitleFor(String path) => switch (path) {
  '/users' => '사용자 관리',
  '/reports' => '신고 처리',
  '/support' => '오류 신고·문의',
  '/ads' => '광고 관리',
  _ => '운영 대시보드',
};

/// 표현부: go_router 비의존 — DpAppShell로 위임. admin은 웹 우선이라
/// Large에서 기존 extended rail을 유지한다.
class AdminShellView extends StatelessWidget {
  const AdminShellView({
    super.key,
    required this.location,
    required this.child,
    this.onSelect,
  });

  final String location;
  final Widget child;
  final void Function(String path)? onSelect;

  int get _index {
    final i = kAdminDestinations.indexWhere((d) => location.startsWith(d.path));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    return DpAppShell(
      selectedIndex: _index,
      onSelect: (i) => onSelect?.call(kAdminDestinations[i].path),
      destinations: [
        for (final d in kAdminDestinations)
          DpDestination(icon: d.icon, label: d.label),
      ],
      // web 셸(app_shell.dart)의 titleSmall 타이포를 맞추되, color를 반드시
      // 명시한다 — DpTheme가 textTheme.apply(bodyColor: c.textPrimary)로
      // titleSmall에 이미 non-null color를 채워 넣어(dp_theme.dart:32-34),
      // DpNavRail._withRailForeground(dp_nav_rail.dart:91)가 공급하는
      // railText가 DefaultTextStyle.merge에서 진다. 라이트 테마에서
      // textPrimary(#1A1815)==railBg(#1A1815)라 color 미명시 시 브랜드
      // 텍스트가 레일 배경에 완전히 묻힌다(web app_shell.dart와 같은 이유,
      // 같은 수정).
      brand: Text(
        '운영 콘솔',
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(color: c.railText),
      ),
      breadcrumb: [
        (label: _headerTitleFor(kAdminDestinations[_index].path), path: null),
      ],
      onSearchTap: () =>
          Actions.invoke(context, const OpenCommandPaletteIntent()),
      body: child,
    );
  }
}
