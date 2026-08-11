# UI/UX 고도화 Phase 0 — dp_design 기반 토큰 & 인터랙션 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** dp_design에 이후 모든 웹 고도화 컴포넌트가 소비할 레이아웃 토큰(`AppTokens`), 6상태 스타일 resolver(`DpStateStyle`), 그리고 얇은 래퍼 위젯(`DpMaxWidth`·`DpSelectable`·`DpScrollbar`·`DpInteractiveCard`)을 신설한다.

**Architecture:** 기존 `DpColors`(ThemeExtension)·`DpTheme._build`(`extensions:` 등록)·`context.dpColors` 확장 패턴을 그대로 계승한다. 색과 달리 레이아웃 토큰은 밝기 무관이라 단일 `AppTokens.standard`를 light/dark 양쪽에 등록한다. 래퍼 위젯은 go_router·Riverpod에 비의존하는 순수 표현부다(로드맵 §2.1 Layer 1).

**Tech Stack:** Flutter 3.44 계열, Material 3, `flutter_test`. 외부 패키지 도입 없음(전부 SDK 기본). melos 7 모노레포.

## Global Constraints

- 브랜치: `develop`에서 분기한 `docs/web-admin-uiux-roadmap`의 후속 작업이나, **구현은 별도 브랜치** `feat/uiux-phase0-foundation`(develop에서 분기)에서 진행한다. `main`·`develop` 직접 push 금지.
- 토큰 SSoT는 `DESIGN.md` — 신규 수치는 로드맵 §4와 일치시킨다: `contentMaxWidth=1440`·`readableMaxWidth=880`·`railWidth=256`·`railCollapsedWidth=72`·`panelRadius=10`(=`DpRadius.card`).
- 색은 반드시 `DpColors` 토큰 경유(직접 `Color(0x..)` 신규 지정 금지). 색만으로 의미 전달 금지(selected는 배경, focus는 테두리 병행).
- 장식 그림자·`BackdropFilter` 금지(DESIGN.md §3 — 그림자는 오버레이 전용).
- 테스트는 `flutter_test` + `MaterialApp(theme: DpTheme.light())` 호스트. 실패 테스트를 먼저 쓰고 통과를 눈으로 확인(레포 절대조건 2).
- 검증 명령(패키지 루트 `packages/dp_design`): 분석 `flutter analyze` · 단일 테스트 `flutter test <경로>` · 전체 `flutter test --exclude-tags golden`.
- 코드 스타일: `abstract final class`(정적 토큰), `@immutable` + `ThemeExtension`(테마 토큰), `const` 생성자 StatelessWidget/StatefulWidget. 파일 접두 `dp_`.

---

## 파일 구조

- Create `packages/dp_design/lib/src/theme/dp_tokens.dart` — `AppTokens`(ThemeExtension) + `context.appTokens` 확장.
- Modify `packages/dp_design/lib/src/theme/dp_theme.dart` — `extensions:`에 `AppTokens.standard` 등록.
- Create `packages/dp_design/lib/src/theme/dp_state_style.dart` — `DpStateStyle` 6상태 `WidgetStateProperty` 팩토리.
- Create `packages/dp_design/lib/src/layout/dp_max_width.dart` — `DpMaxWidth`.
- Create `packages/dp_design/lib/src/layout/dp_selectable.dart` — `DpSelectable`.
- Create `packages/dp_design/lib/src/layout/dp_scrollbar.dart` — `DpScrollbar`.
- Create `packages/dp_design/lib/src/interaction/dp_interactive_card.dart` — `DpInteractiveCard`.
- Modify `packages/dp_design/lib/dp_design.dart` — 신규 파일 export.
- Create tests: `test/theme/dp_tokens_test.dart`, `test/theme/dp_state_style_test.dart`, `test/layout/layout_wrappers_test.dart`, `test/interaction/dp_interactive_card_test.dart`.

---

## Task 1: AppTokens (레이아웃 토큰 ThemeExtension)

**Files:**
- Create: `packages/dp_design/lib/src/theme/dp_tokens.dart`
- Modify: `packages/dp_design/lib/src/theme/dp_theme.dart:34`(`extensions: [c]` → `[c, AppTokens.standard]`)
- Modify: `packages/dp_design/lib/dp_design.dart`(export 추가)
- Test: `packages/dp_design/test/theme/dp_tokens_test.dart`

