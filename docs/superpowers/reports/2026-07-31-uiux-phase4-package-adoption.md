# UI/UX Phase 4 — 패키지 도입 검증 리포트 (2026-07-31)

> 로드맵 §3 검증 절차 이행 기록. spec `docs/superpowers/specs/2026-07-31-uiux-phase4-admin-console-design.md` §2, plan Task 1.
> 대상: `packages/dp_design`(DpDataTable가 래핑) → `apps/admin`(Flutter Web, CanvasKit).

## 도입 패키지 (확정)

| 패키지 | 용도 | pubspec 제약 | 해결 버전(lock) | 라이선스 | CanvasKit/Web |
|---|---|---|---|---|---|
| `data_table_2` | 헤더/첫 열 고정 테이블, 최소 폭·가로 스크롤 | `^2.7.2` | **2.7.2** | BSD 3-Clause | ✅ (순수 Flutter 위젯, DataTable 확장) |

## 검증 절차 (로드맵 §3)

1. **최신 버전·API 확인** — **Context7에 Flutter `data_table_2` 미수록**(R `data.table`·React 계열만 매칭). 대신 `flutter pub add data_table_2`로 최신(2.7.2) 설치 후 **pub cache 소스(`data_table_2-2.7.2/lib/src/data_table_2.dart`)로 API 직접 검증**:
   - `DataTable2({... minWidth, headingRowColor(super), isHorizontalScrollBarVisible, empty, border, fixedLeftColumns=0, required columns, required rows ...})` — plan의 `DpDataTable` 래퍼 파라미터와 일치.
2. **Flutter Web(CanvasKit)·SDK 호환** — `DataTable2`는 SDK `DataTable`을 확장한 순수 위젯(외부 네이티브 의존 없음), 현 SDK로 해결 성공.
3. **라이선스** — BSD 3-Clause(pub cache LICENSE 원문 확인).
4. **`flutter pub add` + `melos run analyze`** — 해결 성공(1 dependency 추가). analyze 결과: **SUCCESS**(아래 갱신 시점 기준).
5. **확정 버전 기록** — 위 표.

## 비고

- Context7 미수록으로 **버전·API 확정을 pub cache 실측으로 대체**(추측 금지 준수). two_dimensional_scrollables는 초대형 전용이라 미도입(YAGNI, spec §1.3).
