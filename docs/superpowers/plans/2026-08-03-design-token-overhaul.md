# 디자인 토큰 개편 (T2 잉크·앰버) 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** DevPath 색·타이포 토큰을 역할 기반으로 확장하고 팔레트를 인디고/slate에서 잉크·앰버(T2)로 교체한다.

**Architecture:** `DpColors`(ThemeExtension)에 면·텍스트·사이드바·차트·태그 토큰을 추가하고 기존 토큰명은 그대로 둔 채 값만 교체한다. 이름을 유지하므로 `dpColors`를 쓰는 47개 파일 중 warning 재배치 대상 11곳만 수정된다.

**Tech Stack:** Flutter 3 · Material 3 ThemeExtension · Dart pub workspaces + melos 7

**스펙:** `devpath-frontend/docs/superpowers/specs/2026-08-03-design-token-overhaul-design.md`

## Global Constraints

- **기존 토큰명을 바꾸지 않는다.** `primary`·`primaryText`·`primaryTextStrong`·`onPrimary`는 이름 유지, 값만 교체. 개명은 후속 단계.
- **`DpColors`는 `ThemeExtension`이라 필드·`copyWith`·`lerp` 셋이 항상 일치해야 한다.** 하나라도 빠지면 테마 전환에서 해당 토큰이 튄다.
- **대비 기준**: 텍스트 ≥4.5:1, UI 컴포넌트·faint ≥3:1. 스펙 §8에서 34건 실측 완료(미달 0). 값 변경 시 재검증.
- **다크의 `onPrimary`는 어두운 색(`#1A1200`)이다.** 앰버 위 흰 텍스트는 2.2:1로 미달. 라이트와 방향이 반대다.
- **브랜치**: `develop`에서 `feat/design-token-t2` 분기 → `develop`으로 PR. `main` 직접 금지.
- **TDD**: 실패 테스트 먼저 → 실패 확인 → 최소 구현.
- 커밋: Conventional Commits. Task 단위.
- 검증: `melos run analyze` · `melos run format`(CI 게이트) · `melos run test`.

## 범위 밖 (스펙 §10)

레일 섹션 구분·브랜드 로고, 상단바 브레드크럼, 대시보드 Bento 재배치, 경로 화면 카드화, 커뮤니티 목록 미리보기. **이 계획으로는 "위계가 밋밋하다"와 "페이지마다 따로 논다"가 해결되지 않는다.**

## ★스펙 정정 — 실측이 분류를 바꿨다★

스펙 §4는 warning 쓰임을 "서비스 상태 4곳 / 구분용 5곳"으로 적었으나, 계획 작성 중 전 사용처를 열어본 결과 다음이 정확하다.

| 부류 | 실측 위치 | 조치 |
|---|---|---|
| **서비스 상태**(6파일 7곳) | `dp_kill_switch.dart:16` · `dp_quota.dart:23` · `dp_sandbox_unavailable.dart:15` · `dp_offline_banner.dart:23,26` · `mentor_page.dart:108`(연결 끊김 부분답변) · `path_page.dart:102`(SSE 중단 note) | **중립**(`textSecondary`)으로 |
| **구분용 색**(3파일 4곳) | `community_home_page.dart:252,338`(FEEDBACK 보드색) · `path_plan_view.dart:57`(약점 태그) · `reports_page.dart:110`(신고 카테고리 칩) | `chart4`(틸)로 |
| **진짜 경고**(1곳) | `review_panel.dart:80` severity `'warning'` | `warning` 유지 |

`mentor_page.dart:108`과 `path_page.dart:102`는 스펙에서 분류되지 않았는데, 열어보니 각각 "연결이 끊겼어요. 부분답변을 받았어요."와 SSE 중단 안내였다. 둘 다 사용자 잘못도 위험도 아니라 **서비스 상태**다.

## 파일 구조

| 파일 | 책임 |
|---|---|
| `packages/dp_design/lib/src/theme/dp_colors.dart` (수정) | 토큰 30종 정의 + T2 라이트/다크 값 |
| `packages/dp_design/lib/src/theme/dp_typography.dart` (수정) | 타입 스케일 3종 추가 |
| `packages/dp_design/test/theme/dp_colors_contrast_test.dart` (신규) | WCAG 대비 34건 단언 |
| `packages/dp_design/test/theme/dp_colors_integrity_test.dart` (신규) | 필드·copyWith·lerp 일치 단언 |
| `packages/dp_design/lib/src/states/dp_kill_switch.dart` 외 3 (수정) | warning → 중립 |
| `packages/dp_design/test/golden/goldens/*.png` (갱신) | 팔레트 변경 반영 |
| `packages/dp_core/lib/src/mock/mock_http_adapter.dart` (수정) | 개발자 원문 노출 차단 |
| `apps/web/lib/src/data/web_mock_fixtures.dart` (수정) | 목 픽스처 3건 |
| `apps/web`·`apps/admin` 화면 5파일 (수정) | warning 재배치 |
| `apps/web/lib/src/features/path/presentation/path_plan_view.dart` (수정) | 제목 중복 제거 |
| `DESIGN.md` (수정) | 토큰 SSoT 갱신 |

## 작업 순서

```
Task 1 dp_design 토큰   ← 임계 경로(모두가 의존)
  ├─→ Task 2 타이포
  ├─→ Task 3 dp_design 상태위젯 + 골든
  └─→ Task 4 dp_core 목 어댑터
        └─→ Task 5 web 픽스처 · Task 6 앱 warning 재배치 · Task 7 제목 중복
              └─→ Task 8 DESIGN.md + 전 검증
```

---

## Task 1: DpColors 토큰 확장 + T2 값

**Files:**
- Modify: `packages/dp_design/lib/src/theme/dp_colors.dart` (전체 교체)
- Test: `packages/dp_design/test/theme/dp_colors_contrast_test.dart` (신규)
- Test: `packages/dp_design/test/theme/dp_colors_integrity_test.dart` (신규)

**Interfaces:**
- Produces: `DpColors`가 다음 30개 필드를 갖는다 —
  `primary` `primaryText` `primaryTextStrong` `onPrimary` `accentSoft` `accentLine`
  `bg` `surface` `surfaceMuted` `border`
  `textPrimary` `textSecondary` `textFaint`
  `railBg` `railText` `railMuted` `railFaint` `railActive` `railBorder`
  `success` `warning` `danger`
  `tagBg` `tagText`
  `chart1` `chart2` `chart3` `chart4` `chart5`
  `codeEditorBg` `codeLogBg` `codeText`
  (총 32개 — 기존 15 + 신규 17)
