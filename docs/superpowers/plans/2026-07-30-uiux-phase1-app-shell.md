# UI/UX Phase 1 — 공통 앱 셸 & 명령 팔레트 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** DESIGN.md §5 4-클래스 반응형 앱 셸(`DpAppShell`)과 Ctrl/Cmd+K 명령 팔레트(`DpCommandPalette`)를 `dp_design`(Layer 2)에 신설하고, `apps/web`·`apps/admin`이 이를 조립만 하도록 이관한다.

**Architecture:** 로드맵 §2.1의 3층 분리를 계승한다 — Layer 2 컴포넌트(`DpAppShell`·`DpCommandPalette`)는 **go_router·Riverpod 비의존 순수 표현부**로 두고, 라우팅/명령 소스는 앱 측 얇은 래퍼(`AppShell`·`AdminShell`)가 주입한다. 기존 web의 `AppShell`(라우터 결합) ↔ `AppShellView`(표현부) 분리 패턴을 admin에도 확장 적용한다.

**Tech Stack:** Flutter 3.44 계열(Flutter Web/CanvasKit), Material 3 SDK 기본 위젯(`NavigationRail`·`NavigationBar`·`SearchAnchor`·`SearchController`·`Shortcuts`/`Actions`·`FocusTraversalGroup`·`Badge`) — **외부 패키지 도입 없음**. 테스트는 `flutter_test` 위젯 테스트. 모노레포는 Dart pub workspaces + melos 7.

## Global Constraints

