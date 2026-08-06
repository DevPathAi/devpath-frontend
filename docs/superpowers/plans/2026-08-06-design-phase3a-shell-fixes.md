# ①디자인 3-A 구현 계획 — 셸 결함 해소 + `tag*` 배선

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 2단계 셸이 남긴 결함 11건을 해소하고, 1단계가 정의만 해둔 `tagBg`/`tagText`를 `DpTag` 단일 지점으로 배선한다.

**Architecture:** 브랜드 슬롯을 Widget에서 **데이터**(`DpRailBrand`)로 좁혀 앱이 색을 실을 통로 자체를 없앤다. 크롬바 액션도 같은 이유로 `DpChromeAction` 데이터형이 되어 오버플로 시 메뉴로 접힌다. 페이지 헤더는 「문서형=스크롤 / 뷰포트 고정형=고정」 규칙으로 갈린다. 다크 레일 팔레트는 5개 토큰을 함께 재조정한다.

**Tech Stack:** Flutter 3.44 · Dart pub workspaces + melos 7 · `flutter_test` · `flutter_riverpod` · go_router

## Global Constraints

- **melos는 PATH에 없다** — 항상 `dart pub global run melos run <cmd>`로 호출한다
- **`python`은 이 환경에서 스텁이다**(조용히 무동작, rc 0) — 대비 스크립트는 반드시 `py`로 실행한다
- **테스트를 먼저 쓴다**(레포 CLAUDE.md 절대조건 2). 실패를 눈으로 확인한 뒤 구현한다
- **`context.dpColors`를 쓰는 위젯의 테스트에는 `theme: DpTheme.light()`(또는 `.dark()`)를 반드시 공급한다** — 없으면 null-check 크래시. 2단계 Task 7·8·9에서 이 전제 누락이 세 번 반복됐다
- **단언은 `find.text()`가 아니라 `tester.widget<T>(…)`로 위젯 필드를 읽는다** — 브레드크럼 마지막 세그먼트·헤더 제목·레일 라벨이 **의도적으로 같은 문자열**이라 셸 포함 렌더 시 `findsOneWidget`이 깨진다
- **폭 의존 테스트는 `tester.view.physicalSize`·`devicePixelRatio`를 설정하고 `addTearDown(tester.view.reset)`으로 되돌린다**
- **`Row`/`Column` 예시 코드는 flex 소속을 명시한다** — non-flex 자식은 무한 주축 제약으로 측정되어 `ellipsis`가 발동하지 않는다(2단계 계획이 이 함정을 세 번 반복했다)
- 커밋은 Conventional Commits. 각 Task 끝에서 커밋한다
- **기준선(2단계 종료 시점):** web 321 · admin 60 · dp_design 134 · mobile 100 · dp_core 97 전부 green, `analyze` 이슈 0, `format` clean, 대비 미달 0건

---

## Task 1: `DpRailBrand` 데이터형과 `DpNavRail` 배선

브랜드 전경색 함정을 구조적으로 닫고, 접힘 레일에서 마크가 살아남게 한다.

**Files:**
- Create: `packages/dp_design/lib/src/shell/dp_rail_brand.dart`
- Modify: `packages/dp_design/lib/src/shell/dp_nav_rail.dart:19,31,52,84-106`
- Modify: `packages/dp_design/lib/dp_design.dart` (export 추가)
- Test: `packages/dp_design/test/shell/dp_rail_brand_test.dart`

**Interfaces:**
- Produces: `class DpRailBrand { const DpRailBrand({required Widget mark, required String wordmark}); final Widget mark; final String wordmark; }`
- Produces: `DpNavRail.brand`의 타입이 `Widget?` → `DpRailBrand?`로 바뀐다 (Task 2가 호출부를 고친다)

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`packages/dp_design/test/shell/dp_rail_brand_test.dart`:

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Flutter의 effectiveTextStyle을 재현한다 — Text는 style.inherit==true일 때
/// DefaultTextStyle.of(context).style.merge(style)로 최종 스타일을 만든다.
/// merge는 인자 쪽 non-null을 취하므로, 앱이 색을 실은 스타일을 넘기면
/// 컴포넌트가 깐 railText가 진다. 2단계에서 이 결함이 319/319 green으로
/// 통과했다(라이트 textPrimary == railBg → 대비 1.00:1).
Color effectiveColorOf(WidgetTester tester, Finder finder) {
  final element = tester.element(finder);
  final widget = tester.widget<Text>(finder);
  final base = DefaultTextStyle.of(element).style;
  return base.merge(widget.style).color!;
}

void main() {
  Widget host(DpColors colors, ThemeData theme, {required bool extended}) =>
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: DpNavRail(
            destinations: const [
              DpDestination(icon: Icons.home, label: '대시보드'),
            ],
            selectedIndex: 0,
            onSelect: (_) {},
            extended: extended,
            brand: DpRailBrand(
              mark: Container(
                key: const ValueKey('brand-mark'),
                width: 22,
                height: 22,
              ),
              wordmark: 'DevPath',
            ),
          ),
        ),
      );

  testWidgets('펼침에서 워드마크 실효색이 railText다 (라이트)', (tester) async {
    final theme = DpTheme.light();
    await tester.pumpWidget(host(DpColors.light, theme, extended: true));

    final color = effectiveColorOf(tester, find.text('DevPath'));
    expect(color, DpColors.light.railText);
  });

  testWidgets('펼침에서 워드마크 실효색이 railText다 (다크)', (tester) async {
    final theme = DpTheme.dark();
    await tester.pumpWidget(host(DpColors.dark, theme, extended: true));

    final color = effectiveColorOf(tester, find.text('DevPath'));
    expect(color, DpColors.dark.railText);
  });

  testWidgets('접힘에서 마크는 남고 워드마크는 사라진다', (tester) async {
    await tester.pumpWidget(
      host(DpColors.light, DpTheme.light(), extended: false),
    );

    expect(find.byKey(const ValueKey('brand-mark')), findsOneWidget);
    expect(find.text('DevPath'), findsNothing);
  });
}
```

**주의:** `DpColors.light`/`DpColors.dark`의 실제 접근자 이름을 `dp_colors.dart`에서 먼저 확인하고 맞춘다. `DpTheme.light()`가 `DpColors`를 어떻게 싣는지도 확인한다(테스트가 색을 직접 참조하려면 같은 출처여야 한다).

- [ ] **Step 2: 테스트가 실패하는지 확인한다**

```
cd packages/dp_design && flutter test test/shell/dp_rail_brand_test.dart
```

Expected: 컴파일 에러 — `DpRailBrand` 미정의.

- [ ] **Step 3: `DpRailBrand`를 만든다**

`packages/dp_design/lib/src/shell/dp_rail_brand.dart`:

```dart
import 'package:flutter/widgets.dart';

/// 레일 브랜드 **데이터**. 위젯이 아니다.
///
/// 앱이 TextStyle을 넘길 통로를 두지 않는 것이 이 타입의 존재 이유다.
/// DpTheme가 textTheme.apply(bodyColor: textPrimary)를 하므로 모든 타이포
/// 스케일이 non-null color를 품는다. 앱이 Text를 만들어 넘기면 그 색이
/// DefaultTextStyle.merge에서 이겨, 컴포넌트가 공급한 railText가 진다.
/// 라이트 팔레트는 textPrimary == railBg라 브랜드가 완전히 사라진다.
///
/// 위젯으로 만들지 않은 이유: extended를 전달할 경로가 필요해지고,
/// 그 경로가 다시 앱이 스타일을 실을 틈이 된다.
class DpRailBrand {
  const DpRailBrand({required this.mark, required this.wordmark});

  /// 접힘 상태에서도 남는 로고 마크.
  final Widget mark;

  /// 펼침 상태에서만 보이는 워드마크. String이므로 스타일을 실을 수 없다.
  final String wordmark;
}
```

`packages/dp_design/lib/dp_design.dart`에 export를 추가한다(기존 shell export들 옆).

- [ ] **Step 4: `DpNavRail`을 고친다**

`dp_nav_rail.dart`에서:

1. `import 'dp_rail_brand.dart';` 추가
2. 필드 타입 변경: `final Widget? brand;` → `final DpRailBrand? brand;`
3. `_buildTop`을 아래로 교체한다 — **`extended &&` 조건이 사라지고**, 워드마크를 컴포넌트가 직접 만든다:

```dart
  Widget _buildTop(BuildContext context, DpColors c) {
    final b = brand;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DpSpacing.md,
        DpSpacing.md,
        DpSpacing.sm,
        DpSpacing.sm,
      ),
      child: Row(
        children: [
          if (b != null) ...[
            // 마크는 접힘에서도 남는다 — 2단계에서는 extended 조건 안에
            // 함께 묶여 있어 접히면 브랜드가 통째로 사라졌다.
            b.mark,
            if (extended) ...[
              const SizedBox(width: DpSpacing.sm),
              // Expanded(flex 참여)로 감싼다 — non-flex Text는 무한 주축
              // 제약으로 측정되어 ellipsis가 발동하지 않는다.
              Expanded(
                child: Text(
                  b.wordmark,
                  overflow: TextOverflow.ellipsis,
                  // 색을 여기서 확정한다. 앱은 문자열만 주므로 이 색이
                  // merge에서 질 상대가 없다.
                  style: text.titleSmall?.copyWith(color: c.railText),
                ),
              ),
            ],
          ],
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
  }
```

4. `build`의 `if (brand != null || onToggle != null) _buildTop(context, c),`는 그대로 둔다.
5. `_withRailForeground`는 `account` 슬롯에서 계속 쓰이므로 **삭제하지 않는다.**

- [ ] **Step 5: 테스트가 통과하는지 확인한다**

```
cd packages/dp_design && flutter test test/shell/dp_rail_brand_test.dart
```

Expected: 3건 PASS.

- [ ] **Step 6: dp_design 전체 테스트를 돌린다**

```
cd packages/dp_design && flutter test
```

기존 `DpNavRail` 테스트가 `brand:`에 Widget을 넘기고 있으면 컴파일 에러가 난다. **테스트를 완화하지 말고** `DpRailBrand(mark: …, wordmark: …)`로 고친다.

- [ ] **Step 7: 커밋**

```bash
git add packages/dp_design/lib/src/shell/dp_rail_brand.dart packages/dp_design/lib/src/shell/dp_nav_rail.dart packages/dp_design/lib/dp_design.dart packages/dp_design/test/
git commit -m "feat(dp_design): DpRailBrand로 브랜드 전경색 함정을 구조적으로 닫는다"
```

---

## Task 2: web·admin 셸의 brand 호출부 교체

**Files:**
- Modify: `apps/web/lib/src/features/shell/presentation/app_shell.dart:130-160`
- Modify: `apps/admin/lib/src/features/shell/presentation/admin_shell.dart:81-95`
- Test: `apps/web/test/features/shell/app_shell_brand_test.dart` (기존 파일이 있으면 그것을 수정)

**Interfaces:**
- Consumes: Task 1의 `DpRailBrand({required Widget mark, required String wordmark})`

- [ ] **Step 1: 기존 브랜드 색 테스트를 찾는다**

```
cd apps/web && grep -rn "railText" test/
cd apps/admin && grep -rn "railText" test/
```

2단계에서 넣은 실효색 단언 테스트가 있다. **그 테스트가 새 구조에서도 유효한지 확인하고, `DpRailBrand` 기준으로 고친다.** 없다면 Task 1의 `effectiveColorOf` 헬퍼를 복사해 web·admin 각 1건씩 새로 쓴다.

- [ ] **Step 2: web 셸을 고친다**

`app_shell.dart`의 `brand:` 인자를 아래로 교체한다. **긴 주석 블록(색을 명시해야 하는 이유)은 삭제한다** — `DpRailBrand`가 그 이유를 구조로 해소했으므로 주석이 사실과 어긋나게 된다.

```dart
      brand: DpRailBrand(
        mark: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: c.primary,
            borderRadius: BorderRadius.circular(DpRadius.button),
          ),
        ),
        wordmark: 'DevPath',
      ),