- Task 3·6이 `surfaceMuted`·`chart4`·`textSecondary`를 쓴다.

- [ ] **Step 1: 브랜치 생성**

```bash
git -C D:/workspace/dpa/devpath-frontend checkout develop
git -C D:/workspace/dpa/devpath-frontend pull
git -C D:/workspace/dpa/devpath-frontend checkout -b feat/design-token-t2
```

- [ ] **Step 2: 대비 테스트 작성(실패하는 테스트)**

`packages/dp_design/test/theme/dp_colors_contrast_test.dart`:

```dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:dp_design/dp_design.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 상대 휘도.
double _lum(Color c) {
  double ch(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // 스펙 §8: 17조합 × 라이트·다크 = 34건. 미달 0건이 확인된 값이다.
  // 토큰 값을 바꿀 때 이 테스트가 회귀를 막는다.
  for (final (label, p) in [('라이트', DpColors.light), ('다크', DpColors.dark)]) {
    group('$label 대비', () {
      test('본문 텍스트는 4.5:1 이상', () {
        expect(contrast(p.textPrimary, p.bg), greaterThanOrEqualTo(4.5));
        expect(contrast(p.textPrimary, p.surface), greaterThanOrEqualTo(4.5));
        expect(contrast(p.textSecondary, p.bg), greaterThanOrEqualTo(4.5));
        expect(contrast(p.textSecondary, p.surface), greaterThanOrEqualTo(4.5));
      });

      test('강조 텍스트는 4.5:1, strong 은 7:1 이상', () {
        expect(contrast(p.primaryText, p.bg), greaterThanOrEqualTo(4.5));
        expect(contrast(p.primaryText, p.surface), greaterThanOrEqualTo(4.5));
        expect(contrast(p.primaryTextStrong, p.surface), greaterThanOrEqualTo(7.0));
        expect(contrast(p.primaryText, p.accentSoft), greaterThanOrEqualTo(4.5));
      });

      test('★채움 위 텍스트 4.5:1 — 다크는 onPrimary 가 어두운 색이다', () {
        // 앰버(#F59E0B) 위 흰 텍스트는 2.2:1 로 미달한다. 다크의 onPrimary 는
        // #1A1200 이며 라이트(#FFFFFF)와 방향이 반대다. 이 단언이 그 반전을 지킨다.
        expect(contrast(p.onPrimary, p.primary), greaterThanOrEqualTo(4.5));
      });

      test('시맨틱 색은 surface 위 4.5:1 이상', () {
        expect(contrast(p.success, p.surface), greaterThanOrEqualTo(4.5));
        expect(contrast(p.warning, p.surface), greaterThanOrEqualTo(4.5));
        expect(contrast(p.danger, p.surface), greaterThanOrEqualTo(4.5));
      });

      test('사이드바 대비 — 활성 4.5:1 · 섹션 레이블 3:1', () {
        expect(contrast(p.railText, p.railBg), greaterThanOrEqualTo(4.5));
        expect(contrast(p.railMuted, p.railBg), greaterThanOrEqualTo(4.5));
        expect(contrast(p.railFaint, p.railBg), greaterThanOrEqualTo(3.0));
      });

      test('faint·태그', () {
        // textFaint 는 UI 컴포넌트 기준 3:1 이며 본문 텍스트로 쓰지 않는다.
        expect(contrast(p.textFaint, p.bg), greaterThanOrEqualTo(3.0));
        expect(contrast(p.tagText, p.tagBg), greaterThanOrEqualTo(4.5));
      });
    });
  }
}
```

- [ ] **Step 3: 무결성 테스트 작성**

`packages/dp_design/test/theme/dp_colors_integrity_test.dart`:

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ThemeExtension 은 필드·copyWith·lerp 셋이 일치해야 한다.
  // 하나라도 빠지면 테마 전환 애니메이션에서 그 토큰만 튄다.
  test('lerp(t=1) 은 목적지 토큰을 그대로 돌려준다', () {
    final mid = DpColors.light.lerp(DpColors.dark, 1.0) as DpColors;
    expect(mid.bg, DpColors.dark.bg);
    expect(mid.surfaceMuted, DpColors.dark.surfaceMuted);
    expect(mid.railBg, DpColors.dark.railBg);
    expect(mid.railActive, DpColors.dark.railActive);
    expect(mid.textFaint, DpColors.dark.textFaint);
    expect(mid.accentSoft, DpColors.dark.accentSoft);
    expect(mid.accentLine, DpColors.dark.accentLine);
    expect(mid.tagBg, DpColors.dark.tagBg);
    expect(mid.chart1, DpColors.dark.chart1);
    expect(mid.chart5, DpColors.dark.chart5);
  });

  test('lerp(t=0) 은 출발 토큰을 그대로 돌려준다', () {
    final mid = DpColors.light.lerp(DpColors.dark, 0.0) as DpColors;
    expect(mid.railFaint, DpColors.light.railFaint);
    expect(mid.chart4, DpColors.light.chart4);
  });

  test('copyWith 는 지정한 토큰만 바꾼다', () {
    final c = DpColors.light.copyWith(chart4: const Color(0xFF123456));
    expect(c.chart4, const Color(0xFF123456));
    expect(c.chart1, DpColors.light.chart1);
    expect(c.railBg, DpColors.light.railBg);
    expect(c.surfaceMuted, DpColors.light.surfaceMuted);
  });

  test('T2 팔레트 기준값 — 라이트 배경은 따뜻한 무채색', () {
    expect(DpColors.light.bg, const Color(0xFFFAF9F7));
    expect(DpColors.light.primary, const Color(0xFFB45309));
    expect(DpColors.light.railBg, const Color(0xFF1A1815));
    // 다크의 onPrimary 는 어두운 색이다(라이트와 반대).
    expect(DpColors.dark.onPrimary, const Color(0xFF1A1200));
  });
}
```

- [ ] **Step 4: 테스트 실패 확인**

Run: `cd D:/workspace/dpa/devpath-frontend/packages/dp_design && flutter test test/theme/`
Expected: FAIL — `No named parameter with the name 'surfaceMuted'` 등 컴파일 오류

- [ ] **Step 5: DpColors 전체 교체**

`packages/dp_design/lib/src/theme/dp_colors.dart` 전체를 다음으로 바꾼다:

```dart
import 'package:flutter/material.dart';

