# UI/UX Phase 2 — 학습자 대시보드/홈 고도화 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 학습자 대시보드를 Bento 그리드 + KPI 카드 + fl_chart 진행률 도넛 + 스켈레톤 로딩 + 상태 전환 애니메이션으로 재구성한다(프론트 전용, 백엔드 계약 불변).

**Architecture:** dp_design에 재사용 `DpKpiCard`(Layer 2, 순수 표현부)를 신설하고, `apps/web` 대시보드 화면(Layer 3)이 KPI 카드·진행률 도넛·Bento 레이아웃을 조립한다. 기존 `DashboardController`/`DashboardState`/`DashboardSummary`·`/dashboard/me` 계약은 그대로 유지한다.

**Tech Stack:** Flutter Web(CanvasKit), Riverpod 3, go_router, fl_chart(도넛), flutter_staggered_grid_view(Bento), skeletonizer(스켈레톤). 검증 SSoT = spec `docs/superpowers/specs/2026-07-31-uiux-phase2-dashboard-design.md`.

## Global Constraints

- **백엔드 계약 불변**: `/dashboard/me`·`DashboardSummary`(`streakDays:int`·`progressPercent:int`·`nextTaskTitle:String?`·`badges:List<String>`·`completedContentCount:int`)·`DashboardController`·`DashboardState` 시그니처 변경 금지.
- **`DpKpiCard`는 go_router·Riverpod 비의존** 순수 표현부(Layer 2 원칙).
- **토큰만 사용**: 색·간격·반경·모션은 `DpColors`(`context.dpColors`)·`DpSpacing`·`DpRadius`·`DpDurations`·`AppTokens`(`context.appTokens`)만. 하드코딩 색/반경 금지.
- **반응형 경계는 SSoT**: `DpWindowClass`(`<600` compact / `<840` medium / `<1240` expanded / `≥1240` large), `context.windowClass` 사용. 재정의 금지.
- **장식 효과 금지**: 그림자·BackdropFilter 미사용(DESIGN.md §3, 보더 우선).
- **패키지 버전은 도입 시 Context7로 확정**하고 확정 버전을 리포트에 기록(spec §6 절차). pubspec의 `^x.y` 는 하한 가이드.
- **SDK**: Flutter 3.44 계열, Flutter Web(CanvasKit) 지원 패키지만.
- **게이트(매 커밋 전 관련 범위, 최종 전체)**: `melos run analyze`(0 issues) · `melos run test`(pass) · `melos run format`(clean). PATH 미설정 시 `dart pub global run melos <cmd>`.
- **커밋**: Conventional Commits. 각 커밋 메시지 끝에 `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

## Task 1: 패키지 도입 + 검증

**Files:**
- Modify: `apps/web/pubspec.yaml` (dependencies 섹션)
- Create/Append: `docs/superpowers/reports/2026-07-31-uiux-phase2-package-adoption.md`

**Interfaces:**
- Produces: `apps/web`에서 `package:fl_chart/fl_chart.dart`·`package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart`·`package:skeletonizer/skeletonizer.dart` import 가능.

- [ ] **Step 1: Context7로 3개 패키지 최신 버전·API·CanvasKit 호환 확인**

`fl_chart`·`flutter_staggered_grid_view`·`skeletonizer` 각각 resolve-library-id → query-docs로 (a) 현재 안정 버전 (b) Flutter Web(CanvasKit) 지원 (c) 사용할 API 시그니처(`PieChart`/`PieChartData`/`PieChartSectionData`/`PieTouchData`, `StaggeredGrid.count`/`StaggeredGridTile.count`, `Skeletonizer`)를 확인. 라이선스(MIT류) 확인.

- [ ] **Step 2: `apps/web/pubspec.yaml` dependencies에 3개 추가**

기존 `visibility_detector: ^0.4.0+2` 아래에 (Step 1에서 확정한 버전으로 `^` 하한 지정):

```yaml
  fl_chart: ^0.69.0                    # Step 1 Context7 결과로 확정
  flutter_staggered_grid_view: ^0.7.0  # Step 1 Context7 결과로 확정
  skeletonizer: ^1.4.0                 # Step 1 Context7 결과로 확정
