# ①디자인 3-B 구현 계획 — 차트 팔레트 재설계 + 다중 계열

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 차트 팔레트를 브랜드에서 분리해 다중 계열이 실제로 구분되게 만들고, 진행률 추세를 과제 유형별 3계열로 분해하며 주차별 진행률 차트를 신설한다.

**Architecture:** 팔레트는 `dp_design` 토큰에서만 바뀌고 화면은 토큰을 참조한다. 유형별 시계열은 `learning-svc`가 `ProgressPoint.byType`(신규 optional 필드)으로 실어 보내므로 **기존 계약이 깨지지 않는다**. 주차별 차트는 `/paths/current`가 이미 주는 `taskType`·`completed`로 프론트에서 계산해 백엔드를 건드리지 않는다.

**Tech Stack:** Flutter 3.44 · Dart pub workspaces + melos 7 · fl_chart · freezed · Spring Boot 4.0.7 · Java 21 · JdbcTemplate

## Global Constraints

- **스펙:** `docs/superpowers/specs/2026-08-07-design-phase3b-charts-design.md`. 실측 절(§2)은 **다시 조사하지 마라.**
- **melos는 PATH에 없다** — 항상 `dart pub global run melos run <cmd>`로 호출한다
- **`python`은 이 환경에서 스텁이다**(조용히 무동작, rc 0) — 스크립트는 반드시 `py`로 실행한다
- **테스트를 먼저 쓴다**(양 레포 CLAUDE.md 절대조건 2). 실패를 눈으로 확인한 뒤 구현한다
- **`context.dpColors`를 쓰는 위젯 테스트에는 `theme: DpTheme.light()`(또는 `.dark()`)를 반드시 공급한다** — 없으면 null-check 크래시
- **색 단언은 토큰 참조로 쓴다**(`DpColors.light.chart1`). **단 팔레트 값 자체를 고정하는 테스트만 리터럴 hex로** 쓴다 — 둘의 역할이 다르다
- **차트 테스트는 렌더된 fl_chart 데이터 객체를 읽어 단언한다**(`find.text` 우회 금지)
- **`melos run test`는 `--exclude-tags golden`이라 dp_design을 157로 센다.** 직접 실행은 159다 — **두 수치를 섞으면 회귀로 오독한다**
- 기준선(3-A 종료): web **346** · dp_design **159**(직접 실행) · admin **72** · mobile **100** · dp_core **97** green, `analyze` 0, `format` 0 changed
- 커밋은 Conventional Commits. 각 Task 끝에서 커밋한다
- **레포가 둘이다.** 모든 git·파일 명령에 절대경로 또는 `-C <레포 절대경로>`를 쓴다.
  프론트 `D:\workspace\dpa\devpath-frontend` · 백엔드 `D:\workspace\dpa\devpath-learning-svc`

---

## Task 1: 팔레트 검증 스크립트

스펙 §3.2의 기준 6개를 기계로 판정한다. **색을 바꾸기 전에** 스크립트가 먼저 있어야 한다 — 그래야 새 값이 통과하는지 실측으로 말할 수 있다.

**Files:**
- Create: `docs/superpowers/specs/2026-08-07-chart-palette-check.py`

**Interfaces:**
- Produces: `py docs/superpowers/specs/2026-08-07-chart-palette-check.py` → 위반 0건이면 `exit 0`, 있으면 목록 출력 후 `exit 1`

- [ ] **Step 1: 스크립트를 만든다**

`docs/superpowers/specs/2026-08-07-chart-palette-check.py`:

```python
"""차트 팔레트 합격 판정(스펙 3-B §3.2). 위반 0건이면 exit 0.

기준:
  1) 배경 대비 >= 3:1 (bg·surface 각각)
  2) 색각 이상(deuteranopia) 시뮬 후 계열 간 dE76 >= 20
  3) 계열 간 hue차 >= 40도
  4) primary와의 dE76 >= 25
  5) 계열 간 명도 대비 — 기록만(합격 판정에 쓰지 않는다)
  6) success·warning·danger·chart4·chart5와의 dE76 >= 25
"""
import colorsys
import math
import sys

# dp_colors.dart와 손으로 맞춘 값. 토큰을 바꾸면 여기도 바꾼다.
PALETTE = {
    'light': {
        'bg': '#FAF9F7', 'surface': '#FFFFFF', 'primary': '#B45309',
        'success': '#15803D', 'warning': '#A16207', 'danger': '#B91C1C',
        'chart1': '#1D4ED8', 'chart2': '#BE185D', 'chart3': '#7E22CE',
        'chart4': '#0F766E', 'chart5': '#8B857D',
    },
    'dark': {
        'bg': '#0F0E0C', 'surface': '#1A1815', 'primary': '#F59E0B',
        'success': '#4ADE80', 'warning': '#FCD34D', 'danger': '#F87171',
        'chart1': '#60A5FA', 'chart2': '#F472B6', 'chart3': '#D8B4FE',
        'chart4': '#2DD4BF', 'chart5': '#8B857D',
    },
}
SERIES = ['chart1', 'chart2', 'chart3']
# chart5(#8B857D, 라이트·다크 동일)는 스펙 초안이 빠뜨린 실재 토큰이다.
# 지금은 어느 화면에도 배선돼 있지 않지만, 배선되는 순간 기준6의 대상이 된다.
RESERVED = ['success', 'warning', 'danger', 'chart4', 'chart5']


def rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def lum(h):
    def ch(c):
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (ch(x) for x in rgb(h))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = lum(a), lum(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


def to_lab(h):
    r, g, b = rgb(h)

    def inv(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = inv(r), inv(g), inv(b)
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883

    def f(t):
        return t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
    fx, fy, fz = f(x), f(y), f(z)
    return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))


def de76(a, b):
    la, aa, ba = to_lab(a)
    lb, ab, bb = to_lab(b)
    return math.sqrt((la - lb) ** 2 + (aa - ab) ** 2 + (ba - bb) ** 2)


def hue_diff(a, b):
    ha = colorsys.rgb_to_hsv(*rgb(a))[0] * 360
    hb = colorsys.rgb_to_hsv(*rgb(b))[0] * 360
    d = abs(ha - hb)
    return min(d, 360 - d)


def deuteranopia(h):
    """적록 색각 이상 근사. 계열이 시뮬 후에도 갈리는지 보기 위한 것."""
    r, g, b = rgb(h)
    m = (0.625 * r + 0.375 * g, 0.70 * r + 0.30 * g, 0.30 * g + 0.70 * b)
    return '#%02X%02X%02X' % tuple(round(max(0, min(1, c)) * 255) for c in m)


violations = []
for theme, p in PALETTE.items():
    for k in SERIES + ['chart4']:
        for bgk in ('bg', 'surface'):
            cr = contrast(p[k], p[bgk])
            print(f'[{theme}] {k} on {bgk}: {cr:.2f}:1')
            if cr < 3.0:
                violations.append(f'[{theme}] 기준1 {k} on {bgk} = {cr:.2f}:1 (< 3:1)')
    for i in range(len(SERIES)):
        for j in range(i + 1, len(SERIES)):
            a, b = SERIES[i], SERIES[j]
            d = de76(deuteranopia(p[a]), deuteranopia(p[b]))
            hd = hue_diff(p[a], p[b])
            cr = contrast(p[a], p[b])
            print(f'[{theme}] {a}-{b}: 시뮬dE={d:.1f} hue={hd:.1f}도 명도={cr:.2f}:1(기록)')
            if d < 20:
                violations.append(f'[{theme}] 기준2 {a}-{b} 시뮬dE={d:.1f} (< 20)')
            if hd < 40:
                violations.append(f'[{theme}] 기준3 {a}-{b} hue={hd:.1f}도 (< 40)')
    for k in SERIES:
        d = de76(p[k], p['primary'])
        if d < 25:
            violations.append(f'[{theme}] 기준4 {k} vs primary dE={d:.1f} (< 25)')
        for rk in RESERVED:
            dr = de76(p[k], p[rk])
            if dr < 25:
                violations.append(f'[{theme}] 기준6 {k} vs {rk} dE={dr:.1f} (< 25)')

print()
if violations:
    print(f'위반 {len(violations)}건:')
    for v in violations:
        print(f'  - {v}')
    sys.exit(1)
print('위반 0건 — 팔레트 합격')
```