```

`final text = Theme.of(context).textTheme;`가 이 파일에서 더는 쓰이지 않으면 지운다(`analyze` 경고 방지).

- [ ] **Step 3: admin 셸을 고친다**

`admin_shell.dart`의 `brand:`를 교체한다. admin은 지금 마크가 없고 텍스트만 있다 — **web과 같은 마크를 준다**(접힘에서 브랜드가 완전히 사라지지 않게 하려면 마크가 필요하다):

```dart
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
```

여기서도 긴 주석 블록을 삭제한다.

- [ ] **Step 4: 테스트를 돌린다**

```
cd apps/web && flutter test
cd apps/admin && flutter test
```

Expected: 전부 PASS (web 321 이상 · admin 60 이상).

- [ ] **Step 5: 커밋**

```bash
git add apps/web apps/admin
git commit -m "refactor(web,admin): 셸 브랜드를 DpRailBrand로 교체한다"
```

---

## Task 3: 다크 레일 팔레트 재조정

**Files:**
- Modify: `packages/dp_design/lib/src/theme/dp_colors.dart:160-165` (다크 rail* 5개)
- Modify: `docs/superpowers/specs/2026-08-03-token-contrast-check.py:30-31` (D 딕셔너리)
- Test: `packages/dp_design/test/shell/dp_nav_rail_dark_test.dart`

**Interfaces:**
- Produces: 다크 `railBg`·`railActive`·`railBorder`·`railFaint`·`railMuted` 새 값. 다른 Task는 토큰 이름만 참조하므로 영향 없다.

### ★계산으로 확정된 값 — 임의로 바꾸지 마라★

**스펙 §5.2의 「본문보다 어둡게 내린다」는 계산으로 반증됐다.** 다크 `bg`가 이미 `#0F0E0C`라 아래로 여지가 없다:

| railBg 후보 | vs `bg` 분리 |
|---|---|
| `#131210` (현재) | 1.031 |
| `#0A0908` | 1.031 |
| `#000000` (순검정) | 1.088 |
| **`#221E1A` (채택)** | **1.166** |

순검정까지 내려도 1.088에 그친다. **분리감은 밝히는 방향에서만 나온다.** 다만 밝히면 `railActive`(선택 배경)가 레일 배경에 묻히고(`#231F1B` vs `#221E1A` = 1.01) `railFaint`가 4.5 미달로 떨어지므로 **5개 토큰을 함께 조정한다.**

| 토큰 | 현재 | 새 값 | 근거 |
|---|---|---|---|
| `railBg` | `#131210` | `#221E1A` | vs `bg` 1.031 → **1.166** |
| `railActive` | `#231F1B` | `#332E28` | vs 새 `railBg` **1.231** (현재 1.144) |
| `railBorder` | `#2A2621` | `#3A342D` | vs 새 `railBg` **1.347** (현재 1.246) |
| `railFaint` | `#8A837B` | `#9A938A` | on 새 `railBg` **5.45** (미조정 시 4.49 → 미달) |
| `railMuted` | `#948D85` | `#A09991` | on 새 `railBg` **5.88**, 다크 `textSecondary`와 같은 값이라 일관 |
| `railText` | `#EAE7E2` | **변경 없음** | on 새 `railBg` 13.42 |

**라이트 팔레트는 건드리지 않는다.**

- [ ] **Step 1: 다크 렌더 red-repro를 쓴다**

`packages/dp_design/test/shell/dp_nav_rail_dark_test.dart`:

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('다크에서 레일 배경이 본문 배경과 구별된다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.dark(),
        home: Scaffold(
          body: DpNavRail(
            destinations: const [
              DpDestination(icon: Icons.home, label: '대시보드'),
            ],
            selectedIndex: 0,
            onSelect: (_) {},
          ),
        ),
      ),
    );

    final container = tester.widget<Container>(
      find.byKey(const ValueKey('rail-root')),
    );
    final decoration = container.decoration! as BoxDecoration;

    // 레일이 본문 배경과 같은 계열이면 「잉크 레일」의 분리감이 사라진다.
    expect(decoration.color, isNot(DpColors.dark.bg));
    expect(decoration.color, DpColors.dark.railBg);
    // 밝히는 방향으로 분리한다(계산: 어둡게는 순검정에서도 1.088에 그친다).
    expect(
      DpColors.dark.railBg.computeLuminance(),
      greaterThan(DpColors.dark.bg.computeLuminance()),
    );
  });

  testWidgets('다크에서 선택 항목 배경이 레일 배경과 구별된다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.dark(),
        home: Scaffold(
          body: DpNavRail(
            destinations: const [
              DpDestination(icon: Icons.home, label: '대시보드'),
              DpDestination(icon: Icons.map, label: '학습 경로'),
            ],
            selectedIndex: 0,
            onSelect: (_) {},
          ),
        ),
      ),
    );

    final selected = tester.widget<Container>(
      find.byKey(const ValueKey('rail-item-0')),
    );
    final decoration = selected.decoration! as BoxDecoration;
    expect(decoration.color, DpColors.dark.railActive);
    expect(decoration.color, isNot(DpColors.dark.railBg));

    // 값이 다르기만 해서는 부족하다 — 육안으로 구별돼야 한다.
    final lumActive = DpColors.dark.railActive.computeLuminance();
    final lumBg = DpColors.dark.railBg.computeLuminance();
    final contrast =
        (lumActive > lumBg ? (lumActive + 0.05) / (lumBg + 0.05)
                           : (lumBg + 0.05) / (lumActive + 0.05));
    expect(contrast, greaterThan(1.2));
  });
}
```

- [ ] **Step 2: 테스트가 실패하는지, 어떤 수치로 실패하는지 확인한다**

```
cd packages/dp_design && flutter test test/shell/dp_nav_rail_dark_test.dart
```

Expected: 첫 테스트는 `railBg` 휘도가 `bg`보다 **낮아** FAIL. 둘째는 contrast 1.144로 FAIL.

**실패 수치를 읽어라.** 2단계에서 통과 여부만 보다가 브레드크럼 원인을 오진했고, 실패값(8.0 vs 99.75)을 보고서야 진짜 원인을 찾았다.

- [ ] **Step 3: 다크 토큰 5개를 바꾼다**

`dp_colors.dart`의 다크 팔레트에서:

```dart
    railBg: Color(0xFF221E1A),
    railText: Color(0xFFEAE7E2),
    railMuted: Color(0xFFA09991),
    railFaint: Color(0xFF9A938A),
    railActive: Color(0xFF332E28),
    railBorder: Color(0xFF3A342D),
```

- [ ] **Step 4: 대비 스크립트의 다크 딕셔너리를 같이 고친다**

`docs/superpowers/specs/2026-08-03-token-contrast-check.py`의 `D` 딕셔너리에서 `railBg`·`railMuted`·`railFaint`·`railActive`를 같은 값으로 갱신한다. **스크립트가 hex를 하드코딩하고 있으므로 이걸 잊으면 검증이 옛 값을 계속 통과시킨다.**

- [ ] **Step 5: 대비 스크립트를 돌린다**

```
py docs/superpowers/specs/2026-08-03-token-contrast-check.py
```

Expected: **미달 0건.** (`python`이 아니라 `py`다 — `python`은 이 환경에서 스텁이라 조용히 아무것도 하지 않는다.)

- [ ] **Step 6: 테스트를 돌린다**

```
cd packages/dp_design && flutter test
```

Expected: 새 다크 테스트 2건 PASS + 기존 전부 PASS.

- [ ] **Step 7: 다크 `railText == textPrimary` 우연 일치를 확인하고 기록한다**

다크에서 `railText`(`#EAE7E2`)와 `textPrimary`(`#EAE7E2`)는 **여전히 같은 값이다.** 이 때문에 Task 1의 다크 실효색 테스트는 「색이 맞아서」가 아니라 「우연히 같아서」 통과할 수 있다. 값을 바꾸지는 말고, `dp_rail_brand_test.dart`의 다크 테스트에 주석으로 명시한다:

```dart
    // 주의: 다크 팔레트는 textPrimary == railText(#EAE7E2)라 이 단언은
    // 현재 가드로서 무력하다 — 함정이 재발해도 통과한다. 라이트 분기가
    // 실질 가드다. 다크 팔레트에서 두 값이 갈리면 이 주석을 지워라.
```

- [ ] **Step 8: 커밋**

```bash
git add packages/dp_design docs/superpowers/specs/2026-08-03-token-contrast-check.py
git commit -m "fix(dp_design): 다크 레일 팔레트를 본문과 분리되게 재조정한다"
```

---

## Task 4: `DpChromeAction`과 크롬바 그룹 축약 (I2)

**Files:**
- Create: `packages/dp_design/lib/src/shell/dp_chrome_action.dart`
- Modify: `packages/dp_design/lib/src/shell/dp_chrome_bar.dart:24,34,50-62,96-111`
- Modify: `packages/dp_design/lib/src/shell/dp_app_shell.dart:29,47` (`chromeActions` 타입)
- Modify: `packages/dp_design/lib/dp_design.dart`
- Modify: `apps/web/lib/src/features/shell/presentation/app_shell.dart:167-176`
- Test: `packages/dp_design/test/shell/dp_chrome_bar_overflow_test.dart`

**Interfaces:**
- Produces: `class DpChromeAction { const DpChromeAction({required IconData icon, required String label, required void Function(BuildContext context) onPressed}); }`
  - **`onPressed`가 `BuildContext`를 받는 이유:** web의 오류 신고 액션이 `showSupportDialog(context)`를 호출하는데, 데이터형으로 바꾸면 앱 쪽엔 쓸 수 있는 context가 없다. `DpChromeBar`가 자기 `context`를 넘겨준다. `VoidCallback`으로 정의하면 호출부가 전역 context를 잡아야 해서 안 된다
