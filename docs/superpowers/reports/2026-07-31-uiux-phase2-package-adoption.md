# UI/UX Phase 2 — 패키지 도입 검증 리포트 (2026-07-31)

> 로드맵 §3 검증 절차 이행 기록. spec `docs/superpowers/specs/2026-07-31-uiux-phase2-dashboard-design.md` §6, plan Task 1.
> 대상: `apps/web`(Flutter Web, CanvasKit).

## 도입 패키지 (확정)

| 패키지 | 용도 | pubspec 제약 | 해결 버전(lock) | 라이선스 | CanvasKit/Web |
|---|---|---|---|---|---|
| `fl_chart` | 진행률 도넛(PieChart) | `^1.2.0` | **1.2.0** | MIT | ✅ (CustomPaint 기반, 웹 지원). `sectionsSpace`만 HTML 렌더러 미지원 — 본 앱은 CanvasKit이라 무관 |
| `flutter_staggered_grid_view` | Bento 폭별 재배치 그리드 | `^0.7.0` | **0.7.0** | MIT | ✅ (순수 위젯) |
| `skeletonizer` | 카드 구조 스켈레톤 로딩 | `^2.1.3` | **2.1.3** | MIT | ✅ (순수 위젯, shimmer) |

## 검증 절차 (로드맵 §3)

1. **Context7 최신 버전·API 확인** — 완료.
   - fl_chart(`/imanneo/fl_chart`): `PieChartData(sections·centerSpaceRadius·sectionsSpace·startDegreeOffset·pieTouchData)`, `PieChartSectionData(value·color·radius·showTitle)`. 도넛 = `centerSpaceRadius` 설정. 플랜 코드와 일치.
   - flutter_staggered_grid_view(`/letsar/flutter_staggered_grid_view`): `StaggeredGrid.count(crossAxisCount·mainAxisSpacing·crossAxisSpacing, children:[StaggeredGridTile.count(crossAxisCellCount·mainAxisCellCount·child)])`. 플랜 코드와 일치.
   - skeletonizer(`/milad-akarie/skeletonizer`): `Skeletonizer(enabled:, child:)` + `enableSwitchAnimation`. 플랜 코드와 일치.
2. **Flutter Web(CanvasKit)·SDK 호환** — 3종 모두 순수 Flutter 위젯(외부 네이티브 의존 없음), 현 SDK로 해결 성공.
3. **라이선스** — 3종 모두 MIT(pub cache LICENSE 원문 확인).
4. **`flutter pub add` + `melos run analyze`** — 해결 성공(버전 충돌 없음). analyze 결과: **SUCCESS**(전 패키지 `flutter analyze`·`dart analyze` "No issues found", 5패키지 green).
5. **확정 버전 기록** — 위 표.

## 비고

- **fl_chart는 1.x 메이저**(1.2.0). 도넛 관련 핵심 API(`PieChartData`/`PieChartSectionData`/`centerSpaceRadius`)는 0.x와 동일해 플랜 코드 변경 불필요.
- 버전 확정은 `flutter pub add`(최신 caret 기록) → `pubspec.lock` 실측으로 수행.