**Interfaces:**
- Consumes: `DpTheme.light()/dark()`, `DpRadius.card`(=10).
- Produces: `AppTokens`(필드 `contentMaxWidth`·`readableMaxWidth`·`railWidth`·`railCollapsedWidth`·`panelRadius`, 모두 `double`), `AppTokens.standard`(const), `BuildContext.appTokens` getter.

- [ ] **Step 1: Write the failing test**

```dart
// packages/dp_design/test/theme/dp_tokens_test.dart
import 'package:dp_design/src/theme/dp_theme.dart';
import 'package:dp_design/src/theme/dp_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('테마는 AppTokens.standard를 주입한다', (tester) async {
    late AppTokens t;
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: Builder(
          builder: (ctx) {
            t = ctx.appTokens;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(t.contentMaxWidth, 1440);
    expect(t.readableMaxWidth, 880);
    expect(t.railWidth, 256);
    expect(t.railCollapsedWidth, 72);
    expect(t.panelRadius, 10);
  });

  testWidgets('다크 테마도 동일 레이아웃 토큰(밝기 무관)', (tester) async {
    late AppTokens t;
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.dark(),
        home: Builder(
          builder: (ctx) {
            t = ctx.appTokens;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(t.railWidth, 256);
  });

  test('lerp는 동일 타입을 반환한다(ThemeExtension 계약)', () {
    final mixed = AppTokens.standard.lerp(AppTokens.standard, 0.5);
    expect(mixed, isA<AppTokens>());
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/dp_design && flutter test test/theme/dp_tokens_test.dart`
Expected: FAIL — `dp_tokens.dart` 없음(`Target of URI doesn't exist`) / `appTokens` 미정의.

- [ ] **Step 3: Write minimal implementation**

```dart
// packages/dp_design/lib/src/theme/dp_tokens.dart
import 'package:flutter/material.dart';

/// 레이아웃 토큰(폭·반경). DESIGN.md §3·§5 + 로드맵 §4.1.
/// 색과 달리 밝기 무관 — light/dark 모두 [standard] 단일값을 쓴다.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.contentMaxWidth,
    required this.readableMaxWidth,
    required this.railWidth,
    required this.railCollapsedWidth,
    required this.panelRadius,
  });

  final double contentMaxWidth;
  final double readableMaxWidth;
  final double railWidth;
  final double railCollapsedWidth;
  final double panelRadius;

  static const standard = AppTokens(
    contentMaxWidth: 1440,
    readableMaxWidth: 880,
    railWidth: 256,
    railCollapsedWidth: 72,
    panelRadius: 10, // = DpRadius.card
  );

  @override
  AppTokens copyWith({
    double? contentMaxWidth,
    double? readableMaxWidth,
    double? railWidth,
    double? railCollapsedWidth,
    double? panelRadius,
  }) => AppTokens(
    contentMaxWidth: contentMaxWidth ?? this.contentMaxWidth,
    readableMaxWidth: readableMaxWidth ?? this.readableMaxWidth,
    railWidth: railWidth ?? this.railWidth,
    railCollapsedWidth: railCollapsedWidth ?? this.railCollapsedWidth,
    panelRadius: panelRadius ?? this.panelRadius,
  );

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      contentMaxWidth:
          _lerp(contentMaxWidth, other.contentMaxWidth, t),
      readableMaxWidth:
          _lerp(readableMaxWidth, other.readableMaxWidth, t),
      railWidth: _lerp(railWidth, other.railWidth, t),
      railCollapsedWidth:
          _lerp(railCollapsedWidth, other.railCollapsedWidth, t),
      panelRadius: _lerp(panelRadius, other.panelRadius, t),
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

/// 토큰 접근 단축: `context.appTokens.contentMaxWidth`.
extension AppTokensX on BuildContext {
  AppTokens get appTokens => Theme.of(this).extension<AppTokens>()!;
}
```

`dp_theme.dart`의 등록부를 수정한다(라인 34 부근):

```dart
// 상단 import 추가
import 'dp_tokens.dart';

// _build 내부 extensions 수정
      extensions: [c, AppTokens.standard],
```

`dp_design.dart`에 export 추가(기존 dp_theme export 아래):

```dart
export 'src/theme/dp_tokens.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/dp_design && flutter test test/theme/dp_tokens_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add packages/dp_design/lib/src/theme/dp_tokens.dart packages/dp_design/lib/src/theme/dp_theme.dart packages/dp_design/lib/dp_design.dart packages/dp_design/test/theme/dp_tokens_test.dart
git commit -m "feat(dp_design): AppTokens 레이아웃 토큰 ThemeExtension 신설"
```