/// 디자인 토큰(색). DESIGN.md §1 의 단일 출처를 코드화.
///
/// 팔레트는 **T2 잉크·앰버**. 따뜻한 무채색 그라운드에 앰버 하나를 액센트로 쓴다.
/// 앰버는 "성취"(진행률·스트릭·1차 행동)를 전담한다.
///
/// 이름 규칙: `primary` 는 **채움 전용**, 텍스트는 `primaryText`(≥4.5:1),
/// 12~14px 강조는 `primaryTextStrong`(≥7:1). 이 분리는 인디고 시절부터의 계약이며
/// 47개 파일이 이 이름에 의존하므로 개명하지 않는다.
///
/// ⚠️ 필드를 추가하면 [copyWith] 와 [lerp] 도 함께 고쳐야 한다.
/// 셋이 어긋나면 테마 전환에서 해당 토큰만 튄다(dp_colors_integrity_test 가 지킨다).
@immutable
class DpColors extends ThemeExtension<DpColors> {
  const DpColors({
    required this.primary,
    required this.primaryText,
    required this.primaryTextStrong,
    required this.onPrimary,
    required this.accentSoft,
    required this.accentLine,
    required this.bg,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textFaint,
    required this.railBg,
    required this.railText,
    required this.railMuted,
    required this.railFaint,
    required this.railActive,
    required this.railBorder,
    required this.success,
    required this.warning,
    required this.danger,
    required this.tagBg,
    required this.tagText,
    required this.chart1,
    required this.chart2,
    required this.chart3,
    required this.chart4,
    required this.chart5,
    required this.codeEditorBg,
    required this.codeLogBg,
    required this.codeText,
  });

  /// 채움 전용. 텍스트에 쓰지 않는다.
  final Color primary;
  final Color primaryText;
  final Color primaryTextStrong;

  /// [primary] 채움 위 텍스트. **다크에서는 어두운 색**이다(앰버 위 흰 텍스트는 대비 미달).
  final Color onPrimary;

  /// 1차 카드 배경·뱃지.
  final Color accentSoft;

  /// 1차 카드 보더.
  final Color accentLine;

  final Color bg;
  final Color surface;

  /// 비활성·보조 면. 카드(surface)와 배경(bg) 사이 단계.
  final Color surfaceMuted;

  final Color border;
  final Color textPrimary;
  final Color textSecondary;

  /// 메타·캡션. UI 컴포넌트 기준(3:1)이라 **본문 텍스트로 쓰지 않는다.**
  final Color textFaint;

  /// 사이드바 전용. 본문과 다른 위계를 갖는다.
  final Color railBg;
  final Color railText;
  final Color railMuted;

  /// 사이드바 섹션 레이블.
  final Color railFaint;
  final Color railActive;
  final Color railBorder;

  final Color success;

  /// **진짜 경고 전용.** 서비스 상태(점검·한도·오프라인)는 중립을 쓰고,
  /// 구분용 색은 [chart4] 를 쓴다. 액센트(앰버)와 계열이 가까워 용도를 좁혔다.
  final Color warning;

  final Color danger;

  final Color tagBg;
  final Color tagText;

  /// 차트 팔레트. chart4 는 앰버의 대비 계열(틸)이라 구분용 색으로도 쓴다.
  final Color chart1;
  final Color chart2;
  final Color chart3;
  final Color chart4;
  final Color chart5;

  final Color codeEditorBg; // 항상 다크(토글 무관)
  final Color codeLogBg;
  final Color codeText;

