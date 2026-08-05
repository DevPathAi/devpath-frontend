import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../support/presentation/support_dialog.dart';

/// 셸 목적지(경로·아이콘·라벨·섹션).
typedef ShellDestination = ({
  String path,
  IconData icon,
  String label,
  String section,
});

/// 설정은 레일이 아니라 계정 블록으로 내려갔다(디자인 2단계).
const List<ShellDestination> kShellDestinations = [
  (path: '/dashboard', icon: DpIcons.dashboard, label: '대시보드', section: '학습'),
  (path: '/path', icon: DpIcons.path, label: '학습 경로', section: '학습'),
  (path: '/mentor', icon: DpIcons.mentor, label: 'AI 멘토', section: '학습'),
  (path: '/community', icon: DpIcons.community, label: '게시판', section: '커뮤니티'),
];

const _crumbCommunity = (label: '커뮤니티', path: null);
const _crumbBoard = (label: '게시판', path: '/community');

/// 경로 → 브레드크럼. **긴 경로를 먼저 검사한다**(`/community/new/post`가
/// `/community/new`보다 앞). 알 수 없는 경로는 빈 목록이라 크롬바가 렌더되지 않는다.
List<DpCrumb> breadcrumbFor(String location) {
  const learning = (label: '학습', path: null);
  const account = (label: '계정', path: null);

  if (location.startsWith('/community/new/post')) {
    return const [_crumbCommunity, _crumbBoard, (label: '새 글', path: null)];
  }
  if (location.startsWith('/community/new')) {
    return const [_crumbCommunity, _crumbBoard, (label: '질문하기', path: null)];
  }
  if (location.startsWith('/community/post/')) {
    return const [_crumbCommunity, _crumbBoard, (label: '게시글', path: null)];
  }
  if (location == '/community') {
    return const [_crumbCommunity, _crumbBoard];
  }
  if (location.startsWith('/community/')) {
    return const [_crumbCommunity, _crumbBoard, (label: 'Q&A', path: null)];
  }
  if (location.startsWith('/dashboard')) {
    return const [learning, (label: '대시보드', path: null)];
  }
  if (location.startsWith('/path')) {
    return const [learning, (label: '학습 경로', path: null)];
  }
  if (location.startsWith('/mentor')) {
    return const [learning, (label: 'AI 멘토', path: null)];
  }
  if (location.startsWith('/content/')) {
    return const [learning, (label: '학습 콘텐츠', path: null)];
  }
  if (location.startsWith('/sandbox')) {
    return const [learning, (label: '실습 샌드박스', path: null)];
  }
  if (location.startsWith('/settings')) {
    return const [account, (label: '설정', path: null)];
  }
  if (location.startsWith('/mypage')) {
    return const [account, (label: '마이페이지', path: null)];
  }
  return const [];
}

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

  // I1: 매칭되는 목적지가 없으면 null(무강조)을 반환한다. kShellDestinations가
  // 5→4로 줄면서 /settings·/mypage·/content/:id·/sandbox가 여기 없다 —
  // 예전처럼 0(대시보드)으로 폴백하면 레일이 잘못된 항목을 활성 표시한다.
  int? get _index {
    final i = kShellDestinations.indexWhere((d) => location.startsWith(d.path));
    return i < 0 ? null : i;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;

    return DpAppShell(
      selectedIndex: _index,
      onSelect: (i) => onSelect?.call(kShellDestinations[i].path),
      destinations: [
        for (final d in kShellDestinations)
          DpDestination(icon: d.icon, label: d.label, section: d.section),
      ],
      brand: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: c.primary,
              borderRadius: BorderRadius.circular(DpRadius.button),
            ),
          ),
          const SizedBox(width: DpSpacing.sm),
          // color를 지정하지 않는다 — DpNavRail._withRailForeground
          // (dp_nav_rail.dart:91)가 이미 레일 배경에 맞는 전경색(railText)을
          // 공급한다. 여기서 다시 지정하면 그 공급을 무력화한다(admin의
          // admin_shell.dart:80-83과 같은 형태로 맞춘다).
          Flexible(
            child: Text(
              'DevPath',
              overflow: TextOverflow.ellipsis,
              style: text.titleSmall,
            ),
          ),
        ],
      ),
      account: _AccountMenu(onGo: onSelect),
      breadcrumb: breadcrumbFor(location),
      onCrumbTap: (p) => onSelect?.call(p),
      onSearchTap: () => _openPalette(context),
      chromeActions: [
        Builder(
          builder: (context) => IconButton(
            icon: const Icon(DpIcons.error),
            tooltip: '오류 신고·문의',
            onPressed: () => showSupportDialog(context),
          ),
        ),
      ],
      body: child,
    );
  }

  static void _openPalette(BuildContext context) =>
      Actions.invoke(context, const OpenCommandPaletteIntent());
}

/// 레일 하단(또는 compact 크롬바 우측) 계정 블록. admin의 행 메뉴와 같은
/// MenuAnchor 패턴을 쓴다 — 새 상호작용을 도입하지 않는다.
class _AccountMenu extends StatelessWidget {
  const _AccountMenu({this.onGo});
  final void Function(String path)? onGo;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          onPressed: () => onGo?.call('/mypage'),
          child: const Text('마이페이지'),
        ),
        MenuItemButton(
          onPressed: () => onGo?.call('/settings'),
          child: const Text('설정'),
        ),
      ],
      // color를 명시하지 않는다 — 슬롯(DpNavRail은 railMuted, compact
      // DpChromeBar는 textSecondary)이 공급하는 IconTheme을 상속해야
      // 양쪽 배경 모두에서 대비가 유지된다(하드코딩 시 한쪽에서 WCAG 미달).
      builder: (context, controller, _) => IconButton(
        icon: const Icon(DpIcons.account),
        tooltip: '계정',
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
