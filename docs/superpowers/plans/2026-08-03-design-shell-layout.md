# 디자인 2단계 — 셸 레이아웃 개편 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 화면마다 따로 만들던 `AppBar` 21곳을 「잉크 레일 + 크롬바 + 페이지 헤더」 3층 셸로 통일하고, 1단계가 남긴 미소비 토큰 중 `rail*` 6종을 실제 화면에 배선한다.

**Architecture:** `dp_design`에 라우팅 비의존 컴포넌트 3종(`DpNavRail`·`DpChromeBar`·`DpPageHeader`)을 신설하고 `DpAppShell`이 이들을 배치만 하도록 재구성한다. web·admin 두 앱이 같은 셸을 공유하며, 각 앱의 셸 어댑터가 경로 → 브레드크럼 변환을 담당한다.

**Tech Stack:** Flutter Web · Material 3 · melos 7 모노레포 · `flutter_test` 위젯 테스트

**Spec:** `docs/superpowers/specs/2026-08-03-design-shell-layout-design.md`

## Global Constraints

- **새 타입 스케일을 만들지 않는다.** 기존 10종(`displaySmall`·`headlineSmall`·`titleLarge`·`titleMedium`·`titleSmall`·`bodyMedium`·`bodySmall`·`labelLarge`·`labelMedium`·`labelSmall`)에서만 고른다. 미정의 스타일은 Material 기본값으로 떨어져 한글 행간 1.6이 빠진다.
- **`textFaint`를 텍스트에 쓰지 않는다.** 대비 3.21:1이라 WCAG 4.5:1 미달이다. 구분자 `·`와 비활성 아이콘에만 쓴다.
- **`tagBg`·`tagText`·`chart1~5`는 이번 범위에서 배선하지 않는다**(3단계 이월).
- Layer 2 컴포넌트(`dp_design/src/**`)는 **go_router·Riverpod을 import하지 않는다.** 콜백 주입만 받는다.
- 화면 이관 시 **`Scaffold`는 유지하고 `appBar` 인자만 제거**한다. FAB·`PinnedHeaderSliver`·본문 로직은 건드리지 않는다.
- 커밋 메시지는 Conventional Commits. 매 커밋 전 `melos run format` 확인(CI 게이트가 별도로 존재한다).
- 브랜치: `feat/design-phase2-shell` (base `develop`)

## 화면에 같은 제목이 세 번 나온다 — 테스트 작성 규칙

브레드크럼 마지막 세그먼트 · 헤더 제목 · 레일 목적지 라벨이 같은 문자열이 된다(예: 「대시보드」). 의도된 설계다(크기·역할이 다르다).

**셸을 포함해 렌더하는 테스트는 `find.text()`를 쓰지 말고 위젯 타입 또는 `Key`로 특정한다.** 페이지 단독 테스트(셸 없이 pump)는 영향이 없다.

---

## 파일 구조

**신규 (dp_design)**
- `packages/dp_design/lib/src/shell/dp_nav_rail.dart` — 잉크 레일
- `packages/dp_design/lib/src/shell/dp_chrome_bar.dart` — 크롬바 + `DpCrumb`
- `packages/dp_design/lib/src/layout/dp_page_header.dart` — 페이지 헤더
- 대응 테스트 3종 (`test/shell/`, `test/layout/`)

**수정 (dp_design)**
- `src/shell/dp_destination.dart` — record → class
- `src/shell/dp_app_shell.dart` — 3종 조립으로 재구성
- `src/icons/dp_icons.dart` — `account` 추가
- `lib/dp_design.dart` — barrel export 3줄 추가

**수정 (앱)**
- web: 셸 1 + 화면 12 + 셸 밖 4
- admin: 셸 1 + 화면 5

**수정 (검증)**
- `docs/superpowers/specs/2026-08-03-token-contrast-check.py` — 레일 조합 추가
- `DESIGN.md` — 셸 구조 절 갱신

---

### Task 1: `DpDestination` class 전환 + `DpIcons.account`

`section` 옵셔널 필드를 넣으려면 record로는 불가능하다(record는 모든 필드가 필수). 소비처는 4곳뿐이다.

**Files:**
- Modify: `packages/dp_design/lib/src/shell/dp_destination.dart`
- Modify: `packages/dp_design/lib/src/icons/dp_icons.dart`
- Modify: `packages/dp_design/lib/src/shell/dp_app_shell.dart:38-40`
- Modify: `apps/web/lib/src/features/shell/presentation/app_shell.dart:68-71`
- Modify: `apps/admin/lib/src/features/shell/presentation/admin_shell.dart:67-70`
- Test: `packages/dp_design/test/shell/dp_destination_test.dart` (신규)
- Test: `packages/dp_design/test/shell/dp_app_shell_test.dart:5-8` (생성 형태 갱신)

**Interfaces:**
- Produces: `DpDestination({required IconData icon, required String label, String? section, int badgeCount = 0})` — Task 2·5·6·10이 소비한다.
- Produces: `DpIcons.account` — Task 2·6이 소비한다.

- [ ] **Step 1: 실패하는 테스트 작성**

