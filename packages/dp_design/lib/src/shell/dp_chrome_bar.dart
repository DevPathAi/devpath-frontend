import 'package:flutter/material.dart';

import '../icons/dp_icons.dart';
import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';
import 'dp_chrome_action.dart';

/// 브레드크럼 세그먼트. [path]가 null이면 비클릭(섹션명 등).
///
/// 필드가 둘뿐이고 옵셔널 확장 계획이 없어 record를 유지한다
/// (DpDestination을 class로 바꾼 것과 다른 판단 — 그쪽은 section이 필요했다).
typedef DpCrumb = ({String label, String? path});

/// 얇은 상단 크롬바(로드맵 Layer 2). 라우팅 비의존.
///
/// 검색 필드는 TextField가 아니라 [onSearchTap]을 호출하는 버튼이다 —
/// 실제 입력은 기존 DpCommandPalette가 받는다. 입력 상태를 두 곳에서
/// 관리하지 않기 위한 선택이다.
class DpChromeBar extends StatelessWidget {
  const DpChromeBar({
    super.key,
    required this.breadcrumb,
    this.onCrumbTap,
    this.onSearchTap,
    this.actions = const [],
    this.account,
    this.compact = false,
  });

  static const double height = 46;

  final List<DpCrumb> breadcrumb;
  final ValueChanged<String>? onCrumbTap;
  final VoidCallback? onSearchTap;
  final List<DpChromeAction> actions;
  final Widget? account;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;