- [ ] **Step 2: 새 값이 통과하는지 확인한다**

```
py docs/superpowers/specs/2026-08-07-chart-palette-check.py
```

Expected: `위반 0건 — 팔레트 합격` (exit 0)

- [ ] **Step 3: 스크립트가 실제로 위반을 잡는지 확인한다(RED 실증)**

`PALETTE['dark']['chart2']`를 임시로 `'#4ADE80'`(다크 `success`와 동일)로 바꿔 실행한다.

Expected: `기준6 chart2 vs success dE=0.0 (< 25)` 가 출력되고 exit 1.
**확인 후 반드시 원복한다.** 원복 후 다시 실행해 위반 0건인지 눈으로 본다.

- [ ] **Step 4: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add docs/superpowers/specs
git -C D:/workspace/dpa/devpath-frontend commit -m "docs: 차트 팔레트 합격 판정 스크립트를 추가한다"
```

---

## Task 2: 팔레트 재정의

**Files:**
- Modify: `packages/dp_design/lib/src/theme/dp_colors.dart:135-137`(라이트 chart1~3) · `:171-173`(다크 chart1~3)
- Modify: `docs/superpowers/specs/2026-08-03-token-contrast-check.py` (딕셔너리의 chart 값)
- Test: `packages/dp_design/test/theme/dp_chart_palette_test.dart` (신규)

**Interfaces:**
- Produces: `DpColors.light.chart1 = #1D4ED8` · `chart2 = #BE185D` · `chart3 = #7E22CE`
- Produces: `DpColors.dark.chart1 = #60A5FA` · `chart2 = #F472B6` · `chart3 = #D8B4FE`
- `chart4`는 **바꾸지 않는다**(라이트 `#0F766E` · 다크 `#2DD4BF`)

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`packages/dp_design/test/theme/dp_chart_palette_test.dart`:

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 차트 팔레트 값 계약. **여기만 리터럴 hex를 쓴다** — 값 자체가 계약이기 때문이다.
/// (다른 테스트는 토큰을 참조한다. 둘의 역할이 다르다.)
///
/// 판정 근거는 `docs/superpowers/specs/2026-08-07-chart-palette-check.py`가 갖고,
/// 이 테스트는 스크립트가 검사한 그 값이 코드에 실제로 들어왔는지를 잠근다.
void main() {
  test('라이트 차트 계열 색이 스펙 값과 일치한다', () {
    expect(DpColors.light.chart1, const Color(0xFF1D4ED8));
    expect(DpColors.light.chart2, const Color(0xFFBE185D));
    expect(DpColors.light.chart3, const Color(0xFF7E22CE));
    expect(DpColors.light.chart4, const Color(0xFF0F766E)); // 보조색 — 불변
  });

  test('다크 차트 계열 색이 스펙 값과 일치한다', () {
    expect(DpColors.dark.chart1, const Color(0xFF60A5FA));
    expect(DpColors.dark.chart2, const Color(0xFFF472B6));
    expect(DpColors.dark.chart3, const Color(0xFFD8B4FE));
    expect(DpColors.dark.chart4, const Color(0xFF2DD4BF)); // 보조색 — 불변
  });

  test('계열 색이 브랜드·의미 토큰과 겹치지 않는다', () {
    // 3-A에서 chart1 == primary 중복이 「이관해도 픽셀 변화 0」을 만들었다.
    // 같은 사고를 값 수준에서 막는다.
    for (final c in [DpColors.light, DpColors.dark]) {
      for (final series in [c.chart1, c.chart2, c.chart3]) {
        expect(series, isNot(c.primary));
        expect(series, isNot(c.success));
        expect(series, isNot(c.warning));
        expect(series, isNot(c.danger));
        expect(series, isNot(c.chart4));
        expect(series, isNot(c.chart5)); // 스펙 초안이 빠뜨린 실재 토큰
      }
    }
  });
}
```

- [ ] **Step 2: 실패 확인**

```
cd packages/dp_design && flutter test test/theme/dp_chart_palette_test.dart
```

Expected: FAIL — 현재 값은 `#B45309`/`#B8863A`/`#78350F`(라이트), `#F59E0B`/`#D9A653`/`#FCD34D`(다크)다.

- [ ] **Step 3: 토큰을 바꾼다**

`dp_colors.dart`의 라이트 블록(135-137행):

```dart
    chart1: Color(0xFF1D4ED8),
    chart2: Color(0xFFBE185D),
    chart3: Color(0xFF7E22CE),
```

다크 블록(171-173행):

```dart
    chart1: Color(0xFF60A5FA),
    chart2: Color(0xFFF472B6),
    chart3: Color(0xFFD8B4FE),
```

`chart4`는 두 블록 모두 **손대지 않는다.**

- [ ] **Step 4: 기존 대비 스크립트의 딕셔너리도 갱신한다**

`docs/superpowers/specs/2026-08-03-token-contrast-check.py`에서 `chart1`·`chart2`·`chart3` 값을 위와 같게 바꾼다.
**빠뜨리면 검증이 옛 값을 계속 통과시킨다** — 3-A Task 3에서 실제로 걸렸던 함정이다.

- [ ] **Step 5: 세 검증을 모두 돌린다**

```
cd packages/dp_design && flutter test
py docs/superpowers/specs/2026-08-07-chart-palette-check.py
py docs/superpowers/specs/2026-08-03-token-contrast-check.py
```

Expected: dp_design **162** green(159 + 신규 3) · 팔레트 위반 0건 · 대비 미달 0건.

- [ ] **Step 6: `chart*` 소비처가 깨지지 않았는지 확인한다**

```
cd D:/workspace/dpa/devpath-frontend && grep -rn "chart1\|chart2\|chart3\|chart4" apps packages --include=*.dart | grep -v "_test.dart" | grep -v "dp_colors.dart"
```

나온 파일 각각을 열어 **의미가 깨진 곳이 없는지** 확인한다(색만 바뀌므로 컴파일은 통과한다). 확인 결과를 보고서에 적는다.

- [ ] **Step 7: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add packages/dp_design docs/superpowers/specs
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(dp_design): 차트 계열 색을 브랜드에서 분리해 재정의한다"
```

---

## Task 3: 기존 차트 3종 색 교체

팔레트가 바뀌었으니 화면이 그것을 쓰게 한다. **도넛의 토큰 오용도 여기서 고친다.**

**Files:**
- Modify: `apps/web/lib/src/features/dashboard/presentation/widgets/weekly_activity_card.dart:99`
- Modify: `apps/web/lib/src/features/dashboard/presentation/widgets/progress_donut.dart:33,39`
- Test: `apps/web/test/features/dashboard/dashboard_chart_colors_test.dart` (신규)

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`apps/web/test/features/dashboard/dashboard_chart_colors_test.dart`:

```dart
import 'package:devpath_web/src/features/dashboard/presentation/widgets/progress_donut.dart';
import 'package:devpath_web/src/features/dashboard/presentation/widgets/weekly_activity_card.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) =>
    MaterialApp(theme: DpTheme.light(), home: Scaffold(body: child));