- Produces: `DpChromeBar.actions`·`DpAppShell.chromeActions`의 타입이 `List<Widget>` → `List<DpChromeAction>`

### ★테스트 조건 규칙 — 2단계 교훈★

2단계 우측 정렬 테스트는 **60자짜리 인위적 crumbs를 써야만 통과**했고, 그 조건을 자기 주석에 적어두고도 「범위 밖」으로 분류했다. 실제 앱 crumbs는 짧아 항상 결함 경로를 탔다.

- **정당한 조건**: `DpChromeBar`에 actions를 N개 주입하는 것 — 공개 API가 임의 개수를 받으므로 **컴포넌트 계약 그 자체**다
- **금지**: 특정 폭에서만 통과하도록 crumbs·라벨 길이를 조정하는 것
- 「이 테스트는 X 없이 Y만 검증한다」는 주석을 쓰게 되면 멈추고 물어라 — X가 실제로는 항상 참인 조건이 아닌가?

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`packages/dp_design/test/shell/dp_chrome_bar_overflow_test.dart`:

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({required int actionCount, required List<DpCrumb> crumbs}) =>
      MaterialApp(
        theme: DpTheme.light(),
        home: Scaffold(
          body: DpChromeBar(
            breadcrumb: crumbs,
            onSearchTap: () {},
            actions: [
              for (var i = 0; i < actionCount; i++)
                DpChromeAction(
                  icon: Icons.star,
                  label: '액션 $i',
                  onPressed: (_) {},
                ),
            ],
            account: const Icon(Icons.person),
          ),
        ),
      );

  // 실제 앱 crumbs 길이를 쓴다. 값을 늘려 조건을 피해 가지 않는다.
  const crumbs = <DpCrumb>[
    (label: '커뮤니티', path: null),
    (label: '게시판', path: '/community'),
  ];

  for (final width in [500.0, 700.0, 1000.0, 1400.0]) {
    testWidgets('폭 $width에서 액션 8개를 줘도 오버플로하지 않는다', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(host(actionCount: 8, crumbs: crumbs));

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('액션이 폭을 넘기면 오버플로 메뉴로 접힌다', (tester) async {
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(actionCount: 8, crumbs: crumbs));

    expect(find.byKey(const ValueKey('chrome-actions-overflow')), findsOneWidget);
  });

  testWidgets('계정은 오버플로 메뉴로 가지 않고 항상 바에 남는다', (tester) async {
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(actionCount: 8, crumbs: crumbs));

    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  testWidgets('액션이 적으면 오버플로 메뉴가 없다', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(actionCount: 1, crumbs: crumbs));

    expect(find.byKey(const ValueKey('chrome-actions-overflow')), findsNothing);
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

```
cd packages/dp_design && flutter test test/shell/dp_chrome_bar_overflow_test.dart
```

Expected: 컴파일 에러 — `DpChromeAction` 미정의.

- [ ] **Step 3: `DpChromeAction`을 만든다**

`packages/dp_design/lib/src/shell/dp_chrome_action.dart`:

```dart
import 'package:flutter/widgets.dart';

/// 크롬바 우측 액션 **데이터**.
///
/// Widget이 아니라 데이터인 이유: 폭이 모자라면 오버플로 메뉴 항목으로
/// 옮겨 그려야 하는데, Widget으로 받으면 라벨을 알 수 없어 메뉴에
/// 무엇을 표시할지 정할 수 없다.
class DpChromeAction {
  const DpChromeAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;

  /// 바에서는 tooltip, 오버플로 메뉴에서는 항목 텍스트로 쓰인다.
  final String label;

  /// DpChromeBar가 자기 context를 넘긴다.
  ///
  /// VoidCallback이 아닌 이유: web의 오류 신고 액션이
  /// showSupportDialog(context)를 호출하는데, 액션을 데이터로 바꾸면
  /// 앱 쪽엔 다이얼로그를 띄울 수 있는 context가 없다. 호출부가 전역
  /// context를 잡게 두느니 컴포넌트가 넘겨주는 편이 안전하다.
  final void Function(BuildContext context) onPressed;
}
```

`dp_design.dart`에 export를 추가한다.

- [ ] **Step 4: `DpChromeBar`를 고친다**

1. 필드 타입: `final List<Widget> actions;` → `final List<DpChromeAction> actions;`
2. 우측 그룹(현재 `dp_chrome_bar.dart:96-111`)을 `LayoutBuilder`로 감싸 폭 상한을 받고, 상한을 넘으면 접는다:

```dart
          // 우측 그룹. 액션이 늘어나면(스펙 §3.0 trailing 슬롯) 폭을 넘길 수
          // 있으므로 상한을 받아 초과분을 메뉴로 접는다. account는 접지
          // 않는다 — 계정 진입점이 메뉴 뒤로 숨으면 접근성이 나빠진다.
          //
          // 현재 앱 조건에서는 이 축약이 발동하지 않는다(web 액션 1개·
          // admin 0개). 늘어날 자리를 미리 견고하게 만든 것이지, 실제
          // 화면의 결함을 고친 것이 아니다.
          IconTheme.merge(
            data: IconThemeData(color: c.textSecondary),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: c.textSecondary),
              child: _actionGroup(context, c),
            ),
          ),
```

3. `_actionGroup`을 새로 만든다. **액션 1개당 폭 48(IconButton 기본 히트 영역)로 계산하고, 상한은 바 폭의 절반으로 둔다:**

```dart
  /// 액션 그룹. 상한을 넘는 액션은 오버플로 메뉴로 접는다.
  Widget _actionGroup(BuildContext context, DpColors c) {
    if (actions.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [if (account != null) account!],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 상한이 무한이면(이론상 Row가 비-flex로 측정할 때) 접지 않는다.
        final maxWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : double.infinity;
        const perAction = 48.0;
        const overflowButton = 48.0;
        final accountWidth = account != null ? 48.0 : 0.0;

        final budget = maxWidth.isFinite
            ? maxWidth - accountWidth
            : double.infinity;
        final fits = budget.isFinite
            ? (budget / perAction).floor()
            : actions.length;

        final inline = fits >= actions.length
            ? actions
            : actions.take(
                ((budget - overflowButton) / perAction).floor().clamp(
                  0,
                  actions.length,
                ),
              ).toList();
        final overflow = actions.sublist(inline.length);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final a in inline)
              IconButton(
                icon: Icon(a.icon),
                tooltip: a.label,
                // LayoutBuilder의 context를 넘긴다 — 크롬바 아래라
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
                  icon: const Icon(DpIcons.more),
                  tooltip: '더 보기',
                  onPressed: () => controller.isOpen
                      ? controller.close()
                      : controller.open(),
                ),
              ),
            if (account != null) ...[
              const SizedBox(width: DpSpacing.sm),
              account!,
            ],
          ],
        );
      },
    );
  }
```

**`DpIcons.more`가 없으면** `dp_icons.dart`를 확인하고 존재하는 「더 보기」 아이콘을 쓰거나 `Icons.more_horiz`를 직접 쓴다. 추측하지 말고 파일을 읽어 확인한다.

4. 좌측 그룹의 `Expanded`는 **그대로 둔다** — 2단계 우측 정렬 수정을 되돌리지 않는다.
5. `dp_chrome_bar.dart:50-62`의 I2 주석을 「축약으로 해소, 현재 조건 미도달」로 갱신한다.

- [ ] **Step 5: `DpAppShell`의 `chromeActions` 타입을 바꾼다**

`dp_app_shell.dart`에서 `final List<Widget> chromeActions;` → `final List<DpChromeAction> chromeActions;`. `DpChromeBar`로 그대로 전달되므로 다른 변경은 없다.

- [ ] **Step 6: web 호출부를 고친다**

`app_shell.dart`의 `chromeActions:`는 지금 `Builder`로 감싼 `IconButton`이다. `Builder`가 필요했던 이유는 `showSupportDialog(context)`에 넘길 context를 얻기 위해서였는데, `DpChromeAction.onPressed`가 context를 받으므로 이제 불필요하다:

```dart
      chromeActions: [
        DpChromeAction(
          icon: DpIcons.error,
          label: '오류 신고·문의',
          onPressed: (context) => showSupportDialog(context),
        ),
      ],
```

`Builder` import가 다른 데서 안 쓰이면 정리한다.

- [ ] **Step 7: 테스트를 돌린다**

```
cd packages/dp_design && flutter test
cd apps/web && flutter test
```

**`support_entrypoints_test`가 통과하는지 특히 확인한다** — 2단계 Task 5에서 이 진입점이 위젯 트리에서 통째로 사라질 뻔했다(5개 레포에 걸쳐 최근 완성한 기능이다). 실패하면 테스트를 완화하지 말고 크롬바 쪽을 고친다.

- [ ] **Step 8: 커밋**

```bash
git add packages/dp_design apps/web
git commit -m "feat(dp_design): 크롬바 액션을 데이터형으로 바꾸고 오버플로 메뉴로 접는다"
```

---

## Task 5: 브레드크럼 마지막 세그먼트 비링크

**Files:**
- Modify: `packages/dp_design/lib/src/shell/dp_chrome_bar.dart:137`
- Modify: `docs/superpowers/specs/2026-08-03-design-shell-layout-design.md` (§7 표기)
- Test: `packages/dp_design/test/shell/dp_chrome_bar_test.dart` (기존 파일에 추가)

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```dart
  testWidgets('마지막 crumb은 path가 있어도 비링크다', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: Scaffold(
          body: DpChromeBar(
            breadcrumb: const [
              (label: '커뮤니티', path: null),
              (label: '게시판', path: '/community'),
            ],
            onCrumbTap: (_) => tapped++,
          ),
        ),
      ),
    );

    // 현재 위치를 자기 자신에게 링크하지 않는다(브레드크럼 관례).
    await tester.tap(find.text('게시판'));
    await tester.pump();
    expect(tapped, 0);
  });

  testWidgets('마지막이 아닌 crumb은 path가 있으면 링크다', (tester) async {
    var tappedPath = '';
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: Scaffold(
          body: DpChromeBar(
            breadcrumb: const [
              (label: '커뮤니티', path: null),
              (label: '게시판', path: '/community'),
              (label: '게시글', path: null),
            ],
            onCrumbTap: (p) => tappedPath = p,
          ),
        ),
      ),
    );

    await tester.tap(find.text('게시판'));
    await tester.pump();
    expect(tappedPath, '/community');
  });
```

- [ ] **Step 2: 실패를 확인한다**

```
cd packages/dp_design && flutter test test/shell/dp_chrome_bar_test.dart
```

Expected: 첫 테스트가 `tapped`가 1이라 FAIL.

- [ ] **Step 3: 구현한다**

`_crumbs`의 `final crumbWidget = crumb.path == null` 조건을 아래로 바꾼다:

```dart
      // 마지막 세그먼트는 현재 위치이므로 path가 있어도 링크하지 않는다
      // (브레드크럼 관례 — 자기 자신으로 가는 링크를 두지 않는다).
      // 앱은 crumb 데이터를 그대로 두면 된다: /community에서 마지막이
      // '게시판'(path: '/community')이지만 여기서 비링크로 렌더된다.
      final crumbWidget = (crumb.path == null || isLast)
          ? label
          : Semantics(
```

`isLast`는 이미 위에서 계산돼 있다(`dp_chrome_bar.dart:126`).

**구분자 패딩 상쇄 로직**(`:181-184`)도 확인한다 — 마지막이 비링크가 되면 `items[i+1].path == null` 판정이 달라진다. 구분자 앞뒤 간격이 대칭인지 기존 테스트로 확인하고, 깨지면 `isLast` 반영해 조건을 고친다:

```dart
            padding: EdgeInsets.only(
              left: crumb.path == null ? DpSpacing.sm : 0,
              // 다음 세그먼트가 마지막이면 비링크이므로 자체 패딩이 없다.
              right: (items[i + 1].path == null || i + 1 == items.length - 1)
                  ? DpSpacing.sm
                  : 0,
            ),
```

- [ ] **Step 4: 통과를 확인한다**

```
cd packages/dp_design && flutter test test/shell/dp_chrome_bar_test.dart
cd packages/dp_design && flutter test
```

- [ ] **Step 5: 2단계 스펙 §7을 갱신한다**

`docs/superpowers/specs/2026-08-03-design-shell-layout-design.md`의 §7에서 `/community → [커뮤니티, 게시판(→/community)]` 표기 옆에 다음을 덧붙인다:

```markdown
> **3-A 갱신(2026-08-06):** 마지막 세그먼트는 `path`가 있어도 비링크로 렌더된다
> (`DpChromeBar`가 `isLast`로 판정). 현재 위치를 자기 자신에게 링크하지 않는
> 브레드크럼 관례를 따른다. crumb 데이터 자체는 위 표기 그대로다.
```

- [ ] **Step 6: web·admin 테스트를 돌린다**

```
cd apps/web && flutter test
cd apps/admin && flutter test
```

브레드크럼 값을 단언하는 기존 테스트가 링크 동작에 의존하면 고친다.

- [ ] **Step 7: 커밋**

```bash
git add packages/dp_design docs/superpowers/specs/2026-08-03-design-shell-layout-design.md apps
git commit -m "fix(dp_design): 마지막 브레드크럼 세그먼트를 비링크로 렌더한다"
```

---

## Task 6: compact 하단 바 무강조

**Files:**
- Modify: `packages/dp_design/lib/src/shell/dp_app_shell.dart:86-104`
- Test: `packages/dp_design/test/shell/dp_app_shell_compact_test.dart`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(int? selectedIndex) => MaterialApp(
    theme: DpTheme.light(),
    home: DpAppShell(
      destinations: const [
        DpDestination(icon: Icons.home, label: '대시보드'),
        DpDestination(icon: Icons.map, label: '학습 경로'),
      ],
      selectedIndex: selectedIndex,
      onSelect: (_) {},
      body: const SizedBox(),
    ),
  );

  setUp(() {});

  testWidgets('compact에서 selectedIndex가 null이면 어떤 항목도 강조되지 않는다',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(null));

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    // selectedIndex는 non-null int라 0으로 클램프될 수밖에 없다.
    // 강조는 인디케이터를 투명으로 만들어 지운다.
    final theme = NavigationBarTheme.of(tester.element(find.byType(NavigationBar)));
    expect(theme.indicatorColor, Colors.transparent);
    expect(bar.selectedIndex, 0);
  });

  testWidgets('compact에서 selectedIndex가 있으면 인디케이터가 보인다',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(1));

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 1);
    final theme = NavigationBarTheme.of(tester.element(find.byType(NavigationBar)));
    expect(theme.indicatorColor, isNot(Colors.transparent));
  });
}
```

**주의:** `NavigationBarTheme.of`가 상위 `ThemeData`의 기본값을 반환할 수 있다. `DpTheme.light()`가 `navigationBarTheme`을 설정하는지 먼저 확인하고, 둘째 테스트의 단언을 실제 기본값에 맞춘다(기본이 null이면 `isNot(Colors.transparent)` 대신 `isNull`).

- [ ] **Step 2: 실패를 확인한다**

```
cd packages/dp_design && flutter test test/shell/dp_app_shell_compact_test.dart
```

- [ ] **Step 3: 구현한다**

`dp_app_shell.dart`의 compact 분기에서 `NavigationBar`를 감싼다:

```dart
    if (compact) {
      // NavigationBar.selectedIndex는 Flutter 3.44에서 non-null int라
      // 0으로 클램프할 수밖에 없다. DpNavRail처럼 무강조를 표현할 수 없으므로
      // 인디케이터를 투명으로 만들고 선택 라벨/아이콘 색을 비선택과 같게 덮어
      // 시각적 강조를 지운다 — 비-compact 레일의 무강조 거동과 일치시킨다.
      final unselected = selectedIndex == null;
      return Scaffold(
        body: main,
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorColor: unselected ? Colors.transparent : null,
          ),
          child: NavigationBar(
            selectedIndex: selectedIndex ?? 0,
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
        ),
      );
    }