`packages/dp_design/test/shell/dp_destination_test.dart`:

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('section·badgeCount는 생략 가능하고 기본값을 갖는다', () {
    const d = DpDestination(icon: Icons.dashboard, label: '대시보드');
    expect(d.section, isNull);
    expect(d.badgeCount, 0);
  });

  test('section을 주면 그룹 레이블로 보존된다', () {
    const d = DpDestination(
      icon: Icons.map,
      label: '학습 경로',
      section: '학습',
      badgeCount: 3,
    );
    expect(d.section, '학습');
    expect(d.badgeCount, 3);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd packages/dp_design && flutter test test/shell/dp_destination_test.dart`
Expected: FAIL — `DpDestination`은 현재 record typedef라 생성자 호출 형태가 컴파일되지 않는다.

- [ ] **Step 3: 구현**

`dp_destination.dart` 전체를 교체:

```dart
import 'package:flutter/widgets.dart';

/// 앱 셸 목적지(표현부 계약). 라우팅 비의존 — 경로 해석은 앱이 index로 처리.
///
/// [section]이 있으면 레일에서 그룹 레이블로 묶인다. **중첩 리스트가 아니라
/// 평면 리스트에서 연속된 같은 [section]끼리 묶는 방식**이라 selectedIndex
/// 계산이 단순하게 유지된다. null이면 그룹 없음(admin).
/// [badgeCount] 0 = 배지 없음.
@immutable
class DpDestination {
  const DpDestination({
    required this.icon,
    required this.label,
    this.section,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final String? section;
  final int badgeCount;
}
```

`dp_icons.dart`의 UI 액션 절(51행 `search` 부근)에 추가:

```dart
  static const IconData account = Symbols.account_circle_rounded;
```

`dp_app_shell.dart:38-40`은 필드 접근 방식이 같아 **수정이 필요 없다**(`d.badgeCount`·`d.icon` 그대로 동작).

소비처 3곳의 생성 형태를 record → 생성자로 바꾼다.

`apps/web/lib/src/features/shell/presentation/app_shell.dart:68-71`:

```dart
      destinations: [
        for (final d in kShellDestinations)
          DpDestination(icon: d.icon, label: d.label),
      ],
```

`apps/admin/lib/src/features/shell/presentation/admin_shell.dart:67-70`도 동일한 형태로 바꾼다.

`packages/dp_design/test/shell/dp_app_shell_test.dart:5-8`:

```dart
const _dests = <DpDestination>[
  DpDestination(icon: Icons.dashboard, label: '대시보드'),
  DpDestination(icon: Icons.map, label: '경로', badgeCount: 3),
];
```

- [ ] **Step 4: 통과 확인**

Run: `melos run analyze && melos run test`
Expected: 5패키지 PASS. `dp_app_shell_test`의 기존 8개 테스트가 그대로 통과해야 한다(이 Task는 동작을 바꾸지 않는다).

- [ ] **Step 5: 커밋**

```bash
melos run format
git add -A
git commit -m "refactor(dp_design): convert DpDestination to class for optional section"
```

---

### Task 2: `DpNavRail` — 잉크 레일

**Files:**
- Create: `packages/dp_design/lib/src/shell/dp_nav_rail.dart`
- Modify: `packages/dp_design/lib/dp_design.dart` (barrel)
- Test: `packages/dp_design/test/shell/dp_nav_rail_test.dart` (신규)

**Interfaces:**
- Consumes: `DpDestination`(Task 1)
- Produces: `DpNavRail({required List<DpDestination> destinations, required int selectedIndex, required ValueChanged<int> onSelect, Widget? brand, Widget? account, bool extended = true, VoidCallback? onToggle})` — Task 5가 소비한다.

- [ ] **Step 1: 실패하는 테스트 작성**

`packages/dp_design/test/shell/dp_nav_rail_test.dart`:

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _dests = <DpDestination>[
  DpDestination(icon: Icons.dashboard, label: '대시보드', section: '학습'),
  DpDestination(icon: Icons.map, label: '학습 경로', section: '학습'),
  DpDestination(icon: Icons.groups, label: '게시판', section: '커뮤니티', badgeCount: 2),
];

Widget _host(Widget child) =>
    MaterialApp(theme: DpTheme.light(), home: Scaffold(body: Row(children: [child])));

void main() {
  testWidgets('펼침 상태에서 섹션 레이블을 그룹마다 한 번씩 렌더', (tester) async {
    await tester.pumpWidget(
      _host(DpNavRail(destinations: _dests, selectedIndex: 0, onSelect: (_) {})),
    );
    expect(find.text('학습'), findsOneWidget);
    expect(find.text('커뮤니티'), findsOneWidget);
  });

  testWidgets('접힘 상태는 섹션 레이블 대신 구분선', (tester) async {
    await tester.pumpWidget(
      _host(DpNavRail(
        destinations: _dests,
        selectedIndex: 0,
        onSelect: (_) {},
        extended: false,
      )),
    );
    expect(find.text('학습'), findsNothing);
    expect(find.byKey(const ValueKey('rail-section-divider')), findsWidgets);
  });

  testWidgets('활성 항목만 railActive 배경을 갖는다', (tester) async {
    await tester.pumpWidget(
      _host(DpNavRail(destinations: _dests, selectedIndex: 1, onSelect: (_) {})),
    );
    final active = tester.widget<Container>(
      find.byKey(const ValueKey('rail-item-1')),
    );
    final deco = active.decoration! as BoxDecoration;
    expect(deco.color, DpColors.light.railActive);
  });

  testWidgets('목적지 탭은 index를 통지', (tester) async {
    int? picked;
    await tester.pumpWidget(
      _host(DpNavRail(
        destinations: _dests,
        selectedIndex: 0,
        onSelect: (i) => picked = i,
      )),
    );
    await tester.tap(find.byKey(const ValueKey('rail-item-2')));
    expect(picked, 2);
  });

  testWidgets('badgeCount>0 목적지는 Badge 표시', (tester) async {
    await tester.pumpWidget(
      _host(DpNavRail(destinations: _dests, selectedIndex: 0, onSelect: (_) {})),
    );
    expect(find.byType(Badge), findsOneWidget);
  });

  testWidgets('brand·account 슬롯을 렌더', (tester) async {
    await tester.pumpWidget(
      _host(DpNavRail(
        destinations: _dests,
        selectedIndex: 0,
        onSelect: (_) {},
        brand: const Text('DevPath'),
        account: const Text('김개발'),
      )),
    );
    expect(find.text('DevPath'), findsOneWidget);
    expect(find.text('김개발'), findsOneWidget);
  });

  testWidgets('onToggle 지정 시 토글 버튼 노출·호출', (tester) async {
    var toggled = false;
    await tester.pumpWidget(
      _host(DpNavRail(
        destinations: _dests,
        selectedIndex: 0,
        onSelect: (_) {},
        onToggle: () => toggled = true,
      )),
    );
    await tester.tap(find.byTooltip('메뉴 접기'));
    expect(toggled, isTrue);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd packages/dp_design && flutter test test/shell/dp_nav_rail_test.dart`
Expected: FAIL — `DpNavRail` 미정의.

- [ ] **Step 3: 구현**

`packages/dp_design/lib/src/shell/dp_nav_rail.dart`:

```dart
import 'package:flutter/material.dart';

import '../icons/dp_icons.dart';
import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';
import '../theme/dp_tokens.dart';
import 'dp_destination.dart';

/// 잉크 사이드바(로드맵 Layer 2). 라우팅 비의존 — 선택은 index로 통지.
///
/// 섹션은 평면 [destinations]에서 연속된 같은 [DpDestination.section]끼리
/// 묶어 렌더한다. 접힘 상태에서는 레이블 대신 구분선을 넣는다.
class DpNavRail extends StatelessWidget {
  const DpNavRail({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    this.brand,
    this.account,
    this.extended = true,
    this.onToggle,
  });

  final List<DpDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Widget? brand;
  final Widget? account;
  final bool extended;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final t = context.appTokens;
    final width = extended ? t.railWidth : t.railCollapsedWidth;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: c.railBg,
        border: Border(right: BorderSide(color: c.railBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (brand != null || onToggle != null) _buildTop(context, c),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: _buildItems(context, c),
            ),
          ),
          if (account != null) ...[
            Divider(height: 1, thickness: 1, color: c.railBorder),
            Padding(
              padding: const EdgeInsets.all(DpSpacing.sm),
              child: account,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTop(BuildContext context, DpColors c) => Padding(
    padding: const EdgeInsets.fromLTRB(
      DpSpacing.md,
      DpSpacing.md,
      DpSpacing.sm,
      DpSpacing.sm,
    ),
    child: Row(
      children: [
        if (extended && brand != null) Expanded(child: brand!),
        if (onToggle != null)
          IconButton(
            icon: Icon(
              extended ? DpIcons.menuOpen : DpIcons.menu,
              color: c.railMuted,
            ),
            tooltip: extended ? '메뉴 접기' : '메뉴 펼치기',
            onPressed: onToggle,
          ),
      ],
    ),
  );

  List<Widget> _buildItems(BuildContext context, DpColors c) {
    final text = Theme.of(context).textTheme;
    final out = <Widget>[];
    String? lastSection;

    for (var i = 0; i < destinations.length; i++) {
      final d = destinations[i];
      if (d.section != null && d.section != lastSection) {
        out.add(
          extended
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DpSpacing.lg,
                    DpSpacing.md,
                    DpSpacing.lg,
                    DpSpacing.xs,
                  ),
                  child: Text(
                    d.section!,
                    style: text.labelMedium?.copyWith(
                      color: c.railFaint,
                      letterSpacing: 0.8,
                    ),
                  ),
                )
              : Padding(
                  key: const ValueKey('rail-section-divider'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: DpSpacing.md,
                    vertical: DpSpacing.sm,
                  ),
                  child: Divider(height: 1, thickness: 1, color: c.railBorder),
                ),
        );
      }
      lastSection = d.section;
      out.add(_item(context, c, d, i));
    }
    return out;
  }

  Widget _item(BuildContext context, DpColors c, DpDestination d, int i) {
    final selected = i == selectedIndex;
    final text = Theme.of(context).textTheme;
    final icon = d.badgeCount > 0
        ? Badge(
            label: Text('${d.badgeCount}'),
            child: Icon(d.icon, size: 20, color: selected ? c.railText : c.railMuted),
          )
        : Icon(d.icon, size: 20, color: selected ? c.railText : c.railMuted);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DpSpacing.sm,
        vertical: 1,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSelect(i),
          borderRadius: BorderRadius.circular(DpRadius.button),
          child: Container(
            key: ValueKey('rail-item-$i'),
            decoration: BoxDecoration(
              color: selected ? c.railActive : Colors.transparent,
              borderRadius: BorderRadius.circular(DpRadius.button),
              border: selected
                  ? Border(left: BorderSide(color: c.primary, width: 2))
                  : null,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: DpSpacing.sm,
              vertical: DpSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: extended
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                icon,
                if (extended) ...[
                  const SizedBox(width: DpSpacing.md),
                  Expanded(
                    child: Text(
                      d.label,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: selected ? c.railText : c.railMuted,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

barrel(`packages/dp_design/lib/dp_design.dart`)의 `export 'src/shell/dp_destination.dart';` 아래에 추가:

```dart
export 'src/shell/dp_nav_rail.dart';
```

- [ ] **Step 4: 통과 확인**

Run: `cd packages/dp_design && flutter test test/shell/dp_nav_rail_test.dart`
Expected: 7개 PASS.

- [ ] **Step 5: 커밋**

```bash
melos run format
git add -A
git commit -m "feat(dp_design): add DpNavRail with ink palette and section groups"
```

---

### Task 3: `DpChromeBar` — 얇은 상단 크롬바

**Files:**
- Create: `packages/dp_design/lib/src/shell/dp_chrome_bar.dart`
- Modify: `packages/dp_design/lib/dp_design.dart` (barrel)
- Test: `packages/dp_design/test/shell/dp_chrome_bar_test.dart` (신규)

**Interfaces:**
- Produces: `typedef DpCrumb = ({String label, String? path});`
- Produces: `DpChromeBar({required List<DpCrumb> breadcrumb, ValueChanged<String>? onCrumbTap, VoidCallback? onSearchTap, List<Widget> actions, Widget? account, bool compact})` — Task 5가 소비한다.

- [ ] **Step 1: 실패하는 테스트 작성**

`packages/dp_design/test/shell/dp_chrome_bar_test.dart`:

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _crumbs = <DpCrumb>[
  (label: '커뮤니티', path: null),
  (label: '게시판', path: '/community'),
  (label: '게시글', path: null),
];

Widget _host(Widget child) =>
    MaterialApp(theme: DpTheme.light(), home: Scaffold(body: child));

void main() {
  testWidgets('모든 세그먼트를 렌더한다', (tester) async {
    await tester.pumpWidget(_host(const DpChromeBar(breadcrumb: _crumbs)));
    expect(find.text('커뮤니티'), findsOneWidget);
    expect(find.text('게시판'), findsOneWidget);
    expect(find.text('게시글'), findsOneWidget);
  });

  testWidgets('path 있는 세그먼트만 탭 시 경로 통지', (tester) async {
    String? tapped;
    await tester.pumpWidget(
      _host(DpChromeBar(breadcrumb: _crumbs, onCrumbTap: (p) => tapped = p)),
    );
    await tester.tap(find.text('게시판'));
    expect(tapped, '/community');

    tapped = null;
    await tester.tap(find.text('커뮤니티'));
    expect(tapped, isNull, reason: 'path가 null인 세그먼트는 비클릭이다');
  });

  testWidgets('검색 필드 탭은 onSearchTap을 호출', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      _host(DpChromeBar(
        breadcrumb: _crumbs,
        onSearchTap: () => opened = true,
      )),
    );
    await tester.tap(find.byKey(const ValueKey('chrome-search')));
    expect(opened, isTrue);
  });

  testWidgets('compact은 마지막 세그먼트만 + 검색 아이콘', (tester) async {
    await tester.pumpWidget(
      _host(const DpChromeBar(breadcrumb: _crumbs, compact: true)),
    );
    expect(find.text('게시글'), findsOneWidget);
    expect(find.text('커뮤니티'), findsNothing);
    expect(find.byKey(const ValueKey('chrome-search-icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('chrome-search')), findsNothing);
  });

  testWidgets('actions·account 슬롯을 렌더', (tester) async {
    await tester.pumpWidget(
      _host(const DpChromeBar(
        breadcrumb: _crumbs,
        actions: [Text('액션')],
        account: Text('계정'),
      )),
    );
    expect(find.text('액션'), findsOneWidget);
    expect(find.text('계정'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd packages/dp_design && flutter test test/shell/dp_chrome_bar_test.dart`
Expected: FAIL — `DpChromeBar`·`DpCrumb` 미정의.

- [ ] **Step 3: 구현**

`packages/dp_design/lib/src/shell/dp_chrome_bar.dart`:

```dart
import 'package:flutter/material.dart';

import '../icons/dp_icons.dart';
import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';

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
  final List<Widget> actions;
  final Widget? account;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: DpSpacing.lg),
      child: Row(
        children: [
          Flexible(child: _crumbs(context, c)),
          const SizedBox(width: DpSpacing.lg),
          if (!compact && onSearchTap != null)
            Flexible(flex: 2, child: _search(context, c))
          else if (compact && onSearchTap != null)
            IconButton(
              key: const ValueKey('chrome-search-icon'),
              icon: Icon(DpIcons.search, size: 20, color: c.textSecondary),
              tooltip: '검색 (Ctrl/Cmd+K)',
              onPressed: onSearchTap,
            ),
          const Spacer(),
          ...actions,
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
      final label = Text(crumb.label, style: style, overflow: TextOverflow.ellipsis);

      children.add(
        crumb.path == null
            ? label
            : InkWell(
                onTap: () => onCrumbTap?.call(crumb.path!),
                borderRadius: BorderRadius.circular(DpRadius.button),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: label,
                ),
              ),
      );

      if (!isLast) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DpSpacing.xs),
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
                Text('검색', style: text.labelMedium?.copyWith(color: c.textSecondary)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border.all(color: c.border),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'Ctrl K',
                    style: text.labelSmall?.copyWith(color: c.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

barrel에 추가:

```dart
export 'src/shell/dp_chrome_bar.dart';
```

- [ ] **Step 4: 통과 확인**

Run: `cd packages/dp_design && flutter test test/shell/dp_chrome_bar_test.dart`
Expected: 5개 PASS.

- [ ] **Step 5: 커밋**

```bash
melos run format
git add -A
git commit -m "feat(dp_design): add DpChromeBar with breadcrumb and palette trigger"
```

---

### Task 4: `DpPageHeader` — 본문 페이지 헤더

**Files:**
- Create: `packages/dp_design/lib/src/layout/dp_page_header.dart`
- Modify: `packages/dp_design/lib/dp_design.dart` (barrel)
- Test: `packages/dp_design/test/layout/dp_page_header_test.dart` (신규)

**Interfaces:**
- Produces: `DpPageHeader({required String title, String? description, List<Widget> actions, Widget? filters})` — Task 7·8·9·10·11이 소비한다.

- [ ] **Step 1: 실패하는 테스트 작성**

`packages/dp_design/test/layout/dp_page_header_test.dart`:

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) =>
    MaterialApp(theme: DpTheme.light(), home: Scaffold(body: child));

void main() {
  testWidgets('제목만 주면 설명·액션·필터는 렌더하지 않는다', (tester) async {
    await tester.pumpWidget(_host(const DpPageHeader(title: '대시보드')));
    expect(find.text('대시보드'), findsOneWidget);
    expect(find.byKey(const ValueKey('page-header-description')), findsNothing);
    expect(find.byKey(const ValueKey('page-header-filters')), findsNothing);
  });

  testWidgets('제목은 headlineSmall 스케일을 쓴다', (tester) async {
    await tester.pumpWidget(_host(const DpPageHeader(title: '대시보드')));
    final widget = tester.widget<Text>(find.text('대시보드'));
    expect(widget.style?.fontSize, 24);
  });

  testWidgets('설명·액션·필터 슬롯을 렌더', (tester) async {
    await tester.pumpWidget(
      _host(const DpPageHeader(
        title: '사용자 관리',
        description: '가입 승인과 제재를 처리합니다',
        actions: [Text('액션')],
        filters: Text('필터'),
      )),
    );
    expect(find.text('가입 승인과 제재를 처리합니다'), findsOneWidget);
    expect(find.text('액션'), findsOneWidget);
    expect(find.text('필터'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd packages/dp_design && flutter test test/layout/dp_page_header_test.dart`
Expected: FAIL — `DpPageHeader` 미정의.

- [ ] **Step 3: 구현**

`packages/dp_design/lib/src/layout/dp_page_header.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';

/// 본문 최상단 페이지 헤더(로드맵 Layer 2).
///
/// 제목은 **기존 headlineSmall(24/32 w600)** 을 쓴다. 새 타입 스케일을
/// 만들면 Material 기본값으로 떨어져 한글 행간 1.6이 빠진다.
class DpPageHeader extends StatelessWidget {
  const DpPageHeader({
    super.key,
    required this.title,
    this.description,
    this.actions = const [],
    this.filters,
  });

  final String title;
  final String? description;
  final List<Widget> actions;
  final Widget? filters;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DpSpacing.lg,
        DpSpacing.lg,
        DpSpacing.lg,
        DpSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: text.headlineSmall?.copyWith(color: c.textPrimary),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: DpSpacing.xs),
                      Text(
                        description!,
                        key: const ValueKey('page-header-description'),
                        style: text.bodySmall?.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(width: DpSpacing.md),
                Wrap(
                  spacing: DpSpacing.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: actions,
                ),
              ],
            ],
          ),
          if (filters != null) ...[
            const SizedBox(height: DpSpacing.md),
            KeyedSubtree(
              key: const ValueKey('page-header-filters'),
              child: filters!,
            ),
          ],
        ],
      ),
    );
  }
}
```

barrel의 `export 'src/layout/dp_window_class.dart';` 아래에 추가:

```dart
export 'src/layout/dp_page_header.dart';
```

- [ ] **Step 4: 통과 확인**

Run: `cd packages/dp_design && flutter test test/layout/dp_page_header_test.dart`
Expected: 3개 PASS.

- [ ] **Step 5: 커밋**

```bash
melos run format
git add -A
git commit -m "feat(dp_design): add DpPageHeader for in-body page titles"
```

---

### Task 5: `DpAppShell` 재구성

기존 `leading`·`trailing`·`accountSlot` 3슬롯을 `brand`·`chromeActions`·`account`로 재편하고, 3종 컴포넌트를 배치한다.

**Files:**
- Modify: `packages/dp_design/lib/src/shell/dp_app_shell.dart` (전체 교체)
- Test: `packages/dp_design/test/shell/dp_app_shell_test.dart` (갱신)

**Interfaces:**
- Consumes: `DpNavRail`(Task 2) · `DpChromeBar`·`DpCrumb`(Task 3) · `DpDestination`(Task 1)
- Produces: 새 `DpAppShell` 시그니처 — Task 6·10이 소비한다.

- [ ] **Step 1: 실패하는 테스트 작성**

`packages/dp_design/test/shell/dp_app_shell_test.dart` 전체 교체:

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _dests = <DpDestination>[
  DpDestination(icon: Icons.dashboard, label: '대시보드', section: '학습'),
  DpDestination(icon: Icons.map, label: '경로', section: '학습', badgeCount: 3),
];

const _crumbs = <DpCrumb>[(label: '학습', path: null), (label: '대시보드', path: null)];

Widget _host(Widget child) => MaterialApp(theme: DpTheme.light(), home: child);

void _setWidth(WidgetTester tester, double w) {
  tester.view.physicalSize = Size(w, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

DpAppShell _shell({
  bool? railExtended,
  VoidCallback? onToggleRail,
  List<DpCrumb> breadcrumb = _crumbs,
  Widget? account,
}) => DpAppShell(
  destinations: _dests,
  selectedIndex: 0,
  onSelect: (_) {},
  railExtended: railExtended,
  onToggleRail: onToggleRail,
  breadcrumb: breadcrumb,
  account: account,
  body: const Text('본문'),
);

void main() {
  testWidgets('compact(<600)은 NavigationBar, 레일 없음', (tester) async {
    _setWidth(tester, 500);
    await tester.pumpWidget(_host(_shell()));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(DpNavRail), findsNothing);
  });

  testWidgets('medium(600–839)은 접힌 DpNavRail', (tester) async {
    _setWidth(tester, 700);
    await tester.pumpWidget(_host(_shell()));
    final rail = tester.widget<DpNavRail>(find.byType(DpNavRail));
    expect(rail.extended, isFalse);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('expanded(≥840)은 펼친 DpNavRail', (tester) async {
    _setWidth(tester, 1000);
    await tester.pumpWidget(_host(_shell()));
    final rail = tester.widget<DpNavRail>(find.byType(DpNavRail));
    expect(rail.extended, isTrue);
  });

  testWidgets('large(≥1240)은 본문을 DpMaxWidth로 제약', (tester) async {
    _setWidth(tester, 1400);
    await tester.pumpWidget(_host(_shell()));
    expect(find.byType(DpMaxWidth), findsOneWidget);
  });

  testWidgets('breadcrumb이 비면 크롬바를 렌더하지 않는다', (tester) async {
    _setWidth(tester, 1000);
    await tester.pumpWidget(_host(_shell(breadcrumb: const [])));
    expect(find.byType(DpChromeBar), findsNothing);
  });

  testWidgets('breadcrumb이 있으면 크롬바를 렌더한다', (tester) async {
    _setWidth(tester, 1000);
    await tester.pumpWidget(_host(_shell()));
    expect(find.byType(DpChromeBar), findsOneWidget);
  });

  testWidgets('account는 expanded에서 레일에, compact에서 크롬바에 배치', (tester) async {
    _setWidth(tester, 1000);
    await tester.pumpWidget(_host(_shell(account: const Text('계정'))));
    final rail = tester.widget<DpNavRail>(find.byType(DpNavRail));
    expect(rail.account, isNotNull);
    var chrome = tester.widget<DpChromeBar>(find.byType(DpChromeBar));
    expect(chrome.account, isNull);

    _setWidth(tester, 500);
    await tester.pumpWidget(_host(_shell(account: const Text('계정'))));
    chrome = tester.widget<DpChromeBar>(find.byType(DpChromeBar));
    expect(chrome.account, isNotNull);
  });

  testWidgets('목적지 선택 콜백은 index 전달', (tester) async {
    _setWidth(tester, 500);
    int? picked;
    await tester.pumpWidget(
      _host(
        DpAppShell(
          destinations: _dests,
          selectedIndex: 0,
          onSelect: (i) => picked = i,
          body: const Text('본문'),
        ),
      ),
    );
    await tester.tap(find.text('경로'));
    expect(picked, 1);
  });

  testWidgets('onToggleRail 지정 시 레일에 전달', (tester) async {
    _setWidth(tester, 1000);
    var toggled = false;
    await tester.pumpWidget(_host(_shell(onToggleRail: () => toggled = true)));
    await tester.tap(find.byTooltip('메뉴 접기'));
    expect(toggled, isTrue);
  });

  testWidgets('railExtended=false가 window class 기본을 오버라이드', (tester) async {
    _setWidth(tester, 1000);
    await tester.pumpWidget(_host(_shell(railExtended: false)));
    final rail = tester.widget<DpNavRail>(find.byType(DpNavRail));
    expect(rail.extended, isFalse);
  });

  testWidgets('badgeCount>0 목적지는 Badge 표시', (tester) async {
    _setWidth(tester, 1000);
    await tester.pumpWidget(_host(_shell()));
    expect(find.byType(Badge), findsOneWidget);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd packages/dp_design && flutter test test/shell/dp_app_shell_test.dart`
Expected: FAIL — `breadcrumb`·`account` 인자 미정의, `DpNavRail` 미사용.

- [ ] **Step 3: 구현**

`packages/dp_design/lib/src/shell/dp_app_shell.dart` 전체 교체:

```dart
import 'package:flutter/material.dart';

import '../layout/dp_max_width.dart';
import '../layout/dp_window_class.dart';
import 'dp_chrome_bar.dart';
import 'dp_destination.dart';
import 'dp_nav_rail.dart';

/// 4-클래스 반응형 앱 셸(로드맵 §2.2 Layer 2). 라우팅 비의존 —
/// 목적지 선택은 [onSelect]에 index로 통지, 경로 해석은 앱이 담당.
///
/// 구조: [DpNavRail](세로) + [DpChromeBar](가로) + body.
/// [breadcrumb]이 비면 크롬바를 렌더하지 않는다.
/// [account]는 폭에 따라 레일 하단 또는 크롬바 우측으로 간다 —
/// 앱은 한 벌만 만들고 배치는 셸이 정한다.
class DpAppShell extends StatelessWidget {
  const DpAppShell({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    required this.body,
    this.brand,
    this.account,
    this.breadcrumb = const [],
    this.onCrumbTap,
    this.onSearchTap,
    this.chromeActions = const [],
    this.railExtended,
    this.onToggleRail,
    this.constrainBodyAtLarge = true,
  });

  final List<DpDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Widget body;
  final Widget? brand;
  final Widget? account;
  final List<DpCrumb> breadcrumb;
  final ValueChanged<String>? onCrumbTap;
  final VoidCallback? onSearchTap;
  final List<Widget> chromeActions;
  final bool? railExtended;
  final VoidCallback? onToggleRail;
  final bool constrainBodyAtLarge;

  @override
  Widget build(BuildContext context) {
    final wc = context.windowClass;
    final compact = wc == DpWindowClass.compact;

    final content = (constrainBodyAtLarge && wc == DpWindowClass.large)
        ? DpMaxWidth(child: body)
        : body;

    final main = Column(
      children: [
        if (breadcrumb.isNotEmpty)
          DpChromeBar(
            breadcrumb: breadcrumb,
            onCrumbTap: onCrumbTap,
            onSearchTap: onSearchTap,
            actions: chromeActions,
            account: compact ? account : null,
            compact: compact,
          ),
        Expanded(child: content),
      ],
    );

    if (compact) {
      return Scaffold(
        body: main,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelect,
          destinations: [
            for (final d in destinations)
              NavigationDestination(
                icon: d.badgeCount > 0
                    ? Badge(label: Text('${d.badgeCount}'), child: Icon(d.icon))
                    : Icon(d.icon),
                label: d.label,
              ),
          ],
        ),
      );
    }

    // medium 기본 접힘, expanded/large 기본 펼침. railExtended가 오버라이드.
    final extended = railExtended ?? (wc != DpWindowClass.medium);

    return Scaffold(
      body: FocusTraversalGroup(
        child: Row(
          children: [
            DpNavRail(
              destinations: destinations,
              selectedIndex: selectedIndex,
              onSelect: onSelect,
              brand: brand,
              account: account,
              extended: extended,
              onToggle: onToggleRail,
            ),
            Expanded(child: main),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `cd packages/dp_design && flutter test`
Expected: dp_design 전체 PASS. `dp_app_shell_test` 11개 포함.

- [ ] **Step 5: 커밋**

```bash
melos run format
git add -A
git commit -m "refactor(dp_design): rebuild DpAppShell on DpNavRail and DpChromeBar"
```

---

### Task 6: web 셸 배선

목적지 5→4 축소, 브레드크럼 매핑, 계정 블록, 검색 배선.

**Files:**
- Modify: `apps/web/lib/src/features/shell/presentation/app_shell.dart` (전체 교체)
- Test: `apps/web/test/features/shell/app_shell_view_test.dart` (갱신)
- Test: `apps/web/test/features/shell/app_shell_breadcrumb_test.dart` (신규)

**Interfaces:**
- Consumes: 새 `DpAppShell`(Task 5) · `DpCrumb`(Task 3) · `DpDestination`(Task 1) · `DpIcons.account`(Task 1)
- Produces: `kShellDestinations`(4개) · `breadcrumbFor(String location)` — Task 7·8·9의 화면 테스트가 참조하지 않지만, 셸 회귀 판단의 기준이 된다.

- [ ] **Step 1: 실패하는 테스트 작성**

`apps/web/test/features/shell/app_shell_breadcrumb_test.dart` (신규):

```dart
import 'package:devpath_web/src/features/shell/presentation/app_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('최상위 화면은 [섹션, 페이지]', () {
    expect(breadcrumbFor('/dashboard'), const [
      (label: '학습', path: null),
      (label: '대시보드', path: null),
    ]);
  });

  test('커뮤니티 하위 화면은 게시판 세그먼트가 클릭 가능', () {
    expect(breadcrumbFor('/community/post/12'), const [
      (label: '커뮤니티', path: null),
      (label: '게시판', path: '/community'),
      (label: '게시글', path: null),
    ]);
  });

  test('커뮤니티 홈 자신은 게시판 세그먼트가 마지막', () {
    expect(breadcrumbFor('/community'), const [
      (label: '커뮤니티', path: null),
      (label: '게시판', path: '/community'),
    ]);
  });

  test('계정 화면은 라우트 없는 섹션을 쓴다', () {
    expect(breadcrumbFor('/settings'), const [
      (label: '계정', path: null),
      (label: '설정', path: null),
    ]);
  });

  test('알 수 없는 경로는 빈 브레드크럼(크롬바 미렌더)', () {
    expect(breadcrumbFor('/unknown'), isEmpty);
  });

  test('/community/new/post는 /community/new보다 먼저 매칭된다', () {
    expect(breadcrumbFor('/community/new/post').last.label, '새 글');
    expect(breadcrumbFor('/community/new').last.label, '질문하기');
  });
}
```

`apps/web/test/features/shell/app_shell_view_test.dart`의 `NavigationRail` 참조 5곳을 `DpNavRail`로 바꾸고, 목적지 축소를 반영한다. `find.text('멘토')` → 레일 라벨이 「AI 멘토」이므로 갱신:

```dart
  testWidgets('넓은 폭(≥840)은 DpNavRail', (tester) async {
    _setWidth(tester, 1200);
    await tester.pumpWidget(
      _host(const AppShellView(location: '/dashboard', child: Text('본문'))),
    );
    expect(find.byType(DpNavRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('목적지 선택 시 해당 경로로 콜백', (tester) async {
    _setWidth(tester, 390);
    String? picked;
    await tester.pumpWidget(
      _host(
        AppShellView(
          location: '/dashboard',
          onSelect: (p) => picked = p,
          child: const Text('본문'),
        ),
      ),
    );
    await tester.tap(find.text('AI 멘토'));
    expect(picked, '/mentor');
  });
```

나머지 3개(`좁은 폭`·`중간 폭`·`Large 폭`)도 `NavigationRail` → `DpNavRail`, `rail.extended` 접근은 `tester.widget<DpNavRail>(...)`로 바꾼다.

- [ ] **Step 2: 실패 확인**

Run: `cd apps/web && flutter test test/features/shell/`
Expected: FAIL — `breadcrumbFor` 미정의, `DpNavRail` 미사용.

- [ ] **Step 3: 구현**

`apps/web/lib/src/features/shell/presentation/app_shell.dart` 전체 교체:

```dart
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
  (
    path: '/community',
    icon: DpIcons.community,
    label: '게시판',
    section: '커뮤니티',
  ),
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

  int get _index {
    final i = kShellDestinations.indexWhere((d) => location.startsWith(d.path));
    return i < 0 ? 0 : i;
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
          Flexible(
            child: Text(
              'DevPath',
              overflow: TextOverflow.ellipsis,
              style: text.titleSmall?.copyWith(color: c.railText),
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
    final c = context.dpColors;
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
      builder: (context, controller, _) => IconButton(
        icon: Icon(DpIcons.account, color: c.railMuted),
        tooltip: '계정',
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `cd apps/web && flutter test test/features/shell/`
Expected: 브레드크럼 6개 + 셸뷰 5개 PASS.

Run: `cd apps/web && flutter test`
Expected: web 전체 PASS. **`golden_path_t1_realapi_test`가 커뮤니티 탭을 텍스트로 찾는다면 레일 라벨 변경(「커뮤니티」→「게시판」)으로 깨질 수 있다. 깨지면 해당 탭 선택을 `find.byKey(const ValueKey('rail-item-3'))`로 바꾼다.**

- [ ] **Step 5: 커밋**

```bash
melos run format
git add -A
git commit -m "feat(web): wire ink rail, breadcrumb chrome bar and account menu"
```

---

### Task 7: web 화면 이관 A — 학습 5화면

**Files:**
- Modify: `apps/web/lib/src/features/dashboard/presentation/dashboard_page.dart:40-41`
- Modify: `apps/web/lib/src/features/path/presentation/path_page.dart:61`
- Modify: `apps/web/lib/src/features/content/presentation/content_page.dart:96-106`
- Modify: `apps/web/lib/src/features/sandbox/presentation/sandbox_page.dart:37-52`
- Modify: `apps/web/lib/src/features/mentor/presentation/mentor_page.dart:65`
- Test: `apps/web/test/features/path/path_title_test.dart` (갱신)

**Interfaces:**
- Consumes: `DpPageHeader`(Task 4)

각 화면의 `Scaffold`에서 `appBar:` 인자를 제거하고 `body`를 `Column`으로 감싸 헤더를 최상단에 넣는다. **본문이 스크롤 위젯이면 `Expanded`로 감싼다.**

- [ ] **Step 1: 실패하는 테스트 작성**

`apps/web/test/features/dashboard/dashboard_header_test.dart` (신규):

```dart
import 'package:devpath_web/src/features/dashboard/presentation/dashboard_page.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('대시보드는 AppBar 대신 DpPageHeader를 쓴다', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: DashboardPage()),
      ),
    );
    await tester.pump();
    expect(find.byType(AppBar), findsNothing);
    final header = tester.widget<DpPageHeader>(find.byType(DpPageHeader));
    expect(header.title, '대시보드');
    expect(header.description, '이번 주 학습 현황과 다음 과제를 한눈에 봅니다');
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd apps/web && flutter test test/features/dashboard/dashboard_header_test.dart`
Expected: FAIL — `AppBar`가 아직 존재한다.

- [ ] **Step 3: 구현**

`dashboard_page.dart:40-61`의 `Scaffold`를 교체:

```dart
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DpPageHeader(
            title: '대시보드',
            description: '이번 주 학습 현황과 다음 과제를 한눈에 봅니다',
          ),
          Expanded(
            child: AnimatedSwitcher(
              key: const ValueKey('dash-switcher'),
              duration: DpDurations.stageReveal,
              child: switch (s) {
                DashLoading() => const Skeletonizer(
                  key: ValueKey('loading'),
                  child: DashboardBody(summary: _skeletonSummary),
                ),
                DashFailed(:final message) => SupportableError(
                  key: const ValueKey('error'),
                  message: message,
                  onRetry: () =>
                      ref.read(dashboardControllerProvider.notifier).load(),
                ),
                DashLoaded(:final summary) => DashboardBody(
                  key: const ValueKey('loaded'),
                  summary: summary,
                ),
              },
            ),
          ),
        ],
      ),
    );
```

나머지 4화면도 같은 형태로 바꾼다. 헤더 인자는 아래 표를 **그대로** 쓴다(문구를 지어내지 말 것).

| 파일 | title | description | actions |
|---|---|---|---|
| `path_page.dart` | `'학습 경로'` | `'진단 결과로 만든 12주 계획입니다'` | 없음 |
| `content_page.dart` | `'학습 콘텐츠'` | `'읽고 나면 바로 실습으로 이어집니다'` | 기존 「실습」 `TextButton.icon` 그대로 이동 |
| `sandbox_page.dart` | `'실습 샌드박스'` | `'코드를 작성하고 바로 실행해 봅니다'` | 기존 언어 `DropdownButton` + 뒤따르는 위젯 그대로 이동 |
| `mentor_page.dart` | `'AI 멘토'` | `'막히는 부분을 물어보면 학습 맥락을 반영해 답합니다'` | 없음 |

**`sandbox_page.dart`는 `Sandbox` → `실습 샌드박스`가 유일한 제목 변경이다.** 다른 화면이 전부 한국어인데 이 화면만 영문이었다.

각 화면에 `import 'package:dp_design/dp_design.dart';`가 없으면 추가한다(대부분 이미 있다).

`apps/web/test/features/path/path_title_test.dart:22`는 테스트가 직접 `AppBar`를 만들어 제목 중복을 검증한다. `DpPageHeader`를 쓰도록 갱신한다:

```dart
          body: Column(
            children: const [
              DpPageHeader(title: '학습 경로'),
              Expanded(child: SizedBox()),
            ],
          ),
```

- [ ] **Step 4: 통과 확인**

Run: `cd apps/web && flutter test`
Expected: web 전체 PASS.

- [ ] **Step 5: 커밋**

```bash
melos run format
git add -A
git commit -m "feat(web): migrate learning screens from AppBar to DpPageHeader"
```

---

### Task 8: web 화면 이관 B — 커뮤니티 5화면

커뮤니티 홈은 `CustomScrollView`라 헤더가 **sliver로** 들어간다. `PinnedHeaderSliver`(검색바·보드 필터)와 FAB는 건드리지 않는다.

**Files:**
- Modify: `apps/web/lib/src/features/community/presentation/community_home_page.dart:121-128`
- Modify: `apps/web/lib/src/features/community/presentation/post_create_page.dart:123`
- Modify: `apps/web/lib/src/features/community/presentation/post_detail_page.dart:59`
- Modify: `apps/web/lib/src/features/community/presentation/qna_detail_page.dart:57`
- Modify: `apps/web/lib/src/features/community/presentation/question_create_page.dart:160`
- Test: `apps/web/test/features/community/post_create_page_test.dart:84,91` (갱신)

**Interfaces:**
- Consumes: `DpPageHeader`(Task 4)

- [ ] **Step 1: 실패하는 테스트 작성**

`apps/web/test/features/community/community_header_test.dart` (신규):

```dart
import 'package:devpath_web/src/features/community/presentation/community_home_page.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('커뮤니티 홈은 AppBar 대신 sliver 헤더를 쓴다', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: CommunityHomePage()),
      ),
    );
    await tester.pump();
    expect(find.byType(AppBar), findsNothing);
    final header = tester.widget<DpPageHeader>(find.byType(DpPageHeader));
    expect(header.title, '커뮤니티');
    expect(find.byType(FloatingActionButton), findsOneWidget,
        reason: 'FAB는 이번 개편에서 유지한다');
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd apps/web && flutter test test/features/community/community_header_test.dart`
Expected: FAIL — `AppBar`가 아직 존재한다.

- [ ] **Step 3: 구현**

`community_home_page.dart:121-129`:

```dart
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openComposeSheet(context),
        icon: const Icon(DpIcons.edit),
        label: const Text('새 글'),
      ),
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: DpPageHeader(
              title: '커뮤니티',
              description: '질문하고 답하고 서로 피드백을 남깁니다',
            ),
          ),
          PinnedHeaderSliver(
            // ... 기존 그대로
```

나머지 4화면은 `appBar:` 제거 + `body`를 `Column`으로 감싸는 Task 7과 같은 형태다.

| 파일 | title | description |
|---|---|---|
| `question_create_page.dart` | `'질문하기'` | `'무엇을 시도했고 어디서 막혔는지 함께 적어주세요'` |
| `post_create_page.dart` | `_pageTitle` (동적 유지) | `'자유롭게 쓰거나 코드 피드백을 요청하세요'` |
| `post_detail_page.dart` | `'게시글'` | `null` (본문이 주인공이라 부연을 넣지 않는다) |
| `qna_detail_page.dart` | `'Q&A'` | `null` (동일) |

`post_create_page_test.dart:84,91`의 `find.text('자유글 작성')`·`'피드백 요청'`은 **그대로 통과한다**(헤더 제목도 텍스트다). 주석의 "AppBar"만 "페이지 헤더"로 고친다.

- [ ] **Step 4: 통과 확인**

Run: `cd apps/web && flutter test`
Expected: web 전체 PASS.

- [ ] **Step 5: 커밋**

```bash
melos run format
git add -A
git commit -m "feat(web): migrate community screens to DpPageHeader"
```

---

### Task 9: web 화면 이관 C — 설정·마이페이지

**Files:**
- Modify: `apps/web/lib/src/features/settings/presentation/settings_page.dart:39`
- Modify: `apps/web/lib/src/features/mypage/presentation/mypage_page.dart:32-43`
- Test: `apps/web/test/features/mypage/mypage_page_test.dart:55` (확인)

**Interfaces:**
- Consumes: `DpPageHeader`(Task 4)

- [ ] **Step 1: 실패하는 테스트 작성**

`apps/web/test/features/mypage/mypage_header_test.dart` (신규):

```dart
import 'package:devpath_web/src/features/mypage/presentation/mypage_page.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('마이페이지 헤더에 설정 버튼이 없다(계정 메뉴로 일원화)', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: MyPagePage())),
    );
    await tester.pump();
    expect(find.byType(AppBar), findsNothing);
    final header = tester.widget<DpPageHeader>(find.byType(DpPageHeader));
    expect(header.title, '마이페이지');
    expect(header.actions, isEmpty);
    expect(find.byIcon(Icons.settings_outlined), findsNothing);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd apps/web && flutter test test/features/mypage/mypage_header_test.dart`
Expected: FAIL — `AppBar`와 설정 `IconButton`이 아직 존재한다.

- [ ] **Step 3: 구현**

| 파일 | title | description | actions |
|---|---|---|---|
| `settings_page.dart` | `'설정'` | `'알림·동의·계정을 관리합니다'` | 없음 |
| `mypage_page.dart` | `'마이페이지'` | `'프로필과 활동 기록입니다'` | **없음 — 기존 설정 `IconButton`을 삭제한다** |

`mypage_page.dart`에서 `import 'package:go_router/go_router.dart';`가 설정 버튼 때문에만 있었다면 **미사용 import가 되므로 함께 제거**한다(`flutter analyze`가 info를 내고 CI가 비-제로로 실패한다).

- [ ] **Step 4: 통과 확인**

Run: `cd apps/web && flutter test && flutter analyze`
Expected: PASS + 이슈 0.

- [ ] **Step 5: 커밋**

```bash
melos run format
git add -A
git commit -m "feat(web): migrate settings and mypage, drop duplicate settings action"
```

---

### Task 10: admin 셸 + 5화면 이관

**Files:**
- Modify: `apps/admin/lib/src/features/shell/presentation/admin_shell.dart:62-85`
- Modify: `apps/admin/lib/src/features/dashboard/presentation/dashboard_page.dart:33`
- Modify: `apps/admin/lib/src/features/users/presentation/users_page.dart:64-...`
- Modify: `apps/admin/lib/src/features/reports/presentation/reports_page.dart:34`
- Modify: `apps/admin/lib/src/features/support/presentation/support_page.dart:28`
- Modify: `apps/admin/lib/src/features/ads/presentation/ads_page.dart:36-...`
- Test: `apps/admin/test/features/shell/admin_shell_view_test.dart` (갱신)

**Interfaces:**
- Consumes: 새 `DpAppShell`(Task 5) · `DpPageHeader`(Task 4)

admin은 **`section` 없이** 평면 목록을 쓴다. 브레드크럼은 단일 세그먼트다.

- [ ] **Step 1: 실패하는 테스트 작성**

`admin_shell_view_test.dart`를 갱신하고 브레드크럼 테스트를 추가:

```dart
  testWidgets('Large 폭은 펼친 DpNavRail + 브랜드', (tester) async {
    _setWidth(tester, 1400);
    await tester.pumpWidget(
      _host(const AdminShellView(location: '/dashboard', child: Text('본문'))),
    );
    final rail = tester.widget<DpNavRail>(find.byType(DpNavRail));
    expect(rail.extended, isTrue);
    expect(find.text('운영 콘솔'), findsOneWidget);
  });

  testWidgets('admin 브레드크럼은 단일 세그먼트', (tester) async {
    _setWidth(tester, 1400);
    await tester.pumpWidget(
      _host(const AdminShellView(location: '/users', child: Text('본문'))),
    );
    final chrome = tester.widget<DpChromeBar>(find.byType(DpChromeBar));
    expect(chrome.breadcrumb, const [(label: '사용자 관리', path: null)]);
  });
```

`compact 폭은 NavigationBar` 테스트의 `find.byType(NavigationRail)` → `DpNavRail`로 바꾼다.

- [ ] **Step 2: 실패 확인**

Run: `cd apps/admin && flutter test test/features/shell/`
Expected: FAIL.

- [ ] **Step 3: 구현**

`admin_shell.dart`의 `AdminShellView.build`를 교체:

```dart
  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;
    final current = kAdminDestinations.firstWhere(
      (d) => location.startsWith(d.path),
      orElse: () => kAdminDestinations.first,
    );

    return DpAppShell(
      selectedIndex: _index,
      onSelect: (i) => onSelect?.call(kAdminDestinations[i].path),
      destinations: [
        for (final d in kAdminDestinations)
          DpDestination(icon: d.icon, label: d.label),
      ],
      brand: Text(
        '운영 콘솔',
        overflow: TextOverflow.ellipsis,
        style: text.titleSmall?.copyWith(color: c.railText),
      ),
      breadcrumb: [(label: _headerTitleFor(current.path), path: null)],
      onSearchTap: () => Actions.invoke(
        context,
        const OpenCommandPaletteIntent(),
      ),
      body: child,
    );
  }
```

`_headerTitleFor`는 같은 파일 최상위에 둔다 — 화면 헤더와 브레드크럼이 같은 문자열을 쓰게 하는 단일 출처다:

```dart
/// 경로 → 화면 제목. 브레드크럼과 DpPageHeader가 같은 값을 쓴다.
String _headerTitleFor(String path) => switch (path) {
  '/users' => '사용자 관리',
  '/reports' => '신고 처리',
  '/support' => '오류 신고·문의',
  '/ads' => '광고 관리',
  _ => '운영 대시보드',
};
```

화면 5개는 `appBar:` 제거 + `DpPageHeader` 삽입:

| 파일 | title | description | actions / filters |
|---|---|---|---|
| `dashboard_page.dart` | `'운영 대시보드'` | `'서비스 지표를 요약합니다'` | — |
| `users_page.dart` | `'사용자 관리'` | `'가입 승인과 제재를 처리합니다'` | `AppBar.bottom`의 상태 필터 `Row`를 **`filters:`** 로 이동 |
| `reports_page.dart` | `'신고 처리'` | `'커뮤니티 신고를 검토하고 판정합니다'` | — |
| `support_page.dart` | `'오류 신고·문의'` | `'사용자가 보낸 오류와 문의를 처리합니다'` | — |
| `ads_page.dart` | `'광고 관리'` | `'하우스·스폰서 광고를 운영합니다'` | actions=전역 노출 `Switch`+「광고 생성」, filters=`bottom` 필터 |

**`users_page.dart`·`ads_page.dart`의 `PreferredSize` 래퍼는 제거한다** — `filters` 슬롯은 높이 제약이 없다. 안쪽 `Padding`의 좌우 여백도 제거한다(`DpPageHeader`가 이미 `DpSpacing.lg`를 준다).

- [ ] **Step 4: 통과 확인**

Run: `cd apps/admin && flutter test && flutter analyze`
Expected: admin 전체 PASS + 이슈 0. `ads_page_test.dart:62`의 "AppBar의 생성 버튼" 주석은 사실과 어긋나므로 "헤더의 생성 버튼"으로 고친다.

- [ ] **Step 5: 커밋**

```bash
melos run format
git add -A
git commit -m "feat(admin): adopt ink rail, chrome bar and page headers"
```

---

### Task 11: 셸 밖 4화면 최소 정합

레일도 크롬바도 없는 단독 화면이다. 같은 헤더·카드·여백 규칙만 적용하고 **흐름·입력·검증 로직은 건드리지 않는다.**

**Files:**
- Modify: `apps/web/lib/src/features/auth/presentation/login_page.dart:24-40`
- Modify: `apps/web/lib/src/features/beta/presentation/beta_pending_page.dart:66`
- Modify: `apps/web/lib/src/features/consent/presentation/consent_page.dart:109`
- Modify: `apps/web/lib/src/features/diagnostic/presentation/diagnostic_page.dart:47`
- Create: `apps/web/lib/src/features/common/presentation/brand_row.dart`
- Test: `apps/web/test/features/diagnostic/diagnostic_page_test.dart:50` (확인)

**Interfaces:**
- Consumes: `DpPageHeader`(Task 4)

- [ ] **Step 1: 실패하는 테스트 작성**

`apps/web/test/features/auth/login_header_test.dart` (신규):

```dart
import 'package:devpath_web/src/features/auth/presentation/login_page.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('로그인은 AppBar 없이 헤더 + 테마 전환 버튼을 유지', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginPage())),
    );
    await tester.pump();
    expect(find.byType(AppBar), findsNothing);
    final header = tester.widget<DpPageHeader>(find.byType(DpPageHeader));
    expect(header.title, '로그인');
    expect(find.byTooltip('테마 전환'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd apps/web && flutter test test/features/auth/login_header_test.dart`
Expected: FAIL — `AppBar`가 아직 존재한다.

- [ ] **Step 3: 구현**

네 화면 모두 `appBar:`를 제거하고 본문 최상단을 아래 구조로 바꾼다.

```dart
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                brandRow(context),           // 로고 + DevPath (+ 로그인만 테마 버튼)
                const DpPageHeader(title: '로그인', description: 'GitHub 또는 Google 계정으로 시작하세요'),
                // ... 기존 본문 그대로
              ],
            ),
          ),
        ),
      ),
    );
