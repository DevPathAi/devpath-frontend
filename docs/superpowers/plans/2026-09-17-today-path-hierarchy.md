# Today/Path 정보 밀도 재편(N05) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Today(`/dashboard`)와 Path(`/path`)의 정보 위계를 `다음 행동 → 완료 조건 → 진행 → 보조 맥락` 순서로 재구성하고, compact(<600)와 large(≥840)의 구성 자체를 다르게 설계하며, 사용자 행동이 아닌 장식 카드(진행률 도넛·배지 스트립)와 중복 문구(페이지 헤더 설명)를 Today/Path 에서 제거한다.

**Architecture:** 위계의 원천은 `DpMissionHeader` 다. 헤더에 선택적 `action` 슬롯을 추가해 1차 행동(`DpNextActionBand`)을 제목 바로 아래(완료 조건 위)에 두고, 근거(`why`)는 진행 표시 아래로 내려 "보조 맥락" 위치에 둔다. Today/Path 페이지는 `context.windowClass` 로 compact(1열, 보조 지표 최소화) / medium(1열) / expanded·large(2열: 미션 + 보조 레일) 구성을 고른다. 기존 `DashboardBody.content`(legacy 대시보드) 는 건드리지 않는다.

**Tech Stack:** Flutter 3.44.1, flutter_riverpod, go_router, dp_design(`DpWindowClass` 600/840/1240), melos 7.

**Spec:** `docs/community-information-architecture/task.md` §5 N05 · `handoff.md` §9.2 · T07 결론(반응형 구성은 "단순 축소"가 아니라 정보 우선순위 변경).

## Global Constraints

- 레포 CLAUDE.md 절대 조건(추측 금지·테스트 우선·원인 분석·신규 브랜치·자화자찬 금지). 브랜치 `feat/today-path-hierarchy-20260917` 을 `origin/develop`(N02 머지 후) 에서 분기, worktree `D:\workspace\dpa\.worktrees\frontend-today-path-hierarchy-20260917`.
- 커밋 Conventional Commits + `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- `DpMissionHeader` 공개 API 는 **추가만**(`Widget? action`) 한다. 기존 호출부(content·sandbox·mentor projection) 는 무변경으로 컴파일·통과해야 한다.
- 문구는 이 문서의 문자열을 그대로 쓴다. 기존 테스트가 잠근 문구('미션 열기', '완료 조건 · …', '이번 주 N/M 미션 완료', '다음 잠금 해제 · …')는 유지한다.
- 순서 단언은 `tester.getTopLeft(...).dy` 비교로 쓴다. 2열 단언은 `getTopLeft(...).dx` 비교.

---

### Task 1: `DpMissionHeader` 에 `action` 슬롯 + 위계 재배치

**Files:**
- Modify: `packages/dp_design/lib/src/mission/dp_mission_header.dart`
- Test: `packages/dp_design/test/mission/dp_mission_header_test.dart`

**Interfaces:**
- Produces: `DpMissionHeader({..., Widget? action})`. 렌더 순서: eyebrow+status → title → **action(있을 때)** → `완료 조건 · …` → progress(label+bar) → **why**(보조 맥락, `bodyMedium`·`textSecondary`). 진행 semantics 라벨(`'$progressLabel, $percent%'`) 불변.

- [ ] **Step 1: 실패하는 테스트** — `dp_mission_header_test.dart` `main()` 끝에 추가

```dart
  testWidgets('action 슬롯은 제목 아래·완료 조건 위에 놓이고 why 는 진행 아래로 간다', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        DpMissionHeader(
          eyebrow: '3주차 · 미션 2',
          title: 'JPA 연관관계의 주인을 설명하고 안전하게 매핑하기',
          why: '이전 실습에서 생긴 중복 쿼리를 줄이기 위한 미션입니다.',
          completionCriterion: '테스트 3개가 통과하면 완료',
          progressValue: 0.5,
          progressLabel: '이번 주 진행',
          action: const Text('ACTION-SLOT'),
        ),
      ),
    );
    final title = tester.getTopLeft(
      find.byKey(const ValueKey('dp-mission-header-title')),
    );
    final action = tester.getTopLeft(find.text('ACTION-SLOT'));
    final criterion = tester.getTopLeft(
      find.text('완료 조건 · 테스트 3개가 통과하면 완료'),
    );
    final progress = tester.getTopLeft(find.text('이번 주 진행 · 50%'));
    final why = tester.getTopLeft(
      find.text('이전 실습에서 생긴 중복 쿼리를 줄이기 위한 미션입니다.'),
    );
    expect(title.dy, lessThan(action.dy));
    expect(action.dy, lessThan(criterion.dy));
    expect(criterion.dy, lessThan(progress.dy));
    expect(progress.dy, lessThan(why.dy));
  });

  testWidgets('action 이 없으면 기존 텍스트 계약이 그대로 렌더된다', (tester) async {
    await tester.pumpWidget(_host(_header()));
    expect(find.text('완료 조건 · 테스트 3개가 통과하면 완료'), findsOneWidget);
    expect(find.text('이전 실습에서 생긴 중복 쿼리를 줄이기 위한 미션입니다.'), findsOneWidget);
  });
