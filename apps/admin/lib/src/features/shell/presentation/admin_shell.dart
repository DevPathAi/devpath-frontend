import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

typedef AdminDestination = ({
  String path,
  IconData icon,
  String label,
  String headerTitle,
});

/// admin 목적지 = 경로·아이콘·레일 라벨·화면 제목의 **유일한** 출처.
///
/// `label`(레일)과 `headerTitle`(페이지 헤더·브레드크럼)은 일부러 다르다 —
/// 레일은 좁아서 짧은 말이 필요하고, 헤더는 무슨 화면인지 분명해야 한다.
/// 화면이 제목 리터럴을 따로 박으면 브레드크럼과 헤더가 조용히 어긋난다.
const List<AdminDestination> kAdminDestinations = [
  (
    path: '/dashboard',
    icon: DpIcons.dashboard,
    label: '대시보드',
    headerTitle: '운영 대시보드',
  ),
  (
    path: '/users',
    icon: DpIcons.community,
    label: '사용자',
    headerTitle: '사용자 관리',
  ),
  (path: '/reports', icon: DpIcons.error, label: '신고', headerTitle: '신고 처리'),
  // ③ 콘텐츠 신고와 ④ 서비스 오류·문의는 별개 기능이라 메뉴도 나눈다.
  (
    path: '/support',
    icon: DpIcons.mentor,
    label: '문의',
    headerTitle: '오류 신고·문의',
  ),
  (path: '/ads', icon: DpIcons.ads, label: '광고', headerTitle: '광고 관리'),
];

/// 경로 → 화면 제목. 매칭 실패 시 대시보드로 폴백한다(`_index`와 같은 규칙).
///
/// 각 화면은 `DpPageHeader(title: adminHeaderTitleFor('/reports'))`처럼 이 함수를
/// 통해 제목을 얻는다. 리터럴을 다시 박지 말 것 — 그 순간 단일 출처가 깨진다.
String adminHeaderTitleFor(String path) {
  final i = kAdminDestinations.indexWhere((d) => path.startsWith(d.path));
  return i < 0
      ? kAdminDestinations.first.headerTitle
      : kAdminDestinations[i].headerTitle;
}

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
      brand: DpRailBrand(
        mark: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: c.primary,
            borderRadius: BorderRadius.circular(DpRadius.button),
          ),
        ),
        wordmark: '운영 콘솔',
      ),
      breadcrumb: [
        (
          label: adminHeaderTitleFor(kAdminDestinations[_index].path),
          path: null,
        ),
      ],
      onSearchTap: () =>
          Actions.invoke(context, const OpenCommandPaletteIntent()),
      body: child,
    );
  }
}