```

**기존 `destinations` 조립부 전체를 복사해 유지한다** — 위 코드는 축약된 형태이므로 실제 파일(`:93-103`)의 내용을 그대로 옮긴다.

`NavigationBarThemeData.indicatorColor`에 `null`을 주면 상위 테마 값을 쓴다. 선택 라벨/아이콘 색까지 통일하려면 `iconTheme`·`labelTextStyle`을 `WidgetStateProperty.resolveWith`로 덮되, **`unselected`일 때만** 적용한다:

```dart
            iconTheme: unselected
                ? WidgetStateProperty.all(IconThemeData(color: c.textSecondary))
                : null,
```

`c`는 `context.dpColors`로 얻는다(compact 분기 위쪽에서 선언).

- [ ] **Step 4: `Semantics`의 selected도 끈다**

`NavigationBar`가 내부적으로 `selected: true`를 붙인다. `unselected`일 때 스크린리더가 잘못된 위치를 읽지 않도록 `ExcludeSemantics`로 감싸지는 **말고**(전체 접근성이 사라진다), 대신 이 한계를 주석으로 남긴다:

```dart
          // 한계: NavigationBar 내부 Semantics의 selected 플래그까지는 끄지
          // 못한다(위젯이 selectedIndex로 직접 계산한다). 시각적 강조는
          // 지워지지만 스크린리더는 여전히 0번을 선택으로 읽는다.
          // 완전 해소는 하단 바 자체 구현이 필요해 범위 밖으로 둔다.
```

- [ ] **Step 5: 테스트를 돌린다**

```
cd packages/dp_design && flutter test
```

- [ ] **Step 6: 커밋**

```bash
git add packages/dp_design
git commit -m "fix(dp_design): compact 하단 바에서 무강조를 표현한다"
```

---

## Task 7: web 레일 토글과 `brandRow` 오버플로

> **★실행 중 발견된 계획 결함과 그 결정(2026-08-06)★**
>
> 이 Task를 그대로 구현하면 **접힘 레일에서 오버플로한다.** 구현자가 격리 probe로
> 확인한 수치: `railCollapsedWidth` 72 − `_buildTop` 패딩 20 = **가용 52px**인데,
> 마크 22 + `IconButton` 최소 탭 타깃 48 = **70px**가 필요하다. Task 1이 세운
> 불변조건(「마크는 접힘에서도 남는다」)과 44px 탭 타깃(DESIGN §6)을 **동시에
> 만족시키는 가로 배치가 수학적으로 존재하지 않는다.** 계획이 두 Task의 상호작용을
> 예상하지 못한 결함이다.
>
> **사용자 결정: 접힘 상태에서 마크와 토글을 세로로 쌓는다.** `_buildTop`을
> `extended`면 `Row`, 접힘이면 `Column`(마크 위, 토글 아래)으로 분기한다. 레일
> 폭과 `DpRailBrand` 계약은 그대로 두고 변경을 `_buildTop` 한 곳에 국소화한다.
> 따라서 이 Task는 `packages/dp_design/lib/src/shell/dp_nav_rail.dart` 수정을
> **포함한다**(아래 Files 목록에 없던 파일).
>
> 검토한 대안: ①접힘에서 마크가 토글 역할(발견성 낮음·시맨틱스 변경) ②
> `railCollapsedWidth` 확대(접힘의 의미 축소·기존 테스트 재검토) ③3-B 이월.

**Files:**
- Modify: `apps/web/lib/src/features/shell/presentation/app_shell.dart:101-180` (`AppShellView`를 Stateful로)
- Modify: `apps/web/lib/src/features/common/presentation/brand_row.dart:28`
- Modify: `packages/dp_design/lib/src/shell/dp_nav_rail.dart` `_buildTop` (위 결정 — 접힘 시 세로 배치)
- Test: `apps/web/test/features/shell/app_shell_rail_toggle_test.dart` · `packages/dp_design/test/shell/` (접힘+토글 오버플로 red-repro)

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web/src/features/shell/presentation/app_shell.dart';

void main() {
  testWidgets('medium 폭에서 레일을 펼칠 수 있다', (tester) async {
    // medium(600~840): 기본 접힘. 2단계에서는 onToggleRail을 넘기지 않아
    // 사용자가 펼칠 방법이 없었다.
    tester.view.physicalSize = const Size(700, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: const AppShellView(location: '/dashboard', child: SizedBox()),
      ),
    );

    // 접힘 상태에서는 라벨이 안 보인다.
    expect(find.text('대시보드'), findsNothing);

    await tester.tap(find.byTooltip('메뉴 펼치기'));
    await tester.pumpAndSettle();

    expect(find.text('대시보드'), findsOneWidget);
  });
}
```

**주의:** 실제 import 경로와 패키지명(`web`인지 다른 이름인지)을 `apps/web/pubspec.yaml`에서 확인한다. 레일 라벨과 브레드크럼·헤더 제목이 같은 문자열일 수 있으므로, `findsOneWidget`이 깨지면 `find.descendant(of: find.byKey(const ValueKey('rail-root')), matching: find.text('대시보드'))`로 좁힌다.

- [ ] **Step 2: 실패를 확인한다**

```
cd apps/web && flutter test test/features/shell/app_shell_rail_toggle_test.dart
```

Expected: `메뉴 펼치기` 툴팁을 못 찾아 FAIL (`onToggleRail`이 없으면 `DpNavRail`이 토글 버튼을 그리지 않는다).

- [ ] **Step 3: `AppShellView`를 `StatefulWidget`으로 바꾼다**