```

- [ ] **Step 2: 실패 확인** — `cd <worktree>/packages/dp_design && flutter test test/mission/dp_mission_header_test.dart` → `action` 파라미터 없음(컴파일 실패).

- [ ] **Step 3: 구현** — 생성자에 `this.action,` 추가, 필드 `final Widget? action;` 추가(doc: `/// 1차 행동. 제목 바로 아래, 완료 조건 위에 렌더된다.`). `build` 의 `Column.children` 을 다음 순서로 재배치:

```dart
                children: [
                  Wrap(/* eyebrow + status — 기존 그대로 */),
                  SizedBox(height: gap),
                  Focus(/* title — 기존 그대로 */),
                  if (action != null) ...[
                    SizedBox(height: gap),
                    action!,
                  ],
                  SizedBox(height: gap),
                  Text('완료 조건 · $completionCriterion', /* 기존 스타일 */),
                  SizedBox(height: gap),
                  Semantics(/* progress — 기존 그대로 */),
                  SizedBox(height: gap),
                  Text(
                    why,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
```

- [ ] **Step 4: 통과 확인** — 같은 파일 + `flutter test test/` 전체 PASS, `flutter analyze` 0. (`golden` 태그 테스트가 헤더를 포함하면 `--exclude-tags golden` 이 CI 기본이므로 로컬 골든 갱신은 하지 않는다.)

- [ ] **Step 5: 커밋** — `feat(dp_design): add DpMissionHeader action slot and reorder hierarchy`

---

### Task 2: Today — 행동 우선 위계 + compact/large 구성

**Files:**
- Modify: `apps/web/lib/src/features/dashboard/presentation/widgets/today_mission_section.dart` (`_AvailableMission`, `_CompletedMission`)
- Modify: `apps/web/lib/src/features/dashboard/presentation/dashboard_page.dart` (build: 페이지 헤더 설명 제거, 2열 구성)
- Modify: `apps/web/lib/src/features/dashboard/presentation/widgets/dashboard_body.dart` (`supportingContent` 에서 도넛·배지 제거, `compact` 에서 스트릭+주간 활동만)
- Test: `apps/web/test/features/dashboard/today_dashboard_page_test.dart`, `apps/web/test/features/dashboard/dashboard_body_test.dart`