  static const light = DpColors(
    primary: Color(0xFFB45309),
    primaryText: Color(0xFF92400E),
    primaryTextStrong: Color(0xFF78350F),
    onPrimary: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFFDF1E0),
    accentLine: Color(0xFFF2D0A0),
    bg: Color(0xFFFAF9F7),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF2F0EC),
    border: Color(0xFFE2DED7),
    textPrimary: Color(0xFF1A1815),
    textSecondary: Color(0xFF615C54),
    textFaint: Color(0xFF918B81),
    railBg: Color(0xFF1A1815),
    railText: Color(0xFFF2F0EC),
    railMuted: Color(0xFFA9A298),
    railFaint: Color(0xFF7D766C),
    railActive: Color(0xFF2F2B24),
    railBorder: Color(0xFF2B2823),
    success: Color(0xFF15803D),
    warning: Color(0xFFA16207),
    danger: Color(0xFFB91C1C),
    tagBg: Color(0xFFF2F0EC),
    tagText: Color(0xFF524D45),
    chart1: Color(0xFFB45309),
    chart2: Color(0xFFF2D0A0),
    chart3: Color(0xFF78350F),
    chart4: Color(0xFF0F766E),
    chart5: Color(0xFF8B857D),
    codeEditorBg: Color(0xFF1E1E1E),
    codeLogBg: Color(0xFF0D1117),
    codeText: Color(0xFFD4D4D4),
  );

  static const dark = DpColors(
    primary: Color(0xFFF59E0B),
    primaryText: Color(0xFFFBBF24),
    primaryTextStrong: Color(0xFFFCD34D),
    // ★라이트와 반대 방향★ 앰버 위 흰 텍스트는 2.2:1 로 미달한다.
    onPrimary: Color(0xFF1A1200),
    accentSoft: Color(0xFF2E2007),
    accentLine: Color(0xFF5C400E),
    bg: Color(0xFF0F0E0C),
    surface: Color(0xFF1A1815),
    surfaceMuted: Color(0xFF231F1B),
    border: Color(0xFF332E28),
    textPrimary: Color(0xFFEAE7E2),
    textSecondary: Color(0xFFA09991),
    textFaint: Color(0xFF6F6961),
    railBg: Color(0xFF131210),
    railText: Color(0xFFEAE7E2),
    railMuted: Color(0xFF948D85),
    railFaint: Color(0xFF6B655D),
    railActive: Color(0xFF231F1B),
    railBorder: Color(0xFF2A2621),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFCD34D),
    danger: Color(0xFFF87171),
    tagBg: Color(0xFF231F1B),
    tagText: Color(0xFFA09991),
    chart1: Color(0xFFF59E0B),
    chart2: Color(0xFF78350F),
    chart3: Color(0xFFFCD34D),
    chart4: Color(0xFF2DD4BF),
    chart5: Color(0xFF8B857D),
    codeEditorBg: Color(0xFF1E1E1E),
    codeLogBg: Color(0xFF0D1117),
    codeText: Color(0xFFC9D1D9),
  );

  @override
  DpColors copyWith({
    Color? primary,
    Color? primaryText,
    Color? primaryTextStrong,
    Color? onPrimary,
    Color? accentSoft,
    Color? accentLine,
    Color? bg,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textFaint,
    Color? railBg,
    Color? railText,
    Color? railMuted,
    Color? railFaint,
    Color? railActive,
    Color? railBorder,
    Color? success,
    Color? warning,
    Color? danger,
    Color? tagBg,
    Color? tagText,
    Color? chart1,
    Color? chart2,
    Color? chart3,
    Color? chart4,
    Color? chart5,
    Color? codeEditorBg,
    Color? codeLogBg,
    Color? codeText,
  }) => DpColors(
    primary: primary ?? this.primary,
    primaryText: primaryText ?? this.primaryText,
    primaryTextStrong: primaryTextStrong ?? this.primaryTextStrong,
    onPrimary: onPrimary ?? this.onPrimary,
    accentSoft: accentSoft ?? this.accentSoft,
    accentLine: accentLine ?? this.accentLine,
    bg: bg ?? this.bg,
    surface: surface ?? this.surface,
    surfaceMuted: surfaceMuted ?? this.surfaceMuted,
    border: border ?? this.border,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textFaint: textFaint ?? this.textFaint,
    railBg: railBg ?? this.railBg,
    railText: railText ?? this.railText,
    railMuted: railMuted ?? this.railMuted,
    railFaint: railFaint ?? this.railFaint,
    railActive: railActive ?? this.railActive,
    railBorder: railBorder ?? this.railBorder,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    tagBg: tagBg ?? this.tagBg,
    tagText: tagText ?? this.tagText,
    chart1: chart1 ?? this.chart1,
    chart2: chart2 ?? this.chart2,
    chart3: chart3 ?? this.chart3,
    chart4: chart4 ?? this.chart4,
    chart5: chart5 ?? this.chart5,
    codeEditorBg: codeEditorBg ?? this.codeEditorBg,
    codeLogBg: codeLogBg ?? this.codeLogBg,
    codeText: codeText ?? this.codeText,
  );

  @override
  DpColors lerp(ThemeExtension<DpColors>? other, double t) {
    if (other is! DpColors) return this;
    Color m(Color a, Color b) => Color.lerp(a, b, t)!;
    return DpColors(
      primary: m(primary, other.primary),
      primaryText: m(primaryText, other.primaryText),
      primaryTextStrong: m(primaryTextStrong, other.primaryTextStrong),
      onPrimary: m(onPrimary, other.onPrimary),
      accentSoft: m(accentSoft, other.accentSoft),
      accentLine: m(accentLine, other.accentLine),
      bg: m(bg, other.bg),
      surface: m(surface, other.surface),
      surfaceMuted: m(surfaceMuted, other.surfaceMuted),
      border: m(border, other.border),
      textPrimary: m(textPrimary, other.textPrimary),
      textSecondary: m(textSecondary, other.textSecondary),
      textFaint: m(textFaint, other.textFaint),
      railBg: m(railBg, other.railBg),
      railText: m(railText, other.railText),
      railMuted: m(railMuted, other.railMuted),
      railFaint: m(railFaint, other.railFaint),
      railActive: m(railActive, other.railActive),
      railBorder: m(railBorder, other.railBorder),
      success: m(success, other.success),
      warning: m(warning, other.warning),
      danger: m(danger, other.danger),
      tagBg: m(tagBg, other.tagBg),
      tagText: m(tagText, other.tagText),
      chart1: m(chart1, other.chart1),
      chart2: m(chart2, other.chart2),
      chart3: m(chart3, other.chart3),
      chart4: m(chart4, other.chart4),
      chart5: m(chart5, other.chart5),
      codeEditorBg: m(codeEditorBg, other.codeEditorBg),
      codeLogBg: m(codeLogBg, other.codeLogBg),
      codeText: m(codeText, other.codeText),
    );
  }
}

/// 토큰 접근 단축: `context.dpColors.primaryText`.
/// 확장은 노출 타입(DpColors)과 같은 파일에 두어, DpColors를 쓰는 위젯이
/// 별도 import 없이 토큰에 접근하도록 한다.
extension DpColorsX on BuildContext {
  DpColors get dpColors => Theme.of(this).extension<DpColors>()!;
}
```

- [ ] **Step 6: 테스트 통과 확인**

Run: `cd D:/workspace/dpa/devpath-frontend/packages/dp_design && flutter test test/theme/`
Expected: PASS. 대비 12 그룹 + 무결성 4 = 16 tests.

대비 테스트가 실패하면 값을 임의로 조정하지 말고 스펙 §8의 실측 표와 대조한다.

- [ ] **Step 7: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add packages/dp_design/lib/src/theme/dp_colors.dart packages/dp_design/test/theme/
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(dp_design): expand color tokens and switch palette to T2"
```

---

## Task 2: 타입 스케일 3종 추가

**Files:**
- Modify: `packages/dp_design/lib/src/theme/dp_typography.dart`
- Test: `packages/dp_design/test/theme/dp_typography_test.dart` (신규)

**Interfaces:**
- Produces: `DpTypography.textTheme(brightness)` 가 `titleLarge`·`titleSmall`·`labelMedium` 을 추가로 정의한다.

- [ ] **Step 1: 실패하는 테스트 작성**