```

- [ ] **Step 3: bootstrap + analyze로 해석 확인**

Run: `dart pub global run melos bootstrap` 그다음 `dart pub global run melos run analyze`
Expected: 해석 성공(버전 충돌 없음), analyze 0 issues.

- [ ] **Step 4: 도입 결과 리포트 기록**

`docs/superpowers/reports/2026-07-31-uiux-phase2-package-adoption.md`에 3개 패키지의 **확정 버전·라이선스·CanvasKit 호환 여부·bootstrap 결과**를 표로 기록(spec §6 AC).

- [ ] **Step 5: Commit**

```bash
git add apps/web/pubspec.yaml pubspec.lock docs/superpowers/reports/2026-07-31-uiux-phase2-package-adoption.md
git commit -m "chore(web): Phase2 대시보드 패키지 도입(fl_chart·staggered·skeletonizer)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: DpKpiCard (dp_design Layer 2)

**Files:**
- Create: `packages/dp_design/lib/src/data/dp_kpi_card.dart`
- Modify: `packages/dp_design/lib/dp_design.dart` (export 추가)
- Test: `packages/dp_design/test/data/dp_kpi_card_test.dart`

**Interfaces:**
- Consumes: `context.dpColors`(DpColors), `context.appTokens`(AppTokens.panelRadius), `DpSpacing`, `DpRadius`, `DpDurations`.
- Produces: `DpKpiCard({required String label, required int value, IconData? icon, String? suffix, double? progress, Duration countUpDuration})` — go_router·Riverpod 비의존 순수 위젯.

- [ ] **Step 1: Write the failing test**