    return Container(
      key: const ValueKey('chrome-bar-root'),
      height: height,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: DpSpacing.lg),
      // I2(3단계 해소): actions·account 그룹은 non-flex 자식이라 RenderFlex가
      // 무한 주축 제약으로 먼저 측정한다 — actions가 늘어나면(스펙 §3.0
      // trailing 슬롯) 오버플로할 수 있었다. DpPageHeader.actions의
      // LayoutBuilder+ConstrainedBox(maxWidth: 폭/2) 해법을 이식했던 적이
      // 있었으나 되돌렸다 — DpPageHeader에서 그 패턴이 통하는 이유는 자식이
      // Wrap이라 상한을 줄바꿈으로 흡수하기 때문이다(dp_page_header.dart:
      // 72-86). 이 바의 자식은 Row(mainAxisSize.min)이고 높이가 46 고정이라
      // 줄바꿈이 불가능해, 상한을 걸어도 오버플로가 바깥 Row에서 안쪽 Row로
      // 이동할 뿐이었다(임계 W<G+16 → W<2G로 오히려 넓어짐, G=그룹 자연폭).
      //
      // 지금은 줄바꿈이 아니라 넘치는 액션을 오버플로 메뉴(MenuAnchor)로
      // 접는다. account는 접지 않는다(계정 진입점이 메뉴 뒤로 숨으면
      // 접근성이 나빠진다). 캡을 얻는 방법이 관건이다 — _actionGroup을
      // 그 자리(Row의 non-flex 두 번째 자식)에서 LayoutBuilder로 직접
      // 감싸는 최초 시도는 실측에서 실패했다: RenderFlex가 non-flex
      // 자식에게 주는 제약은 `BoxConstraints(maxHeight: ...)`뿐이라
      // maxWidth가 항상 무한이다(hasBoundedWidth=false) — 즉 non-flex
      // 위치에 놓인 LayoutBuilder는 자기 폭 상한을 절대 알 수 없다. 그
      // 결과 접힘이 전혀 발동하지 않고 8액션이 그대로 자연폭을 요구해
      // Expanded 좌측 그룹이 12px까지 짜부라지며 내부 crumbs Row가
      // RenderFlex overflow로 죽었다(폭 500 테스트로 실측 확인).
      //
      // 해법: 바 컨테이너(패딩 적용 후) 전체를 감싸는 바깥 LayoutBuilder로
      // 실제 사용 가능 폭을 먼저 얻고, 그 절반을 캡으로 _actionGroup에
      // 명시적으로 넘긴다. 이러면 우측 그룹은 캡 안에서 inline 액션 수를
      // 결정하고(account·구분 간격까지 전부 예산에 포함 — _actionGroup의
      // accountReserve 참고), 좌측 Expanded는 최소 절반을 보장받는다.
      // "항상 절반만 요구"는 정확한 서술이 아니다 — account가 있고 캡이
      // 매우 좁을 때(대략 overflowButton+accountReserve=104px 미만)는
      // 더보기 버튼과 account만으로도 캡을 넘는 이론적 하한이 있다(코드
      // 리뷰 실측으로 확인). 이 하한은 이 컴포넌트가 도달 가능한 실제
      // 폭 범위 밖이라 별도로 방어하지 않았다.
      //
      // ★현재 조건 미도달★ — 이 축약은 web 오류 신고 액션 1개·admin
      // 액션 0개인 지금 상태에서는 어떤 폭에서도 발동하지 않는다(둘 다
      // perAction 1개분(48px)이 절반-캡을 넘기지 못한다). 이 작업은 스펙
      // §3.0이 trailing 슬롯의 행선지로 지정한 자리가 액션 수가 늘어나도
      // 안전하도록 미리 만들어 둔 것이지, 실제 화면에서 관찰된 결함을
      // 고친 것이 아니다 — 8액션 시나리오는 테스트에서만 구성된다.
      child: LayoutBuilder(
        builder: (context, barConstraints) {
          final barWidth = barConstraints.maxWidth;
          final actionCap = barWidth.isFinite ? barWidth / 2 : double.infinity;

          return Row(
            children: [
              // 좌측 그룹(crumbs+검색)을 Expanded로 묶어 남는 폭을 전부
              // 흡수시킨다. 예전에는 이 자리에 Flexible들을 늘어놓고 뒤에
              // Spacer를 뒀는데, Spacer(Expanded=tight)는 freeSpace를 flex
              // 비율로 나눈 자기 몫만 받는 반면 Flexible(loose fit)은
              // 몫보다 적게 쓸 수 있다 — 그 잔여가 Spacer로 재분배되지
              // 않고 Row 끝(=actions 오른쪽)에 남아 우측 정렬이 깨졌다.
              // 실제 앱 crumbs는 '학습 · 대시보드' 수준으로 짧아 항상 이
              // 경로를 탔고, 2단계 육안 확인에서 1400폭 약 448px 여백으로
              // 드러났다.
              Expanded(
                child: Row(
                  children: [
                    Flexible(child: _crumbs(context, c)),
                    const SizedBox(width: DpSpacing.lg),
                    if (!compact && onSearchTap != null)
                      Flexible(flex: 2, child: _search(context, c))
                    else if (compact && onSearchTap != null)
                      IconButton(
                        key: const ValueKey('chrome-search-icon'),
                        icon: Icon(
                          DpIcons.search,
                          size: 20,
                          color: c.textSecondary,
                        ),
                        tooltip: '검색 (Ctrl/Cmd+K)',
                        onPressed: onSearchTap,
                      ),
                  ],
                ),
              ),
              // 밝은 surface 배경 위이므로 무스타일 액션/계정 위젯도
              // textSecondary를 기본 전경색으로 받는다 — 하위 위젯이 색을
              // 명시하면 그게 이긴다(merge).
              IconTheme.merge(
                data: IconThemeData(color: c.textSecondary),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: c.textSecondary),
                  child: _actionGroup(context, c, actionCap),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 액션 그룹. [maxWidth](바 폭의 절반, build()가 바깥 LayoutBuilder로
  /// 계산해 넘긴다)를 넘는 액션은 오버플로 메뉴로 접는다.
  Widget _actionGroup(BuildContext context, DpColors c, double maxWidth) {
    if (actions.isEmpty) {
      return Row(mainAxisSize: MainAxisSize.min, children: [?account]);
    }

    const perAction = 48.0;
    const overflowButton = 48.0;
    // account가 있으면 실제 렌더(아래 Row)에서 액션그룹과 account 사이에
    // SizedBox(width: DpSpacing.sm) 8px이 항상 붙는다(account는 절대 접지
    // 않으므로 이 간격은 오버플로 여부와 무관하게 항상 소비된다). 이 8px을
    // 예산에서 빠뜨리면 경계 폭에서 "오버플로 없음"으로 오판하고 실제
    // 콘텐츠가 상한을 넘긴다(코드 리뷰 실측 재현: 폭 328·액션 2개·account
    // 있는 조건에서 4px 오버플로 확인 — dp_chrome_bar_account_gap_test.dart).
    final accountReserve = account != null ? 48.0 + DpSpacing.sm : 0.0;

    final budget = maxWidth.isFinite
        ? maxWidth - accountReserve
        : double.infinity;
    final fits = budget.isFinite
        ? (budget / perAction).floor()
        : actions.length;

    final inline = fits >= actions.length
        ? actions
        : actions
              .take(
                ((budget - overflowButton) / perAction).floor().clamp(
                  0,
                  actions.length,
                ),
              )
              .toList();
    final overflow = actions.sublist(inline.length);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final a in inline)
            IconButton(
              // 색을 명시해 상태(disabled 등)·주변 테마와 무관하게 고정한다.
              // ※ M3 IconButton은 ambient IconTheme.color를 themeStyleOf에서
              //   foregroundColor로 흡수하므로(icon_button.dart:1029-1044,
              //   Flutter 3.44.1) 명시가 없어도 상속은 된다 — 실측 확인함.
              //   여기서는 크롬바 밖 테마 변화에 흔들리지 않도록 못박는 쪽을 택한다.
              icon: Icon(a.icon, color: c.textSecondary),
              tooltip: a.label,
              // 바깥 LayoutBuilder 콜백의 context를 넘긴다 — 크롬바 아래라
              // Navigator/Overlay에 접근할 수 있다.
              onPressed: () => a.onPressed(context),
            ),
          if (overflow.isNotEmpty)
            MenuAnchor(
              key: const ValueKey('chrome-actions-overflow'),
              menuChildren: [
                for (final a in overflow)
                  MenuItemButton(
                    leadingIcon: Icon(a.icon),
                    onPressed: () => a.onPressed(context),
                    child: Text(a.label),
                  ),
              ],
              builder: (context, controller, _) => IconButton(
                icon: const Icon(DpIcons.moreVert),
                tooltip: '더 보기',
                onPressed: () =>
                    controller.isOpen ? controller.close() : controller.open(),
              ),
            ),
          if (account != null) ...[
            const SizedBox(width: DpSpacing.sm),
            account!,
          ],
        ],
      ),
    );
  }

  Widget _crumbs(BuildContext context, DpColors c) {
    final text = Theme.of(context).textTheme;
    final items = compact && breadcrumb.isNotEmpty
        ? [breadcrumb.last]
        : breadcrumb;
    final children = <Widget>[];

    for (var i = 0; i < items.length; i++) {
      final crumb = items[i];
      final isLast = i == items.length - 1;
      final style = text.labelMedium?.copyWith(
        color: c.textSecondary,
        fontWeight: isLast ? FontWeight.w600 : FontWeight.w400,
      );
      final label = Text(
        crumb.label,
        style: style,
        overflow: TextOverflow.ellipsis,
      );

      // 마지막 세그먼트는 현재 위치이므로 path가 있어도 링크하지 않는다
      // (브레드크럼 관례 — 자기 자신으로 가는 링크를 두지 않는다).
      // 앱은 crumb 데이터를 그대로 두면 된다: /community에서 마지막이
      // '게시판'(path: '/community')이지만 여기서 비링크로 렌더된다.
      final crumbWidget = (crumb.path == null || isLast)
          ? label
          : Semantics(
              button: true,
              label: crumb.label,
              child: InkWell(
                onTap: () => onCrumbTap?.call(crumb.path!),
                borderRadius: BorderRadius.circular(DpRadius.button),
                // 46px 바 안에 44px 탭 타깃이 들어간다(바깥 Row가 세로
                // center 정렬이라 여유가 있다) — DESIGN.md §6.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    // 탭 타깃 확보용 수평 여백. 첫 세그먼트에만 왼쪽을 빼서
                    // 크롬바 좌측 정렬이 8px 밀리지 않게 한다. 이 여백은
                    // 아래 구분자 패딩이 링크 쪽을 0으로 두어 상쇄한다.
                    padding: EdgeInsets.only(
                      left: i == 0 ? 0 : DpSpacing.sm,
                      right: DpSpacing.sm,
                    ),
                    // widthFactor: 1 — 세로만 중앙 정렬한다. 기본 Center는
                    // 부모가 주는 최대 폭까지 확장하는데, 이 세그먼트는
                    // Flexible(loose)이라 flex 몫만큼 폭을 받는다. 그러면
                    // 라벨이 그 넓은 폭의 한가운데로 밀려 구분자와의 간격이
                    // 벌어진다('커뮤니티 · 게시판'에서 약 100px).
                    child: Center(widthFactor: 1, child: label),
                  ),
                ),
              ),
            );

      // Flexible로 감싸 이 세그먼트가 자기 폭 제약을 받게 한다 — 감싸지
      // 않으면 RenderFlex가 non-flex 자식을 무한 폭으로 측정해 ellipsis가
      // 발동하지 않고 오버플로가 난다. 구분자(·)는 항상 온전히 보여야
      // 하므로 감싸지 않는다.
      children.add(Flexible(child: crumbWidget));

      if (!isLast) {
        // 구분자는 좌우 텍스트로부터 같은 거리(sm)에 있어야 한다. 링크
        // 세그먼트는 이미 자체 패딩 sm을 갖고 있으므로 그쪽 변은 0으로 둬
        // 상쇄한다 — 안 그러면 링크가 붙은 쪽만 두 배로 벌어진다(2단계 육안
        // 확인에서 '커뮤니티 · 게시판'의 비대칭으로 드러났다).
        children.add(
          Padding(
            padding: EdgeInsets.only(
              left: crumb.path == null ? DpSpacing.sm : 0,
              // 다음 세그먼트가 마지막이면 비링크이므로 자체 패딩이 없다.
              right: (items[i + 1].path == null || i + 1 == items.length - 1)
                  ? DpSpacing.sm
                  : 0,
            ),
            // textFaint는 대비 3.21:1 — 텍스트가 아닌 구분자 글리프에만 쓴다.
            child: Text('·', style: style?.copyWith(color: c.textFaint)),
          ),
        );
      }
    }

    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _search(BuildContext context, DpColors c) {
    final text = Theme.of(context).textTheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('chrome-search'),
          onTap: onSearchTap,
          borderRadius: BorderRadius.circular(DpRadius.input),
          // 히트 영역은 44px(DESIGN.md §6), 시각적 입력 상자는 28px을
          // 유지해 밀도를 해치지 않는다 — 상자를 세로 중앙에 둔다.
          child: SizedBox(
            height: 44,
            child: Center(
              child: Container(
                height: 28,
                decoration: BoxDecoration(
                  color: c.surfaceMuted,
                  border: Border.all(color: c.border),
                  borderRadius: BorderRadius.circular(DpRadius.input),
                ),
                padding: const EdgeInsets.symmetric(horizontal: DpSpacing.sm),
                child: Row(
                  children: [
                    Icon(DpIcons.search, size: 16, color: c.textSecondary),
                    const SizedBox(width: DpSpacing.xs),
                    Text(
                      '검색',
                      style: text.labelMedium?.copyWith(color: c.textSecondary),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: c.surface,
                        border: Border.all(color: c.border),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        'Ctrl K',
                        style: text.labelSmall?.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