**Interfaces:**
- Consumes: Task 1 `DpMissionHeader.action`.
- Produces: `DashboardBody.supportingContent(context, summary, {Key? key})` 시그니처 불변. compact: `[weekly, streak]`; medium: `[weekly, streak, completed]`; expanded/large: `[weekly, trend, streak, completed]`. 도넛(`_DonutCard`)·배지(`_BadgeStrip`)는 `supportingContent` 에서 제외(legacy `content` 는 유지).
- 페이지 구성: compact/medium = 1열(header → mission → supporting → ad); expanded/large = `Row`[Expanded(flex 3): mission, Expanded(flex 2): supporting rail] 뒤 ad. 키 `today-mission-section`·`today-metrics-section`·`today-ad-section` 유지(기존 순서 테스트 통과 조건: mission → metrics → ad 의 sliver 인덱스 순서는 compact 에서 유지; large 에서는 mission·metrics 가 한 sliver 안의 Row 이므로 기존 순서 테스트는 폭 미지정(기본 800px=medium) 에서 그대로 통과).

- [ ] **Step 1: 실패하는 테스트 추가** — `today_dashboard_page_test.dart` `main()` 끝

```dart
  testWidgets('390px Today 는 행동 → 완료 조건 → 진행 → 보조 순서로 쌓이고 도넛·배지가 없다', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pumpDashboard(
      tester,
      enabled: true,
      missionApi: _DashboardMissionApi([Future.value(_mission('AVAILABLE'))]),
      dashboardClient: _DashboardClient(),
    );
    await tester.pump();

    final action = tester.getTopLeft(find.text('미션 열기'));
    final criterion = tester.getTopLeft(find.textContaining('완료 조건 ·'));
    final progress = tester.getTopLeft(find.textContaining('이번 주 0/1 미션 완료'));
    expect(action.dy, lessThan(criterion.dy));
    expect(criterion.dy, lessThan(progress.dy));
    await tester.scrollUntilVisible(
      find.byKey(const Key('weekly-activity-card')),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const Key('weekly-activity-card')), findsOneWidget);
    expect(find.text('62%'), findsNothing); // 진행률 도넛 제거
    expect(find.textContaining('첫 경로'), findsNothing); // 배지 스트립 제거
    expect(find.text('지금 완료할 한 가지 미션부터 시작합니다'), findsNothing);
  });

  testWidgets('1240px Today 는 미션과 보조 레일을 2열로 놓는다', (tester) async {
    tester.view.physicalSize = const Size(1240, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pumpDashboard(
      tester,
      enabled: true,
      missionApi: _DashboardMissionApi([Future.value(_mission('AVAILABLE'))]),
      dashboardClient: _DashboardClient(),
    );
    await tester.pump();
    await tester.pump();

    final mission = tester.getTopLeft(find.text('JPA 트랜잭션 경계 읽기'));
    final rail = tester.getTopLeft(find.byKey(const Key('weekly-activity-card')));
    expect(rail.dx, greaterThan(mission.dx));
    expect((rail.dy - mission.dy).abs(), lessThan(120));
    expect(find.byKey(const Key('progress-trend-card')), findsOneWidget);
  });
```

`dashboard_body_test.dart` `main()` 끝:

```dart
  testWidgets('Today 보조 지표는 compact 에서 주간 활동과 스트릭만 남긴다', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_supportingDashboardHost(_summary));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('weekly-activity-card')), findsOneWidget);
    expect(find.text('연속 학습'), findsOneWidget);
    expect(find.text('62%'), findsNothing);
    expect(find.text('완료 콘텐츠'), findsNothing);
    expect(find.byKey(const Key('progress-trend-card')), findsNothing);
    expect(find.textContaining('첫걸음'), findsNothing);
  });
```

- [ ] **Step 2: 실패 확인** — `flutter test test/features/dashboard/today_dashboard_page_test.dart test/features/dashboard/dashboard_body_test.dart` → 새 3건 FAIL.

- [ ] **Step 3: 구현**

`today_mission_section.dart` `_AvailableMission.build`: `DpMissionHeader(...)` 에 `variant: context.windowClass == DpWindowClass.compact ? DpMissionHeaderVariant.compact : DpMissionHeaderVariant.standard,` 와 `action: DpNextActionBand(/* 기존 band 인자 그대로 */)` 를 넣고, `children` 에서 기존 `const SizedBox(height: DpSpacing.md), DpNextActionBand(...)` 를 제거한다. `_CompletedMission` 도 같은 방식(band 를 `action` 으로 이동).