void main() {
  // 색 단언은 **토큰 참조**로 쓴다(리터럴 hex는 팔레트 계약 테스트의 몫).
  testWidgets('주간 활동 막대는 chart1을 쓴다', (tester) async {
    await tester.pumpWidget(
      _host(
        const WeeklyActivityCard(
          activity: [
            DailyActivity(date: '2026-08-01', completedCount: 2),
            DailyActivity(date: '2026-08-02', completedCount: 3),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chart = tester.widget<BarChart>(find.byType(BarChart));
    final rod = chart.data.barGroups.first.barRods.first;
    expect(rod.color, DpColors.light.chart1);
  });

  testWidgets('도넛은 완료 chart1 · 미완료 surfaceMuted를 쓴다', (tester) async {
    await tester.pumpWidget(_host(const ProgressDonut(percent: 62)));
    await tester.pumpAndSettle();

    final chart = tester.widget<PieChart>(find.byType(PieChart));
    final sections = chart.data.sections;
    expect(sections.length, 2);
    expect(sections[0].color, DpColors.light.chart1);
    // 경계선 토큰(border)을 데이터 면에 쓰던 오용을 면 토큰으로 바로잡는다.
    expect(sections[1].color, DpColors.light.surfaceMuted);
    expect(sections[1].color, isNot(DpColors.light.border));
  });
}
```

- [ ] **Step 2: 실패 확인**

```
cd apps/web && flutter test test/features/dashboard/dashboard_chart_colors_test.dart
```

Expected: FAIL — 현재는 셋 다 `c.primary`이고 미완료는 `c.border`다.

- [ ] **Step 3: 구현**

`weekly_activity_card.dart:99` — `color: c.primary,` → `color: c.chart1,`

`progress_donut.dart:33` — `color: c.primary,` → `color: c.chart1,`

`progress_donut.dart:39` — `color: c.border,` → 다음으로 바꾸고 주석을 남긴다:

```dart
                    // 미완료는 **면**이다 — 경계선 토큰(border)을 면에 쓰던 오용을
                    // 면 토큰으로 바로잡는다(3-B 스펙 §4).
                    color: c.surfaceMuted,
```

- [ ] **Step 4: 통과 확인 + 회귀**

```
cd apps/web && flutter test test/features/dashboard/
```

Expected: 신규 2건 통과, 기존 대시보드 테스트 green.

- [ ] **Step 5: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add apps/web
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(web): 대시보드 차트가 새 계열 색을 쓰고 도넛 토큰 오용을 고친다"
```

---

## Task 4: [백엔드] 완료일을 유형과 함께 집계한다

**Files:**
- Modify: `src/main/java/ai/devpath/learning/content/ContentProgressRepository.java:102-122`
- Test: `src/test/java/ai/devpath/learning/content/ContentProgressRepositoryTest.java` (있으면 수정, 없으면 생성)

**Interfaces:**
- Produces: `record ActivePathCompletions(int totalTasks, List<LocalDate> completedDates, Map<String, Integer> totalByType, Map<String, List<LocalDate>> completedByType)`
  - **기존 두 필드를 남긴다** — `DashboardService`의 전체 진행률 경로가 그대로 동작해야 한다
  - `taskType` 키는 DB 원문(`READ`·`PRACTICE`·`QUIZ`)이다

- [ ] **Step 1: 레코드를 확장한다**

`ContentProgressRepository.java:122`:

```java
  /** 활성 경로의 전체/유형별 과제 수와 완료일. taskType 키는 DB 원문(READ·PRACTICE·QUIZ). */
  public record ActivePathCompletions(
      int totalTasks,
      List<LocalDate> completedDates,
      Map<String, Integer> totalByType,
      Map<String, List<LocalDate>> completedByType) {}
```

- [ ] **Step 2: 쿼리를 유형별로 확장한다**

`activePathCompletions`(102-120행)를 다음으로 바꾼다:

```java
  public ActivePathCompletions activePathCompletions(long userId) {
    var totalSql = """
        SELECT t.task_type AS tt, count(*) AS n
        FROM path_weekly_tasks t
        JOIN path_milestones m ON m.id = t.milestone_id
        JOIN learning_paths p ON p.id = m.path_id
        WHERE p.user_id = :userId AND p.status = 'ACTIVE'
        GROUP BY t.task_type
        """;
    Map<String, Integer> totalByType = new HashMap<>();
    jdbc.query(totalSql, Map.of("userId", userId),
        rs -> { totalByType.put(rs.getString("tt"), rs.getInt("n")); });

    var datesSql = """
        SELECT t.task_type AS tt, (t.completed_at AT TIME ZONE 'Asia/Seoul')::date AS d
        FROM path_weekly_tasks t
        JOIN path_milestones m ON m.id = t.milestone_id
        JOIN learning_paths p ON p.id = m.path_id
        WHERE p.user_id = :userId AND p.status = 'ACTIVE' AND t.completed_at IS NOT NULL
        """;
    Map<String, List<LocalDate>> completedByType = new HashMap<>();
    List<LocalDate> allDates = new ArrayList<>();
    jdbc.query(datesSql, Map.of("userId", userId), rs -> {
      LocalDate d = rs.getObject("d", LocalDate.class);
      completedByType.computeIfAbsent(rs.getString("tt"), k -> new ArrayList<>()).add(d);
      allDates.add(d);
    });

    int total = totalByType.values().stream().mapToInt(Integer::intValue).sum();
    return new ActivePathCompletions(total, allDates, totalByType, completedByType);
  }
```

import에 `java.util.ArrayList`가 없으면 추가한다.

- [ ] **Step 3: 빌드·테스트**

```
cd D:/workspace/dpa/devpath-learning-svc && ./gradlew test
```

Expected: 기존 테스트 green(전체 필드가 유지되므로 `DashboardService` 경로는 그대로 동작한다).

- [ ] **Step 4: 커밋**

```bash
git -C D:/workspace/dpa/devpath-learning-svc add src/main/java
git -C D:/workspace/dpa/devpath-learning-svc commit -m "feat(dashboard): 활성 경로 완료일을 과제 유형별로 집계한다"
```

---

## Task 5: [백엔드] 유형별 진행률 추세

**Files:**
- Modify: `src/main/java/ai/devpath/learning/dashboard/ProgressPoint.java`
- Modify: `src/main/java/ai/devpath/learning/dashboard/DashboardTimeseries.java:26-39`
- Modify: `src/main/java/ai/devpath/learning/dashboard/DashboardService.java:44-45`
- Test: `src/test/java/ai/devpath/learning/dashboard/DashboardTimeseriesTest.java`

**Interfaces:**
- Consumes: Task 4의 `ActivePathCompletions.totalByType`·`completedByType`
- Produces: `record ProgressPoint(String date, int percent, Map<String, Integer> byType)`
  - `percent`는 **전체 누적%로 유지**한다(기존 소비자 보호)
  - `byType`은 유형별 누적%. 해당 유형의 과제가 0개면 그 키는 **아예 없다**(0%로 채우지 않는다 — 「없음」과 「0%」는 다르다)
- Produces: `DashboardTimeseries.progressHistory(LocalDate today, ActivePathCompletions pc)`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`DashboardTimeseriesTest.java`에 추가한다:

```java
  @Test
  void progressHistory_유형별_누적률을_함께_낸다() {
    LocalDate today = LocalDate.of(2026, 8, 7);
    var pc = new ContentProgressRepository.ActivePathCompletions(
        4,
        List.of(LocalDate.of(2026, 8, 5), LocalDate.of(2026, 8, 6)),
        Map.of("READ", 2, "PRACTICE", 2),
        Map.of("READ", List.of(LocalDate.of(2026, 8, 5)),
               "PRACTICE", List.of(LocalDate.of(2026, 8, 6))));

    List<ProgressPoint> out = DashboardTimeseries.progressHistory(today, pc);

    assertThat(out).hasSize(DashboardTimeseries.HISTORY_DAYS);
    ProgressPoint last = out.get(out.size() - 1);
    assertThat(last.date()).isEqualTo("2026-08-07");
    assertThat(last.percent()).isEqualTo(50);           // 전체 2/4
    assertThat(last.byType()).containsEntry("READ", 50); // 1/2
    assertThat(last.byType()).containsEntry("PRACTICE", 50);

    // 8/5 시점: READ만 완료됐다
    ProgressPoint onAug5 = out.stream()
        .filter(p -> p.date().equals("2026-08-05")).findFirst().orElseThrow();
    assertThat(onAug5.byType()).containsEntry("READ", 50);
    assertThat(onAug5.byType()).containsEntry("PRACTICE", 0);
  }

  @Test
  void progressHistory_과제가_없는_유형은_키_자체가_없다() {
    LocalDate today = LocalDate.of(2026, 8, 7);
    var pc = new ContentProgressRepository.ActivePathCompletions(
        2, List.of(), Map.of("READ", 2), Map.of());

    List<ProgressPoint> out = DashboardTimeseries.progressHistory(today, pc);

    // 「QUIZ가 0%」와 「QUIZ 과제가 아예 없다」는 다르다 — 후자는 키가 없어야 한다.
    assertThat(out.get(0).byType()).containsOnlyKeys("READ");
  }
```

`ContentProgressRepository`·`Map` import를 추가한다.

- [ ] **Step 2: 실패 확인**

```
cd D:/workspace/dpa/devpath-learning-svc && ./gradlew test --tests "*DashboardTimeseriesTest*"
```

Expected: 컴파일 실패 — `progressHistory(LocalDate, ActivePathCompletions)` 시그니처와 `ProgressPoint.byType()`이 없다.

**★주의: 이 시점의 컴파일 실패는 신규 테스트만의 것이 아니다.★** 계약을 바꾸면 **기존 테스트 3곳이 함께 깨진다**(실측 확인):

| 위치 | 깨지는 이유 |
|---|---|
| `DashboardTimeseriesTest.java:37` | `progressHistory(TODAY, 4, done)` — 3-인자 호출 |
| `DashboardTimeseriesTest.java:47` | `progressHistory(TODAY, 0, List.of())` — 3-인자 호출 |
| `DashboardSummaryJsonTest.java:17` | `new ProgressPoint("2026-07-31", 42)` — **2-인자 생성자** |

따라서 RED 신호가 섞인다. **신규 테스트의 실패만 골라 읽지 말고, 위 3곳이 그리고 오직 그 3곳만 함께 깨졌는지 확인한다.** 고치는 것은 Step 6이다.

- [ ] **Step 3: `ProgressPoint`를 확장한다**

```java
package ai.devpath.learning.dashboard;

import java.util.Map;

/**
 * 진행률 추이 1점. [date] KST 기준 ISO 날짜(yyyy-MM-dd), [percent] 0~100 전체 누적 완료율.
 * [byType] 과제 유형(READ·PRACTICE·QUIZ)별 누적 완료율. 해당 유형의 과제가 0개면 키가 없다.
 */
public record ProgressPoint(String date, int percent, Map<String, Integer> byType) {}
```

- [ ] **Step 4: `progressHistory`를 바꾼다**

`DashboardTimeseries.java`의 `progressHistory`를 다음으로 교체한다(기존 3-인자 버전은 지운다):

```java
  /** 최근 HISTORY_DAYS일 누적 완료율(%). 전체 과제가 없으면 빈 배열. date는 ISO 문자열. */
  static List<ProgressPoint> progressHistory(
      LocalDate today, ContentProgressRepository.ActivePathCompletions pc) {
    if (pc.totalTasks() <= 0) {
      return List.of();
    }
    List<ProgressPoint> out = new ArrayList<>(HISTORY_DAYS);
    for (int i = HISTORY_DAYS - 1; i >= 0; i--) {
      LocalDate d = today.minusDays(i);
      long done = pc.completedDates().stream().filter(cd -> !cd.isAfter(d)).count();
      int percent = (int) Math.round(done * 100.0 / pc.totalTasks());

      Map<String, Integer> byType = new LinkedHashMap<>();
      for (Map.Entry<String, Integer> e : pc.totalByType().entrySet()) {
        int typeTotal = e.getValue();
        if (typeTotal <= 0) {
          continue;
        }
        long typeDone = pc.completedByType().getOrDefault(e.getKey(), List.of()).stream()
            .filter(cd -> !cd.isAfter(d)).count();
        byType.put(e.getKey(), (int) Math.round(typeDone * 100.0 / typeTotal));
      }
      out.add(new ProgressPoint(d.toString(), percent, byType));
    }
    return out;
  }
```

import에 `java.util.LinkedHashMap`과 `ai.devpath.learning.content.ContentProgressRepository`를 추가한다.

- [ ] **Step 5: 호출부를 고친다**

`DashboardService.java:44-45`:

```java
    List<ProgressPoint> progressHistory = DashboardTimeseries.progressHistory(today, pc);
```

(`pc`는 42-43행에서 이미 얻고 있다. `DashboardService`의 `progressHistory` **변수** 사용처
2곳(`:50`·`:65`)은 `DashboardSummary` 생성자 인자라 **시그니처 변경의 영향을 받지 않는다** — 손대지 않는다.)

- [ ] **Step 6: 계약 변경으로 깨진 기존 테스트 3곳을 고친다**

Step 2에서 확인한 3곳이다. **숫자만 맞추지 말고 각 테스트가 무엇을 지키던 것인지 유지한다.**

`DashboardTimeseriesTest.java` — 두 호출을 새 record로 감싼다. 기존 단언(누적 50%·75%, 빈 배열)은
**그대로 둔다**. 유형별 단언은 이 Task의 신규 테스트가 따로 담당한다.

```java
    var pc = new ContentProgressRepository.ActivePathCompletions(
        4, done, Map.of("READ", 4), Map.of("READ", done));

    List<ProgressPoint> out = DashboardTimeseries.progressHistory(TODAY, pc);
```

```java
    var empty = new ContentProgressRepository.ActivePathCompletions(
        0, List.of(), Map.of(), Map.of());
    assertThat(DashboardTimeseries.progressHistory(TODAY, empty)).isEmpty();
```

`ai.devpath.learning.content.ContentProgressRepository` import를 추가한다.

`DashboardSummaryJsonTest.java:17` — 계약 **직렬화** 검증이다. 새 필드가 JSON에 나가는지
여기서 함께 잠근다(그러지 않으면 `byType`이 전송 계약에 들어갔는지 아무도 검사하지 않는다):

```java
        List.of(new ProgressPoint("2026-07-31", 42, Map.of("READ", 42))));
```

```java
    assertThat(json).contains("\"byType\"").contains("\"READ\":42");
```

`java.util.Map` import를 추가한다.

- [ ] **Step 7: 테스트 통과 확인**

```
cd D:/workspace/dpa/devpath-learning-svc && ./gradlew test
```

Expected: 신규 2건 포함 전부 green.

- [ ] **Step 8: 커밋**

```bash
git -C D:/workspace/dpa/devpath-learning-svc add src
git -C D:/workspace/dpa/devpath-learning-svc commit -m "feat(dashboard): 진행률 추이에 과제 유형별 누적률을 더한다"
```

---

## Task 6: dp_core 계약 확장

**Files:**
- Modify: `packages/dp_core/lib/src/models/dashboard_timeseries.dart:20-26`
- Test: `packages/dp_core/test/models/dashboard_timeseries_test.dart` (있으면 수정, 없으면 생성)

**Interfaces:**
- Consumes: Task 5의 JSON — `{"date": "2026-08-07", "percent": 50, "byType": {"READ": 50}}`
- Produces: `ProgressPoint(date, percent, byType)` — `byType`은 `@Default(<String, int>{})`라 **필드가 없는 옛 응답도 파싱된다**

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`packages/dp_core/test/models/dashboard_timeseries_test.dart`:

```dart
import 'package:dp_core/dp_core.dart';
import 'package:test/test.dart';

void main() {
  test('byType이 있는 응답을 파싱한다', () {
    final p = ProgressPoint.fromJson(const {
      'date': '2026-08-07',
      'percent': 50,
      'byType': {'READ': 50, 'PRACTICE': 0},
    });
    expect(p.date, '2026-08-07');
    expect(p.percent, 50);
    expect(p.byType['READ'], 50);
    expect(p.byType['PRACTICE'], 0);
  });

  test('byType이 없는 옛 응답도 깨지지 않는다', () {
    // 백엔드가 먼저 배포되지 않은 상태에서도 웹이 살아 있어야 한다.
    final p = ProgressPoint.fromJson(const {'date': '2026-08-07', 'percent': 50});
    expect(p.byType, isEmpty);
  });
}
```

- [ ] **Step 2: 실패 확인**

```
cd packages/dp_core && dart test test/models/dashboard_timeseries_test.dart
```

Expected: FAIL — `byType` 게터가 없다.

- [ ] **Step 3: 모델을 확장한다**

`dashboard_timeseries.dart:20-26`:

```dart
/// 진행률 추이 1점(백엔드 `ProgressPoint`). [percent]=0~100 전체 누적률.
/// [byType]=과제 유형(READ·PRACTICE·QUIZ)별 누적률. 해당 유형의 과제가 0개면 키가 없다.
/// 백엔드가 먼저 배포되지 않아도 깨지지 않도록 기본값을 빈 맵으로 둔다.
@freezed
abstract class ProgressPoint with _$ProgressPoint {
  const factory ProgressPoint({
    required String date,
    @Default(0) int percent,
    @Default(<String, int>{}) Map<String, int> byType,
  }) = _ProgressPoint;

  factory ProgressPoint.fromJson(Map<String, dynamic> json) =>
      _$ProgressPointFromJson(json);
}
```

- [ ] **Step 4: 코드 생성 + 테스트**

```
cd packages/dp_core && dart run build_runner build --delete-conflicting-outputs && dart test
```

Expected: dp_core **99** green(97 + 신규 2).

- [ ] **Step 5: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add packages/dp_core
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(dp_core): ProgressPoint에 유형별 누적률을 더한다"
```

---

## Task 7: `DpChartLegend` 신설

**Files:**
- Create: `packages/dp_design/lib/src/data/dp_chart_legend.dart`
- Modify: `packages/dp_design/lib/dp_design.dart` (export 추가)
- Test: `packages/dp_design/test/data/dp_chart_legend_test.dart`

**Interfaces:**
- Produces: `class DpChartLegend extends StatelessWidget { const DpChartLegend({super.key, required this.items}); final List<({Color color, String label})> items; }`
- **Widget 슬롯을 받지 않는다** — 앱이 스타일을 실을 통로를 만들지 않는다(3-A `DpRailBrand`의 교훈)

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`packages/dp_design/test/data/dp_chart_legend_test.dart`:

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child, {double width = 400}) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(body: SizedBox(width: width, child: child)),
);

void main() {
  testWidgets('항목마다 색 견본과 라벨을 렌더한다', (tester) async {
    await tester.pumpWidget(
      _host(
        DpChartLegend(
          items: [
            (color: DpColors.light.chart1, label: '읽기'),
            (color: DpColors.light.chart2, label: '실습'),
          ],
        ),
      ),
    );

    expect(find.text('읽기'), findsOneWidget);
    expect(find.text('실습'), findsOneWidget);
    // 견본은 색을 그대로 쓴다 — 앱이 넘긴 색이 컴포넌트에서 바뀌면 안 된다.
    final swatches = tester.widgetList<Container>(
      find.byKey(const ValueKey('dp-chart-legend-swatch')),
    );
    expect(swatches.length, 2);
    expect(
      (swatches.first.decoration! as BoxDecoration).color,
      DpColors.light.chart1,
    );
  });

  testWidgets('항목이 1개면 1개만 렌더한다', (tester) async {
    // 유형이 한 종류뿐인 경로에서 범례가 어색해지지 않는지 잠근다.
    await tester.pumpWidget(
      _host(DpChartLegend(items: [(color: DpColors.light.chart1, label: '읽기')])),
    );
    expect(find.text('읽기'), findsOneWidget);
    expect(find.text('실습'), findsNothing);
  });

  testWidgets('좁은 폭에서 오버플로하지 않는다', (tester) async {
    await tester.pumpWidget(
      _host(
        DpChartLegend(
          items: [
            (color: DpColors.light.chart1, label: '읽기'),
            (color: DpColors.light.chart2, label: '실습'),
            (color: DpColors.light.chart3, label: '퀴즈'),
          ],
        ),
        width: 120,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: 실패 확인**

```
cd packages/dp_design && flutter test test/data/dp_chart_legend_test.dart
```

Expected: FAIL — `DpChartLegend`가 없다.

- [ ] **Step 3: 구현**

`packages/dp_design/lib/src/data/dp_chart_legend.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';

/// 차트 계열 범례. 색 견본 + 라벨을 나란히 놓고 좁은 폭에서 줄바꿈한다.
///
/// **입력은 레코드 리스트 하나뿐이다 — Widget 슬롯을 받지 않는다.** 앱이 스타일을
/// 실을 통로를 애초에 만들지 않는다(3-A `DpRailBrand`에서 같은 함정을 타입으로 닫았다).
class DpChartLegend extends StatelessWidget {
  const DpChartLegend({super.key, required this.items});

  final List<({Color color, String label})> items;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;
    return Wrap(
      spacing: DpSpacing.md,
      runSpacing: DpSpacing.xs,
      children: [
        for (final it in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                key: const ValueKey('dp-chart-legend-swatch'),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: it.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: DpSpacing.xs),
              Text(
                it.label,
                style: text.bodySmall?.copyWith(color: c.textSecondary),
              ),
            ],
          ),
      ],
    );
  }
}
```

`packages/dp_design/lib/dp_design.dart`에 export를 추가한다:

```dart
export 'src/data/dp_chart_legend.dart';
```

- [ ] **Step 4: 통과 확인**

```
cd packages/dp_design && flutter test
```

Expected: dp_design **165** green(162 + 신규 3).

- [ ] **Step 5: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add packages/dp_design
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(dp_design): 차트 범례 DpChartLegend를 신설한다"
```

---

## Task 8: 진행률 추세 다중 계열

**Files:**
- Modify: `apps/web/lib/src/features/dashboard/presentation/widgets/progress_trend_card.dart`
- Test: `apps/web/test/features/dashboard/progress_trend_card_test.dart` — **이미 존재한다(38줄·2건).
  덮어쓰지 말고 병합한다.** 기존 2건은 `const ProgressTrendCard(history: [...])`로 렌더 여부만 본다:
  ① 「데이터 있으면 LineChart 렌더」는 아래 신규 1번이 더 강하게 덮으므로 **지운다**.
  ② 「빈 배열이면 빈 상태 안내」는 아래 신규 4번과 **완전히 같은 것을 검사한다** — 신규 4번을 쓰지 말고
  **기존 것을 그대로 남긴다**(같은 검사를 두 벌 두지 않는다). 결과적으로 이 파일은 **2 + 3 = 5건**이 된다.

**Interfaces:**
- Consumes: Task 6의 `ProgressPoint.byType` · Task 7의 `DpChartLegend`
- 계열 순서·색·라벨은 **이 파일의 상수 하나**가 정한다:
  `const _series = [(key: 'READ', label: '읽기'), (key: 'PRACTICE', label: '실습'), (key: 'QUIZ', label: '퀴즈')]`
  **키는 서버 enum 원문이라 불변**이고 라벨만 표시용이다(3-A Task 14-2와 같은 규칙)

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`apps/web/test/features/dashboard/progress_trend_card_test.dart`:

```dart
import 'package:devpath_web/src/features/dashboard/presentation/widgets/progress_trend_card.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) =>
    MaterialApp(theme: DpTheme.light(), home: Scaffold(body: child));

/// byType에 유형 n종이 **실제로 들어 있는** 히스토리를 만든다.
/// 「유형별로 나눴다」를 선언하는 것과 조건이 성립하는 것은 다르다(3-A의 반복 교훈).
List<ProgressPoint> _history(Map<String, int> byType) => [
  for (var i = 0; i < 14; i++)
    ProgressPoint(date: '2026-08-${(i + 1).toString().padLeft(2, '0')}',
        percent: i * 5, byType: byType),
];

void main() {
  testWidgets('유형 3종이면 선 3개와 범례 3개를 렌더한다', (tester) async {
    final history = _history(const {'READ': 80, 'PRACTICE': 40, 'QUIZ': 60});
    // 조건 성립 검산: 계열 키가 정말 3개인가
    expect(history.first.byType.keys.length, 3);

    await tester.pumpWidget(_host(ProgressTrendCard(history: history)));
    await tester.pumpAndSettle();

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.length, 3);
    expect(chart.data.lineBarsData[0].color, DpColors.light.chart1);
    expect(chart.data.lineBarsData[1].color, DpColors.light.chart2);
    expect(chart.data.lineBarsData[2].color, DpColors.light.chart3);
    // 채움은 제거했다 — 반투명 면 3장이 겹치면 계열 판별이 나빠진다.
    // ★`every(...) == isFalse`로 쓰지 마라 — 그것은 「셋 중 하나만 꺼도」 통과한다.
    // 3선 **전부**를 잠그려면 any로 쓴다(스펙 §7.2: 테스트가 조건을 피해 가지 않게).
    expect(chart.data.lineBarsData.any((b) => b.belowBarData.show), isFalse);

    expect(find.byType(DpChartLegend), findsOneWidget);
    expect(find.text('읽기'), findsOneWidget);
    expect(find.text('실습'), findsOneWidget);
    expect(find.text('퀴즈'), findsOneWidget);
  });

  testWidgets('유형이 1종뿐이면 선도 범례도 1개다', (tester) async {
    final history = _history(const {'READ': 80});
    expect(history.first.byType.keys.length, 1);

    await tester.pumpWidget(_host(ProgressTrendCard(history: history)));
    await tester.pumpAndSettle();

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.length, 1);
    expect(find.text('실습'), findsNothing);
  });

  testWidgets('byType이 비면 전체 누적률 1선으로 떨어진다', (tester) async {
    // 백엔드가 아직 배포되지 않은 상태(옛 응답)에서도 차트가 살아 있어야 한다.
    final history = _history(const {});

    await tester.pumpWidget(_host(ProgressTrendCard(history: history)));
    await tester.pumpAndSettle();

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    expect(chart.data.lineBarsData.length, 1);
    expect(find.byType(DpChartLegend), findsNothing);
  });

  // 「빈 배열이면 빈 상태 안내」는 여기 새로 쓰지 않는다 — 기존 파일에 이미 있고
  // 같은 것을 검사한다(Files 절 참조). 기존 것을 그대로 남긴다.
}
```

**병합 주의:** 기존 파일에도 같은 이름의 `_host` 헬퍼가 있다(줄바꿈만 다르고 기능은 같다).
**하나만 남긴다.** 기존 파일의 import에는 `fl_chart`·`dp_design`이 이미 있다.

- [ ] **Step 2: 실패 확인**

```
cd apps/web && flutter test test/features/dashboard/progress_trend_card_test.dart
```

Expected: FAIL — 현재는 항상 선 1개이고 범례가 없다.

- [ ] **Step 3: 구현**

`progress_trend_card.dart`의 `build`와 `_chart`를 다음으로 바꾼다(카드 껍데기·빈 상태는 그대로 둔다):

```dart
/// 계열 정의 — **키는 서버 enum 원문이라 불변**이고 라벨만 표시용이다.
/// 순서가 곧 chart1·chart2·chart3 배정 순서다.
const _series = <({String key, String label})>[
  (key: 'READ', label: '읽기'),
  (key: 'PRACTICE', label: '실습'),
  (key: 'QUIZ', label: '퀴즈'),
];
```

`build`의 `else` 분기(40행)를 다음으로 바꾼다:

```dart
          else ...[
            SizedBox(height: 140, child: _chart(context)),
            if (_activeSeries().isNotEmpty) ...[
              const SizedBox(height: DpSpacing.sm),
              DpChartLegend(
                items: [
                  for (final s in _activeSeries())
                    (color: _colorOf(context, s), label: s.label),
                ],
              ),
            ],
          ],
```

클래스에 헬퍼를 추가한다:

```dart
  /// 히스토리에 실제로 존재하는 계열만 고른다 — 과제가 없는 유형은 키 자체가 없다.
  List<({String key, String label})> _activeSeries() {
    if (history.isEmpty) return const [];
    final keys = history.first.byType.keys.toSet();
    return _series.where((s) => keys.contains(s.key)).toList();
  }

  Color _colorOf(BuildContext context, ({String key, String label}) s) {
    final c = context.dpColors;
    final palette = [c.chart1, c.chart2, c.chart3];
    return palette[_series.indexOf(s) % palette.length];
  }
```

`_chart`를 다음으로 바꾼다:

```dart
  Widget _chart(BuildContext context) {
    final c = context.dpColors;
    final active = _activeSeries();
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        lineTouchData: const LineTouchData(enabled: true),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineBarsData: active.isEmpty
            // byType이 비면(옛 응답) 전체 누적률 1선으로 떨어진다.
            ? [_bar([
                for (var i = 0; i < history.length; i++)
                  FlSpot(i.toDouble(), history[i].percent.toDouble()),
              ], c.chart1)]
            : [
                for (final s in active)
                  _bar([
                    for (var i = 0; i < history.length; i++)
                      FlSpot(i.toDouble(),
                          (history[i].byType[s.key] ?? 0).toDouble()),
                  ], _colorOf(context, s)),
              ],
      ),
    );
  }

  /// 채움(belowBarData)은 쓰지 않는다 — 반투명 면이 여러 장 겹치면 색이 섞여
  /// 계열 판별이 오히려 나빠진다(3-B 스펙 §4).
  LineChartBarData _bar(List<FlSpot> spots, Color color) => LineChartBarData(
    spots: spots,
    isCurved: true,
    color: color,
    barWidth: 3,
    dotData: const FlDotData(show: false),
  );
```

- [ ] **Step 4: 통과 확인**

```
cd apps/web && flutter test test/features/dashboard/
```

Expected: 이 파일이 **5건**(기존 「빈 배열」 1건 유지 + 신규 3건 + 기존 「LineChart 렌더」를 대체한 신규 1번) green.
web 전체는 기준선 346 → Task 3의 +2 → 여기서 **+2**(3건 추가, 흡수된 1건 삭제) = **350**.

- [ ] **Step 5: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add apps/web
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(web): 진행률 추세를 과제 유형별 다중 계열로 바꾼다"
```

---

## Task 9: 주차별 진행률 카드 신설

백엔드를 건드리지 않는다 — `/paths/current`가 주는 `milestones[].tasks[].completed`로 계산한다.

**배치는 대시보드가 아니라 학습 경로 화면(`/path`)이다.** `DashboardBody`는 `DashboardSummary`만 받아 `milestones`에 접근할 수 없고(`dashboard_body.dart:14-15`), 학습 경로 화면은 이미 `LearningPath`를 갖고 있다(`PathPlanView.children(context, plan)`). 의미상으로도 주차별 진행률은 경로 화면에 속한다.

**Files:**
- Create: `apps/web/lib/src/features/path/presentation/milestone_progress_card.dart`
- Modify: `apps/web/lib/src/features/path/presentation/path_plan_view.dart:26`(`children`가 반환하는 리스트에 타일 추가)
- Test: `apps/web/test/features/path/milestone_progress_card_test.dart`

**Interfaces:**
- Consumes: `PathMilestone(weekNum, title, goalDescription, targetSkills, estimatedHours, whyThisOrder, expectedOutcome, locked, tasks)` · `WeeklyTask(orderNum, taskType, title, required, contentId, contentSlug, completed)` — 둘 다 `packages/dp_core/lib/src/models/learning_path.dart`
- Produces: `class MilestoneProgressCard extends StatelessWidget { const MilestoneProgressCard({super.key, required this.milestones}); final List<PathMilestone> milestones; }`
- **범례를 두지 않는다** — 단일 계열이라 정보가 0이다(스펙 §5)

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`apps/web/test/features/path/milestone_progress_card_test.dart`:

```dart
import 'package:devpath_web/src/features/path/presentation/milestone_progress_card.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) =>
    MaterialApp(theme: DpTheme.light(), home: Scaffold(body: child));

WeeklyTask _task({required bool done}) =>
    WeeklyTask(orderNum: 1, taskType: 'READ', title: 't', completed: done);

/// PathMilestone은 필수 필드가 많다 — 전부 채워야 컴파일된다.
PathMilestone _ms(int week, List<WeeklyTask> tasks) => PathMilestone(
  weekNum: week,
  title: '$week주차',
  goalDescription: '목표',
  estimatedHours: 5,
  whyThisOrder: '이유',
  expectedOutcome: '결과',
  tasks: tasks,
);

void main() {
  testWidgets('주차마다 완료율 막대를 하나씩 렌더한다', (tester) async {
    final milestones = [
      _ms(1, [_task(done: true), _task(done: true)]),   // 100%
      _ms(2, [_task(done: true), _task(done: false)]),  // 50%
      _ms(3, [_task(done: false), _task(done: false)]), // 0%
    ];

    await tester.pumpWidget(_host(MilestoneProgressCard(milestones: milestones)));
    await tester.pumpAndSettle();

    final chart = tester.widget<BarChart>(find.byType(BarChart));
    expect(chart.data.barGroups.length, 3);
    expect(chart.data.barGroups[0].barRods.first.toY, 100);
    expect(chart.data.barGroups[1].barRods.first.toY, 50);
    expect(chart.data.barGroups[2].barRods.first.toY, 0);
    expect(chart.data.barGroups[0].barRods.first.color, DpColors.light.chart1);

    // 단일 계열이라 범례를 두지 않는다.
    expect(find.byType(DpChartLegend), findsNothing);
  });

  testWidgets('과제가 없는 주차는 0%로 센다', (tester) async {
    await tester.pumpWidget(_host(MilestoneProgressCard(milestones: [_ms(1, const [])])));
    await tester.pumpAndSettle();

    final chart = tester.widget<BarChart>(find.byType(BarChart));
    expect(chart.data.barGroups.first.barRods.first.toY, 0);
  });

  testWidgets('마일스톤이 없으면 안내 문구를 렌더한다', (tester) async {
    await tester.pumpWidget(_host(const MilestoneProgressCard(milestones: [])));
    await tester.pumpAndSettle();

    expect(find.text('아직 학습 경로가 없어요'), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);
  });
}
```

- [ ] **Step 2: 실패 확인**

```
cd apps/web && flutter test test/features/path/milestone_progress_card_test.dart
```

Expected: FAIL — `MilestoneProgressCard`가 없다.

- [ ] **Step 3: 구현**

`apps/web/lib/src/features/path/presentation/milestone_progress_card.dart`:

```dart
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// 마일스톤(주차)별 완료율 막대차트.
///
/// 마일스톤을 **계열이 아니라 X축**으로 둔다 — 12주를 색으로 구분하는 것은
/// 불가능하기 때문이다(3-B 스펙 §2.1). 단일 계열이라 범례를 두지 않는다.
/// `/paths/current`가 주는 데이터만 쓰므로 백엔드 확장이 필요 없다.
class MilestoneProgressCard extends StatelessWidget {
  const MilestoneProgressCard({super.key, required this.milestones});

  final List<PathMilestone> milestones;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;
    return Container(
      key: const Key('milestone-progress-card'),
      padding: const EdgeInsets.all(DpSpacing.lg),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(context.appTokens.panelRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('주차별 진행률', style: text.titleMedium),
          const SizedBox(height: DpSpacing.sm),
          if (milestones.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: DpSpacing.lg),
              child: Text(
                '아직 학습 경로가 없어요',
                style: text.bodyMedium?.copyWith(color: c.textSecondary),
              ),
            )
          else
            SizedBox(height: 140, child: _chart(context)),
        ],
      ),
    );
  }

  /// 과제가 없는 주차는 0%다(나눗셈을 하지 않는다).
  double _percentOf(PathMilestone m) {
    if (m.tasks.isEmpty) return 0;
    final done = m.tasks.where((t) => t.completed).length;
    return done * 100.0 / m.tasks.length;
  }

  Widget _chart(BuildContext context) {
    final c = context.dpColors;
    return BarChart(
      BarChartData(
        minY: 0,
        maxY: 100,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(),
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= milestones.length) return const SizedBox.shrink();
                return Text(
                  '${milestones[i].weekNum}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: c.textSecondary),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < milestones.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: _percentOf(milestones[i]),
                  color: c.chart1,
                  width: 10,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(2),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
```

**`Milestone`·`WeeklyTask`의 실제 이름·필드가 다르면 그것에 맞춘다**(Step 1에서 확인한 값).

- [ ] **Step 4: 학습 경로 화면에 배치한다**

`path_plan_view.dart`의 `children`(20행 `static List<Widget> children(BuildContext context, LearningPath plan)`)이 반환하는 리스트에 추가한다. 위치는 **「이번 주 과제」 뒤·12주 타임라인 앞** — 「이번 주」에서 「전체 주차」로 시야가 넓어지는 순서다. 파일을 읽어 그 경계의 인덱스를 찾는다.

```dart
      MilestoneProgressCard(milestones: plan.milestones),
      const SizedBox(height: DpSpacing.md),
```

`plan`은 이미 `children`의 파라미터라 **provider 배선이 필요 없다.** `import 'milestone_progress_card.dart';`를 추가한다.

`PathPlanView`는 sliver 배선용 `children` 정적 메서드를 앱이 쓰고(`path_page.dart:50`) 위젯 본체는 테스트만 쓴다 — **둘 다 같은 리스트를 거치므로 한 곳만 고치면 된다.**

- [ ] **Step 5: 통과 확인**

```
cd apps/web && flutter test
```

Expected: 신규 3건 포함 web green.

**★깨질 지점은 「항목 개수」가 아니라 「드래그 거리」다(실측).★** 두 테스트가 **고정 `-500` 드래그**로
스크롤한 뒤 그 아래 항목을 찾는다:

| 위치 | 코드 | 그 뒤에 찾는 것 |
|---|---|---|
| `path_plan_view_test.dart:89` | `tester.drag(find.byType(ListView), const Offset(0, -500))` | `find.text('트랜잭션 심화')`(2주차 타임라인) |
| `path_page_test.dart:73` | `tester.drag(find.byType(CustomScrollView), const Offset(0, -500))` | (파일을 열어 확인) |

이 카드는 타임라인 **앞**에 들어가고 높이가 **≈216px**(패딩 32 + 제목 ~24 + 간격 8 + 차트 140 + 뒤 간격 12)다.
즉 같은 -500 드래그로 도달하던 지점이 216px만큼 밀린다. 여유가 그보다 적으면 실패한다.

깨지면 **드래그 값을 키워 해결한다**(그 테스트의 의도는 「스크롤하면 뒤쪽 주차가 보인다」이지
「500px가 정확한 거리다」가 아니다). 개수를 세는 단언이 아니므로 숫자 조작 위험은 없다.
깨지지 않아도 **실행 결과로 확인하고 넘어간다** — 「안 깨졌을 것이다」로 넘기지 않는다.

- [ ] **Step 6: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add apps/web
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(web): 주차별 진행률 카드를 신설한다"
```

---

## Task 10: 문서 정합

**Files:**
- Modify: `DESIGN.md` (§1 컬러 토큰 절에 차트 색 규칙 추가)

- [ ] **Step 1: 규칙을 적는다**

`DESIGN.md`의 `## 1. 컬러 토큰` 절 끝에 다음을 추가한다:

```markdown
### 1.x 차트 색

**`chart1~3`은 데이터 계열 색이고 브랜드 액센트가 아니다.** `primary`(앰버)는 브랜드가,
`chart*`는 데이터가 쓴다 — 3-A 시점에는 `chart1`이 `primary`와 값이 같아 둘을 구분할 수
없었고, 그래서 「차트를 `chart1`로 이관」해도 픽셀이 하나도 바뀌지 않았다.

계열 색을 바꿀 때는 `docs/superpowers/specs/2026-08-07-chart-palette-check.py`를 통과해야 한다:

- 배경 대비 ≥ 3:1 (`bg`·`surface` 각각)
- 색각 이상 시뮬 후 계열 간 dE76 ≥ 20 · 계열 간 hue차 ≥ 40°
- `primary`·`success`·`warning`·`danger`·`chart4`와 dE76 ≥ 25
- 계열 간 **명도** 대비는 기록만 한다 — 배경 대비와 동시에 만족할 수 없다(배경이 극단이라
  세 색이 모두 반대쪽 명도대로 몰린다)

`chart4`는 계열이 아니라 **구분용 보조색**이다. 계열이 4개 이상 필요한 화면은 색으로 가르지
말고 축·분할·직접 라벨링을 쓴다 — 색으로 구분 가능한 계열은 3~4개가 한계다.
```

- [ ] **Step 2: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add DESIGN.md
git -C D:/workspace/dpa/devpath-frontend commit -m "docs: 차트 색 규칙을 DESIGN.md에 못박는다"
```

---

## Task 11: 육안 확인

**3-A에서 위젯 테스트가 전부 green인 상태로 캡처가 결함을 잡았다.** 자동 테스트로 대체하지 마라.

**Files:**
- Create: `docs/superpowers/reports/2026-08-07-design-phase3b-visual-check.md`
- (임시 수정 후 **반드시 원복**: `apps/web/lib/src/data/web_mock_fixtures.dart` · `apps/web/lib/src/providers/theme_provider.dart`)

- [ ] **Step 1: 목 데이터에 유형 3종이 실제로 들어 있는지 먼저 확인한다**

목 `/dashboard/me` 픽스처의 `progressHistory[].byType`에 `READ`·`PRACTICE`·`QUIZ`가 **다 있어야** 3계열이 화면에 뜬다. 없으면 픽스처를 임시로 채운다(캡처 후 원복).
**이 확인을 건너뛰면 「계열이 1개인 화면」을 찍고 정상이라고 판단하게 된다** — 3-A Task 12의 「조건 미성립」과 같은 함정이다.

- [ ] **Step 2: 라이트 빌드·캡처**

```
cd apps/web && flutter build web --release
cd apps/web/build/web && py -m http.server 8099
```

`web_mock_fixtures.dart`의 `onboardingStatus`를 임시로 `'DONE'`으로 바꿔야 셸 화면에 들어간다.
캡처: 4폭(500·700·1000·1400) × 대시보드·학습 경로.

**`wait --networkidle`만으로는 이르다** — 목 모드는 네트워크가 없어 즉시 만족되고 Flutter async 로딩은 그 뒤다. 로딩 스피너만 찍힌다. `$B js "new Promise(r => setTimeout(() => r(1), 4000))"`로 명시적으로 기다린다.

- [ ] **Step 3: 다크 빌드·캡처**

`theme_provider.dart:7`을 임시로 `ThemeMode.dark`로 바꿔 재빌드한다.
**재빌드해도 화면이 그대로면 서비스워커 캐시다** — 포트를 바꿔 새 origin으로 띄운다.

- [ ] **Step 4: 확인 지점**

| 항목 | 무엇을 보나 |
|---|---|
| 계열 구분 | 추세선 3개가 **실제로 구별되는가**. 겹치는 구간에서도 갈리는가 |
| 범례 | 색 견본이 선 색과 같은가. 좁은 폭에서 줄바꿈하는가 |
| 주차별 차트 | 막대가 주차 수만큼 있는가. X축 라벨이 읽히는가 |
| 도넛 | 미완료 조각이 배경·카드와 구별되는가(경계선 색이 아니라 면 색인가) |
| 브랜드 분리 | 차트 색이 앰버 브랜드와 **다르게** 보이는가 |
| 다크 | 세 계열이 다크에서도 갈리는가 |

**색 판정은 축소 스크린샷 인상이 아니라 토큰 값으로 한다** — 3-A에서 다크 레일 분리감을 그렇게 오판했다.

- [ ] **Step 5: 결함은 red-repro → 수정 → 재캡처**

실패 수치를 읽는다. 2단계에서 브레드크럼 원인을 패딩으로 오진했다가 실패값을 보고서야 진짜 원인을 알았다.

- [ ] **Step 6: 임시 수정 원복 확인**

```
git -C D:/workspace/dpa/devpath-frontend status --short
git -C D:/workspace/dpa/devpath-frontend diff
```

`apps/` 아래 변경이 **0건**이어야 한다. 눈으로 확인한다.

- [ ] **Step 7: 보고서 + 최종 검증 + 커밋**

```
dart pub global run melos run analyze
dart pub global run melos run test
dart format --output=none --set-exit-if-changed .
py docs/superpowers/specs/2026-08-07-chart-palette-check.py
py docs/superpowers/specs/2026-08-03-token-contrast-check.py
cd D:/workspace/dpa/devpath-learning-svc && ./gradlew test
```

Expected: analyze 0 · 전 패키지 green · format 0 changed · 팔레트 위반 0 · 대비 미달 0 · 백엔드 green.

```bash
git -C D:/workspace/dpa/devpath-frontend add docs/superpowers/reports
git -C D:/workspace/dpa/devpath-frontend commit -m "docs: 3-B 육안 확인 결과를 기록한다"
```
