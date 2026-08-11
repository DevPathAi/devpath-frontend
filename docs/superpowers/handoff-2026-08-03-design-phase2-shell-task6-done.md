# 핸드오프 — ①디자인 2단계(셸 레이아웃) Task 1~6 완료, Task 7~12 이관

> 작성 2026-08-03 · 브랜치 `feat/design-phase2-shell`(base `develop`, 미푸시·미PR)
> 스펙 `docs/superpowers/specs/2026-08-03-design-shell-layout-design.md`
> 계획 `docs/superpowers/plans/2026-08-03-design-shell-layout.md` (12 Task)
> 실행 기록 `.superpowers/sdd/2026-08-03-design-shell-layout/progress.md` (**git-ignored — 이 문서가 요약본이다**)

## 1. 지금 어디까지 왔나

**Task 1~6 완료. Task 7~12 미착수.** 12커밋 + 문서 3커밋, 21파일 4058줄 추가.

| Task | 내용 | 커밋 | 리뷰 |
|---|---|---|---|
| 1 | `DpDestination` record→class(`section` 옵셔널) + `DpIcons.account` | `9d8c0d9` | clean |
| 2 | `DpNavRail` — 잉크 레일·섹션 그룹·계정 블록 | `22ed408`→`a1e6928` | fix 1R |
| 3 | `DpChromeBar` — 브레드크럼·가짜 검색·전역 액션 | `b275216`→`a8176ec` | fix 1R |
| 4 | `DpPageHeader` — 제목·설명·액션·필터 | `fac76dd`→`bdeacd3`→`bd445a6` | fix 2R |
| 5 | `DpAppShell` 재구성 + web·admin 셸 슬롯 이관 | `4cfe9c7`→`4ccbe90`→`0b97c4f` | fix 1R |
| 6 | web 셸 배선(`breadcrumbFor`·계정 메뉴·검색) | `d70852f`→`fc1ba38` | fix 1R |

**전 패키지 green**(컨트롤러가 직접 확인): admin 50 · dp_design 127 · mobile 100 · **web 310** · dp_core 97. `melos run analyze` 5패키지 이슈 0, `melos run format` 0 changed.

> ⚠️ **Task 6 fix(`fc1ba38`)는 스코프 재리뷰를 거치지 않았다.** 세션 종료 시점과 겹쳐, 컨트롤러가 직접 검증하는 것으로 대신했다 — diff 육안 확인(정확히 `color:` 인자 제거), 요구한 테스트 2건 존재 확인, 셸 테스트 15/15, 전 패키지 green, analyze 0, format clean. 수정이 한 줄 삭제이고 리뷰어가 지목한 지점과 정확히 일치하지만, **정식 재리뷰는 생략됐다.** 최종 whole-branch 리뷰(§6)에서 이 커밋을 반드시 포함해 검토하라.

## 2. 남은 일 (Task 7~12)

계획 문서에 각 Task의 코드·테스트·화면별 문구가 **전부 명시돼 있다.** 브리프는 `scripts/task-brief <plan> <N>`으로 추출한다.

| Task | 내용 | 규모 |
|---|---|---|
| 7 | web 학습 5화면 헤더 이관(dashboard·path·content·sandbox·mentor) | 중 |
| 8 | web 커뮤니티 5화면(홈은 sliver 헤더, FAB·`PinnedHeaderSliver` 유지) | 중 |
| 9 | web 설정·마이페이지(마이페이지 설정 버튼 삭제) | 소 |
| 10 | admin 셸 + 5화면(`AppBar.bottom` 필터 → `filters` 슬롯) | 중 |
| 11 | 셸 밖 4화면 최소 정합(공용 `brandRow` 신설) | 중 |
| 12 | 대비 스크립트에 레일 5조합 추가 + `DESIGN.md` 갱신 | 소 |

**Task 7 브리프는 이미 생성돼 있다**(`.superpowers/sdd/.../task-7-brief.md`). 워크스페이스가 지워졌으면 재생성하면 된다.

## 3. ★다음 세션이 반드시 알아야 할 것★

### 3.1 계획에 빠진 것 — Task 7에서 처리해야 함

**스펙 §10이 `accentSoft`/`accentLine`을 "헤더 보조 액션 버튼"에 배선한다고 했으나, 계획 Task 4~11 어디에도 명세가 없다.** Task 7에서 `content_page.dart`의 「실습」 버튼을 `accentSoft` 배경 + `accentLine` 보더 + `primaryText` 텍스트로 만들도록 지시하라. 그러지 않으면 이 두 토큰이 3단계까지 소비처 0으로 남는다.

### 3.2 이 브랜치에서 다섯 번 반복된 결함