`packages/dp_design/test/data/dp_kpi_card_test.dart`:

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DpKpiCard: 라벨·카운트업 최종값·suffix 렌더', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: const Scaffold(
          body: DpKpiCard(
            label: '연속 학습',
            value: 7,
            suffix: '일',
            icon: Icons.local_fire_department,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(); // 카운트업 애니메이션 종료까지

    expect(find.text('연속 학습'), findsOneWidget);
    expect(find.text('7일'), findsOneWidget);
  });

  testWidgets('DpKpiCard: progress 슬롯 지정 시 진행바 렌더', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: const Scaffold(
          body: DpKpiCard(label: '진척', value: 3, progress: 0.5),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/dp_design && flutter test test/data/dp_kpi_card_test.dart`
Expected: FAIL — `DpKpiCard` 정의되지 않음(컴파일 에러).

- [ ] **Step 3: Write minimal implementation**

`packages/dp_design/lib/src/data/dp_kpi_card.dart`:

```dart
import 'package:flutter/material.dart';

import '../theme/dp_colors.dart';
import '../theme/dp_spacing.dart';
import '../theme/dp_tokens.dart';

/// KPI 단일 지표 카드(Layer 2). 숫자 카운트업 + 라벨 + 옵셔널 아이콘/진행바.
/// go_router·Riverpod 비의존 순수 표현부. 색·반경·간격은 토큰만 사용.
class DpKpiCard extends StatelessWidget {
  const DpKpiCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.suffix,
    this.progress,
    this.countUpDuration = DpDurations.stageReveal,
  });

  final String label;
  final int value;
  final IconData? icon;
  final String? suffix;

  /// 0~1 목표 진행바(옵셔널). 데이터 없으면 미지정 → 진행바 미표시.
  final double? progress;
  final Duration countUpDuration;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final text = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '$label $value${suffix ?? ''}',
      child: Container(
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
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: c.primary),
                  const SizedBox(width: DpSpacing.xs),
                ],
                Text(
                  label,
                  style: text.titleSmall?.copyWith(color: c.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: DpSpacing.sm),
            TweenAnimationBuilder<int>(
              duration: countUpDuration,
              tween: IntTween(begin: 0, end: value),
              builder: (_, v, __) => Text(
                '$v${suffix ?? ''}',
                style: text.displaySmall?.copyWith(color: c.primaryText),
              ),
            ),
            if (progress != null) ...[
              const SizedBox(height: DpSpacing.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(DpRadius.button),
                child: LinearProgressIndicator(value: progress),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

`packages/dp_design/lib/dp_design.dart`에 export 추가(`export 'src/content/dp_markdown.dart';` 다음 줄):

```dart
export 'src/data/dp_kpi_card.dart';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd packages/dp_design && flutter test test/data/dp_kpi_card_test.dart`
Expected: PASS(2 tests).

- [ ] **Step 5: Commit**

```bash
git add packages/dp_design/lib/src/data/dp_kpi_card.dart packages/dp_design/lib/dp_design.dart packages/dp_design/test/data/dp_kpi_card_test.dart
git commit -m "feat(dp_design): DpKpiCard — 카운트업 KPI 카드(Layer 2)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: 진행률 도넛 위젯 (fl_chart, apps/web)

**Files:**
- Create: `apps/web/lib/src/features/dashboard/presentation/widgets/progress_donut.dart`
- Test: `apps/web/test/features/dashboard/progress_donut_test.dart`

**Interfaces:**
- Consumes: `context.dpColors`, `package:fl_chart/fl_chart.dart`(`PieChart`/`PieChartData`/`PieChartSectionData`/`PieTouchData`).
- Produces: `ProgressDonut({required int percent})` — `percent`(0~100) 도넛 + 중앙 `"$percent%"` 라벨.

- [ ] **Step 1: Write the failing test**

`apps/web/test/features/dashboard/progress_donut_test.dart`:

```dart
import 'package:devpath_web/src/features/dashboard/presentation/widgets/progress_donut.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ProgressDonut: 중앙에 퍼센트 라벨 렌더', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: const Scaffold(body: Center(child: ProgressDonut(percent: 62))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('62%'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/web && flutter test test/features/dashboard/progress_donut_test.dart`
Expected: FAIL — `ProgressDonut` 정의되지 않음.

- [ ] **Step 3: Write minimal implementation**

`apps/web/lib/src/features/dashboard/presentation/widgets/progress_donut.dart`:

```dart
import 'package:dp_design/dp_design.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// 전체 진행률 도넛(fl_chart PieChart). 중앙 퍼센트 라벨 + 섹션 hover 툴팁.
class ProgressDonut extends StatelessWidget {
  const ProgressDonut({super.key, required this.percent});

  /// 0~100.
  final int percent;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final p = percent.clamp(0, 100).toDouble();
    return Semantics(
      label: '전체 진행률 $percent 퍼센트',
      child: SizedBox(
        height: 132,
        width: 132,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                startDegreeOffset: -90,
                sectionsSpace: 0,
                centerSpaceRadius: 46,
                pieTouchData: PieTouchData(enabled: true),
                sections: [
                  PieChartSectionData(
                    value: p,
                    color: c.primary,
                    radius: 12,
                    showTitle: false,
                  ),
                  PieChartSectionData(
                    value: 100 - p,
                    color: c.border,
                    radius: 12,
                    showTitle: false,
                  ),
                ],
              ),
            ),
            Text(
              '$percent%',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: c.primaryText),
            ),
          ],
        ),
      ),
    );
  }
}
```

> Step 1 Context7 결과가 위 API와 다르면(예: `PieChartData` 파라미터명 변경) 확정 버전 API로 대조·수정한다.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/web && flutter test test/features/dashboard/progress_donut_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/web/lib/src/features/dashboard/presentation/widgets/progress_donut.dart apps/web/test/features/dashboard/progress_donut_test.dart
git commit -m "feat(web): 진행률 도넛 위젯(fl_chart PieChart)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Bento 레이아웃 + 반응형 (성공 상태 _Body 재작성)

**Files:**
- Create: `apps/web/lib/src/features/dashboard/presentation/widgets/dashboard_body.dart`
- Modify: `apps/web/lib/src/features/dashboard/presentation/dashboard_page.dart` (`_Body` → `DashboardBody` 사용)
- Test: `apps/web/test/features/dashboard/dashboard_body_test.dart`

**Interfaces:**
- Consumes: `DpKpiCard`(Task 2), `ProgressDonut`(Task 3), `DashboardSummary`(dp_core), `context.windowClass`(DpWindowClass), `context.appTokens.contentMaxWidth`, `StaggeredGrid`/`StaggeredGridTile`(flutter_staggered_grid_view), 기존 `AdSlotWidget`(`../../ads/presentation/ad_slot_widget.dart`).
- Produces: `DashboardBody({required DashboardSummary summary})` — 폭별 Bento 조립(성공 상태 본문).

- [ ] **Step 1: Write the failing test**

`apps/web/test/features/dashboard/dashboard_body_test.dart`:

```dart
import 'package:devpath_web/src/features/dashboard/presentation/widgets/dashboard_body.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget _host(DashboardSummary s, Size size) {
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => Scaffold(body: DashboardBody(summary: s))),
      GoRoute(path: '/path', builder: (_, _) => const SizedBox()),
    ],
  );
  return ProviderScope(
    child: MaterialApp.router(theme: DpTheme.light(), routerConfig: router),
  );
}