`dashboard_body.dart` `_content` 의 `else` 분기(Today 보조):

```dart
      ] else ...[
        // Today 보조 맥락: 이번 주 진행 근거 → 추세 → KPI. 도넛(헤더 진행과 중복)과
        // 배지(장식)는 Today 에서 제외한다.
        _weeklyActivityTile(summary, donutSpan),
        if (cross >= 4) _progressTrendTile(summary, donutSpan),
        _streakTile(summary),
        if (cross >= 2) _completedContentTile(summary),
      ],
      if (includeLegacyHero && summary.badges.isNotEmpty)
        StaggeredGridTile.fit(
          crossAxisCellCount: badgeSpan,
          child: _BadgeStrip(badges: summary.badges),
        ),
```

`dashboard_page.dart` `build`: `DpPageHeader(title: '오늘')` 로 설명 제거. `showSupporting` 인 경우 `context.windowClass` 가 `expanded`/`large` 면 mission 과 supporting 을 하나의 `SliverToBoxAdapter(key: ValueKey('today-two-column'))` 안의 `Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: missionSection), Expanded(flex: 2, child: supportingSliverChild)])` 로 놓고, 그 외에는 기존 1열 sliver 순서를 유지한다. `missionSection` 위젯은 `KeyedSubtree(key: ValueKey('today-mission-section'))` 로 감싸 키를 보존한다(기존 sliver 순서 테스트는 기본 800px 에서 1열 경로를 탄다).

- [ ] **Step 4: 통과 확인** — `flutter test test/features/dashboard` 전체 PASS, analyze 0.

- [ ] **Step 5: 커밋** — `feat(web): reorder Today around the next action and split compact/large layouts`

---

### Task 3: Path — 행동 우선 위계 + compact/large 구성

**Files:**
- Modify: `apps/web/lib/src/features/path/presentation/mission_path_plan_view.dart` (`_AvailablePath`, `_CompletedPath`)
- Modify: `apps/web/lib/src/features/path/presentation/path_page.dart` (페이지 헤더 설명 제거)
- Test: `apps/web/test/features/path/mission_path_plan_view_test.dart`

**Interfaces:**
- Produces: `_AvailablePath` 순서 = header[eyebrow → title → action band → 완료 조건 → progress → why] → 인라인 알림 → `DpProgressSpine`(진행; compact 는 `DpProgressSpineLayout.text`, 그 외 `vertical`) → 보조 맥락(`다음 잠금 해제 · …`, `_CurrentWeekDetail`, `_RoadmapDetails`/`_PlanEnrichmentStatus`). expanded/large 에서는 `Row`[Expanded(3): header+알림+spine, Expanded(2): 보조 맥락].

- [ ] **Step 1: 실패하는 테스트** — `mission_path_plan_view_test.dart` `main()` 끝

```dart
  testWidgets('390px Path 는 행동 → 완료 조건 → 진행 → 다음 잠금 해제 순서로 쌓인다', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(
        missionState: CurrentMissionState(mission: _availableMission()),
        plan: _path(),
      ),
    );
    final action = tester.getTopLeft(find.text('미션 열기'));
    final criterion = tester.getTopLeft(find.textContaining('완료 조건 ·'));
    final progress = tester.getTopLeft(find.textContaining('미션 완료'));
    final unlock = tester.getTopLeft(find.textContaining('다음 잠금 해제 ·'));
    expect(action.dy, lessThan(criterion.dy));
    expect(criterion.dy, lessThan(progress.dy));
    expect(progress.dy, lessThan(unlock.dy));
  });

  testWidgets('1240px Path 는 미션과 로드맵 보조 맥락을 2열로 놓는다', (tester) async {
    tester.view.physicalSize = const Size(1240, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _host(
        missionState: CurrentMissionState(mission: _availableMission()),
        plan: _path(),
      ),
    );
    final mission = tester.getTopLeft(find.text('미션 열기'));
    final unlock = tester.getTopLeft(find.textContaining('다음 잠금 해제 ·'));
    expect(unlock.dx, greaterThan(mission.dx));
  });
```