```dart
/// 표현부: go_router 비의존 — DpAppShell(4-클래스 반응형)로 위임.
///
/// 레일 펼침 상태를 여기서 보유한다. 2단계에서는 onToggleRail을 넘기지
/// 않아 medium(600~840)에서 접힘 고정이었다 — 사용자가 펼칠 방법이 없었다.
class AppShellView extends StatefulWidget {
  const AppShellView({
    super.key,
    required this.location,
    required this.child,
    this.onSelect,
  });

  final String location;
  final Widget child;
  final void Function(String path)? onSelect;

  @override
  State<AppShellView> createState() => _AppShellViewState();
}

class _AppShellViewState extends State<AppShellView> {
  /// null이면 DpAppShell의 폭 기반 기본값(medium 접힘 / 그 이상 펼침)을 따른다.
  /// 사용자가 토글하면 그 값이 기본값을 덮는다.
  bool? _railExtended;
```

`build`에서 `widget.location`·`widget.onSelect`·`widget.child`로 참조를 바꾸고, `DpAppShell`에 다음을 추가한다:

```dart
      railExtended: _railExtended,
      onToggleRail: () => setState(() {
        // 현재 실효 상태를 뒤집는다. 아직 토글한 적이 없으면 DpAppShell의
        // 폭 기반 기본값(dp_app_shell.dart:107)과 같은 규칙으로 계산한다.
        final wc = context.windowClass;
        final current = _railExtended ?? (wc != DpWindowClass.medium);
        _railExtended = !current;
      }),
```

`context.windowClass`·`DpWindowClass`가 `dp_design`에서 export되는지 확인한다. 안 되면 `MediaQuery.sizeOf(context).width`로 같은 임계(600~840)를 직접 판정하되, **`dp_app_shell.dart:107`의 규칙과 어긋나지 않게** 한다.

`_index` getter는 `location` → `widget.location`으로 바꾼다.

- [ ] **Step 4: `brandRow`의 non-flex `Text`를 고친다**

`brand_row.dart`에서:

```dart
        // Flexible로 감싼다 — Spacer(Expanded)와 같은 Row의 non-flex 자식은
        // 무한 주축 제약으로 측정되어 ellipsis가 발동하지 않고 오버플로한다.
        Flexible(
          child: Text(
            'DevPath',
            overflow: TextOverflow.ellipsis,
            style: text.titleSmall?.copyWith(color: c.textPrimary),
          ),
        ),
```

- [ ] **Step 5: `brandRow` 오버플로 red-repro를 추가한다**

`apps/web/test/features/common/brand_row_test.dart`:

```dart
  testWidgets('좁은 폭에서 brandRow가 오버플로하지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => brandRow(
              context,
              actions: [
                TextButton(onPressed: () {}, child: const Text('로그아웃')),
                TextButton(onPressed: () {}, child: const Text('도움말')),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
```

- [ ] **Step 6: 테스트를 돌린다**

```
cd apps/web && flutter test
```

- [ ] **Step 7: 커밋**

```bash
git add apps/web
git commit -m "fix(web): medium에서 레일을 펼칠 수 있게 하고 brandRow 오버플로를 막는다"
```

---

## Task 8: `DpTag` 신설과 3곳 배선

**Files:**
- Create: `packages/dp_design/lib/src/data/dp_tag.dart`
- Modify: `packages/dp_design/lib/dp_design.dart`
- Modify: `apps/web/lib/src/features/community/presentation/post_detail_page.dart:140`
- Modify: `apps/web/lib/src/features/dashboard/presentation/widgets/dashboard_body.dart:177`
- Modify: `apps/admin/lib/src/features/reports/presentation/reports_page.dart:173-189`
- Test: `packages/dp_design/test/data/dp_tag_test.dart`

**Interfaces:**
- Produces: `class DpTag extends StatelessWidget { const DpTag({super.key, required String label, Color? tone}); }`

**배경:** `tagBg`·`tagText`는 정의·`copyWith`·`lerp` 외에 참조가 **0건**이다. 한편 세 곳이 각자 다른 방식으로 같은 것을 그린다 — 두 곳은 맨 Material `Chip`(M3 기본색 노출), admin은 `Container` 배경에 `c.border`(**경계선 토큰을 면에 쓰는 의미 오용**).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`packages/dp_design/test/data/dp_tag_test.dart`:

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child, ThemeData theme) =>
      MaterialApp(theme: theme, home: Scaffold(body: Center(child: child)));

  testWidgets('배경은 tagBg, 전경은 tagText다', (tester) async {
    await tester.pumpWidget(host(const DpTag(label: '#flutter'), DpTheme.light()));

    final container = tester.widget<Container>(
      find.byKey(const ValueKey('dp-tag')),
    );
    expect((container.decoration! as BoxDecoration).color, DpColors.light.tagBg);

    final text = tester.widget<Text>(find.text('#flutter'));
    expect(text.style!.color, DpColors.light.tagText);
  });

  testWidgets('tone이 주어지면 전경만 덮고 배경은 tagBg를 유지한다', (tester) async {
    await tester.pumpWidget(
      host(
        DpTag(label: '스팸', tone: DpColors.light.danger),
        DpTheme.light(),
      ),
    );

    final container = tester.widget<Container>(
      find.byKey(const ValueKey('dp-tag')),
    );
    expect((container.decoration! as BoxDecoration).color, DpColors.light.tagBg);

    final text = tester.widget<Text>(find.text('스팸'));
    expect(text.style!.color, DpColors.light.danger);
  });

  testWidgets('다크에서도 tagBg/tagText를 쓴다', (tester) async {
    await tester.pumpWidget(host(const DpTag(label: '#dart'), DpTheme.dark()));

    final container = tester.widget<Container>(
      find.byKey(const ValueKey('dp-tag')),
    );
    expect((container.decoration! as BoxDecoration).color, DpColors.dark.tagBg);

    final text = tester.widget<Text>(find.text('#dart'));
    expect(text.style!.color, DpColors.dark.tagText);
  });
}
```

- [ ] **Step 2: 실패를 확인한다**

```
cd packages/dp_design && flutter test test/data/dp_tag_test.dart
```

- [ ] **Step 3: `DpTag`를 만든다**

`packages/dp_design/lib/src/data/dp_tag.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';
import '../theme/dp_tokens.dart';

/// 중립 태그 칩. 배경 [DpColors.tagBg] / 전경 [DpColors.tagText].
///
/// 이 위젯이 tag* 토큰의 유일한 배선 지점이다. 이전에는 맨 Material Chip
/// (M3 기본색)과 border를 배경에 쓴 Container가 섞여 있었다.
class DpTag extends StatelessWidget {
  const DpTag({super.key, required this.label, this.tone});

  final String label;

  /// 전경색만 덮는다(신고 카테고리·위험도 구분 등). 배경은 언제나 tagBg다.
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    return Container(
      key: const ValueKey('dp-tag'),
      padding: const EdgeInsets.symmetric(
        horizontal: DpSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: c.tagBg,
        borderRadius: BorderRadius.circular(DpRadius.button),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: tone ?? c.tagText),
      ),
    );
  }
}
```

**`DpRadius.button`의 실제 값을 `dp_tokens.dart`에서 확인한다.** admin `_chip`은 `BorderRadius.circular(4)`였다 — 토큰 값이 4가 아니면 시각 변화가 생기므로, 토큰을 쓰되 변화를 인지하고 진행한다.

`dp_design.dart`에 export를 추가한다. **`packages/dp_design/lib/src/data/` 디렉터리가 이미 있는지 확인한다**(로드맵 Phase 2에서 `DpKpiCard`를 Layer2 `data/`에 뒀다). 있으면 그 아래에 둔다.

- [ ] **Step 4: 배선 3곳을 교체한다**

`post_detail_page.dart:140`:

```dart
            children: [for (final t in detail.tags) DpTag(label: '#$t')],
```

`dashboard_body.dart:177`:

```dart
            children: [for (final b in badges) DpTag(label: b)],
```

`reports_page.dart`: `_chip` 메서드를 삭제하고 호출부 3곳을 바꾼다:

```dart
                DpTag(label: r.targetTypeLabel),
                const SizedBox(width: DpSpacing.xs),
                DpTag(label: r.categoryLabel, tone: c.chart4),
                if (r.reportCount > 1) ...[
                  const SizedBox(width: DpSpacing.xs),
                  DpTag(label: '${r.reportCount}명 신고', tone: c.danger),
                ],
```

**커뮤니티 보드 뱃지(`community_home_page.dart:255-262`·`:341-348`)는 건드리지 않는다** — `border`/`chart4`/`primary`로 보드를 구분하는 의미 있는 색이라 중립 태그로 바꾸면 정보가 사라진다.

- [ ] **Step 5: 대비 스크립트를 확인한다**

```
py docs/superpowers/specs/2026-08-03-token-contrast-check.py
```

`('tagText', 'tagBg', 4.5)`는 **스크립트에 이미 있다**(`:47`). 새로 추가할 필요 없이 미달 0건인지만 확인한다.

- [ ] **Step 6: 테스트를 돌린다**

```
cd packages/dp_design && flutter test
cd apps/web && flutter test
cd apps/admin && flutter test
```

`Chip`을 찾던 기존 테스트가 있으면 `DpTag`로 고친다.

- [ ] **Step 7: 커밋**

```bash
git add packages/dp_design apps/web apps/admin
git commit -m "feat(dp_design): DpTag를 신설해 tag* 토큰을 배선한다"
```

---

## Task 9: `filters` 슬롯 줄바꿈과 admin 필터 배치 통일

**Files:**
- Modify: `packages/dp_design/lib/src/layout/dp_page_header.dart:92-98`
- Modify: `apps/admin/lib/src/features/reports/presentation/reports_page.dart:39-58`
- Modify: `apps/admin/lib/src/features/support/presentation/support_page.dart` (필터 블록)
- Modify: `apps/admin/lib/src/features/users/presentation/users_page.dart:70-95`
- Modify: `apps/admin/lib/src/features/ads/presentation/ads_page.dart:53-70`
- Test: `packages/dp_design/test/layout/dp_page_header_filters_test.dart`

**현재 상태(실측):**

| 화면 | 필터 위치 | 위젯 |
|---|---|---|
| `users` `:70` · `ads` `:53` | 헤더 `filters` 슬롯 | `Row(['상태:'/'슬롯:', ChoiceChip × N])` — compact 오버플로 |
| `reports` `:39-58` · `support` | 헤더 **밖** 별도 `Padding` + `Align` | `SegmentedButton` |

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('좁은 폭에서 filters가 줄바꿈해 오버플로하지 않는다', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: Scaffold(
          body: DpPageHeader(
            title: '사용자 관리',
            filters: [
              const Text('상태:'),
              for (final s in ['전체', 'ACTIVE', 'BETA_PENDING', 'SUSPENDED', 'DELETED'])
                ChoiceChip(label: Text(s), selected: false, onSelected: (_) {}),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
```