---

## Task 2: DpStateStyle (6상태 WidgetStateProperty 팩토리)

**Files:**
- Create: `packages/dp_design/lib/src/theme/dp_state_style.dart`
- Modify: `packages/dp_design/lib/dp_design.dart`(export 추가)
- Test: `packages/dp_design/test/theme/dp_state_style_test.dart`

**Interfaces:**
- Consumes: `DpColors`(필드 `primary`·`bg`·`border`).
- Produces: `DpStateStyle.navItemBackground(DpColors) → WidgetStateProperty<Color>` (states: `selected`→`primary` 12% 오버레이, `pressed`→`border`, `hovered`→`bg`, 그 외 `Colors.transparent`, `disabled`→`Colors.transparent`).

> 참고: `selected`와 `disabled`가 동시에 오면 `disabled`가 우선(비활성이 선택보다 앞선다).

- [ ] **Step 1: Write the failing test**

```dart
// packages/dp_design/test/theme/dp_state_style_test.dart
import 'package:dp_design/src/theme/dp_colors.dart';
import 'package:dp_design/src/theme/dp_state_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final p = DpStateStyle.navItemBackground(DpColors.light);

  test('selected는 primary 12% 오버레이', () {
    expect(
      p.resolve({WidgetState.selected}),
      DpColors.light.primary.withValues(alpha: 0.12),
    );
  });

  test('hovered는 bg', () {
    expect(p.resolve({WidgetState.hovered}), DpColors.light.bg);
  });

  test('pressed는 border', () {
    expect(p.resolve({WidgetState.pressed}), DpColors.light.border);
  });

  test('기본(무상태)은 투명', () {
    expect(p.resolve(<WidgetState>{}), Colors.transparent);
  });

  test('disabled는 selected보다 우선하여 투명', () {
    expect(
      p.resolve({WidgetState.disabled, WidgetState.selected}),
      Colors.transparent,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/dp_design && flutter test test/theme/dp_state_style_test.dart`
Expected: FAIL — `dp_state_style.dart` 없음.

- [ ] **Step 3: Write minimal implementation**

```dart
// packages/dp_design/lib/src/theme/dp_state_style.dart
import 'package:flutter/material.dart';

import 'dp_colors.dart';

/// 상호작용 6상태(normal/hover/focus/pressed/selected/disabled) 스타일 팩토리.
/// 색은 DpColors 토큰만 사용(로드맵 §4.2). 색만으로 의미 전달 금지 —
/// 소비 위젯은 selected에 굵기/테두리를 병행한다.
abstract final class DpStateStyle {
  /// 내비게이션 항목·리스트 행 배경 오버레이.
  static WidgetStateProperty<Color> navItemBackground(DpColors c) =>
      WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return Colors.transparent;
        if (states.contains(WidgetState.selected)) {
          return c.primary.withValues(alpha: 0.12);
        }
        if (states.contains(WidgetState.pressed)) return c.border;
        if (states.contains(WidgetState.hovered)) return c.bg;
        return Colors.transparent;
      });
}
```

`dp_design.dart`에 export 추가:

```dart
export 'src/theme/dp_state_style.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/dp_design && flutter test test/theme/dp_state_style_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add packages/dp_design/lib/src/theme/dp_state_style.dart packages/dp_design/lib/dp_design.dart packages/dp_design/test/theme/dp_state_style_test.dart
git commit -m "feat(dp_design): DpStateStyle 6상태 배경 오버레이 팩토리"
```

---

## Task 3: 레이아웃/텍스트 래퍼 3종 (DpMaxWidth · DpSelectable · DpScrollbar)

**Files:**
- Create: `packages/dp_design/lib/src/layout/dp_max_width.dart`
- Create: `packages/dp_design/lib/src/layout/dp_selectable.dart`
- Create: `packages/dp_design/lib/src/layout/dp_scrollbar.dart`
- Modify: `packages/dp_design/lib/dp_design.dart`(export 3줄)
- Test: `packages/dp_design/test/layout/layout_wrappers_test.dart`