**`Row`/`Column`의 non-flex 자식은 무한 주축 제약으로 측정된다.** 그래서 `TextOverflow.ellipsis`가 영영 발동하지 않고 `Wrap`이 줄바꿈하지 않은 채 오버플로한다. `DpNavRail`·`DpChromeBar`·`DpPageHeader` 전부 이 결함으로 fix 라운드를 돌았다 — **계획에 쓰인 코드가 세 번 다 같은 실수를 했다.**

**역함정도 있다**: `DpPageHeader`에서 이를 고치려 `Flexible`을 씌웠더니 형제 `Expanded`와 공간을 50/50으로 나눠 **우측 정렬이 깨졌다**(액션 버튼이 헤더 한가운데로 밀렸다). 최종 해법은 `LayoutBuilder` + `ConstrainedBox(maxWidth: 가용폭/2)`로 **flex 자식을 늘리지 않으면서 상한만 주는 것**이었다.

Task 7~11은 화면에 `DpPageHeader`를 꽂는 작업이라 이 함정이 다시 나온다. 브리프에 미리 못박아라.

### 3.3 다크 레일 위 전경색 — 두 번 발생한 결함

**라이트 테마의 `textPrimary`와 `railBg`가 둘 다 `#1A1815`다.** 비트 단위로 같다. 그래서 스타일 없는 텍스트를 레일에 놓으면 **대비 1:1로 완전히 사라진다.** admin 브랜드 「운영 콘솔」이 실제로 이 상태로 커밋됐다가 리뷰에서 잡혔다.

해결은 `DpNavRail`·`DpChromeBar`가 슬롯에 배경별 전경색을 공급하는 것이다(`IconTheme.merge` + `DefaultTextStyle.merge`, 레일=`railText`/`railMuted`, 크롬바=`textSecondary`). **앱 코드에서 색을 박으면 안 된다** — `account`는 폭에 따라 다크 레일과 밝은 크롬바를 오가는 **같은 위젯 인스턴스**라, 한 색으로 고정하면 반드시 한쪽에서 실패한다. Task 6이 경고를 받고도 `Icon(color: c.railMuted)`를 박아 compact에서 2.53:1이 됐다(§4).

`DefaultTextStyle`은 반드시 **`.merge`** 를 써라. 통째로 갈아치우면 크기·행간이 사라져 새 타입 스케일을 만드는 셈이 된다.

### 3.4 테스트가 색 배선을 검증하지 않으면 토큰을 뒤바꿔도 통과한다

세 위젯 연속으로 이 결함이 나왔다. `DpChromeBar`는 색 토큰 5종에 단언이 **0건**이라 `textFaint`와 `textSecondary`를 서로 바꿔 써도 컴파일·analyze·전 테스트가 통과했다(= WCAG 위반이 조용히 부활). **Task 7~11 브리프에 "토큰 뒤바뀜 방지 단언"을 미리 요구하라.**

### 3.5 접근성이 반복 취약점

- 접힘 레일 항목에 툴팁·`Semantics` 부재(Material `NavigationRail`이 주던 기능의 회귀)
- 탭 타깃 36px·24px·28px — `DESIGN.md` §6은 **≥44×44**
- **내 판단 오류**: "44px를 강제하면 46px 크롬바가 깨진다"고 구현자에게 잘못된 전제를 줬다. 44 < 46이라 그냥 들어간다. 바의 패딩이 수평뿐이라 세로가 통째로 비어 있었다.

### 3.6 제목이 화면에 세 번 나온다

브레드크럼 마지막 세그먼트 · 페이지 헤더 제목 · 레일 목적지 라벨이 같은 문자열이 된다(의도된 설계, 크기·역할이 다름). **셸을 포함해 렌더하는 테스트는 `find.text()`가 `findsOneWidget`에서 깨진다** — 위젯 타입이나 `Key`로 특정하라. 스펙 §7.1에 적어뒀다.

### 3.7 영향 분석을 타입 grep으로만 하지 말 것

Task 5에서 `DpAppShell`의 슬롯 이름을 바꿀 때, 내가 준 영향 범위는 `NavigationRail` 참조 grep 결과(web 5·admin 3)뿐이었다. 그 그물에 **`support_entrypoints_test`가 걸리지 않았다** — 이 테스트는 오류 신고 버튼의 *존재*를 단언하는데, 그 버튼이 `chromeActions`로 옮겨진 뒤 크롬바가 `breadcrumb` 없이 렌더되지 않아 **위젯 트리에서 통째로 사라졌다.** ④오류 신고·문의는 5개 레포에 걸쳐 최근 완성한 기능이고 그 진입점이 셸 상단바다.

구현자가 이를 발견하고 "테스트를 known-red로 두거나 단언을 완화하자"는 두 안을 제시했는데, **둘 다 소실을 덮는 쪽이라** 크롬바 자체를 살리는 쪽으로 지시했다(임시 브레드크럼 주입 → Task 6이 정식 매핑으로 교체).