const _summary = DashboardSummary(
  streakDays: 7,
  progressPercent: 62,
  nextTaskTitle: '비동기 프로그래밍 기초',
  badges: ['첫걸음', '3일 연속'],
  completedContentCount: 12,
);

void main() {
  testWidgets('DashboardBody: 스트릭·진행률·완료·CTA·배지 렌더(Expanded 폭)', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_host(_summary, const Size(1000, 900)));
    await tester.pumpAndSettle();

    expect(find.text('7일'), findsOneWidget);       // 스트릭 KPI
    expect(find.text('62%'), findsOneWidget);        // 진행률 도넛
    expect(find.text('12'), findsWidgets);           // 완료 콘텐츠 KPI
    expect(find.text('이어서 학습'), findsOneWidget); // 히어로 CTA
    expect(find.textContaining('첫걸음'), findsOneWidget); // 배지
  });

  testWidgets('DashboardBody: Compact 폭에서도 핵심 요소 렌더', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_host(_summary, const Size(400, 900)));
    await tester.pumpAndSettle();

    expect(find.text('이어서 학습'), findsOneWidget);
    expect(find.text('62%'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/web && flutter test test/features/dashboard/dashboard_body_test.dart`
Expected: FAIL — `DashboardBody` 정의되지 않음.

- [ ] **Step 3: Write minimal implementation**

`apps/web/lib/src/features/dashboard/presentation/widgets/dashboard_body.dart`:

```dart
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../../ads/presentation/ad_slot_widget.dart';
import 'progress_donut.dart';

/// 대시보드 성공 상태 본문. 폭별 Bento(staggered) 재배치.
class DashboardBody extends StatelessWidget {
  const DashboardBody({super.key, required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final cross = switch (context.windowClass) {
      DpWindowClass.compact => 1,
      DpWindowClass.medium => 2,
      _ => 4, // expanded/large: 4열 Bento
    };
    final maxW = context.appTokens.contentMaxWidth;

    // 셀 배치: Expanded/Large(4열) 기준 — CTA 2열, 우측 KPI 2 + 도넛, 배지 풀폭.
    final tiles = <StaggeredGridTile>[
      StaggeredGridTile.fit(crossAxisCellCount: cross, child: const AdSlotWidget(slot: 'DASHBOARD_TOP')),
      StaggeredGridTile.fit(crossAxisCellCount: cross >= 4 ? 2 : cross, child: _HeroCta(title: summary.nextTaskTitle)),
      StaggeredGridTile.fit(crossAxisCellCount: 1, child: DpKpiCard(label: '연속 학습', value: summary.streakDays, suffix: '일', icon: DpIcons.stepDone)),
      StaggeredGridTile.fit(crossAxisCellCount: 1, child: DpKpiCard(label: '완료 콘텐츠', value: summary.completedContentCount, icon: DpIcons.content)),
      StaggeredGridTile.fit(crossAxisCellCount: cross >= 2 ? (cross >= 4 ? 1 : 2) : 1, child: _DonutCard(percent: summary.progressPercent)),
      if (summary.badges.isNotEmpty)
        StaggeredGridTile.fit(crossAxisCellCount: cross, child: _BadgeStrip(badges: summary.badges)),
    ];

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DpSpacing.lg),
          child: StaggeredGrid.count(
            crossAxisCount: cross,
            mainAxisSpacing: DpSpacing.md,
            crossAxisSpacing: DpSpacing.md,
            children: tiles,
          ),
        ),
      ),
    );
  }
}

Widget _panel(BuildContext context, Widget child) {
  final c = context.dpColors;
  return Container(
    padding: const EdgeInsets.all(DpSpacing.lg),
    decoration: BoxDecoration(
      color: c.surface,
      border: Border.all(color: c.border),
      borderRadius: BorderRadius.circular(context.appTokens.panelRadius),
    ),
    child: child,
  );
}

class _HeroCta extends StatelessWidget {
  const _HeroCta({required this.title});
  final String? title;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.dpColors;
    return _panel(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('다음 과제', style: text.titleMedium),
          const SizedBox(height: DpSpacing.xs),
          Text(title ?? '경로를 생성해 보세요', style: text.bodyMedium?.copyWith(color: c.textSecondary)),
          const SizedBox(height: DpSpacing.md),
          FilledButton(onPressed: () => context.go('/path'), child: const Text('이어서 학습')),
        ],
      ),
    );
  }
}