`packages/dp_design/test/theme/dp_typography_test.dart`:

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t = DpTypography.textTheme(Brightness.light);

  test('추가 3종이 정의돼 있다 — 미정의면 Material 기본 크기·행간이 쓰인다', () {
    // 실측: titleLarge 1곳 · titleSmall 4곳 · labelMedium 2곳이 이미 사용 중이었고,
    // 정의가 없어 한글 행간(1.6)이 적용되지 않았다.
    expect(t.titleLarge, isNotNull);
    expect(t.titleSmall, isNotNull);
    expect(t.labelMedium, isNotNull);
  });

  test('DESIGN.md §2 스케일과 일치한다', () {
    expect(t.titleLarge!.fontSize, 20);
    expect(t.titleLarge!.fontWeight, FontWeight.w700);
    expect(t.titleSmall!.fontSize, 14);
    expect(t.titleSmall!.fontWeight, FontWeight.w600);
    expect(t.labelMedium!.fontSize, 12);
    expect(t.labelMedium!.fontWeight, FontWeight.w600);
  });

  test('모든 정의 스타일이 Pretendard 를 쓴다', () {
    for (final s in [
      t.displaySmall, t.headlineSmall, t.titleLarge, t.titleMedium,
      t.titleSmall, t.bodyMedium, t.bodySmall, t.labelLarge, t.labelMedium,
    ]) {
      expect(s!.fontFamily, 'Pretendard');
    }
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd D:/workspace/dpa/devpath-frontend/packages/dp_design && flutter test test/theme/dp_typography_test.dart`
Expected: FAIL — `Expected: not null / Actual: <null>` (titleLarge)

- [ ] **Step 3: 구현**

`dp_typography.dart` 의 `TextTheme(...)` 안에 세 항목을 추가한다. `headlineSmall` 다음, `titleMedium` 앞에 `titleLarge` 를, `titleMedium` 다음에 `titleSmall` 을, `labelLarge` 다음에 `labelMedium` 을 둔다:

```dart
      titleLarge: TextStyle(
        fontFamily: f,
        fontSize: 20,
        height: 28 / 20,
        fontWeight: FontWeight.w700,
      ),
```

```dart
      titleSmall: TextStyle(
        fontFamily: f,
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w600,
      ),
```

```dart
      labelMedium: TextStyle(
        fontFamily: f,
        fontSize: 12,
        height: 16 / 12,
        fontWeight: FontWeight.w600,
      ),
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/theme/dp_typography_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add packages/dp_design/lib/src/theme/dp_typography.dart packages/dp_design/test/theme/dp_typography_test.dart
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(dp_design): define titleLarge, titleSmall, labelMedium"
```

---

## Task 3: dp_design 상태위젯 warning → 중립 + 골든 갱신

**Files:**
- Modify: `packages/dp_design/lib/src/states/dp_kill_switch.dart:16`
- Modify: `packages/dp_design/lib/src/states/dp_quota.dart:23`
- Modify: `packages/dp_design/lib/src/states/dp_sandbox_unavailable.dart:15`
- Modify: `packages/dp_design/lib/src/states/dp_offline_banner.dart:23,26`
- Modify: `packages/dp_design/test/golden/goldens/kill_switch_light.png` · `kill_switch_dark.png` (갱신)
- Test: `packages/dp_design/test/states/service_state_tone_test.dart` (신규)

**Interfaces:**
- Consumes: Task 1의 `textSecondary`·`surfaceMuted`

**왜 중립인가:** "AI 기능이 잠시 점검 중이에요" · "한도를 다 썼어요" · "오프라인" 은 **사용자 잘못도 위험도 아니다.** 노란 경고색은 사용자에게 자기 잘못이라는 신호를 준다. 액센트(앰버)와 계열이 겹치는 문제까지 함께 해소된다.

- [ ] **Step 1: 실패하는 테스트 작성**

`packages/dp_design/test/states/service_state_tone_test.dart`:

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) =>
    MaterialApp(theme: DpTheme.light(), home: Scaffold(body: child));

Color _iconColor(WidgetTester tester) =>
    tester.widget<Icon>(find.byType(Icon).first).color!;

void main() {
  // 서비스 상태는 사용자 잘못도 위험도 아니다 → 경고색이 아니라 중립을 쓴다.
  // 액센트(앰버)와 warning 의 계열 충돌도 이 재배치로 해소된다.
  testWidgets('DpKillSwitch 아이콘은 중립색', (tester) async {
    await tester.pumpWidget(_wrap(const DpKillSwitch()));
    expect(_iconColor(tester), DpColors.light.textSecondary);
  });

  testWidgets('DpQuota 아이콘은 중립색', (tester) async {
    // 생성자 실측: DpQuota({super.key, required this.retryAfterSeconds, this.onUpgrade})
    await tester.pumpWidget(_wrap(const DpQuota(retryAfterSeconds: 60)));
    expect(_iconColor(tester), DpColors.light.textSecondary);
  });

  testWidgets('DpSandboxUnavailable 아이콘은 중립색', (tester) async {
    await tester.pumpWidget(_wrap(const DpSandboxUnavailable()));
    expect(_iconColor(tester), DpColors.light.textSecondary);
  });

  testWidgets('DpOfflineBanner 는 중립 배경과 중립 아이콘', (tester) async {
    await tester.pumpWidget(_wrap(const DpOfflineBanner()));
    expect(_iconColor(tester), DpColors.light.textSecondary);
    final box = tester.widget<Container>(find.byType(Container).first);
    expect((box.decoration as BoxDecoration).color, DpColors.light.surfaceMuted);
  });
}
```

> 생성자는 실측 확인했다: `DpSandboxUnavailable({super.key, this.onDismiss})` · `DpOfflineBanner({super.key, this.message = '오프라인 — 캐시된 콘텐츠를 보여드려요'})` 는 인자 없이 생성 가능하고, `DpQuota` 만 `retryAfterSeconds` 가 필수다.

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd D:/workspace/dpa/devpath-frontend/packages/dp_design && flutter test test/states/service_state_tone_test.dart`
Expected: FAIL — 실제 색이 `warning`(#A16207)이라 `textSecondary`(#615C54)와 다름

- [ ] **Step 3: 네 파일 수정**

`dp_kill_switch.dart:16` · `dp_quota.dart:23` · `dp_sandbox_unavailable.dart:15` 의
`iconColor: context.dpColors.warning,` 를 각각 다음으로 바꾼다:

```dart
    // 서비스 상태는 사용자 잘못도 위험도 아니다 → 중립. (경고색은 진짜 경고 전용)
    iconColor: context.dpColors.textSecondary,
```

`dp_offline_banner.dart:23,26`:

```dart
        color: c.surfaceMuted,
```

```dart
            Icon(DpIcons.offline, size: 18, color: c.textSecondary),
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/states/service_state_tone_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: 골든 재생성**

팔레트가 통째로 바뀌었으므로 기존 골든 2장은 반드시 깨진다. 재생성한다:

```bash
cd D:/workspace/dpa/devpath-frontend/packages/dp_design
flutter test --tags golden --update-goldens
flutter test --tags golden
```

Expected: 두 번째 실행이 PASS. `goldens/kill_switch_light.png` · `kill_switch_dark.png` 가 갱신된다.

**갱신된 이미지를 눈으로 확인한다** — 잉크 배경에 중립 아이콘이어야 하고, 노란색이 남아 있으면 안 된다.

- [ ] **Step 6: dp_design 전체 확인 후 커밋**

```bash
cd D:/workspace/dpa/devpath-frontend/packages/dp_design && flutter test --exclude-tags golden
git -C D:/workspace/dpa/devpath-frontend add packages/dp_design
git -C D:/workspace/dpa/devpath-frontend commit -m "refactor(dp_design): use neutral tone for service state widgets"
```

---

## Task 4: 목 어댑터의 개발자 원문 노출 차단

**Files:**
- Modify: `packages/dp_core/lib/src/mock/mock_http_adapter.dart:24`
- Test: `packages/dp_core/test/mock/mock_http_adapter_test.dart` (신규)

**Interfaces:**
- Produces: 픽스처 미등록 시 응답이 `{"error":{"code":"RESOURCE_NOT_FOUND","message":"<사용자용 카피>","debug":"no mock: GET /x"}}` 형태가 된다. `message` 에 경로가 들어가지 않는다.

**배경:** 실측 결과 `/settings`·`/mypage`·`/content/:id` 화면에 `no mock: GET /consents/me` 라는 개발자 원문이 그대로 노출되고 있었다. 프론트는 `error.message` 를 그대로 렌더한다.

- [ ] **Step 1: 실패하는 테스트 작성**

`packages/dp_core/test/mock/mock_http_adapter_test.dart`:

```dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:test/test.dart';

void main() {
  test('픽스처 미등록 시 사용자용 카피를 내고 경로를 노출하지 않는다', () async {
    final adapter = MockHttpAdapter(const {});
    final res = await adapter.fetch(
      RequestOptions(path: '/consents/me', method: 'GET'),
      null,
      null,
    );
    final body = jsonDecode(await utf8.decodeStream(res.stream))
        as Map<String, dynamic>;
    final err = body['error'] as Map<String, dynamic>;

    expect(res.statusCode, 404);
    expect(err['code'], 'RESOURCE_NOT_FOUND');
    // 사용자에게 개발자 원문을 보이지 않는다.
    expect(err['message'], isNot(contains('no mock')));
    expect(err['message'], isNot(contains('/consents/me')));
    expect(err['message'], isNotEmpty);
    // 프로토 진단은 계속 가능해야 하므로 debug 필드에는 남긴다.
    expect(err['debug'], contains('GET /consents/me'));
  });

  test('등록된 픽스처는 그대로 돌려준다', () async {
    final adapter = MockHttpAdapter(const {
      'GET /ping': (200, {'ok': true}),
    });
    final res = await adapter.fetch(
      RequestOptions(path: '/ping', method: 'GET'),
      null,
      null,
    );
    expect(res.statusCode, 200);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd D:/workspace/dpa/devpath-frontend/packages/dp_core && dart test test/mock/mock_http_adapter_test.dart`
Expected: FAIL — `message` 가 `no mock: GET /consents/me` 라서 첫 단언이 깨진다

- [ ] **Step 3: 구현**

`mock_http_adapter.dart` 의 픽스처 미등록 분기(24행 부근)를 다음으로 바꾼다:

```dart
    final fixture = _resolve(options);
    if (fixture == null) {
      final key = '${options.method} ${options.path}';
      // 사용자에게는 사람이 읽는 문장만 보인다. 개발자 원문은 debug 필드에만 둔다
      // (프론트는 error.message 를 그대로 화면에 렌더한다).
      assert(() {
        // ignore: avoid_print
        print('[MockHttpAdapter] 등록되지 않은 픽스처: $key');
        return true;
      }());
      return ResponseBody.fromString(
        jsonEncode({
          'error': {
            'code': 'RESOURCE_NOT_FOUND',
            'message': '아직 준비되지 않은 화면이에요. 잠시 후 다시 시도해 주세요.',
            'debug': 'no mock: $key',
          },
        }),
        404,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `dart test test/mock/mock_http_adapter_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: dp_core 전체 확인 후 커밋**

```bash
cd D:/workspace/dpa/devpath-frontend/packages/dp_core && dart test
git -C D:/workspace/dpa/devpath-frontend add packages/dp_core
git -C D:/workspace/dpa/devpath-frontend commit -m "fix(dp_core): stop leaking mock adapter internals to users"
```

---

## Task 5: 목 픽스처 3건 추가

**Files:**
- Modify: `apps/web/lib/src/data/web_mock_fixtures.dart`
- Test: `apps/web/test/data/mock_fixture_coverage_test.dart` (신규)

**Interfaces:**
- Consumes: Task 4의 `debug` 필드 계약
- Produces: `webMockFixtures` 에 `GET /consents/me` · `GET /users/me/profile` · `POST /contents/:id/progress` 키가 존재한다.

**배경:** 목 모드가 기본값(`USE_MOCK=true`)이라 이 셋이 없으면 설정·마이페이지·학습 콘텐츠가 **에러 화면으로 뜬다**. 실측으로 확인했다.

- [ ] **Step 1: 실패하는 테스트 작성**

`apps/web/test/data/mock_fixture_coverage_test.dart`:

```dart
import 'package:devpath_web/src/data/web_mock_fixtures.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 목 모드가 기본값이라 픽스처가 없으면 화면이 에러로 뜬다.
  // 2026-08-03 실측에서 아래 셋이 누락돼 설정·마이페이지·콘텐츠가 깨져 있었다.
  test('사용자가 도달하는 주요 GET 은 픽스처가 있다', () {
    expect(webMockFixtures.containsKey('GET /consents/me'), isTrue);
    expect(webMockFixtures.containsKey('GET /users/me/profile'), isTrue);
  });

  test('콘텐츠 진행 저장 픽스처가 있다', () {
    expect(webMockFixtures.containsKey('POST /contents/c1/progress'), isTrue);
  });

  test('상태코드는 성공 범위다', () {
    for (final key in [
      'GET /consents/me',
      'GET /users/me/profile',
      'POST /contents/c1/progress',
    ]) {
      final (status, _) = webMockFixtures[key]!;
      expect(status, inInclusiveRange(200, 299), reason: key);
    }
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd D:/workspace/dpa/devpath-frontend/apps/web && flutter test test/data/mock_fixture_coverage_test.dart`
Expected: FAIL — 세 키 모두 없음

- [ ] **Step 3: 픽스처 추가**

`web_mock_fixtures.dart` 의 맵에 추가한다. **필드명은 모델을 열어 실측한 것이다** — 추측이 아니다.

- `ConsentsView.fromJson`(`apps/web/.../settings/data/settings_models.dart:13`) → `consentStatus`(String) · `items`(List) · `birthYear`(int?)
- `ConsentItemView.fromJson`(같은 파일 :44) → `type`(String) · `agreed`(bool) · `version`(String) · `agreedAt`(String?)
- `ProfileView`(json_serializable, `profile_view.g.dart:9`) → `avatar` · `bio` · `learningGoal` · `targetTrack` · `experienceYears` — **전부 nullable**

```dart
  // 2026-08-03: 아래 셋이 없어 설정·마이페이지·학습 콘텐츠가 에러 화면으로 떴다.
  'GET /consents/me': (
    200,
    {
      'consentStatus': 'DONE',
      'birthYear': 1998,
      'items': [
        {'type': 'TERMS', 'agreed': true, 'version': '1.0', 'agreedAt': '2026-07-01T09:00:00Z'},
        {'type': 'PRIVACY', 'agreed': true, 'version': '1.0', 'agreedAt': '2026-07-01T09:00:00Z'},
        {'type': 'MARKETING', 'agreed': false, 'version': '1.0', 'agreedAt': null},
      ],
    },
  ),
  'GET /users/me/profile': (
    200,
    {
      'avatar': null,
      'bio': '백엔드로 전향 중입니다.',
      'learningGoal': '6개월 내 백엔드 이직',
      'targetTrack': 'BACKEND',
      'experienceYears': 2,
    },
  ),
  'POST /contents/c1/progress': (200, {'ok': true}),
```

> `type` 값(`TERMS`·`PRIVACY`·`MARKETING`)은 설정 화면이 `itemOf(type)` 으로 조회하는 키다. 화면 코드에서 어떤 문자열로 조회하는지 확인해 맞춘다 — 값이 다르면 항목이 비어 보인다.

- [ ] **Step 4: 테스트 통과 확인 + 실제 화면 확인**

Run: `flutter test test/data/mock_fixture_coverage_test.dart`
Expected: PASS (3 tests)

필드명이 화면의 모델과 어긋나면 테스트는 통과해도 화면은 여전히 깨진다. Task 8의 재캡처에서 반드시 눈으로 확인한다.

- [ ] **Step 5: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add apps/web/lib/src/data/web_mock_fixtures.dart apps/web/test/data/
git -C D:/workspace/dpa/devpath-frontend commit -m "fix(web): add missing mock fixtures for settings, mypage, content"
```

---

## Task 6: 앱 화면 warning 재배치

**Files:**
- Modify: `apps/web/lib/src/features/mentor/presentation/mentor_page.dart:108` (서비스 상태 → 중립)
- Modify: `apps/web/lib/src/features/path/presentation/path_page.dart:102` (서비스 상태 → 중립)
- Modify: `apps/web/lib/src/features/community/presentation/community_home_page.dart:252,338` (구분용 → chart4)
- Modify: `apps/web/lib/src/features/path/presentation/path_plan_view.dart:57` (구분용 → chart4)
- Modify: `apps/admin/lib/src/features/reports/presentation/reports_page.dart:110` (구분용 → chart4)

**Interfaces:**
- Consumes: Task 1의 `textSecondary`·`chart4`

**남는 `warning` 사용처는 `review_panel.dart:80` 한 곳뿐이다**(백엔드 severity 계약값). 이것만 진짜 경고다.

- [ ] **Step 1: 서비스 상태 2곳 → 중립**

`mentor_page.dart:108` — "연결이 끊겼어요. 부분답변을 받았어요.":

```dart
                      ).textTheme.bodySmall?.copyWith(color: c.textSecondary),
```

`path_page.dart:102` — SSE 중단 note:

```dart
                ).textTheme.bodySmall?.copyWith(color: c.textSecondary),