- **브랜치 규칙**: 모든 작업은 `develop`에서 분기한 작업 브랜치에서 진행. `develop`·`main` 직접 push 금지. 머지는 develop으로 PR → CI(`melos run analyze`·`melos run test`·`melos run format`) green 후. (CLAUDE.md 🔀)
- **Test-First (절대 조건 2)**: 모든 변경은 실패 테스트 먼저 → 최소 구현 → `melos run test`(또는 대상 패키지 `flutter test`)로 통과를 눈으로 확인. 테스트 없는 구현 변경 금지.
- **포맷 게이트**: 커밋 전 `melos run format`(= `dart format --set-exit-if-changed .`) green. (Phase 0 PR #86이 이 게이트로 1회 red 났던 전례 — 매 커밋 전 확인.)
- **토큰 SSoT = DESIGN.md**: 색·간격·반경·폭은 반드시 `DpColors`/`DpSpacing`/`DpRadius`/`AppTokens` 토큰만 사용. 화면·컴포넌트에서 리터럴 색·폭 직접 지정 금지(로드맵 안티패턴 §6).
- **반응형 브레이크포인트(DESIGN.md §5, 재정의 금지)**: Compact `<600` / Medium `600–839` / Expanded `840–1239` / Large `≥1240`.
- **Layer 2 순수성**: `packages/dp_design`의 신규 위젯은 `go_router`·`flutter_riverpod`를 import하지 않는다(pubspec에 이미 없음 — 유지). 라우팅/상태는 콜백·주입으로만 받는다.
- **장식 정책(DESIGN.md §3)**: APP UI 장식 그림자·BackdropFilter 금지. 구분은 보더(`VerticalDivider`·`Border`) 우선.
- **접근성(DESIGN.md §6)**: 색만으로 상태 의미 전달 금지 — selected는 배경+굵기, focus는 테두리 병행. 키보드 포커스·Tab 순서 보장(`FocusTraversalGroup`). 아이콘 버튼에 `tooltip`/`Semantics`.
- **Phase 0 확정 시그니처(소비 대상, 변경 금지)**:
  - `AppTokens`(ThemeExtension): `contentMaxWidth=1440`·`readableMaxWidth=880`·`railWidth=256`·`railCollapsedWidth=72`·`panelRadius=10`. 조회: `context.appTokens`.
  - `DpColors`(ThemeExtension): `primary`·`primaryText`·`bg`·`surface`·`border`·`textPrimary`·`textSecondary` 등. 조회: `context.dpColors`.
  - `DpStateStyle.navItemBackground(DpColors c) → WidgetStateProperty<Color>`.
  - `DpInteractiveCard`·`DpMaxWidth({child, maxWidth})`·`DpSelectable`·`DpScrollbar`.
  - `DpSpacing.{xs=4,sm=8,md=12,lg=16,xl=24}`·`DpRadius.card=10`·`DpDurations.{stageReveal=200,skeletonCrossfade=150}`.
  - `DpTheme.light()/dark()`에 `DpColors`·`AppTokens` 등록됨(Phase 0 AC).
- **YAGNI 결정(이 플랜에서 확정)**: 로드맵 §Phase 1이 언급한 **2차 메뉴 `ExpansionTile`(하위 목적지)** 는 web/admin 현재 목적지가 전부 평면(children 없음)이므로 **이번 Phase에서 구현하지 않는다**. `NavigationRail` 기반을 유지해 기존 위젯 테스트 계약(`find.byType(NavigationRail)`)을 보존한다. 실제 하위 목적지 소비처가 생기면 별도 spec으로 추가한다.

---

## File Structure

**신설 (dp_design Layer 2):**
- `packages/dp_design/lib/src/layout/dp_window_class.dart` — `DpWindowClass` enum + `dpWindowClassOf(double)` + `context.windowClass`. 단일 책임: 폭→size class 판정(DESIGN.md §5).
- `packages/dp_design/lib/src/shell/dp_destination.dart` — `DpDestination` 표현부 목적지 레코드(icon·label·badgeCount). 라우팅 비의존.
- `packages/dp_design/lib/src/shell/dp_app_shell.dart` — `DpAppShell`(4-클래스 반응형 셸 + rail 확장/축소 + badge + 계정 슬롯 + FocusTraversalGroup).
- `packages/dp_design/lib/src/shell/dp_command.dart` — `DpCommand` 레코드(id·label·icon·onInvoke).
- `packages/dp_design/lib/src/shell/dp_command_palette.dart` — `DpCommandPalette`(SearchAnchor+Shortcuts/Actions, Ctrl/Cmd+K) + `OpenCommandPaletteIntent`(공개 인텐트).

**수정 (dp_design Layer 1 잔여 — Phase 0에서 이월된 §4.3·§4.4):**
- `packages/dp_design/lib/src/icons/dp_icons.dart` — `search`·`moreVert`·`star`·`menu`·`menuOpen` 추가.
- `packages/dp_design/lib/src/theme/dp_spacing.dart` — `DpDurations`에 `hover`·`select`·`panelExpand` 추가.
- `packages/dp_design/lib/dp_design.dart` — 신규 파일 export.

**수정 (앱 이관 Layer 3):**
- `apps/web/lib/src/features/shell/presentation/app_shell.dart` — `AppShellView`가 `DpAppShell` 소비, `AppShell`이 `DpCommandPalette`로 감쌈. `kShellDestinations`·`ShellDestination` 계약 유지.
- `apps/admin/lib/src/features/shell/presentation/admin_shell.dart` — `AdminShell`(라우터) + `AdminShellView`(표현부) 분리, `DpAppShell`·`DpCommandPalette` 소비. `kAdminDestinations` 유지.

**테스트:**
- `packages/dp_design/test/layout/dp_window_class_test.dart` (신설)
- `packages/dp_design/test/shell/dp_app_shell_test.dart` (신설)
- `packages/dp_design/test/shell/dp_command_palette_test.dart` (신설)
- `apps/web/test/features/shell/app_shell_view_test.dart` (기존 확장)
- `apps/admin/test/features/shell/admin_shell_view_test.dart` (신설 — admin 최초 셸 테스트)

**Task 의존 순서:** Task 1(토큰) → Task 2(DpAppShell) → Task 3(DpCommandPalette) → Task 4(web 이관) → Task 5(admin 이관). Task 4·5는 Task 2·3 완료 후 병렬 가능.

---

### Task 1: Layer 1 잔여 토큰 — DpIcons·DpDurations 보강

Phase 0에서 이월된 로드맵 §4.3·§4.4. `DpCommandPalette`의 검색 아이콘(`search`)과 셸 토글 아이콘(`menu`/`menuOpen`), rail 확장 모션(`panelExpand`)의 선행 요소.

**Files:**
- Modify: `packages/dp_design/lib/src/icons/dp_icons.dart`
- Modify: `packages/dp_design/lib/src/theme/dp_spacing.dart:20-23`
- Test: `packages/dp_design/test/theme/dp_tokens_test.dart` (기존 파일에 추가) 또는 신규 `packages/dp_design/test/theme/dp_durations_test.dart`

**Interfaces:**
- Produces: `DpIcons.search`·`DpIcons.moreVert`·`DpIcons.star`·`DpIcons.menu`·`DpIcons.menuOpen` (`IconData`), `DpDurations.hover`·`DpDurations.select`·`DpDurations.panelExpand` (`Duration`).

- [ ] **Step 1: 실패 테스트 작성** — `packages/dp_design/test/theme/dp_durations_test.dart`

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('모션 토큰이 로드맵 §4.3 수치와 일치', () {
    expect(DpDurations.hover, const Duration(milliseconds: 120));
    expect(DpDurations.select, const Duration(milliseconds: 180));
    expect(DpDurations.panelExpand, const Duration(milliseconds: 220));
  });

  test('명령 팔레트·셸 토글 아이콘이 정의됨', () {
    // 컴파일되면 상수 존재. IconData 동일성으로 오탈자 방지.
    expect(DpIcons.search, isA<IconData>());
    expect(DpIcons.menu, isA<IconData>());
    expect(DpIcons.menuOpen, isA<IconData>());
    expect(DpIcons.moreVert, isA<IconData>());
    expect(DpIcons.star, isA<IconData>());
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd packages/dp_design && flutter test test/theme/dp_durations_test.dart`
Expected: FAIL — `DpDurations.hover` 등 미정의 컴파일 에러.

- [ ] **Step 3: DpDurations 확장** — `packages/dp_design/lib/src/theme/dp_spacing.dart`의 `DpDurations` 블록을 아래로 교체

```dart
abstract final class DpDurations {
  static const Duration stageReveal = Duration(milliseconds: 200);
  static const Duration skeletonCrossfade = Duration(milliseconds: 150);
  // 로드맵 §4.3 — hover/select/panelExpand (과도한 지연 회피).
  static const Duration hover = Duration(milliseconds: 120);
  static const Duration select = Duration(milliseconds: 180);
  static const Duration panelExpand = Duration(milliseconds: 220);
}
```

- [ ] **Step 4: DpIcons 보강** — `packages/dp_design/lib/src/icons/dp_icons.dart`의 `DpIcons` 클래스 안(마지막 필드 뒤)에 추가

```dart
  // 명령 팔레트 / 셸 토글 / 리스트 액션 (로드맵 §4.4)
  static const IconData search = Symbols.search_rounded;
  static const IconData moreVert = Symbols.more_vert_rounded;
  static const IconData star = Symbols.star_rounded;
  static const IconData menu = Symbols.menu_rounded;
  static const IconData menuOpen = Symbols.menu_open_rounded;
```

- [ ] **Step 5: 통과 확인**

Run: `cd packages/dp_design && flutter test test/theme/dp_durations_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: 포맷 + 커밋**

```bash
cd D:/workspace/dpa/devpath-frontend
dart format packages/dp_design/lib/src/theme/dp_spacing.dart packages/dp_design/lib/src/icons/dp_icons.dart packages/dp_design/test/theme/dp_durations_test.dart
git add packages/dp_design/lib/src/theme/dp_spacing.dart packages/dp_design/lib/src/icons/dp_icons.dart packages/dp_design/test/theme/dp_durations_test.dart
git commit -m "feat(dp_design): 모션 토큰·명령팔레트 아이콘 보강 (Phase1 선행, 로드맵 §4.3·§4.4)"
```

---

### Task 2: DpWindowClass + DpDestination + DpAppShell (Layer 2)

4-클래스 반응형 셸. `NavigationRail`(medium 접힘 / expanded·large 펼침) ↔ `NavigationBar`(compact) 전환, rail 확장/축소 토글, 목적지 `Badge`, 하단 계정 슬롯, `FocusTraversalGroup`. **go_router·Riverpod 비의존.**

**Files:**
- Create: `packages/dp_design/lib/src/layout/dp_window_class.dart`
- Create: `packages/dp_design/lib/src/shell/dp_destination.dart`
- Create: `packages/dp_design/lib/src/shell/dp_app_shell.dart`
- Modify: `packages/dp_design/lib/dp_design.dart` (export 3줄 추가)
- Test: `packages/dp_design/test/layout/dp_window_class_test.dart`, `packages/dp_design/test/shell/dp_app_shell_test.dart`

**Interfaces:**
- Consumes: `AppTokens`(`context.appTokens.railWidth`), `DpMaxWidth`, `DpSpacing.{sm,md}`, `DpIcons.{menu,menuOpen}`(Task 1).
- Produces:
  - `enum DpWindowClass { compact, medium, expanded, large }`
  - `DpWindowClass dpWindowClassOf(double width)`
  - `extension DpWindowClassX on BuildContext { DpWindowClass get windowClass; }`
  - `typedef DpDestination = ({IconData icon, String label, int badgeCount});`
  - `class DpAppShell extends StatelessWidget` — 생성자:
    ```dart
    const DpAppShell({
      required List<DpDestination> destinations,
      required int selectedIndex,
      required ValueChanged<int> onSelect,
      required Widget body,
      Widget? leading,        // rail 상단(로고/'운영 콘솔')
      Widget? trailing,       // rail 하단 위(명령팔레트 런처 등)
      Widget? accountSlot,    // rail 최하단(계정)
      bool? railExtended,     // null = window class 기본(medium 접힘, 그 외 펼침)
      VoidCallback? onToggleRail, // 지정 시 접힘/펼침 토글 버튼 노출
      bool constrainBodyAtLarge = true,
    });
    ```

- [ ] **Step 1: DpWindowClass 실패 테스트** — `packages/dp_design/test/layout/dp_window_class_test.dart`

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('폭 경계가 DESIGN.md §5와 일치', () {
    expect(dpWindowClassOf(599), DpWindowClass.compact);
    expect(dpWindowClassOf(600), DpWindowClass.medium);
    expect(dpWindowClassOf(839), DpWindowClass.medium);
    expect(dpWindowClassOf(840), DpWindowClass.expanded);
    expect(dpWindowClassOf(1239), DpWindowClass.expanded);
    expect(dpWindowClassOf(1240), DpWindowClass.large);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd packages/dp_design && flutter test test/layout/dp_window_class_test.dart`
Expected: FAIL — `dpWindowClassOf` 미정의.

- [ ] **Step 3: DpWindowClass 구현** — `packages/dp_design/lib/src/layout/dp_window_class.dart`

```dart
import 'package:flutter/widgets.dart';

/// Material 3 window size class(DESIGN.md §5). 폭 경계는 SSoT — 재정의 금지.
enum DpWindowClass { compact, medium, expanded, large }

DpWindowClass dpWindowClassOf(double width) {
  if (width < 600) return DpWindowClass.compact;
  if (width < 840) return DpWindowClass.medium;
  if (width < 1240) return DpWindowClass.expanded;
  return DpWindowClass.large;
}

/// 현재 컨텍스트 폭의 size class 조회.
extension DpWindowClassX on BuildContext {
  DpWindowClass get windowClass =>
      dpWindowClassOf(MediaQuery.sizeOf(this).width);
}
```

- [ ] **Step 4: DpDestination 정의** — `packages/dp_design/lib/src/shell/dp_destination.dart`

```dart
import 'package:flutter/widgets.dart';

/// 앱 셸 목적지(표현부 계약). 라우팅 비의존 — 경로 해석은 앱이 index로 처리.
/// [badgeCount] 0 = 배지 없음.
typedef DpDestination = ({IconData icon, String label, int badgeCount});
```

- [ ] **Step 5: barrel export 추가** — `packages/dp_design/lib/dp_design.dart`의 `dp_max_width` export 아래에 추가

```dart
export 'src/layout/dp_window_class.dart';
export 'src/shell/dp_destination.dart';
export 'src/shell/dp_app_shell.dart';
```

- [ ] **Step 6: DpAppShell 위젯 테스트(실패)** — `packages/dp_design/test/shell/dp_app_shell_test.dart`

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _dests = <DpDestination>[
  (icon: Icons.dashboard, label: '대시보드', badgeCount: 0),
  (icon: Icons.map, label: '경로', badgeCount: 3),
];

Widget _host(Widget child) => MaterialApp(theme: DpTheme.light(), home: child);

void _setWidth(WidgetTester tester, double w) {
  tester.view.physicalSize = Size(w, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

DpAppShell _shell({bool? railExtended, VoidCallback? onToggleRail}) => DpAppShell(
      destinations: _dests,
      selectedIndex: 0,
      onSelect: (_) {},
      railExtended: railExtended,
      onToggleRail: onToggleRail,
      body: const Text('본문'),
    );

void main() {
  testWidgets('compact(<600)은 NavigationBar', (tester) async {
    _setWidth(tester, 500);
    await tester.pumpWidget(_host(_shell()));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('medium(600–839)은 접힌 NavigationRail(extended=false)', (tester) async {
    _setWidth(tester, 700);
    await tester.pumpWidget(_host(_shell()));
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('expanded(≥840)은 펼친 NavigationRail(extended=true)', (tester) async {
    _setWidth(tester, 1000);
    await tester.pumpWidget(_host(_shell()));
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
  });

  testWidgets('large(≥1240)은 본문을 DpMaxWidth로 제약', (tester) async {
    _setWidth(tester, 1400);
    await tester.pumpWidget(_host(_shell()));
    expect(find.byType(DpMaxWidth), findsOneWidget);
  });

  testWidgets('badgeCount>0 목적지는 Badge 표시', (tester) async {
    _setWidth(tester, 1000);
    await tester.pumpWidget(_host(_shell()));
    expect(find.byType(Badge), findsOneWidget); // '경로'만 badgeCount=3
  });

  testWidgets('목적지 선택 콜백은 index 전달', (tester) async {
    _setWidth(tester, 500);
    int? picked;
    await tester.pumpWidget(_host(DpAppShell(
      destinations: _dests,
      selectedIndex: 0,
      onSelect: (i) => picked = i,
      body: const Text('본문'),
    )));
    await tester.tap(find.text('경로'));
    expect(picked, 1);
  });

  testWidgets('onToggleRail 지정 시 토글 버튼 노출·호출', (tester) async {
    _setWidth(tester, 1000);
    var toggled = false;
    await tester.pumpWidget(_host(_shell(onToggleRail: () => toggled = true)));
    final btn = find.byTooltip('메뉴 접기');
    expect(btn, findsOneWidget);
    await tester.tap(btn);
    expect(toggled, isTrue);
  });

  testWidgets('railExtended=false가 window class 기본을 오버라이드', (tester) async {
    _setWidth(tester, 1000); // 기본은 펼침
    await tester.pumpWidget(_host(_shell(railExtended: false)));
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
  });
}
```

- [ ] **Step 7: 실패 확인**

Run: `cd packages/dp_design && flutter test test/shell/dp_app_shell_test.dart`
Expected: FAIL — `DpAppShell` 미정의.

- [ ] **Step 8: DpAppShell 구현** — `packages/dp_design/lib/src/shell/dp_app_shell.dart`

```dart
import 'package:flutter/material.dart';

import '../icons/dp_icons.dart';
import '../layout/dp_max_width.dart';
import '../layout/dp_window_class.dart';
import '../theme/dp_spacing.dart';
import '../theme/dp_tokens.dart';
import 'dp_destination.dart';

/// 4-클래스 반응형 앱 셸(로드맵 §2.2 Layer 2). 라우팅 비의존 —
/// 목적지 선택은 [onSelect]에 index로 통지, 경로 해석은 앱이 담당.
class DpAppShell extends StatelessWidget {
  const DpAppShell({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    required this.body,
    this.leading,
    this.trailing,
    this.accountSlot,
    this.railExtended,
    this.onToggleRail,
    this.constrainBodyAtLarge = true,
  });

  final List<DpDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Widget body;
  final Widget? leading;
  final Widget? trailing;
  final Widget? accountSlot;
  final bool? railExtended;
  final VoidCallback? onToggleRail;
  final bool constrainBodyAtLarge;

  static Widget _icon(DpDestination d) => d.badgeCount > 0
      ? Badge(label: Text('${d.badgeCount}'), child: Icon(d.icon))
      : Icon(d.icon);

  @override
  Widget build(BuildContext context) {
    final wc = context.windowClass;

    if (wc == DpWindowClass.compact) {
      return Scaffold(
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelect,
          destinations: [
            for (final d in destinations)
              NavigationDestination(icon: _icon(d), label: d.label),
          ],
        ),
      );
    }

    // medium 기본 접힘, expanded/large 기본 펼침. railExtended가 오버라이드.
    final extended = railExtended ?? (wc != DpWindowClass.medium);
    final content = (constrainBodyAtLarge && wc == DpWindowClass.large)
        ? DpMaxWidth(child: body)
        : body;

    return Scaffold(
      body: FocusTraversalGroup(
        child: Row(
          children: [
            NavigationRail(
              extended: extended,
              minExtendedWidth: context.appTokens.railWidth,
              labelType:
                  extended ? null : NavigationRailLabelType.none,
              selectedIndex: selectedIndex,
              onDestinationSelected: onSelect,
              leading: _buildLeading(extended),
              trailing: _buildTrailing(),
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: _icon(d),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  Widget? _buildLeading(bool extended) {
    final items = <Widget>[
      if (leading != null) leading!,
      if (onToggleRail != null)
        IconButton(
          icon: Icon(extended ? DpIcons.menuOpen : DpIcons.menu),
          tooltip: extended ? '메뉴 접기' : '메뉴 펼치기',
          onPressed: onToggleRail,
        ),
    ];
    if (items.isEmpty) return null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DpSpacing.sm),
      child: Column(mainAxisSize: MainAxisSize.min, children: items),
    );
  }

  Widget? _buildTrailing() {
    final items = <Widget>[
      if (trailing != null) trailing!,
      if (accountSlot != null) accountSlot!,
    ];
    if (items.isEmpty) return null;
    return Expanded(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: DpSpacing.md),
          child: Column(mainAxisSize: MainAxisSize.min, children: items),
        ),
      ),
    );
  }
}
```

- [ ] **Step 9: 통과 확인**

Run: `cd packages/dp_design && flutter test test/layout/dp_window_class_test.dart test/shell/dp_app_shell_test.dart`
Expected: PASS (window class 1 + shell 8 tests).

> **참고(디버깅 지점):** `NavigationRail`은 `extended && labelType != null && labelType != none`이면 assert로 실패한다. 위 구현은 `extended ? null : none`으로 회피한다. `minExtendedWidth`가 `context.appTokens`를 읽으므로 테스트 `_host`는 반드시 `theme: DpTheme.light()`를 줘야 한다(AppTokens 미등록 시 `extension<AppTokens>()!` null 크래시 — Phase 0에서 등록됨).

- [ ] **Step 10: 전체 analyze + 포맷 + 커밋**

```bash
cd D:/workspace/dpa/devpath-frontend
dart pub global run melos run analyze
dart format packages/dp_design
git add packages/dp_design/lib/src/layout/dp_window_class.dart packages/dp_design/lib/src/shell/dp_destination.dart packages/dp_design/lib/src/shell/dp_app_shell.dart packages/dp_design/lib/dp_design.dart packages/dp_design/test/layout/dp_window_class_test.dart packages/dp_design/test/shell/dp_app_shell_test.dart
git commit -m "feat(dp_design): DpAppShell 4-클래스 반응형 셸·rail 토글 (Phase1, 로드맵 §2.2)"
```

---

### Task 3: DpCommandPalette + OpenCommandPaletteIntent (Layer 2)

`SearchAnchor`+`SearchController` 기반 명령 팔레트. `Shortcuts`/`Actions`로 Ctrl/Cmd+K 오픈, 결과 소스(`List<DpCommand>`)는 앱이 주입. 공개 인텐트 `OpenCommandPaletteIntent`로 하위 위젯(셸 trailing 버튼)이 프로그래밍적으로 오픈.

**Files:**
- Create: `packages/dp_design/lib/src/shell/dp_command.dart`
- Create: `packages/dp_design/lib/src/shell/dp_command_palette.dart`
- Modify: `packages/dp_design/lib/dp_design.dart` (export 2줄)
- Test: `packages/dp_design/test/shell/dp_command_palette_test.dart`

**Interfaces:**
- Consumes: `DpIcons.search`(Task 1).
- Produces:
  - `typedef DpCommand = ({String id, String label, IconData icon, VoidCallback onInvoke});`
  - `class OpenCommandPaletteIntent extends Intent { const OpenCommandPaletteIntent(); }`
  - `class DpCommandPalette extends StatefulWidget` — 생성자: `const DpCommandPalette({required Widget child, required List<DpCommand> commands, String hintText})`. 앱 트리 상단(라우터 위)을 감싼다.

- [ ] **Step 1: 실패 테스트** — `packages/dp_design/test/shell/dp_command_palette_test.dart`

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(theme: DpTheme.light(), home: child);

void main() {
  testWidgets('Ctrl+K로 팔레트가 열리고 명령 필터·실행', (tester) async {
    String invoked = '';
    await tester.pumpWidget(_host(DpCommandPalette(
      commands: [
        (id: 'dash', label: '대시보드로 이동', icon: DpIcons.dashboard,
            onInvoke: () => invoked = 'dash'),
        (id: 'mentor', label: '멘토로 이동', icon: DpIcons.mentor,
            onInvoke: () => invoked = 'mentor'),
      ],
      child: const Scaffold(body: Text('앱 본문')),
    )));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    // 검색 뷰가 열려 두 명령 모두 노출
    expect(find.text('대시보드로 이동'), findsOneWidget);
    expect(find.text('멘토로 이동'), findsOneWidget);

    // 타이핑으로 필터
    await tester.enterText(find.byType(TextField).last, '멘토');
    await tester.pumpAndSettle();
    expect(find.text('대시보드로 이동'), findsNothing);

    // 선택 → onInvoke
    await tester.tap(find.text('멘토로 이동'));
    await tester.pumpAndSettle();
    expect(invoked, 'mentor');
  });

  testWidgets('OpenCommandPaletteIntent로도 오픈', (tester) async {
    await tester.pumpWidget(_host(DpCommandPalette(
      commands: [
        (id: 'a', label: '항목 A', icon: DpIcons.star, onInvoke: () {}),
      ],
      child: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: IconButton(
              icon: const Icon(DpIcons.search),
              onPressed: () =>
                  Actions.invoke(context, const OpenCommandPaletteIntent()),
            ),
          ),
        ),
      ),
    )));

    await tester.tap(find.byIcon(DpIcons.search));
    await tester.pumpAndSettle();
    expect(find.text('항목 A'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd packages/dp_design && flutter test test/shell/dp_command_palette_test.dart`
Expected: FAIL — `DpCommandPalette`·`OpenCommandPaletteIntent` 미정의.

- [ ] **Step 3: DpCommand 정의** — `packages/dp_design/lib/src/shell/dp_command.dart`

```dart
import 'package:flutter/widgets.dart';

/// 명령 팔레트 항목. [onInvoke]는 선택 시 실행(라우팅·액션은 앱이 주입).
typedef DpCommand = ({
  String id,
  String label,
  IconData icon,
  VoidCallback onInvoke,
});
```

- [ ] **Step 4: DpCommandPalette 구현** — `packages/dp_design/lib/src/shell/dp_command_palette.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dp_command.dart';

/// 하위 위젯이 명령 팔레트를 프로그래밍적으로 열기 위한 공개 인텐트.
class OpenCommandPaletteIntent extends Intent {
  const OpenCommandPaletteIntent();
}

/// Ctrl/Cmd+K 명령 팔레트(로드맵 §Phase1). 앱 트리 상단을 감싸며,
/// 결과 소스([commands])는 앱이 주입한다. 라우팅 비의존.
class DpCommandPalette extends StatefulWidget {
  const DpCommandPalette({
    super.key,
    required this.child,
    required this.commands,
    this.hintText = '명령·이동 검색',
  });

  final Widget child;
  final List<DpCommand> commands;
  final String hintText;

  @override
  State<DpCommandPalette> createState() => _DpCommandPaletteState();
}

class _DpCommandPaletteState extends State<DpCommandPalette> {
  final SearchController _controller = SearchController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open() {
    if (!_controller.isOpen) _controller.openView();
  }

  Iterable<Widget> _suggestions(
      BuildContext context, SearchController controller) {
    final q = controller.text.trim().toLowerCase();
    final matches = q.isEmpty
        ? widget.commands
        : widget.commands
            .where((c) => c.label.toLowerCase().contains(q));
    return [
      for (final c in matches)
        ListTile(
          leading: Icon(c.icon),
          title: Text(c.label),
          onTap: () {
            controller.closeView(null);
            c.onInvoke();
          },
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyK, control: true):
            OpenCommandPaletteIntent(),
        SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            OpenCommandPaletteIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          OpenCommandPaletteIntent: CallbackAction<OpenCommandPaletteIntent>(
            onInvoke: (_) {
              _open();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Stack(
            children: [
              widget.child,
              // 0-크기 앵커: openView()가 전체화면 검색 뷰를 오버레이로 연다.
              Positioned(
                left: 0,
                top: 0,
                child: SearchAnchor(
                  searchController: _controller,
                  viewHintText: widget.hintText,
                  isFullScreen: false,
                  builder: (context, controller) => const SizedBox.shrink(),
                  suggestionsBuilder: _suggestions,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: barrel export 추가** — `packages/dp_design/lib/dp_design.dart`의 Task 2에서 추가한 shell export 아래에

```dart
export 'src/shell/dp_command.dart';
export 'src/shell/dp_command_palette.dart';
```

- [ ] **Step 6: 통과 확인**

Run: `cd packages/dp_design && flutter test test/shell/dp_command_palette_test.dart`
Expected: PASS (2 tests).

> **참고(디버깅 지점):** 키 이벤트가 `Shortcuts`에 도달하려면 트리에 포커스가 있어야 한다 — `Focus(autofocus:true)`가 primary focus를 잡는다. 테스트에서 팔레트가 안 열리면 `await tester.pump()` 후 포커스 확보 여부를 확인(systematic-debugging). `enterText`는 검색 뷰의 마지막 `TextField`(뷰 내부 입력창)를 대상으로 `.last` 사용.

- [ ] **Step 7: 전체 analyze + 포맷 + 커밋**

```bash
cd D:/workspace/dpa/devpath-frontend
dart pub global run melos run analyze
dart format packages/dp_design
git add packages/dp_design/lib/src/shell/dp_command.dart packages/dp_design/lib/src/shell/dp_command_palette.dart packages/dp_design/lib/dp_design.dart packages/dp_design/test/shell/dp_command_palette_test.dart
git commit -m "feat(dp_design): DpCommandPalette Ctrl/Cmd+K 명령팔레트 (Phase1, 로드맵 §Phase1)"
```

---

### Task 4: web 셸 이관 — AppShellView → DpAppShell + 명령 팔레트

기존 `AppShell`(라우터)/`AppShellView`(표현부) 분리를 계승. `AppShellView`가 `DpAppShell`을 소비하고, `AppShell`이 `DpCommandPalette`로 감싸 목적지 이동 명령을 주입. `kShellDestinations`·`ShellDestination` 계약 유지. **기존 테스트 3건 보존 + 신규 추가.**

**Files:**
- Modify: `apps/web/lib/src/features/shell/presentation/app_shell.dart`
- Test: `apps/web/test/features/shell/app_shell_view_test.dart` (기존 확장)

**Interfaces:**
- Consumes: `DpAppShell`·`DpCommandPalette`·`OpenCommandPaletteIntent`·`DpDestination`·`DpCommand`·`DpIcons.search`(Task 2·3).
- Preserves: `const List<ShellDestination> kShellDestinations`(변경 금지), `AppShellView({location, child, onSelect})` 공개 API(파라미터 추가는 optional만).

- [ ] **Step 1: 신규 실패 테스트 추가** — `apps/web/test/features/shell/app_shell_view_test.dart`의 `main()` 안에 추가(기존 3 테스트는 유지)

```dart
  testWidgets('중간 폭(600–839)은 접힌 NavigationRail(하단 Bar 아님)', (tester) async {
    _setWidth(tester, 700);
    await tester.pumpWidget(
      _host(const AppShellView(location: '/dashboard', child: Text('본문'))),
    );
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
  });

  testWidgets('Large 폭(≥1240)은 펼친 Rail + 본문 최대폭 제약', (tester) async {
    _setWidth(tester, 1400);
    await tester.pumpWidget(
      _host(const AppShellView(location: '/dashboard', child: Text('본문'))),
    );
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
    expect(find.byType(DpMaxWidth), findsOneWidget);
  });
```

> 기존 테스트(`_setWidth` 390→NavigationBar, 1200→NavigationRail, 멘토 콜백)는 4-클래스 신로직에서도 그대로 통과한다(390=compact→Bar, 1200=expanded→Rail). 수정 불필요.

- [ ] **Step 2: 실패 확인**

Run: `cd apps/web && flutter test test/features/shell/app_shell_view_test.dart`
Expected: 신규 2건 FAIL — `AppShellView`가 아직 `DpMaxWidth`/접힘 Rail을 렌더하지 않음. 기존 3건은 PASS.

- [ ] **Step 3: app_shell.dart 재작성** — `apps/web/lib/src/features/shell/presentation/app_shell.dart` 전체 교체

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
      trailing: Builder(
        builder: (context) => IconButton(
          icon: const Icon(DpIcons.search),
          tooltip: '명령 팔레트 (Ctrl/Cmd+K)',
          onPressed: () =>
              Actions.invoke(context, const OpenCommandPaletteIntent()),
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
```

- [ ] **Step 4: 통과 확인(셸 테스트 5건)**

Run: `cd apps/web && flutter test test/features/shell/app_shell_view_test.dart`
Expected: PASS (기존 3 + 신규 2 = 5).

- [ ] **Step 5: web 전체 회귀 확인**

Run: `cd apps/web && flutter test`
Expected: 전체 PASS(셸 이관이 다른 화면 회귀를 유발하지 않음). 실패 시 근본 원인 분석(systematic-debugging) — 추측 수정 금지.

- [ ] **Step 6: 포맷 + 커밋**

```bash
cd D:/workspace/dpa/devpath-frontend
dart format apps/web/lib/src/features/shell/presentation/app_shell.dart apps/web/test/features/shell/app_shell_view_test.dart
git add apps/web/lib/src/features/shell/presentation/app_shell.dart apps/web/test/features/shell/app_shell_view_test.dart
git commit -m "feat(web): 앱 셸을 DpAppShell·명령팔레트로 이관 (Phase1, kShellDestinations 계약 유지)"
```

---

### Task 5: admin 셸 이관 — AdminShell 분리 → DpAppShell + 명령 팔레트

admin에 표현부 분리 도입(`AdminShell` 라우터 + `AdminShellView` 표현부), `DpAppShell`·`DpCommandPalette` 소비. Large에서 기존 extended rail 동일 유지. `kAdminDestinations` 유지. **admin 최초 셸 테스트 신설.**

**Files:**
- Modify: `apps/admin/lib/src/features/shell/presentation/admin_shell.dart`
- Test: `apps/admin/test/features/shell/admin_shell_view_test.dart` (신설)

**Interfaces:**
- Consumes: `DpAppShell`·`DpCommandPalette`·`OpenCommandPaletteIntent`·`DpDestination`·`DpCommand`·`DpIcons.search`.
- Preserves: `const List<AdminDestination> kAdminDestinations`, `AdminShell({child})`.
- Produces: `class AdminShellView extends StatelessWidget` — `AdminShellView({required String location, required Widget child, void Function(String path)? onSelect})`.

- [ ] **Step 1: 실패 테스트 신설** — `apps/admin/test/features/shell/admin_shell_view_test.dart`

```dart
import 'package:devpath_admin/src/features/shell/presentation/admin_shell.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(theme: DpTheme.light(), home: child);

void _setWidth(WidgetTester tester, double w) {
  tester.view.physicalSize = Size(w, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('Large 폭은 펼친 NavigationRail(extended)', (tester) async {
    _setWidth(tester, 1400);
    await tester.pumpWidget(
      _host(const AdminShellView(location: '/dashboard', child: Text('본문'))),
    );
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
    expect(find.text('운영 콘솔'), findsOneWidget);
  });

  testWidgets('compact 폭은 NavigationBar', (tester) async {
    _setWidth(tester, 500);
    await tester.pumpWidget(
      _host(const AdminShellView(location: '/dashboard', child: Text('본문'))),
    );
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('목적지 선택 시 경로 콜백', (tester) async {
    _setWidth(tester, 500);
    String? picked;
    await tester.pumpWidget(
      _host(AdminShellView(
        location: '/dashboard',
        onSelect: (p) => picked = p,
        child: const Text('본문'),
      )),
    );
    await tester.tap(find.text('광고'));
    expect(picked, '/ads');
  });
}
```

> **주의:** `devpath_admin` 패키지명은 `apps/admin/pubspec.yaml`의 `name:`을 실측해 import 경로를 맞춘다(가정 금지 — CLAUDE.md 절대조건 1). web은 `devpath_web`. 다르면 실제 값으로 교정.

- [ ] **Step 2: 실패 확인**

Run: `cd apps/admin && flutter test test/features/shell/admin_shell_view_test.dart`
Expected: FAIL — `AdminShellView` 미정의.

- [ ] **Step 3: admin_shell.dart 재작성** — `apps/admin/lib/src/features/shell/presentation/admin_shell.dart` 전체 교체

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

typedef AdminDestination = ({String path, IconData icon, String label});

const List<AdminDestination> kAdminDestinations = [
  (path: '/dashboard', icon: DpIcons.dashboard, label: '대시보드'),
  (path: '/users', icon: DpIcons.community, label: '사용자'),
  (path: '/reports', icon: DpIcons.error, label: '신고'),
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
    final i =
        kAdminDestinations.indexWhere((d) => location.startsWith(d.path));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    return DpAppShell(
      selectedIndex: _index,
      onSelect: (i) => onSelect?.call(kAdminDestinations[i].path),
      destinations: [
        for (final d in kAdminDestinations)
          (icon: d.icon, label: d.label, badgeCount: 0),
      ],
      leading: const Padding(
        padding: EdgeInsets.all(DpSpacing.md),
        child: Text('운영 콘솔'),
      ),
      trailing: Builder(
        builder: (context) => IconButton(
          icon: const Icon(DpIcons.search),
          tooltip: '명령 팔레트 (Ctrl/Cmd+K)',
          onPressed: () =>
              Actions.invoke(context, const OpenCommandPaletteIntent()),
        ),
      ),
      body: child,
    );
  }
}
```

- [ ] **Step 4: 통과 확인**

Run: `cd apps/admin && flutter test test/features/shell/admin_shell_view_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: admin 전체 회귀 확인**

Run: `cd apps/admin && flutter test`
Expected: 전체 PASS. 실패 시 근본 원인 분석.

- [ ] **Step 6: 포맷 + 커밋**

```bash
cd D:/workspace/dpa/devpath-frontend
dart format apps/admin/lib/src/features/shell/presentation/admin_shell.dart apps/admin/test/features/shell/admin_shell_view_test.dart
git add apps/admin/lib/src/features/shell/presentation/admin_shell.dart apps/admin/test/features/shell/admin_shell_view_test.dart
git commit -m "feat(admin): 셸을 DpAppShell·명령팔레트로 이관, 표현부 분리 + 최초 셸 테스트 (Phase1)"
```

---

## 최종 검증 (전 Task 완료 후)

- [ ] **모노레포 전체 게이트 통과**

```bash
cd D:/workspace/dpa/devpath-frontend
dart pub global run melos run format   # dart format --set-exit-if-changed . (CI 게이트)
dart pub global run melos run analyze  # flutter/dart analyze
dart pub global run melos run test     # 전체 위젯 테스트
```
Expected: 3개 모두 green. (melos PATH 미설정 시 `dart pub global run melos ...`; 설정 시 `melos run ...`.)

- [ ] **PR 생성** — 브랜치를 push하고 `develop`으로 PR. CI(analyze-test) green 확인 후 머지(2단계 PR 규칙). base=`develop`, 머지=merge commit.

## 수용 기준 매핑 (로드맵 §Phase1 AC ↔ Task)

| 로드맵 AC | 검증 Task |
|---|---|
| web 셸이 Compact/Medium/Expanded/Large에서 의도된 형태(폭별 위젯 테스트) | Task 4 Step 1·4 (+ Task 2 shell 테스트) |
| 기존 `kShellDestinations` 계약 유지 | Task 4 (typedef·상수 불변) |
| Ctrl+K로 팔레트 오픈·Esc 닫힘·방향키 이동 | Task 3 (오픈·필터·실행), Task 4·5 (앱 배선) |
| admin `extended` 유지가 Large에서 동일 | Task 5 Step 1 (`rail.extended isTrue`) |
| hover·focus 상태 시각 구분 | DpAppShell=NavigationRail 기본 상태 스타일 + `FocusTraversalGroup`; DpInteractiveCard(Phase 0) |
| analyze·test green | 최종 검증 |

## Self-Review 결과 (작성자 점검)

- **Spec coverage**: 로드맵 §Phase1 신설 항목(4-클래스 셸·rail 확장/축소·badge·계정 슬롯·FocusTraversalGroup·명령팔레트·web/admin 이관) 모두 Task 매핑됨. 2차 메뉴 ExpansionTile은 Global Constraints에서 YAGNI 근거로 명시적 제외(현재 소비처 없음). §4.3·§4.4 이월분은 Task 1에 흡수.
- **Placeholder scan**: TBD/TODO 없음. 모든 코드·테스트 실체 제공.
- **Type consistency**: `DpDestination`=`({icon,label,badgeCount})`, `DpCommand`=`({id,label,icon,onInvoke})`, `DpAppShell.onSelect`=`ValueChanged<int>`, `OpenCommandPaletteIntent` 공개 — Task 2·3·4·5 전반 일치. `kShellDestinations`/`kAdminDestinations`는 `path` 포함(앱 전용), `DpDestination`은 `path` 미포함(index 기반) — 어댑터에서 변환.
- **실측 확인 완료**: ① 패키지명 `devpath_web`·`devpath_admin`(pubspec `name:` 실측) — 플랜 import 경로 정확. ② `DpTheme._build`가 `extensions: [c, AppTokens.standard]`로 `AppTokens` 등록 확인 — Task 2·5 테스트 `_host`의 `DpTheme.light()`로 충분.
- **후속 개선 여지(가정 금지)**: SearchAnchor 검색 뷰의 키보드 방향키 이동은 focus traversal 기반 — 완전한 arrow-nav(하이라이트 이동+Enter 실행)는 별도 후속 spec 여지. Task 3의 AC는 오픈/필터/선택/Esc로 한정.