- [ ] **Step 2: 실패 확인** — `flutter test test/features/path/mission_path_plan_view_test.dart` → 새 2건 FAIL.

- [ ] **Step 3: 구현** — `_AvailablePath.build` 를 다음 구조로 재배치(변수 계산부는 기존 그대로):

```dart
    final compact = context.windowClass == DpWindowClass.compact;
    final wide = switch (context.windowClass) {
      DpWindowClass.expanded || DpWindowClass.large => true,
      _ => false,
    };
    final band = DpNextActionBand(/* 기존 인자 그대로 */);
    final primary = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DpMissionHeader(
          /* 기존 인자 그대로 */,
          variant: compact ? DpMissionHeaderVariant.compact : DpMissionHeaderVariant.standard,
          action: band,
        ),
        if (!detailMatches && plan != null) ...[ /* 기존 DpInlineNotice */ ],
        if (missionState.failureMessage != null) ...[ /* 기존 DpInlineNotice */ ],
        const SizedBox(height: DpSpacing.lg),
        DpProgressSpine(
          /* 기존 인자 */,
          layout: compact ? DpProgressSpineLayout.text : DpProgressSpineLayout.vertical,
        ),
      ],
    );
    final supporting = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('다음 잠금 해제 · $nextUnlock', /* 기존 스타일 */),
        if (currentMilestone != null) ...[ const SizedBox(height: DpSpacing.xl), _CurrentWeekDetail(milestone: currentMilestone) ],
        if (matchingPlan != null) ...[ const SizedBox(height: DpSpacing.xl), _RoadmapDetails(plan: matchingPlan, currentWeek: mission.weekNum!) ]
        else if (isPlanLoading || planFailureMessage != null) ...[ const SizedBox(height: DpSpacing.xl), _PlanEnrichmentStatus(isLoading: isPlanLoading, failureMessage: planFailureMessage, onRetry: onRetryPlan) ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.all(DpSpacing.lg),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: primary),
                const SizedBox(width: DpSpacing.xl),
                Expanded(flex: 2, child: supporting),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [primary, const SizedBox(height: DpSpacing.md), supporting],
            ),
    );
```

`_CompletedPath` 도 band 를 `action` 으로 옮긴다. `path_page.dart` 의 `DpPageHeader` 는 `title: '학습 경로'` 만 남긴다(설명 제거; legacy 분기 설명 `'진단 결과로 만든 12주 계획입니다'` 는 flag OFF 전용이므로 유지).

- [ ] **Step 4: 통과 확인** — `flutter test test/features/path` 전체 PASS(기존 `320px와 200% 글자…` 테스트 포함), analyze 0.

- [ ] **Step 5: 커밋** — `feat(web): reorder Path around the next action and split compact/large layouts`

---

### Task 4: 전체 게이트 + 문서 + PR

- [ ] `docs/design/app-state-matrix.md` 옆에 `docs/design/today-path-hierarchy.md` 작성: 위계 규칙(다음 행동 → 완료 조건 → 진행 → 보조 맥락), 폭별 구성 표(compact/medium/expanded·large × Today/Path), 제거한 요소와 이유(도넛=헤더 진행과 중복, 배지=장식, 페이지 헤더 설명=미션 헤더와 중복).
- [ ] `dart run melos run format && dart run melos run analyze && dart run melos run test` 녹색.
- [ ] 커밋 `docs: describe the Today/Path hierarchy and layout matrix`, push, PR → develop(제목 `feat(web): reorder Today and Path around the next action`), CI 녹색 확인 후 merge commit.