**Interfaces:**
- Consumes: `BuildContext.appTokens`(Task 1).
- Produces:
  - `DpMaxWidth({required Widget child, double? maxWidth})` — `maxWidth` 생략 시 `context.appTokens.contentMaxWidth` 사용, 상단 중앙 정렬.
  - `DpSelectable({required Widget child})` — `SelectionArea` 래핑.
  - `DpScrollbar({required ScrollController controller, required Widget child})` — `thumbVisibility:true, interactive:true`.

- [ ] **Step 1: Write the failing test**

```dart
// packages/dp_design/test/layout/layout_wrappers_test.dart
import 'package:dp_design/src/layout/dp_max_width.dart';
import 'package:dp_design/src/layout/dp_scrollbar.dart';
import 'package:dp_design/src/layout/dp_selectable.dart';
import 'package:dp_design/src/theme/dp_theme.dart';
import 'package:dp_design/src/theme/dp_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) =>
    MaterialApp(theme: DpTheme.light(), home: Scaffold(body: child));

void main() {
  testWidgets('DpMaxWidth는 maxWidth 미지정 시 contentMaxWidth로 제약', (tester) async {
    await tester.pumpWidget(_host(const DpMaxWidth(child: Text('본문'))));
    final box = tester.widget<ConstrainedBox>(
      find.descendant(
        of: find.byType(DpMaxWidth),
        matching: find.byType(ConstrainedBox),
      ).first,
    );
    expect(box.constraints.maxWidth, AppTokens.standard.contentMaxWidth);
    expect(find.text('본문'), findsOneWidget);
  });

  testWidgets('DpMaxWidth는 명시 maxWidth를 우선한다', (tester) async {
    await tester.pumpWidget(
      _host(const DpMaxWidth(maxWidth: 600, child: Text('좁게'))),
    );
    final box = tester.widget<ConstrainedBox>(
      find.descendant(
        of: find.byType(DpMaxWidth),
        matching: find.byType(ConstrainedBox),
      ).first,
    );
    expect(box.constraints.maxWidth, 600);
  });

  testWidgets('DpSelectable은 SelectionArea로 감싼다', (tester) async {
    await tester.pumpWidget(_host(const DpSelectable(child: Text('선택가능'))));
    expect(find.byType(SelectionArea), findsOneWidget);
    expect(find.text('선택가능'), findsOneWidget);
  });

  testWidgets('DpScrollbar는 thumbVisibility=true로 Scrollbar를 구성', (tester) async {
    final ctrl = ScrollController();
    addTearDown(ctrl.dispose);
    await tester.pumpWidget(
      _host(
        DpScrollbar(
          controller: ctrl,
          child: ListView(
            controller: ctrl,
            children: const [SizedBox(height: 2000)],
          ),
        ),
      ),
    );
    final bar = tester.widget<Scrollbar>(find.byType(Scrollbar));
    expect(bar.thumbVisibility, isTrue);
    expect(bar.controller, same(ctrl));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/dp_design && flutter test test/layout/layout_wrappers_test.dart`
Expected: FAIL — layout 파일 3종 없음.

- [ ] **Step 3: Write minimal implementation**

```dart
// packages/dp_design/lib/src/layout/dp_max_width.dart
import 'package:flutter/material.dart';

import '../theme/dp_tokens.dart';

/// 웹 본문이 큰 화면에서 전체 폭으로 퍼지지 않도록 상단 중앙에 최대폭 제약.
/// (로드맵 §2.2·안티패턴 "전체 너비 확장" 대응.)
class DpMaxWidth extends StatelessWidget {
  const DpMaxWidth({super.key, required this.child, this.maxWidth});

  final Widget child;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final w = maxWidth ?? context.appTokens.contentMaxWidth;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: w),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}
```

```dart
// packages/dp_design/lib/src/layout/dp_selectable.dart
import 'package:flutter/material.dart';

/// 본문 텍스트를 브라우저처럼 선택 가능하게 만든다(웹 완성도).
/// 버튼·내비 등 비선택 영역은 감싸지 않는다.
class DpSelectable extends StatelessWidget {
  const DpSelectable({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SelectionArea(child: child);
}
```

```dart
// packages/dp_design/lib/src/layout/dp_scrollbar.dart
import 'package:flutter/material.dart';

/// 웹/데스크톱 스크롤바를 항상 표시(특히 가로 스크롤 탐색성).
/// 스크롤 영역과 동일한 [controller]를 반드시 공유한다.
class DpScrollbar extends StatelessWidget {
  const DpScrollbar({
    super.key,
    required this.controller,
    required this.child,
  });

  final ScrollController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scrollbar(
    controller: controller,
    thumbVisibility: true,
    interactive: true,
    child: child,
  );
}
```