**이 테스트는 `filters`의 타입이 `Widget?` → `List<Widget>`으로 바뀐다는 것을 전제한다.** 슬롯이 `Wrap`으로 감싸려면 자식들이 `Wrap`의 형제여야 하기 때문이다 — `Row`를 통째로 받으면 `Wrap` 안에 `Row` 하나가 들어가 줄바꿈이 일어나지 않는다.

- [ ] **Step 2: 실패를 확인한다**

```
cd packages/dp_design && flutter test test/layout/dp_page_header_filters_test.dart
```

- [ ] **Step 3: `DpPageHeader.filters`를 `List<Widget>`으로 바꾸고 `Wrap`으로 감싼다**

```dart
  /// 헤더 아래 필터 줄. 자식들은 Wrap의 형제로 배치되어 좁은 폭에서
  /// 줄바꿈한다 — Row를 통째로 받으면 줄바꿈이 일어나지 않는다.
  final List<Widget> filters;
```

기본값 `const []`. `build`의 filters 블록:

```dart
          if (filters.isNotEmpty) ...[
            const SizedBox(height: DpSpacing.md),
            KeyedSubtree(
              key: const ValueKey('page-header-filters'),
              child: Wrap(
                spacing: DpSpacing.sm,
                runSpacing: DpSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: filters,
              ),
            ),
          ],
```

- [ ] **Step 4: admin 4화면을 고친다**

`users_page.dart` — `filters: Row(children: [...])` → `filters: [Text('상태:'), for (...) ChoiceChip(...)]`. 기존 `Row` 안의 `SizedBox(width:)` 간격재는 `Wrap`의 `spacing`이 대신하므로 **삭제한다.** `Padding`으로 감싼 칩이 있으면 그 `Padding`도 뺀다.

`ads_page.dart` — 같은 방식(`'슬롯:'`).

`reports_page.dart` — 헤더 밖 `Padding` + `Align` + `SegmentedButton` 블록을 삭제하고 헤더로 옮긴다:

```dart
          DpPageHeader(
            title: '신고 처리',
            description: '커뮤니티 신고를 검토하고 판정합니다',
            filters: [
              SegmentedButton<String?>(
                segments: [
                  for (final (label, value) in _filters)
                    ButtonSegment(value: value, label: Text(label)),
                ],
                selected: {current},
                showSelectedIcon: false,
                onSelectionChanged: (sel) => n.load(status: sel.first),
              ),
            ],
          ),
```

`const DpPageHeader(...)`였다면 `const`를 뗀다.

`support_page.dart` — 같은 방식.

- [ ] **Step 5: 테스트를 돌린다**

```
cd packages/dp_design && flutter test
cd apps/admin && flutter test
cd apps/web && flutter test
```

`page-header-filters` 키나 필터 위치를 단언하는 기존 테스트를 새 구조에 맞춘다.

- [ ] **Step 6: 커밋**

```bash
git add packages/dp_design apps/admin
git commit -m "fix(dp_design,admin): 필터를 헤더 슬롯으로 통일하고 줄바꿈시킨다"
```

---

## Task 10: 문서형 헤더 sliver 전환 — web 학습·계정 5화면

**Files:**
- Modify: `apps/web/lib/src/features/dashboard/presentation/dashboard_page.dart:40-60`
- Modify: `apps/web/lib/src/features/path/presentation/path_page.dart:60-70`
- Modify: `apps/web/lib/src/features/content/presentation/content_page.dart:95-125`
- Modify: `apps/web/lib/src/features/mypage/presentation/mypage_page.dart:33-45`
- Modify: `apps/web/lib/src/features/settings/presentation/settings_page.dart:38-58`
- Test: `apps/web/test/features/shell/page_header_scroll_test.dart`

### 전환 패턴 (5화면 공통)

현재 구조는 전부 이 형태다:

```dart
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DpPageHeader(title: …, description: …),
          Expanded(child: <상태 분기>),
        ],
      ),
```

`CustomScrollView`로 바꾼다. **상태 분기가 관건이다** — 로딩·에러는 화면 중앙에 놓여야 하고(스크롤 불필요) 본문만 스크롤이다:

```dart
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: DpPageHeader(title: …, description: …),
          ),
          switch (s) {
            // 로딩·에러는 남은 높이를 채워 중앙에 놓는다. hasScrollBody: false가
            // 핵심 — true면 자식이 자체 스크롤 뷰포트를 가져야 한다.
            XLoading() => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
            XFailed(:final message) => SliverFillRemaining(
              hasScrollBody: false,
              child: _errorView(message),
            ),
            // 본문은 기존 스크롤 위젯을 벗겨 sliver로 만든다.
            XReady(…) => SliverToBoxAdapter(child: _readyView(…)),
          },
        ],
      ),
```

**본문 위젯에서 스크롤을 벗기는 규칙:**
- 본문이 `ListView(children: […])`였다면 → `SliverList.list(children: […])`
- 본문이 `SingleChildScrollView(child: X)`였다면 → `SliverToBoxAdapter(child: X)` (안쪽 `padding`은 `SliverPadding`으로 옮긴다)
- 본문이 `ListView.builder`였다면 → `SliverList.builder`
- **본문에 스크롤이 남아 있으면 중첩 스크롤이 되어 헤더가 사라지지 않는다.** 반드시 벗겨라

