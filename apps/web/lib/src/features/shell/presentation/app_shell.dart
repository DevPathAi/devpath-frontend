import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../common/application/external_link_opener.dart';
import '../../support/presentation/support_dialog.dart';
import '../../updates/presentation/notice_banner_bar.dart';
import '../../settings/application/settings_controller.dart';

/// 상단 헤더의 주 메뉴(스펙 §5.3·시안). 커뮤니티는 드롭다운이고 세 게시판이
/// 그 자식이다 — 게시판 이동 수단은 이 메뉴뿐이다(사용자 결정 2026-09-19 §5.4-3).
const List<DpWebNavItem> kWebNavItems = [
  DpWebNavItem(id: '/dashboard', label: '오늘'),
  DpWebNavItem(id: '/path', label: '학습 경로'),
  DpWebNavItem(id: '/mentor', label: 'AI 멘토'),
  DpWebNavItem(
    id: '/community',
    label: '커뮤니티',
    children: [
      DpWebNavItem(id: '/community?board=FREE', label: '자유게시판'),
      DpWebNavItem(id: '/community?board=QNA', label: 'Q/A'),
      DpWebNavItem(id: '/community?board=FEEDBACK', label: '피드백'),
    ],
  ),
];

/// `shellDestinationIndexFor` 의 index 순서와 1:1 로 맞춘 평면 id 목록.
/// 순서를 바꾸면 두 곳을 함께 바꿔야 한다.
const List<String> _flatNavIds = [
  '/dashboard',
  '/path',
  '/mentor',
  '/community?board=FREE',
  '/community?board=QNA',
  '/community?board=FEEDBACK',
];

String _commandLabelFor(String id) => switch (id) {
  '/dashboard' => '오늘',
  '/path' => '학습 경로',
  '/mentor' => 'AI 멘토',
  '/community?board=FREE' => '자유게시판',
  '/community?board=QNA' => 'Q/A',
  _ => '피드백',
};

IconData _commandIconFor(String id) => switch (id) {
  '/dashboard' => DpIcons.dashboard,
  '/path' => DpIcons.path,
  '/mentor' || '/community?board=QNA' => DpIcons.mentor,
  '/community?board=FREE' => DpIcons.community,
  _ => DpIcons.thumbUp,
};

const _crumbCommunity = (label: '커뮤니티', path: null);

String _communityBoardLabel(Uri uri) => switch (uri.queryParameters['board']) {
  'QNA' => 'Q/A',
  'FEEDBACK' => '피드백',
  _ => '자유게시판',
};

/// 경로 → 브레드크럼. **긴 경로를 먼저 검사한다**(`/community/new/post`가
/// `/community/new`보다 앞). 알 수 없는 경로는 빈 목록을 반환한다 — 그러면
/// `DpBreadcrumb` 이 자리를 차지하지 않는다.
List<DpCrumb> breadcrumbFor(String location) {
  final uri = Uri.parse(location);
  final path = uri.path;
  const learning = (label: '학습', path: null);
  const account = (label: '계정', path: null);

  if (path.startsWith('/mission/')) {
    final label = path.contains('/mentor')
        ? 'AI 멘토'
        : path.contains('/sandbox')
        ? '실습 샌드박스'
        : '학습 콘텐츠';
    return [
      learning,
      const (label: '오늘', path: '/dashboard'),
      (label: label, path: null),
    ];
  }
  if (path.startsWith('/path/') && path.endsWith('/today')) {
    return const [learning, (label: '오늘', path: null)];
  }
  if (path.startsWith('/community/new/post')) {
    return [
      _crumbCommunity,
      (
        label: _communityBoardLabel(uri),
        path: '/community?board=${uri.queryParameters['board'] ?? 'FREE'}',
      ),
      const (label: '새 글', path: null),
    ];
  }
  if (path.startsWith('/community/new')) {
    return const [
      _crumbCommunity,
      (label: 'Q/A', path: '/community?board=QNA'),
      (label: '질문하기', path: null),
    ];
  }
  if (path.startsWith('/community/post/')) {
    final board = uri.queryParameters['board'] == 'FEEDBACK'
        ? 'FEEDBACK'
        : 'FREE';
    return [
      _crumbCommunity,
      (
        label: board == 'FEEDBACK' ? '피드백' : '자유게시판',
        path: '/community?board=$board',
      ),
      const (label: '게시글', path: null),
    ];
  }
  if (path == '/community') {
    return [_crumbCommunity, (label: _communityBoardLabel(uri), path: null)];
  }
  if (path.startsWith('/community/')) {
    return const [
      _crumbCommunity,
      (label: 'Q/A', path: '/community?board=QNA'),
      (label: '게시글', path: null),
    ];
  }
  if (path.startsWith('/dashboard')) {
    return const [learning, (label: '오늘', path: null)];
  }
  if (path.startsWith('/path')) {
    return const [learning, (label: '학습 경로', path: null)];
  }
  if (path.startsWith('/mentor')) {
    return const [learning, (label: 'AI 멘토', path: null)];
  }
  if (path.startsWith('/content/')) {
    return const [learning, (label: '학습 콘텐츠', path: null)];
  }
  if (path.startsWith('/sandbox')) {
    return const [learning, (label: '실습 샌드박스', path: null)];
  }
  if (path.startsWith('/settings')) {
    return const [account, (label: '설정', path: null)];
  }
  if (path.startsWith('/mypage')) {
    return const [account, (label: '마이페이지', path: null)];
  }
  return const [];
}