## 4. Task 6 fix — 무엇이었나 (`fc1ba38`, 완료)

리뷰가 Critical 1건을 냈다.

`apps/web/lib/src/features/shell/presentation/app_shell.dart`의 `_AccountMenu`:
```dart
icon: Icon(DpIcons.account, color: c.railMuted),   // ← 이 color를 제거
```
`Icon.color` 명시는 컴포넌트가 공급하는 `IconTheme`을 항상 이긴다. compact(<600) 폭에서 이 아이콘은 밝은 `surface`(`#FFFFFF`) 위에 놓이는데 `#A9A298`은 **대비 2.53:1**로 WCAG 1.4.11(비텍스트 3:1) 미달이다. 색을 지우면 레일에서 `railMuted`, 크롬바에서 `textSecondary`(6.6:1)를 자동 상속한다.

함께 지시한 것: compact/비-compact 양쪽에서 계정 아이콘의 **실효 색**을 단언하는 테스트(이 조합에 테스트가 하나도 없어 결함이 통과했다). `final c = context.dpColors;`가 미사용이 되어 함께 삭제됐다(analyze가 info도 비-제로 종료).

적용된 결과 — `_AccountMenu`의 아이콘이 `const Icon(DpIcons.account)`가 되어 슬롯이 공급하는 색을 상속한다. 신규 테스트 2건: 「compact 폭: 계정 아이콘은 색을 상속하고 크롬바의 textSecondary가 된다」·「비-compact 폭: … 레일의 railMuted가 된다」.

## 5. 실행 방식

`superpowers:subagent-driven-development`로 진행 중이다. Task마다 구현자 dispatch → 컨트롤러가 커밋 범위·테스트 직접 검증 → 리뷰어 dispatch → fix 라운드 → 스코프 재리뷰.

**이 환경 특이사항:**
- 서브에이전트의 **최종 메시지가 비어서 오는 일이 잦다**("(no action needed)"·"Standing by." 등). 작업 자체는 정상 수행된다. **리포트를 파일로도 쓰게 지시하면 해결된다** — 모든 리뷰어 프롬프트에 출력 파일 경로를 넣어라.
- 컨트롤러는 매 Task마다 `git log --oneline <base>..HEAD`로 커밋 범위를, `melos run test`로 green을 **직접** 재확인했다. 구현자 보고를 그대로 믿지 않는다.
- `melos`가 PATH에 없다 → `dart pub global run melos run <cmd>`.
- Bash 도구의 cwd가 호출 사이 유지되지 않는 경우가 있다. 스크립트 실행 시 `cd /d/workspace/dpa/devpath-frontend &&`를 붙여라.
- **구현자가 두 번 범위를 넘지 않고 멈춰 판단을 요청한 덕에** 컴파일 파손과 기능 소실이 조용히 머지되지 않았다. 스코프 락 지시문을 계속 넣어라.

## 6. 마무리 절차 (Task 12 이후)

1. 최종 whole-branch 리뷰(가장 유능한 모델) — ledger의 deferred minor 목록을 triage 대상으로 넘겨라
2. 목 모드로 web 빌드 후 **네 폭(500·700·1000·1400) × 라이트·다크** 육안 확인. 접힘 상태의 섹션 구분선이 이번 개편의 유일한 새 분기다
3. 전 라우트 재캡처해 1단계 캡처와 비교(스펙 §14)
4. `develop`으로 PR

## 7. 이월된 Minor (최종 리뷰에서 triage)

- `DpDestination`에 `==`/`hashCode` 없음(record의 value equality → class의 identity equality). 현재 `==` 비교 소비처 없음
- `DpNavRail` 펼침 상태에서 `Semantics(label:)` 래퍼와 내부 `Text(label)`이 둘 다 시맨틱스에 기여 → 스크린리더 이중 포커스 가능
- 브레드크럼 세그먼트 균등 `Flexible(flex:1)` — 긴 마지막 세그먼트가 1/3로 제한될 수 있음(현재 스펙상 전부 3~5자 정적 라벨이라 도달 불가)
- 자식의 명시적 색이 ambient 기본값을 이기는지 미검증(`.merge` 의미상 정상)
- 다크 테마 슬롯 렌더 위젯 테스트 없음(리뷰어가 수동 대비 계산으로만 확인)
- `breadcrumbFor` 문서 주석이 "알 수 없는 경로면 크롬바 미렌더"라 하나, `showChromeBar`가 `chromeActions.isNotEmpty`도 OR하므로 실제로는 렌더된다
- `description: ''`(빈 문자열)이면 `DpPageHeader`가 빈 `Text`와 간격을 렌더(null 체크만 있음)