class _DonutCard extends StatelessWidget {
  const _DonutCard({required this.percent});
  final int percent;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _panel(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('전체 진행률', style: text.titleMedium),
          const SizedBox(height: DpSpacing.sm),
          Center(child: ProgressDonut(percent: percent)),
        ],
      ),
    );
  }
}

class _BadgeStrip extends StatelessWidget {
  const _BadgeStrip({required this.badges});
  final List<String> badges;
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _panel(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('배지', style: text.titleMedium),
          const SizedBox(height: DpSpacing.sm),
          Wrap(
            spacing: DpSpacing.sm,
            runSpacing: DpSpacing.xs,
            children: [for (final b in badges) Chip(label: Text(b))],
          ),
        ],
      ),
    );
  }
}
```

> Step 1 Context7 결과가 staggered API와 다르면(예: `StaggeredGridTile.fit` 시그니처) 확정 버전 API로 대조·수정한다. 도넛 카드의 `crossAxisCellCount` 계산은 폭별로 셀 합이 `cross`를 넘지 않게 유지한다.

- [ ] **Step 4: Run test + 기존 dashboard_page 회귀 확인**

Run: `cd apps/web && flutter test test/features/dashboard/dashboard_body_test.dart`
Expected: PASS(2 tests).
(dashboard_page.dart 수정은 Step 5에서.)

- [ ] **Step 5: dashboard_page.dart가 DashboardBody를 사용하도록 교체 + 회귀**

`apps/web/lib/src/features/dashboard/presentation/dashboard_page.dart`의 기존 `_Body`(ListView)를 제거하고 `DashLoaded` 분기가 `DashboardBody`를 쓰도록 수정:

```dart
import '../application/dashboard_controller.dart';
import '../state/dashboard_state.dart';
import 'widgets/dashboard_body.dart';
// ...
body: switch (s) {
  DashLoading() => const DpLoading(),
  DashFailed(:final message) => DpError(
    message: message,
    onRetry: () => ref.read(dashboardControllerProvider.notifier).load(),
  ),
  DashLoaded(:final summary) => DashboardBody(summary: summary),
},
```

Run: `cd apps/web && flutter test test/features/dashboard/`
Expected: 기존 `dashboard_page_test.dart`(스트릭 7·진행률 62·"이어서 학습")·`dashboard_controller_test.dart`·신규 테스트 전부 PASS.

- [ ] **Step 6: Commit**

```bash
git add apps/web/lib/src/features/dashboard/presentation/widgets/dashboard_body.dart apps/web/lib/src/features/dashboard/presentation/dashboard_page.dart apps/web/test/features/dashboard/dashboard_body_test.dart
git commit -m "feat(web): 대시보드 Bento 레이아웃 + 반응형(KPI·도넛·CTA·배지)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: 로딩 스켈레톤 + 상태 전환 애니메이션

**Files:**
- Modify: `apps/web/lib/src/features/dashboard/presentation/dashboard_page.dart`
- Test: `apps/web/test/features/dashboard/dashboard_transition_test.dart`

**Interfaces:**
- Consumes: `Skeletonizer`(skeletonizer), `AnimatedSwitcher`, `DashboardBody`(Task 4), `DashboardState`(sealed), `DashboardSummary`.
- Produces: 로딩 시 `DashboardBody` 구조 스켈레톤, 상태 전환 `AnimatedSwitcher`.

- [ ] **Step 1: Write the failing test**

`apps/web/test/features/dashboard/dashboard_transition_test.dart`:

```dart
import 'package:devpath_web/src/features/dashboard/presentation/dashboard_page.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

void main() {
  testWidgets('대시보드: 로딩 시 스켈레톤(Skeletonizer) + AnimatedSwitcher 존재', (tester) async {
    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, _) => const DashboardPage())],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(theme: DpTheme.light(), routerConfig: router),
      ),
    );
    await tester.pump(); // 첫 프레임: 아직 DashLoading

    expect(find.byType(AnimatedSwitcher), findsOneWidget);
    expect(find.byType(Skeletonizer), findsWidgets); // 로딩 골격

    await tester.pumpAndSettle(); // load() 완료 → DashLoaded
    expect(find.text('이어서 학습'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd apps/web && flutter test test/features/dashboard/dashboard_transition_test.dart`