**`AnimatedSwitcher`는 sliver를 받지 못한다.** `dashboard_page.dart:49`가 이걸 쓴다 — `SliverToBoxAdapter(child: AnimatedSwitcher(…))`로 내리면 자식 높이가 무한이 되어 레이아웃이 깨진다. 대시보드는 **`AnimatedSwitcher`를 `SliverAnimatedSwitcher`로 바꿀 수 없으므로**, 전환 애니메이션을 본문 안쪽(`DashboardBody` 내부)으로 내리거나 이번 전환에서 제거한다. **어느 쪽이든 기존 `ValueKey('dash-switcher')`를 단언하는 테스트가 있는지 먼저 확인하고**, 있으면 그 테스트를 새 구조에 맞게 고친다(완화하지 말 것).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`apps/web/test/features/shell/page_header_scroll_test.dart`:

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 문서형 화면은 헤더가 본문과 함께 스크롤된다(DESIGN.md §9).
/// 뷰포트 고정형(mentor·sandbox·admin users/ads/support)은 고정이다.
void main() {
  testWidgets('설정 화면에서 헤더가 스크롤과 함께 사라진다', (tester) async {
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // 실제 SettingsPage를 렌더한다. 필요한 provider override는
    // 기존 settings_page_test.dart의 설정을 그대로 재사용한다.
    await tester.pumpWidget(/* 기존 테스트의 host()를 재사용 */);
    await tester.pumpAndSettle();

    expect(find.text('설정'), findsWidgets);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pump();

    // 헤더가 뷰포트 밖으로 나갔다.
    final headerFinder = find.byType(DpPageHeader);
    expect(
      tester.getBottomLeft(headerFinder).dy,
      lessThanOrEqualTo(0),
    );
  });
}
```

**`/* 기존 테스트의 host()를 재사용 */`을 그대로 두지 마라.** `apps/web/test/features/settings/settings_page_test.dart`를 읽어 provider override와 pump 절차를 복사해 채운다.

- [ ] **Step 2: 실패를 확인한다**

```
cd apps/web && flutter test test/features/shell/page_header_scroll_test.dart
```

Expected: `CustomScrollView`를 못 찾아 FAIL.

- [ ] **Step 3: `settings_page.dart`를 전환한다**

가장 단순한 구조라 여기서 시작한다. `_readyView`의 `ListView(padding: …, children: […])`를 `SliverList.list`로 바꾸고 `padding`은 `SliverPadding`으로 옮긴다.

- [ ] **Step 4: 통과를 확인한다**

```
cd apps/web && flutter test test/features/settings/ test/features/shell/page_header_scroll_test.dart
```

- [ ] **Step 5: 나머지 4화면을 같은 패턴으로 전환한다**

`mypage` → `path` → `content` → `dashboard` 순서로 한다(단순한 것부터). 각 화면마다:

1. 해당 화면의 기존 테스트를 먼저 돌려 기준선을 확인한다
2. 전환한다
3. 기존 테스트를 다시 돌린다 — **실패하면 테스트를 완화하지 말고 전환을 고친다**

`dashboard`는 `AnimatedSwitcher` 때문에 마지막에 한다.

- [ ] **Step 6: 각 화면에 헤더 스크롤 단언을 추가한다**

Step 1의 테스트에 5화면 각각의 케이스를 추가한다. 화면마다 provider override가 다르므로 기존 테스트 파일에서 복사한다.

- [ ] **Step 7: web 전체 테스트**

```
cd apps/web && flutter test
```

- [ ] **Step 8: 커밋**

```bash
git add apps/web
git commit -m "refactor(web): 문서형 화면 5곳의 페이지 헤더를 스크롤에 싣는다"
```

---

## Task 11: 문서형 헤더 sliver 전환 — 커뮤니티 4화면

**Files:**
- Modify: `apps/web/lib/src/features/community/presentation/post_detail_page.dart:60-70`
- Modify: `apps/web/lib/src/features/community/presentation/qna_detail_page.dart:58-68`
- Modify: `apps/web/lib/src/features/community/presentation/post_create_page.dart:124-135`
- Modify: `apps/web/lib/src/features/community/presentation/question_create_page.dart:161-172`
- Test: `apps/web/test/features/shell/page_header_scroll_test.dart` (Task 10에서 만든 파일에 추가)

**커뮤니티 홈(`community_home_page.dart:131`)은 이미 `SliverToBoxAdapter`다 — 건드리지 않는다.**

- [ ] **Step 1: 4화면의 현재 구조를 확인한다**

```
cd apps/web && grep -n "body:\|ListView\|SingleChildScrollView\|Column(\|Expanded(" lib/src/features/community/presentation/post_detail_page.dart lib/src/features/community/presentation/qna_detail_page.dart lib/src/features/community/presentation/post_create_page.dart lib/src/features/community/presentation/question_create_page.dart
```

- [ ] **Step 2: 각 화면의 헤더 스크롤 테스트를 쓴다**

Task 10의 파일에 4건을 추가한다. 패턴은 동일하다 — 기존 `post_detail_page_test.dart` 등에서 provider override를 복사한다.

- [ ] **Step 3: 실패를 확인한다**

```
cd apps/web && flutter test test/features/shell/page_header_scroll_test.dart
```

- [ ] **Step 4: Task 10의 전환 패턴을 적용한다**

작성 화면 2곳(`post_create`·`question_create`)은 폼이다 — `TextField`가 포커스를 받을 때 키보드/스크롤 거동이 바뀔 수 있으므로 **기존 폼 테스트를 반드시 다시 돌린다.** `flutter_quill`(`DpRichEditor`)이 들어간 화면은 에디터가 자체 스크롤을 가질 수 있으니 중첩 스크롤이 생기지 않는지 확인한다.

- [ ] **Step 5: 테스트를 돌린다**

```
cd apps/web && flutter test
```

- [ ] **Step 6: 커밋**

```bash
git add apps/web
git commit -m "refactor(web): 커뮤니티 4화면의 페이지 헤더를 스크롤에 싣는다"
```

---

## Task 12: 문서형 헤더 sliver 전환 — admin 2화면

**Files:**
- Modify: `apps/admin/lib/src/features/dashboard/presentation/dashboard_page.dart:33-45`
- Modify: `apps/admin/lib/src/features/reports/presentation/reports_page.dart:33-80`
- Test: `apps/admin/test/features/shell/page_header_scroll_test.dart`

**admin `users`·`ads`·`support`는 `DpDataTable`(data_table_2)이 자체 뷰포트를 갖는 뷰포트 고정형이다 — 전환하지 않는다.**

- [ ] **Step 1: 테스트를 쓴다**

Task 10의 패턴으로 admin 2화면. provider override는 `apps/admin/test/features/dashboard/dashboard_page_test.dart`·`reports_page_test.dart`에서 복사한다.

- [ ] **Step 2: 실패를 확인한다**

```
cd apps/admin && flutter test test/features/shell/page_header_scroll_test.dart
```

- [ ] **Step 3: 전환한다**

`reports_page.dart`는 Task 9에서 필터를 헤더 슬롯으로 옮겼으므로 헤더 하나만 `SliverToBoxAdapter`로 감싸면 된다. 본문 `ListView(padding: …)`는 `SliverList.list` + `SliverPadding`으로.

- [ ] **Step 4: 테스트를 돌린다**

```
cd apps/admin && flutter test
```

- [ ] **Step 5: 커밋**

```bash
git add apps/admin
git commit -m "refactor(admin): 문서형 화면 2곳의 페이지 헤더를 스크롤에 싣는다"
```

---

## Task 13: admin 화면 제목 단일 출처화

**Files:**
- Modify: `apps/admin/lib/src/features/shell/presentation/admin_shell.dart:5-13,44-50,97`
- Modify: `apps/admin/lib/src/features/{dashboard,users,reports,support,ads}/presentation/*_page.dart` (각 `DpPageHeader.title`)
- Test: `apps/admin/test/features/shell/admin_title_source_test.dart`

**문제:** `_headerTitleFor`가 「단일 출처」라 주석돼 있으나 **private**이고 admin 5화면이 각자 문자열 리터럴을 박는다(예: `reports_page.dart:36` `'신고 처리'`). 한쪽만 고치면 브레드크럼과 헤더가 조용히 어긋난다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```dart
import 'package:admin/src/features/shell/presentation/admin_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('모든 admin 목적지가 headerTitle을 갖는다', () {
    for (final d in kAdminDestinations) {
      expect(d.headerTitle, isNotEmpty, reason: '${d.path}에 headerTitle이 없다');
    }
  });

  test('경로로 headerTitle을 조회할 수 있다', () {
    expect(adminHeaderTitleFor('/reports'), '신고 처리');
    expect(adminHeaderTitleFor('/support'), '오류 신고·문의');
    expect(adminHeaderTitleFor('/unknown'), '운영 대시보드');
  });
}
```

**패키지명(`admin`)을 `apps/admin/pubspec.yaml`에서 확인한다.**

- [ ] **Step 2: 실패를 확인한다**

```
cd apps/admin && flutter test test/features/shell/admin_title_source_test.dart
```

- [ ] **Step 3: `AdminDestination`에 `headerTitle`을 추가한다**

```dart
typedef AdminDestination = ({
  String path,
  IconData icon,
  String label,
  String headerTitle,
});

/// admin 목적지 = 경로·아이콘·레일 라벨·화면 제목의 **유일한** 출처.
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
  (
    path: '/reports',
    icon: DpIcons.error,
    label: '신고',
    headerTitle: '신고 처리',
  ),
  // ③ 콘텐츠 신고와 ④ 서비스 오류·문의는 별개 기능이라 메뉴도 나눈다.
  (
    path: '/support',
    icon: DpIcons.mentor,
    label: '문의',
    headerTitle: '오류 신고·문의',
  ),
  (path: '/ads', icon: DpIcons.ads, label: '광고', headerTitle: '광고 관리'),
];

/// 경로 → 화면 제목. 매칭 실패 시 대시보드로 폴백한다(_index와 같은 규칙).
String adminHeaderTitleFor(String path) {
  final i = kAdminDestinations.indexWhere((d) => path.startsWith(d.path));
  return i < 0
      ? kAdminDestinations.first.headerTitle
      : kAdminDestinations[i].headerTitle;
}
```

기존 `_headerTitleFor`를 삭제하고 `:97`의 breadcrumb 조립을 `adminHeaderTitleFor(kAdminDestinations[_index].path)`로 바꾼다.

- [ ] **Step 4: 5화면의 제목 리터럴을 없앤다**

각 화면의 `DpPageHeader(title: '신고 처리', …)`를 `DpPageHeader(title: adminHeaderTitleFor('/reports'), …)`로 바꾼다. `const`였다면 뗀다.

**더 나은 대안이 있는지 판단하라:** 화면이 자기 경로를 아는 게 자연스럽지 않다면, 셸이 제목을 주입하는 구조(예: `DpPageHeader`를 셸이 그리고 화면은 본문만)도 가능하다. 다만 그건 2단계 셸 구조의 변경이라 이번 범위를 넘는다 — **경로 상수 참조로 끝내라.**

- [ ] **Step 5: 테스트를 돌린다**

```
cd apps/admin && flutter test
```

- [ ] **Step 6: 커밋**

```bash
git add apps/admin
git commit -m "refactor(admin): 화면 제목을 kAdminDestinations 단일 출처로 모은다"
```

---

## Task 14: 화면 잡정리 4건

**Files:**
- Modify: `apps/web/lib/src/features/sandbox/presentation/sandbox_layout.dart:78-93`
- Modify: `apps/web/lib/src/features/mypage/presentation/mypage_page.dart:63-72,170-195`
- Modify: `apps/web/lib/src/features/community/presentation/post_create_page.dart` · `question_create_page.dart`
- Modify: `apps/web/lib/src/features/beta/presentation/beta_pending_page.dart:87,95,101,104`
- Test: `apps/web/test/features/mypage/mypage_labels_test.dart` · `apps/web/test/features/sandbox/sandbox_layout_test.dart`

### 14-1 샌드박스 탭 좌측 정렬

`SegmentedButton`이 `Column`의 자식이고 `Column`의 기본 `crossAxisAlignment`가 `center`라 중앙에 놓인다. 좌측 정렬된 페이지 헤더와 어긋난다.

- [ ] **Step 1: 테스트를 쓴다**

```dart
  testWidgets('세그먼트 탭이 좌측 정렬된다', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(/* SandboxLayout을 <1024 폭으로 렌더 */);

    final segLeft = tester.getTopLeft(find.byType(SegmentedButton<int>)).dx;
    // 헤더와 같은 좌측 여백(DpSpacing.sm)에서 시작한다.
    expect(segLeft, lessThan(100));
  });
```

`SandboxLayout`의 생성자 인자(editor·log·review·onEditorVisible)를 `sandbox_layout.dart`에서 확인해 채운다.

- [ ] **Step 2: 실패 확인 → 구현**

```dart
        Padding(
          padding: const EdgeInsets.all(DpSpacing.sm),
          // 좌측 정렬 — Column의 기본 crossAxisAlignment(center)로는 페이지
          // 헤더의 좌측 정렬과 어긋난다.
          child: Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<int>(…),
          ),
        ),
```

### 14-2 마이페이지 enum 원문 노출

`_goals`(`JOB`·`CAREER_CHANGE`·`UPSKILL`·`SIDE_PROJECT`)와 `_tracks`(`BACKEND_SPRING` 등)가 드롭다운에 원문 그대로 나온다.

- [ ] **Step 3: 테스트를 쓴다**

```dart
  testWidgets('학습 목표·트랙이 한국어 라벨로 표시된다', (tester) async {
    await tester.pumpWidget(/* MyPage를 프로필 로드된 상태로 렌더 */);
    await tester.pumpAndSettle();

    expect(find.text('CAREER_CHANGE'), findsNothing);
    expect(find.text('BACKEND_SPRING'), findsNothing);
    expect(find.text('커리어 전환'), findsWidgets);
  });
```

- [ ] **Step 4: 실패 확인 → 구현**

**전송 payload(`learningGoal`·`targetTrack`)의 값은 그대로 두고 표시 라벨만 바꾼다.** `_goals`·`_tracks`를 `Map<String, String>`으로 바꾸거나 별도 라벨 맵을 둔다:

```dart
  static const _goalLabels = <String, String>{
    'JOB': '취업',
    'CAREER_CHANGE': '커리어 전환',
    'UPSKILL': '역량 강화',
    'SIDE_PROJECT': '사이드 프로젝트',
  };

  static const _trackLabels = <String, String>{
    'BACKEND_SPRING': '백엔드 (Spring)',
    'FRONTEND_REACT': '프론트엔드 (React)',
    'MOBILE_FLUTTER': '모바일 (Flutter)',
    'DEVOPS': 'DevOps',
    'FULLSTACK': '풀스택',
  };