```

- [ ] **Step 2: 구분용 4곳 → chart4**

`community_home_page.dart:252` 와 `:338` — FEEDBACK 보드 구분색:

```dart
      'FEEDBACK' => c.chart4,
```

`path_plan_view.dart:57` — 약점 태그:

```dart
                _Tag(label: weakness, color: c.chart4),
```

`reports_page.dart:110` — 신고 카테고리 칩:

```dart
                _chip(context, r.categoryLabel, tone: c.chart4),
```

- [ ] **Step 3: 남은 warning 사용처 확인**

```bash
cd D:/workspace/dpa/devpath-frontend
grep -rn "\.warning" apps/*/lib packages/*/lib --include='*.dart' | grep -v "dp_colors.dart"
```

Expected: `review_panel.dart:80` **한 줄만** 출력된다. 다른 줄이 남아 있으면 위 목록에서 빠진 곳이므로 성격을 판단해 재배치한다.

- [ ] **Step 4: 앱 테스트 확인**

```bash
cd D:/workspace/dpa/devpath-frontend/apps/web && flutter test --exclude-tags golden
cd D:/workspace/dpa/devpath-frontend/apps/admin && flutter test --exclude-tags golden
```

Expected: 둘 다 PASS. 색을 단언하는 기존 테스트가 있으면 새 토큰으로 갱신한다.

- [ ] **Step 5: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add apps/web/lib apps/admin/lib
git -C D:/workspace/dpa/devpath-frontend commit -m "refactor: reassign warning color by meaning"
```