Expected: FAIL — `AnimatedSwitcher`/`Skeletonizer` 미존재.

- [ ] **Step 3: Write minimal implementation**

`dashboard_page.dart`의 `build`에서 `switch`를 `AnimatedSwitcher`로 감싸고, `DashLoading`을 `Skeletonizer`로 감싼 `DashboardBody`(placeholder summary)로 렌더:

```dart
import 'package:skeletonizer/skeletonizer.dart';
// ...
const _skeletonSummary = DashboardSummary(
  streakDays: 0,
  progressPercent: 0,
  nextTaskTitle: '불러오는 중 자리표시자 텍스트',
  badges: ['배지', '배지'],
  completedContentCount: 0,
);

@override
Widget build(BuildContext context) {
  final s = ref.watch(dashboardControllerProvider);
  return Scaffold(
    appBar: AppBar(title: const Text('대시보드')),
    body: AnimatedSwitcher(
      duration: DpDurations.stageReveal,
      child: switch (s) {
        DashLoading() => const Skeletonizer(
            key: ValueKey('loading'),
            child: DashboardBody(summary: _skeletonSummary),
          ),
        DashFailed(:final message) => DpError(
            key: const ValueKey('error'),
            message: message,
            onRetry: () => ref.read(dashboardControllerProvider.notifier).load(),
          ),
        DashLoaded(:final summary) => DashboardBody(
            key: const ValueKey('loaded'),
            summary: summary,
          ),
      },
    ),
  );
}
```

> `AnimatedSwitcher`는 자식 전환을 감지하도록 각 분기에 고유 `Key`를 준다. `Skeletonizer`가 `DashboardBody` 실제 구조를 감싸 "카드 구조 반영" AC를 만족한다. `DashboardBody`에 `key` 파라미터 전달을 위해 이미 `super.key`가 있으므로 추가 변경 불필요.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd apps/web && flutter test test/features/dashboard/dashboard_transition_test.dart`
Expected: PASS.

- [ ] **Step 5: 전체 게이트**

Run: `dart pub global run melos run analyze` · `dart pub global run melos run test` · `dart pub global run melos run format`
Expected: analyze 0 issues · 전 패키지 test PASS(기존 dashboard_page/controller 회귀 포함) · format clean.

- [ ] **Step 6: Commit**

```bash
git add apps/web/lib/src/features/dashboard/presentation/dashboard_page.dart apps/web/test/features/dashboard/dashboard_transition_test.dart
git commit -m "feat(web): 대시보드 로딩 스켈레톤 + 상태 전환 애니메이션

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review (작성자 체크 결과)

**1. Spec coverage:**
- §2.1 DpKpiCard(Layer 2, 비의존) → Task 2 ✓ / §3 진행률 도넛(fl_chart) → Task 3 ✓ / §3 히어로 CTA·KPI·배지·광고 → Task 4 ✓ / §4 반응형 폭별 재배치(staggered, 최대폭) → Task 4 ✓ / §5 스켈레톤·AnimatedSwitcher → Task 5 ✓ / §6 패키지 §3 검증·기록 → Task 1 ✓ / §7 테스트 폭별·상태·도넛·CTA·광고 → Task 2~5 ✓ / §8 계약 불변 → Global Constraints + Task 4 회귀 ✓.
- 빈 상태(nextTaskTitle==null)는 Task 4 `_HeroCta`의 '경로를 생성해 보세요'로 커버(기존 동작 유지) ✓.

**2. Placeholder scan:** TBD/TODO/"적절히 처리" 없음. 모든 코드 스텝에 실제 코드 포함 ✓. (패키지 버전만 Context7 확정 대상으로 명시 — 외부 의존 특성상 의도된 검증 스텝.)

**3. Type consistency:** `DpKpiCard`(label/value/icon/suffix/progress/countUpDuration)·`ProgressDonut(percent)`·`DashboardBody(summary)` 시그니처가 정의 Task와 소비 Task(4·5)에서 일치 ✓. `DashboardSummary` 필드명(streakDays/progressPercent/nextTaskTitle/badges/completedContentCount)이 dp_core 실측과 일치 ✓. `context.windowClass`·`context.appTokens.contentMaxWidth`·`DpDurations.stageReveal` 실측 심볼과 일치 ✓.