`dp_design.dart`에 export 3줄 추가:

```dart
export 'src/layout/dp_max_width.dart';
export 'src/layout/dp_selectable.dart';
export 'src/layout/dp_scrollbar.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/dp_design && flutter test test/layout/layout_wrappers_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add packages/dp_design/lib/src/layout/ packages/dp_design/lib/dp_design.dart packages/dp_design/test/layout/layout_wrappers_test.dart
git commit -m "feat(dp_design): 레이아웃 래퍼 3종(DpMaxWidth·DpSelectable·DpScrollbar)"
```

---

## Task 4: DpInteractiveCard (hover/focus/click 베이스)

**Files:**
- Create: `packages/dp_design/lib/src/interaction/dp_interactive_card.dart`
- Modify: `packages/dp_design/lib/dp_design.dart`(export 추가)
- Test: `packages/dp_design/test/interaction/dp_interactive_card_test.dart`

**Interfaces:**
- Consumes: `BuildContext.appTokens`(Task 1, `panelRadius`), `BuildContext.dpColors`(기존, `border`·`primary`).
- Produces: `DpInteractiveCard({required Widget child, VoidCallback? onTap, double? borderRadius})` — `FocusableActionDetector` → `Material`(투명) → `InkWell` 계층. 클릭·키보드 접근 모두 지원. hover 시 테두리 `border`→`primary`, focus 시 2px `primary` 테두리.

> 왜 StatefulWidget인가: hover/focus 하이라이트를 `setState`로 반영해야 하므로. `GestureDetector` 단독 금지(키보드 접근 불가 — 안티패턴).

- [ ] **Step 1: Write the failing test**

```dart
// packages/dp_design/test/interaction/dp_interactive_card_test.dart
import 'package:dp_design/src/interaction/dp_interactive_card.dart';
import 'package:dp_design/src/theme/dp_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) =>
    MaterialApp(theme: DpTheme.light(), home: Scaffold(body: child));

void main() {
  testWidgets('탭하면 onTap을 호출한다', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _host(
        DpInteractiveCard(
          onTap: () => tapped = true,
          child: const Text('카드'),
        ),
      ),
    );
    await tester.tap(find.text('카드'));
    expect(tapped, isTrue);
  });

  testWidgets('키보드 접근성을 위해 FocusableActionDetector와 InkWell을 포함', (tester) async {
    await tester.pumpWidget(
      _host(DpInteractiveCard(onTap: () {}, child: const Text('카드'))),
    );
    expect(find.byType(FocusableActionDetector), findsOneWidget);
    expect(find.byType(InkWell), findsOneWidget);
  });

  testWidgets('onTap이 null이면 InkWell은 비활성(탭 무동작)', (tester) async {
    await tester.pumpWidget(
      _host(const DpInteractiveCard(child: Text('정적')),),
    );
    final inkwell = tester.widget<InkWell>(find.byType(InkWell));
    expect(inkwell.onTap, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/dp_design && flutter test test/interaction/dp_interactive_card_test.dart`
Expected: FAIL — `dp_interactive_card.dart` 없음.

- [ ] **Step 3: Write minimal implementation**

```dart
// packages/dp_design/lib/src/interaction/dp_interactive_card.dart
import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_tokens.dart';

/// 클릭 가능한 커스텀 카드의 웹 표준 베이스.
/// FocusableActionDetector(hover+focus+키보드) → Material(투명) → InkWell(리플).
/// GestureDetector 단독 사용을 대체한다(키보드 사용자 접근 보장).
class DpInteractiveCard extends StatefulWidget {
  const DpInteractiveCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final VoidCallback? onTap;
  final double? borderRadius;
  final EdgeInsetsGeometry padding;

  @override
  State<DpInteractiveCard> createState() => _DpInteractiveCardState();
}

class _DpInteractiveCardState extends State<DpInteractiveCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final radius = BorderRadius.circular(
      widget.borderRadius ?? context.appTokens.panelRadius,
    );

    final Color borderColor;
    final double borderWidth;
    if (_focused) {
      borderColor = c.primary;
      borderWidth = 2;
    } else if (_hovered) {
      borderColor = c.primary;
      borderWidth = 1;
    } else {
      borderColor = c.border;
      borderWidth = 1;
    }

    return FocusableActionDetector(
      enabled: widget.onTap != null,
      mouseCursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onShowHoverHighlight: (v) => setState(() => _hovered = v),
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: radius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: borderColor, width: borderWidth),
            ),
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}
```