---

## Task 7: 경로 화면 제목 중복 제거

**Files:**
- Modify: `apps/web/lib/src/features/path/presentation/path_plan_view.dart:21`
- Modify: `apps/web/lib/src/features/path/presentation/path_page.dart:61`
- Test: `apps/web/test/features/path/path_title_test.dart` (신규)

**배경:** 앱바가 "학습 경로 생성", 본문이 "학습 경로"를 동시에 렌더해 **같은 화면에 제목이 둘**이고 문구도 다르다. 실측 캡처에서 확인했다.

- [ ] **Step 1: 실패하는 테스트 작성**

`apps/web/test/features/path/path_title_test.dart`:

```dart
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:devpath_web/src/data/web_mock_fixtures.dart';
import 'package:devpath_web/src/features/path/presentation/path_plan_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('본문에 화면 제목을 반복하지 않는다 — 앱바가 제목을 갖는다', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // 생성자 실측: PathPlanView({super.key, required this.plan})
    // 목 데이터는 web_mock_fixtures.dart:410 의 mockLearningPath() 를 재사용한다.
    final plan = LearningPath.fromJson(mockLearningPath());

    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: Scaffold(
          appBar: AppBar(title: const Text('학습 경로')),
          body: PathPlanView(plan: plan),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 앱바에만 있어야 한다.
    expect(find.text('학습 경로'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd D:/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/path/path_title_test.dart`