```

브랜드 행은 **`apps/web/lib/src/features/common/presentation/brand_row.dart`에 한 번만 만들고 4화면이 import한다.** 4곳에 같은 코드를 복제하지 않는다(`features/common/presentation/`은 이미 존재하는 디렉토리다). dp_design까지 올리지는 않는다 — web 전용이고 admin에는 대응 화면이 없다.

```dart
// apps/web/lib/src/features/common/presentation/brand_row.dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

/// 셸 밖 화면(로그인·동의·진단·베타)의 상단 브랜드 행.
/// 이 화면들엔 레일이 없어 제품 정체성을 보여줄 자리가 여기뿐이다.
Widget brandRow(BuildContext context, {List<Widget> actions = const []}) {
  final c = context.dpColors;
  final text = Theme.of(context).textTheme;
  return Padding(
    padding: const EdgeInsets.fromLTRB(DpSpacing.lg, DpSpacing.lg, DpSpacing.lg, 0),
    child: Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: c.primary,
            borderRadius: BorderRadius.circular(DpRadius.button),
          ),
        ),
        const SizedBox(width: DpSpacing.sm),
        Text('DevPath', style: text.titleSmall?.copyWith(color: c.textPrimary)),
        const Spacer(),
        ...actions,
      ],
    ),
  );
}
```

| 파일 | title | description | 브랜드 행 actions |
|---|---|---|---|
| `login_page.dart` | `'로그인'` | `'GitHub 또는 Google 계정으로 시작하세요'` | 기존 테마 전환 `IconButton` |
| `beta_pending_page.dart` | `'베타 대기'` | `'승인되면 알려드립니다'` | 없음 |
| `consent_page.dart` | `'가입 전 동의'` | `'서비스 이용에 필요한 항목입니다'` | 없음 |
| `diagnostic_page.dart` | `'실력 진단'` | `'몇 문항으로 현재 수준을 파악합니다'` | 없음 |

**진단 화면은 문항 카드가 440px보다 넓어야 읽힌다.** 이 화면만 `maxWidth`를 `context.appTokens.readableMaxWidth`(880)로 준다.

`diagnostic_page_test.dart:50`의 `find.text('실력 진단')`은 헤더 제목으로 그대로 통과한다. 주석의 "AppBar 타이틀"만 "페이지 헤더"로 고친다.

- [ ] **Step 4: 통과 확인**

Run: `cd apps/web && flutter test`
Expected: web 전체 PASS.

- [ ] **Step 5: 커밋**

```bash
melos run format
git add -A
git commit -m "feat(web): align pre-shell screens with page header and brand row"
```

---

### Task 12: 대비 검증 확장 + 문서 + 전 스위트

**Files:**
- Modify: `docs/superpowers/specs/2026-08-03-token-contrast-check.py`
- Modify: `DESIGN.md`

- [ ] **Step 1: 대비 스크립트에 레일 조합 추가**

기존 스크립트의 조합 목록에 아래를 더한다. **`railMuted`·`railFaint`는 UI 기준 3:1이 아니라 텍스트 기준 4.5:1로 단언한다** — 목적지 라벨과 섹션 레이블은 읽어야 하는 텍스트다.

```python
RAIL_PAIRS = [
    ("railText",   "railBg",     4.5),
    ("railMuted",  "railBg",     4.5),
    ("railFaint",  "railBg",     4.5),
    ("railText",   "railActive", 4.5),
    ("railMuted",  "railActive", 4.5),
]
```

- [ ] **Step 2: 실행해서 미달을 확인**

Run: `python docs/superpowers/specs/2026-08-03-token-contrast-check.py`
Expected: 라이트·다크 각각 5조합 추가. **미달이 나오면 토큰 값을 조정하고 1단계 스펙 §3.2·§3.3 표를 함께 고친다.** 1단계에서 `chart2`가 1.47:1로 미달해 재조정한 전례가 있다 — 레일 값도 실측 전까지는 통과를 가정하지 않는다.

- [ ] **Step 3: `DESIGN.md` 갱신**

셸 구조 절에 다음을 반영한다:
- `DpNavRail`·`DpChromeBar`·`DpPageHeader` 3종과 각자의 책임
- 레일 섹션 그룹 규칙(평면 리스트 + 연속 `section`)
- 크롬바 검색이 명령 팔레트 트리거라는 점
- `textFaint`는 구분자·비활성 아이콘 전용이라는 제약
- 화면은 `AppBar`를 만들지 않는다는 규칙

- [ ] **Step 4: 전 스위트 + 육안 검증**

```bash
melos run format
melos run analyze
melos run test
```

Expected: 5패키지(web·dp_core·dp_design·admin·mobile) green, analyze 이슈 0.

이어서 목 모드로 빌드해 **네 폭(500·700·1000·1400)에서 레일 전환**과 라이트·다크를 육안 확인한다. 접힘 상태의 섹션 구분선이 이번 개편의 유일한 새 분기다.

- [ ] **Step 5: 커밋**

```bash
git add -A
git commit -m "test(dp_design): extend contrast check with rail pairs; docs: update DESIGN.md"
```

---

## 자기 검토 결과

**스펙 커버리지**

| 스펙 절 | 담당 Task |
|---|---|
| §3.0 `DpAppShell` API 변경 | 5 |
| §3.1 `DpDestination` class화 | 1 |
| §3.2 `DpNavRail` | 2 |
| §3.3 `DpChromeBar` / §3.4 가짜 검색 | 3 |
| §3.5 `DpPageHeader` | 4 |
| §4 레일 구성(4목적지·계정 메뉴) | 6 |
| §5 web 12화면 | 7·8·9 |
| §6 admin 5화면 | 10 |
| §7 브레드크럼 매핑 / §7.1 제목 3중 노출 | 6 (+ 전 Task의 테스트 작성 규칙) |
| §8 반응형 4클래스 | 5 |
| §9 셸 밖 4화면 | 11 |
| §10 토큰 배선 | 2·3·4 (`tag*`·`chart*`는 명시적 제외) |
| §11 테스트 전략 | 각 Task + 12 |
| §14 검증 | 12 |

**타입 일관성 확인**

- `DpDestination` 생성자(Task 1) → Task 2·5·6·10에서 동일 형태 사용 ✓
- `DpCrumb` record(Task 3) → Task 5·6·10에서 `(label:, path:)` 동일 ✓
- `DpNavRail.extended`·`.account`(Task 2) → Task 5 테스트가 같은 이름으로 접근 ✓
- `DpChromeBar.breadcrumb`·`.account`(Task 3) → Task 5·10 테스트가 같은 이름으로 접근 ✓
- `DpPageHeader.title`·`.description`·`.actions`·`.filters`(Task 4) → Task 7~11에서 동일 ✓
- `breadcrumbFor`(Task 6) → Task 6 테스트에서만 사용 ✓

**남은 위험**

1. **`golden_path_t1_realapi_test`** — 레일 라벨이 「커뮤니티」→「게시판」으로 바뀐다. Task 6 Step 4에 대응을 명시했다.
2. **레일 대비 미달 가능성** — Task 12에서 실측 전까지 통과를 가정하지 않는다.
3. **`Scaffold` 중첩** — 셸과 화면이 각자 `Scaffold`를 갖는다. 배경색이 같아 무해하지만, 화면 `Scaffold`가 자체 `backgroundColor`를 지정하면 크롬바 아래 색이 튄다. 이관 시 발견되면 해당 화면의 `backgroundColor` 지정을 제거한다.