`dp_design.dart`에 export 추가:

```dart
export 'src/interaction/dp_interactive_card.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/dp_design && flutter test test/interaction/dp_interactive_card_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add packages/dp_design/lib/src/interaction/ packages/dp_design/lib/dp_design.dart packages/dp_design/test/interaction/dp_interactive_card_test.dart
git commit -m "feat(dp_design): DpInteractiveCard hover/focus/click 베이스"
```

---

## Task 5: 전체 검증 & DESIGN.md 토큰 반영

**Files:**
- Modify: `DESIGN.md`(§3 라운드·§5 반응형 절에 신규 레이아웃 토큰 표 추가)
- Test: 전체 스위트 재실행

**Interfaces:**
- Consumes: Task 1~4 산출 전부.
- Produces: 없음(문서·검증 게이트).

- [ ] **Step 1: dp_design 전체 분석·테스트**

Run: `cd packages/dp_design && flutter analyze`
Expected: `No issues found!`

Run: `cd packages/dp_design && flutter test --exclude-tags golden`
Expected: 전체 PASS(신규 4파일 포함, 기존 테스트 회귀 없음).

- [ ] **Step 2: 모노레포 전역 회귀 확인(다운스트림 컴파일)**

Run(모노레포 루트): `dart pub global run melos run analyze`
Expected: web·admin 포함 전 멤버 분석 통과(dp_design export 변경이 앱을 깨지 않음).

- [ ] **Step 3: DESIGN.md에 레이아웃 토큰 반영**

`DESIGN.md` §3(간격·라운드·고도) 끝에 추가:

```markdown
**레이아웃 토큰(AppTokens — 밝기 무관)**
| 토큰 | 값 | 용도 |
|---|---|---|
| `contentMaxWidth` | 1440 | Large 본문 최대 폭 |
| `readableMaxWidth` | 880 | 문서·상세 읽기 폭 |
| `railWidth` | 256 | 확장 rail 폭 |
| `railCollapsedWidth` | 72 | Medium 접힘 rail 폭 |
| `panelRadius` | 10 | 패널 반경(=카드) |

> 소비: `context.appTokens`. 최대폭 제약은 `DpMaxWidth`, 상태 스타일은 `DpStateStyle`, 클릭 카드 베이스는 `DpInteractiveCard`.
```

- [ ] **Step 4: 최종 커밋**

```bash
git add DESIGN.md
git commit -m "docs(dp_design): DESIGN.md에 AppTokens 레이아웃 토큰 반영"
```

- [ ] **Step 5: PR 생성(develop 대상)**

```bash
git push -u origin feat/uiux-phase0-foundation
gh pr create --base develop --title "feat(dp_design): UI/UX Phase 0 — 기반 토큰 & 인터랙션" --body "로드맵 Phase 0. AppTokens·DpStateStyle·레이아웃 래퍼 3종·DpInteractiveCard 신설. 전부 SDK 기본, 외부 의존 없음. 다음: Phase 1 앱 셸."
```

CI(analyze·test) green 확인 후에만 머지(레포 절대조건 5).

---

## Self-Review 결과 (작성자 확인)

- **Spec 커버리지**: 로드맵 §5 Phase 0의 신설 항목(AppTokens / WidgetState resolver / DpMaxWidth / DpSelectable / Scrollbar 정책 / DpInteractiveCard)을 Task 1~4가 각각 구현. DESIGN.md 반영은 Task 5. AC(테마 등록·6상태·폭별·green)는 각 Task Step에 매핑됨.
- **플레이스홀더**: 없음(모든 코드·테스트 실체 포함).
- **타입 일관성**: `AppTokens`(Task 1) 필드명이 Task 3(`contentMaxWidth`)·Task 4(`panelRadius`)에서 동일하게 소비됨. `DpStateStyle.navItemBackground`는 Phase 1(내비)에서 소비 예정(이 플랜 내 미소비이나 Produces에 명시). `context.appTokens`·`context.dpColors` getter명 일치.
- **범위 밖 확인**: WidgetState resolver는 현재 `navItemBackground` 하나만 신설(YAGNI — 실제 소비처가 생기는 Phase 1/3에서 리스트 행·버튼용 resolver를 필요 시 확장).