```

**`_tracks`의 실제 값 목록을 `mypage_page.dart:64-72`에서 읽어 정확히 맞춘다** — 위 5개와 다를 수 있다. `DropdownMenuItem(value: k, child: Text(labels[k]!))` 형태로 쓰고, `initialValue`·`onChanged`는 그대로 원문 값을 다룬다.

### 14-3 커뮤니티 작성 문구 중복

헤더 설명과 본문 안내가 사실상 같은 말이다(2단계 계획이 헤더 문구를 지정하면서 본문 수정을 금지해 생긴 결과).

- [ ] **Step 5: 두 화면의 실제 문구를 읽고 판단한다**

```
cd apps/web && grep -n "DpPageHeader" -A5 lib/src/features/community/presentation/post_create_page.dart lib/src/features/community/presentation/question_create_page.dart
```

같은 뜻이면 **본문 안내를 제거한다**(헤더가 더 눈에 띄는 자리다). 본문 안내에 헤더에 없는 정보(예: 작성 규칙·글자 수 제한)가 있으면 그 부분만 남긴다. 기존 테스트가 본문 문구를 단언하면 함께 고친다.

### 14-4 `beta_pending` 원시 여백

- [ ] **Step 6: `DpSpacing`으로 바꾼다**

`beta_pending_page.dart:87,95,101,104`의 `SizedBox(height: 16)` → `DpSpacing.md`, `SizedBox(height: 24)` → `DpSpacing.lg`. **`DpSpacing`의 실제 값을 `dp_spacing.dart`에서 확인하고 16·24에 대응하는 이름을 쓴다.** 값이 정확히 일치하지 않으면 가장 가까운 토큰을 쓰되 시각 변화가 생김을 인지한다.

- [ ] **Step 7: 테스트를 돌린다**

```
cd apps/web && flutter test
```

- [ ] **Step 8: 커밋**

```bash
git add apps/web
git commit -m "fix(web): 샌드박스 탭 정렬·마이페이지 라벨·작성 문구·여백 토큰을 정리한다"
```

---

## Task 15: 커버리지 공백과 문서 정합

**Files:**
- Modify: `apps/web/test/features/path/path_title_test.dart`
- Modify: `apps/web/test/features/sandbox/` (헤더 단언 추가)
- Modify: `packages/dp_design/test/shell/dp_chrome_bar_test.dart` (주석)
- Modify: `apps/web/lib/src/features/shell/presentation/app_shell.dart` · `apps/admin/.../admin_shell.dart` (주석)
- Modify: `docs/DESIGN.md` (§9에 헤더 스크롤 규칙 절)

### 15-1 `path_title_test` 동어반복 해소

**문제:** 이 테스트가 `PathPage`가 아니라 **테스트가 직접 조립한 `Column`을 렌더한다.** 2단계 계획이 "본문을 빈 `SizedBox`로 바꿔라"고 지시해, 검증 대상 텍스트를 만들 위젯이 하나뿐이 되어 `findsOneWidget`이 **구조적으로 항상 참**이 됐다.

- [ ] **Step 1: 실제 `PathPage`를 렌더하도록 고친다**

`apps/web/test/features/path/path_page_test.dart`(있으면)의 provider override를 참고해 실제 `PathPage`를 띄우고, 헤더 제목을 `tester.widget<DpPageHeader>(…)`의 `title` 필드로 단언한다:

```dart
    final header = tester.widget<DpPageHeader>(find.byType(DpPageHeader));
    expect(header.title, '학습 경로');
```

**`find.text('학습 경로')`를 쓰지 마라** — 레일 라벨·브레드크럼과 같은 문자열이라 셸 포함 렌더에서 깨진다.

- [ ] **Step 2: 이 테스트를 지우면 red가 되는지 확인한다**

`PathPage`의 `DpPageHeader(title: …)`를 임시로 다른 문자열로 바꿔 테스트가 실패하는지 본다. **실패하지 않으면 여전히 동어반복이다.** 확인 후 원복한다.

### 15-2 샌드박스 헤더 커버

- [ ] **Step 3: 단언을 추가한다**

2단계 스펙 §5가 지정한 유일한 제목 변경(`Sandbox` → `실습 샌드박스`)이 회귀 고정 없이 남아 있다.

```dart
    final header = tester.widget<DpPageHeader>(find.byType(DpPageHeader));
    expect(header.title, '실습 샌드박스');
    expect(header.description, '코드를 작성하고 바로 실행해 봅니다');
```

### 15-3 주석 교정

- [ ] **Step 4: 사실과 어긋난 주석 3건을 고친다**

1. `dp_chrome_bar_test.dart`의 우측 정렬 테스트 주석이 "group을 flex 참여자로 바꾸면서"라 하나 원복으로 더는 flex 참여자가 아니다(테스트 자체는 유효)
2. `app_shell.dart`·`admin_shell.dart`가 인용한 `dp_nav_rail.dart:91`은 실제로 `:75-82`(정의)·`:94`(적용)였다 — **Task 2에서 이 주석 블록을 이미 삭제했으므로 남아 있는지만 확인한다**
3. `dp_chrome_bar.dart`의 I2 주석은 Task 4에서 갱신했다 — 확인만

### 15-4 `DESIGN.md` 헤더 스크롤 규칙

- [ ] **Step 5: §9(셸 구조)에 절을 추가한다**

```markdown
### 9.x 페이지 헤더의 스크롤 거동

일관성의 기준은 「모든 화면 동일」이 아니라 **「화면 유형별 동일」** 이다.

- **문서형** — 본문이 스크롤 축을 가지는 화면. 페이지 헤더도 `CustomScrollView`의
  `SliverToBoxAdapter`로 실어 **본문과 함께 스크롤**한다. 크롬바(46px 고정)에
  브레드크럼이 있으므로 헤더가 사라져도 위치를 잃지 않는다.
  (web `dashboard`·`path`·`content`·`mypage`·`settings`·커뮤니티 5화면,
   admin `dashboard`·`reports`)
- **뷰포트 고정형** — 본문이 남은 높이를 꽉 채우는 화면. 헤더를 **고정**한다.
  (web `mentor`(채팅+하단 입력창)·`sandbox`(탭+에디터),
   admin `users`·`ads`·`support`(`DpDataTable` 자체 뷰포트))

뷰포트 고정형에서 헤더를 `SliverFillRemaining`으로 감싸면 남은 높이를 전부
차지해 **바깥 스크롤 여지가 0이 되므로 헤더는 결국 고정이다.** 코드만
복잡해지고 결과가 같으므로 하지 않는다.
```

- [ ] **Step 6: 전체 검증**

```
dart pub global run melos run analyze
dart pub global run melos run format
dart pub global run melos run test
py docs/superpowers/specs/2026-08-03-token-contrast-check.py
```

Expected: analyze 이슈 0 · format clean · 전 패키지 green · 대비 미달 0건.

- [ ] **Step 7: 커밋**

```bash
git add apps packages docs
git commit -m "test(web): 동어반복 테스트를 해소하고 헤더 스크롤 규칙을 문서화한다"
```

---

## Task 16: 육안 확인

**★2단계에서 위젯 테스트 321건이 전부 green인 상태로 레이아웃 결함 2건이 나왔다★**(크롬바 우측 448px 여백·브레드크럼 비대칭). 자동 테스트로 대체하지 마라.

**Files:**
- Create: `docs/superpowers/reports/2026-08-06-design-phase3a-visual-check.md`
- (임시 수정 후 **반드시 원복**: `apps/web/lib/.../web_mock_fixtures.dart` · `theme_provider.dart`)

- [ ] **Step 1: 목 모드 릴리스 빌드를 만든다**

목 유저는 `onboardingStatus: PENDING`이라 앱이 `/diagnostic`으로 리다이렉트된다. 셸 화면을 보려면 `web_mock_fixtures.dart`를 임시로 `DONE`으로 바꿔 빌드한다. **캡처 후 반드시 원복한다** — 골든패스 테스트 2건이 `PENDING`을 전제한다.

```
cd apps/web && flutter build web --release
```

- [ ] **Step 2: 정적 서버로 띄운다**

```
cd apps/web/build/web && py -m http.server 8099
```

해시 라우팅(`usePathUrlStrategy()` 미호출)이라 SPA 폴백이 필요 없다. **`python`이 아니라 `py`다.**

- [ ] **Step 3: 라이트 테마를 4폭으로 캡처한다**

500·700·1000·1400 × 주요 화면(대시보드·경로·멘토·커뮤니티 홈·게시글 상세·설정·마이페이지·샌드박스·admin 5화면).

`bootstrapSession()`이 목 `/auth/refresh`로 자동 인증하므로 로그인 클릭이 필요 없다. URL만 바꿔가며 캡처한다.

- [ ] **Step 4: 다크 테마를 별도 빌드로 캡처한다**

CDP `Emulation.setEmulatedMedia`가 gstack browse allowlist에서 **차단된다.** `theme_provider.dart`의 기본값을 임시로 `ThemeMode.dark`로 바꿔 따로 빌드한다.

**재빌드해도 화면이 그대로면 서비스워커 캐시다** — 포트를 바꿔 새 origin으로 띄우면 우회된다(2단계에서 다크가 라이트로 찍혀 한 번 헛짚었다).

- [ ] **Step 5: 셸 밖 4화면도 캡처한다**

login·beta-pending·consent·diagnostic. 2단계에서는 목 유저 자동 인증 탓에 빠졌다 — 픽스처를 임시로 손대야 한다.

- [ ] **Step 6: 이번 변경의 확인 지점을 특히 본다**

| 확인 항목 | 무엇을 보나 |
|---|---|
| 다크 레일 분리감 | 레일이 본문과 구별되는가(Task 3의 목적). 선택 항목 강조가 보이는가 |
| 접힘 레일 브랜드 | medium(700폭)에서 마크가 남아 있는가. 토글로 펼쳐지는가 |
| 헤더 스크롤 | 문서형 화면에서 스크롤 시 헤더가 사라지는가. 뷰포트 고정형은 그대로인가 |
| `DpTag` | 게시글 태그·대시보드 배지·admin 신고 칩이 같은 톤인가 |
| admin 필터 | 헤더 슬롯 안에서 좁은 폭에 줄바꿈하는가. 4화면 간격이 같은가 |
| compact 하단 바 | 400폭 `/settings`·`/mypage`에서 「대시보드」가 강조되지 않는가 |
| 크롬바 | 우측 그룹이 바 오른쪽 끝에 붙는가(2단계 수정이 유지되는가) |

- [ ] **Step 7: 발견한 결함을 red-repro → 수정 → 재캡처한다**

결함마다 실패하는 테스트를 먼저 세우고 **실패 수치를 읽어라.** 2단계에서 브레드크럼 원인을 패딩으로 오진했다가 실패값(8.0 vs 99.75)을 보고서야 `Center`의 폭 확장이 진짜 원인임을 알았다.

수정 후 **실빌드를 다시 캡처해 육안으로 재확인**한다.

- [ ] **Step 8: 임시 수정을 원복하고 확인한다**

```
git diff apps/web/lib
```

`web_mock_fixtures.dart`·`theme_provider.dart`가 원래대로인지 **눈으로 확인한다.**

- [ ] **Step 9: 보고서를 쓴다**

`docs/superpowers/reports/2026-08-06-design-phase3a-visual-check.md`에 캡처 범위·발견 결함·수정 내역·미해결 항목을 적는다.

- [ ] **Step 10: 최종 검증**

```
dart pub global run melos run analyze
dart pub global run melos run format
dart pub global run melos run test
py docs/superpowers/specs/2026-08-03-token-contrast-check.py
```

- [ ] **Step 11: 커밋하고 PR을 연다**

```bash
git add docs apps packages
git commit -m "docs: 3-A 육안 확인 결과를 기록한다"
git push -u origin feat/design-phase3a-shell-fixes
gh pr create --base develop --title "feat: ①디자인 3-A — 셸 결함 해소 + tag* 배선" --body "…"
```

**`develop`에 직접 push하지 않는다**(레포 CLAUDE.md Git 전략).

---

## 완료 기준

- [ ] Task 1~16 전부 완료
- [ ] `melos run analyze` 이슈 0 · `melos run format` clean
- [ ] `melos run test` 전 패키지 green (기준선 이상)
- [ ] 대비 스크립트 미달 **0건**
- [ ] 육안 확인 완료, 발견 결함은 수정하거나 3-B 이월로 명시 기록
- [ ] 임시 픽스처 수정 원복 확인
- [ ] `develop`으로 PR, CI green