/// Mission workspace child routes belong to Today. Legacy secondary routes stay
/// neutral so a content deep link never pretends that the first tab is active.
int? shellDestinationIndexFor(String location) {
  final uri = Uri.parse(location);
  final path = uri.path;
  if (path == '/dashboard' ||
      path.startsWith('/dashboard/') ||
      (path.startsWith('/path/') && path.endsWith('/today')) ||
      path.startsWith('/mission/')) {
    return 0;
  }
  if (path == '/path') return 1;
  if (path == '/mentor') return 2;
  if (path.startsWith('/community')) {
    if (path == '/community/new' ||
        (path.startsWith('/community/') &&
            !path.startsWith('/community/post/') &&
            !path.startsWith('/community/new/post'))) {
      return 4;
    }
    return switch (uri.queryParameters['board']) {
      'QNA' => 4,
      'FEEDBACK' => 5,
      _ => 3,
    };
  }

  final index = _flatNavIds.indexWhere(
    (id) =>
        id != '/dashboard' &&
        id != '/path' &&
        path.startsWith(Uri.parse(id).path),
  );
  return index < 0 ? null : index;
}

/// 위치 → 헤더에서 현재 표시할 id. 매칭되는 목적지가 없으면 null(무강조) —
/// /settings·/mypage·/content/:id·/sandbox 에서 엉뚱한 항목에 밑줄이 가지 않게 한다.
String? webNavSelectedIdFor(String location) {
  final index = shellDestinationIndexFor(location);
  return index == null ? null : _flatNavIds[index];
}

/// 라우터 결합 셸: 위치를 읽고, 명령 팔레트로 감싸 표현부에 위임.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter.of(context);
    return ListenableBuilder(
      // Imperative `push` routes are wrapped in an internal match and are not
      // reflected by RouteMatchList.uri on every go_router version. The route
      // information provider is the browser-visible source of truth for both
      // declarative `go` and imperative `push` navigation.
      listenable: router.routeInformationProvider,
      builder: (context, _) {
        final location = router.routeInformationProvider.value.uri.toString();
        return DpCommandPalette(
          commands: [
            for (final id in _flatNavIds)
              (
                id: id,
                label: _commandLabelFor(id),
                icon: _commandIconFor(id),
                onInvoke: () => context.go(id),
              ),
          ],
          child: AppShellView(
            location: location,
            onSelect: (path) => context.go(path),
            onLogout: () =>
                ref.read(settingsControllerProvider.notifier).logout(),
            onOpenExternal: (url) =>
                ref.read(externalLinkOpenerProvider).open(url),
            onOpenSupport: () => showSupportDialog(context),
            child: Column(
              children: [
                const NoticeBannerBar(),
                Expanded(child: child),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 표현부: go_router 비의존 — DpWebShell(상단 헤더 문법)로 위임.
class AppShellView extends StatelessWidget {
  const AppShellView({
    super.key,
    required this.location,
    required this.child,
    this.onSelect,
    this.onLogout,
    this.onOpenExternal,
    this.onOpenSupport,
  });

  final String location;
  final Widget child;
  final void Function(String path)? onSelect;
  final Future<void> Function()? onLogout;
  final void Function(String url)? onOpenExternal;
  final VoidCallback? onOpenSupport;

  /// 법적 문서와 업데이트 소식은 홈(leva.ai.kr)에 있다 — 앱에 라우트가 없다.
  static const _homeBaseUrl = 'https://leva.ai.kr';

  @override
  Widget build(BuildContext context) {
    return DpWebShell(
      brand: DpRailBrand(mark: const DpBrandMark(size: 24), wordmark: 'Leva'),
      items: kWebNavItems,
      selectedId: webNavSelectedIdFor(location),
      onSelect: (id) => onSelect?.call(id),
      accountEntries: [
        (label: '마이페이지', onSelect: () => onSelect?.call('/mypage')),
        (label: '설정', onSelect: () => onSelect?.call('/settings')),
        (
          label: '로그아웃',
          onSelect: onLogout == null ? null : () async => onLogout!.call(),
        ),
      ],
      footerNotice: '© 레바 · 사업자등록번호 796-76-00732',
      footerLinks: [
        (
          label: '이용약관',
          onTap: () => onOpenExternal?.call('$_homeBaseUrl/terms'),
        ),
        (
          label: '개인정보 처리방침',
          onTap: () => onOpenExternal?.call('$_homeBaseUrl/privacy'),
        ),
        (label: '오류 신고·문의', onTap: () => onOpenSupport?.call()),
        (
          label: '업데이트 소식',
          onTap: () => onOpenExternal?.call('$_homeBaseUrl/updates'),
        ),
      ],
      breadcrumb: breadcrumbFor(location),
      onCrumbTap: (p) => onSelect?.call(p),
      onSearchTap: () =>
          Actions.invoke(context, const OpenCommandPaletteIntent()),
      body: child,
    );
  }
}