Expected: FAIL — `findsOneWidget` 인데 2개 발견

- [ ] **Step 3: 본문 제목 제거 + 앱바 문구 통일**

`path_plan_view.dart:21` 의 다음 줄을 **삭제**한다:

```dart
        Text('학습 경로', style: text.headlineSmall),
```

삭제 후 바로 뒤 `SizedBox` 가 남아 여백이 두 번 들어가면 그것도 함께 정리한다. `text` 변수가 더 이상 쓰이지 않으면 선언도 지운다(analyze 가 잡는다).

`path_page.dart:61` 의 앱바 제목을 통일한다:

```dart
      appBar: AppBar(title: const Text('학습 경로')),
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `flutter test test/features/path/path_title_test.dart`
Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add apps/web/lib/src/features/path apps/web/test/features/path
git -C D:/workspace/dpa/devpath-frontend commit -m "fix(web): remove duplicated page title on path screen"
```

---

## Task 8: DESIGN.md 갱신 + 전체 검증 + 재캡처

**Files:**
- Modify: `DESIGN.md` (§1 컬러 토큰 · §2 타이포 표)

**Interfaces:**
- Consumes: Task 1~7 전부

- [ ] **Step 1: DESIGN.md §1 교체**

§1 의 컬러 표 전체를 T2 값으로 바꾸고 다음 문단을 §1 머리에 넣는다:

```markdown
프라이머리는 **잉크·앰버(T2)**. 따뜻한 무채색 그라운드에 앰버 하나를 액센트로 쓰며,
앰버는 **"성취"를 전담**한다(진행률·스트릭·1차 행동).

- `primary` 는 **채움 전용**, 텍스트는 `primaryText`(≥4.5:1), 12~14px 강조는 `primaryTextStrong`(≥7:1).
- **다크의 `onPrimary` 는 어두운 색**(`#1A1200`)이다 — 앰버 위 흰 텍스트는 2.2:1 로 미달한다.
- 면은 3단계(`bg` · `surface` · `surfaceMuted`), 사이드바는 전용 토큰 6종을 갖는다.
- `warning` 은 **진짜 경고 전용**이다. 서비스 상태(점검·한도·오프라인·부분실패)는 중립(`textSecondary`),
  의미 없는 구분용 색은 `chart4` 를 쓴다. 액센트와 계열이 가까워 용도를 좁혔다.
- 대비는 17조합 × 라이트·다크 = 34건을 실측해 미달 0건을 확인했다(2026-08-03).
  검증 스크립트: `docs/superpowers/specs/2026-08-03-token-contrast-check.py`
```

토큰 값 표는 스펙 §3.2·§3.3 을 그대로 옮긴다.

- [ ] **Step 2: DESIGN.md §2 타이포 표에 3행 추가**

```markdown
| titleLarge | 20/28 (w700) | 섹션 제목 |
| titleSmall | 14/20 (w600) | 카드 소제목 |
| labelMedium | 12/16 (w600) | 칩·뱃지 |
```

- [ ] **Step 3: 모노레포 전체 게이트**

```bash
cd D:/workspace/dpa/devpath-frontend
dart pub global run melos analyze
dart pub global run melos format
dart pub global run melos test
```

Expected: 5패키지 전부 green. `format` 은 CI 게이트라 변경이 생기면 재실행해 0 changed 를 확인한다.

- [ ] **Step 4: ★전 라우트 재캡처 — 전/후 비교★**

이번 세션의 캡처 절차를 그대로 재사용한다.

```bash
cd D:/workspace/dpa/devpath-frontend/apps/web
flutter build web --release
cd build/web && py -m http.server 8099
# 별도 셸에서 Playwright 캡처 스크립트 실행 (16개 라우트)
```

확인할 것:
1. **설정·마이페이지·학습 콘텐츠가 더 이상 에러 화면이 아니다**(Task 5)
2. 에러가 나는 화면에도 `no mock:` 원문이 보이지 않는다(Task 4)
3. 경로 화면에 제목이 하나뿐이다(Task 7)
4. 전 화면이 잉크·앰버 팔레트로 렌더된다
5. 점검 중·오프라인 배너가 노란색이 아니라 중립이다(Task 3)

- [ ] **Step 5: 커밋·푸시·PR**

```bash
git -C D:/workspace/dpa/devpath-frontend add DESIGN.md
git -C D:/workspace/dpa/devpath-frontend commit -m "docs: update DESIGN.md for T2 palette and token structure"
git -C D:/workspace/dpa/devpath-frontend push -u origin feat/design-token-t2
gh pr create -R DevPathAi/devpath-frontend --base develop --head feat/design-token-t2 \
  --title "feat: 디자인 토큰 개편 (T2 잉크·앰버)" \
  --body "스펙: docs/superpowers/specs/2026-08-03-design-token-overhaul-design.md"
```

---

## 머지 후 확인

1. 재캡처 이미지를 1단계 전 캡처와 나란히 두고 **위계·여백 문제가 얼마나 남았는지** 판단한다.
2. 남은 문제(대시보드 L자 빈 구멍 · 경로 화면 카드 부재 · 레일 하단 공백)를 근거로 **2단계 범위**를 정한다.
