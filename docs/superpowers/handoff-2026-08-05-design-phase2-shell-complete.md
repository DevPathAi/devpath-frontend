# 핸드오프 — ①디자인 2단계(셸 레이아웃) 완결, 3단계 이월 항목

> 작성 2026-08-05 · 브랜치 `feat/design-phase2-shell` → `develop` 머지
> 스펙 `docs/superpowers/specs/2026-08-03-design-shell-layout-design.md`
> 계획 `docs/superpowers/plans/2026-08-03-design-shell-layout.md` (12 Task)
> 직전 핸드오프 `handoff-2026-08-03-design-phase2-shell-task6-done.md`

## 1. 무엇이 끝났나

**계획 12 Task 전부 완료** (1~6은 2026-08-03, 7~12는 2026-08-05) + 최종 whole-branch 리뷰 + fix wave 2회 = **35커밋**.

화면마다 따로 만들던 `AppBar` 21곳이 「잉크 레일 + 크롬바 + 페이지 헤더」 3층 셸로 통일됐고, 1단계가 남긴 `rail*` 6종이 실제 화면에 배선됐다.

| Task | 내용 |
|---|---|
| 1~4 | `DpDestination` class 전환 · `DpNavRail` · `DpChromeBar` · `DpPageHeader` 신설 |
| 5~6 | `DpAppShell` 재구성 · web 셸 배선(경로→브레드크럼·계정 메뉴·검색) |
| 7~9 | web 12화면 헤더 이관(학습 5 · 커뮤니티 5 · 설정/마이페이지 2) |
| 10 | admin 셸 + 5화면(`AppBar.bottom` 필터 → `filters` 슬롯) |
| 11 | 셸 밖 4화면 최소 정합 + 공용 `brandRow` 신설 |
| 12 | 대비 검증 확장(`railFaint` 토큰 상향) + `DESIGN.md` §9 셸 구조 절 신설 |

**최종 상태(컨트롤러 직접 검증):** web 321 · admin 60 · dp_design 130 · mobile 100 · dp_core 97 전부 green, `melos run analyze` 이슈 0, `melos run format` clean, 대비 스크립트 미달 0건.

## 2. ★사람 몫으로 남은 것 — 아직 안 했다★

계획 §6 마무리 절차 중 **브라우저가 필요한 두 가지가 미수행**이다:

1. **목 모드로 web 빌드 후 네 폭(500·700·1000·1400) × 라이트·다크 육안 확인.** 접힘 상태의 섹션 구분선이 이번 개편의 유일한 새 분기다.
2. **전 라우트 재캡처해 1단계 캡처와 비교**(스펙 §14).

**특히 1번은 지금 반드시 필요하다** — 아래 §4의 사건에서 드러났듯 레일 브랜드 색이 위젯 테스트로도 오래 잡히지 않았다.

## 3. 3단계 이월 항목 (우선순위 순)

### 3.1 ★구조적 함정 — 최우선 검토★

**"앱이 `Theme.of(context).textTheme.*`를 Layer 2 슬롯에 넘기면, 그 슬롯이 `DefaultTextStyle.merge`로 공급하는 전경색이 항상 진다."**

`DpTheme`가 `textTheme.apply(bodyColor: c.textPrimary)`를 하므로 **모든 타이포 스케일이 non-null color를 이미 품고 있다**. 지금은 web·admin 브랜드 두 곳이 `copyWith(color: c.railText)`로 막고 있을 뿐, **새 슬롯(예: 레일 하단 상태 텍스트)이 생기면 같은 결함이 재발한다.**

해소 방향(3단계에서 결정): `DpNavRail`이 brand `Text` 스타일에 rail 전경색을 강제 적용하거나, `DpRailBrand` 같은 슬롯 전용 위젯을 제공.

### 3.2 I2 — `DpChromeBar` 우측 그룹 오버플로 (미해결, 명시 이월)

`packages/dp_design/lib/src/shell/dp_chrome_bar.dart` 우측(actions·account) 그룹이 non-flex 자식이라 폭 상한을 못 받는다. `RenderFlex`가 무한 주축 제약으로 측정 → `Spacer`/`Flexible`이 0이 되면 오버플로.

**국소 수정으로 해결되지 않는다:** `ConstrainedBox` 상한을 걸면 오버플로가 바깥 `Row`에서 안쪽 `Row`로 **이동**할 뿐이다(자식이 `Row(min)`이고 바 높이 46 고정이라 `DpPageHeader`의 `Wrap`처럼 줄바꿈으로 흡수하지 못한다). 실제로 fix wave에서 시도했다가 오버플로 임계를 `W < G+16` → `W < 2G`로 **넓혀** 원복했다.

**crumbs flex 가중치·그룹 축약(overflow 메뉴) 설계와 함께 다뤄라.** 현재 도달 불가(web 액션 1개·admin 0개)이나 스펙 §3.0이 `trailing`의 행선지로 지정한 슬롯이라 늘어날 자리다. **actions 그룹을 포함한 오버플로 테스트가 지금 어느 폭에도 없으니 red-repro를 새로 세울 것.**

같은 뿌리 3곳을 한 Task로 묶어라: I2(크롬바 우측) · `brandRow`의 `Text('DevPath')`(`Spacer`와 같은 Row의 non-flex 자식) · admin 필터 `Row`(`'상태:'` + `ChoiceChip` 5개, compact에서 오버플로).

### 3.3 I1 잔여 — compact에서 하단 `NavigationBar`는 여전히 오표시

`DpAppShell`의 compact 분기가 `selectedIndex ?? 0`으로 클램프한다(`NavigationBar.selectedIndex`가 non-null `int`라 불가피). 비-compact 레일은 무강조로 고쳐졌지만, **compact에서 `/settings`·`/mypage`·`/content/:id`·`/sandbox`는 여전히 「대시보드」를 강조한다.**

### 3.4 문서·주석 정확성

- `dp_chrome_bar_test.dart`의 우측 정렬 테스트 주석이 "group을 flex 참여자로 바꾸면서"라 하나 원복으로 더는 flex 참여자가 아니다(테스트 자체는 유효). I2 작업 시 함께 교정.
- `app_shell.dart`·`admin_shell.dart`의 새 주석이 인용한 `dp_nav_rail.dart:91`이 실제로는 `:75-82`(정의)·`:94`(brand 적용). 사실관계는 옳고 줄번호만 어긋난다.
- `admin_shell.dart`의 `_headerTitleFor`가 "단일 출처"라 주장하나 실제로는 **private**이고 admin 5화면이 각자 문자열 리터럴을 박는다 — 출처가 둘이라 한쪽만 고치면 브레드크럼과 헤더가 조용히 어긋난다. 경로 리터럴도 `kAdminDestinations`와 이중 관리된다.

### 3.5 커버리지 공백

- **다크 테마 렌더 테스트가 거의 없다.** 색 결정이 라이트에서만 위젯 레벨로 검증되고 다크는 대비 스크립트의 수치 단언에만 의존한다. `DpNavRail`·`DpChromeBar` 각 1건 권장.
- **다크 팔레트에서 `textPrimary == railText`인 우연 일치** 때문에 브랜드 실효색 테스트의 다크 분기가 현재 무력하다. 다크 팔레트 재조정 시 이 가드를 함께 점검할 것.
- `path_title_test.dart`가 `PathPage`가 아니라 테스트가 직접 조립한 `Column`을 렌더한다 — `PathPage`의 헤더 배선은 여전히 무커버.
- `sandbox_page.dart`의 헤더 `title`/`description` 미커버(actions만 간접 커버). 스펙 §5가 지정한 유일한 제목 변경(`Sandbox`→`실습 샌드박스`)이 회귀 고정 없이 남아 있다.

### 3.6 시각·카피 정리

- **헤더 스크롤 거동 불일치:** 커뮤니티 홈만 `SliverToBoxAdapter`라 스크롤과 함께 사라지고 나머지는 고정. 고정 헤더가 `AppBar`(56px)의 약 2배 세로를 점유해 낮은 뷰포트의 작성 화면에서 본문 가용 높이가 줄어든다.
- **`filters` 배치 불일치:** admin `reports`·`support`는 헤더 아래 별도 `Padding`에 남아 `users`·`ads`보다 헤더–필터 간격이 두 배다.
- **안내 문구 중복:** 커뮤니티 작성 2화면에서 헤더 설명과 본문 안내가 사실상 같은 말을 한다(계획이 헤더 문구를 지정하면서 본문 수정을 금지해 생긴 결과).
- `beta_pending_page.dart`에 원시 숫자 여백(`SizedBox(height: 16)`·`24`)이 `DpSpacing`과 혼재.
- `tag*`·`chart*` 토큰은 여전히 미배선(3단계 예정대로).

## 4. ★이 브랜치에서 배운 것 — 다음 계획에 반드시 반영★

### 4.1 계획이 제시하는 위젯 코드도 리뷰 대상이다

계획 자체의 결함이 **셋** 확인됐다:
1. 계획 코드가 **non-flex 함정을 세 번 반복**했다(Task 2·3·4 — `Row`/`Column`의 non-flex 자식은 무한 주축 제약으로 측정되어 `ellipsis`가 발동하지 않는다).
2. Task 7의 `path_title_test` 갱신 지시가 **동어반복 테스트**를 만들었다(본문을 빈 `SizedBox`로 바꾸라 해서 검증 대상 텍스트를 만들 위젯이 하나뿐이 됨 → `findsOneWidget`이 구조적으로 항상 참).
3. Task 8의 헤더 문구 지정 + "본문 수정 금지" 제약이 **문구 중복을 강제**했다.

**다음 계획 작성 시 `Row`/`Column` 예시 코드는 flex 소속을 명시하라.** 또 계획 코드가 그대로 실패하는 전제(테스트에 `theme: DpTheme.light()` 미공급 → `context.dpColors` null-check 크래시, 단일 `pump`의 pending timer)가 Task 7·8·9에서 **세 번 반복**됐다.

### 4.2 ★규칙을 문맥 없이 일반화하면 회귀가 된다★ (이번 세션 최대 사건)

"**앱 코드에서 색을 박지 마라 — 컴포넌트가 배경별 전경색을 공급한다**"는 계약이 Task 5·6에서 세워졌다. 그런데 이 계약은 **무스타일 `Text`일 때만 성립한다.**

- `DpTheme`가 `textTheme.apply(bodyColor: c.textPrimary)`를 하므로 `titleSmall`은 이미 non-null color를 갖는다.
- `Text`는 `style.inherit == true`일 때 `DefaultTextStyle.style.merge(style)`이고, merge는 `style`의 non-null을 취한다 → **컴포넌트가 공급한 `railText`가 진다.**
- 라이트 `textPrimary`(`#1A1815`) == `railBg`(`#1A1815`) → **대비 1.00:1, 브랜드 완전 비가시.**

이 사실을 모른 채:
- Task 10 fix에서 컨트롤러가 admin에 "`titleSmall`, `color` 없이"를 지시 → admin 브랜드가 라이트에서 사라진 채 머지될 뻔했다.
- 최종 whole-branch 리뷰가 web의 **올바른 코드**(`copyWith(color: c.railText)`)를 M1 결함으로 판정했고, 컨트롤러가 그 지시를 그대로 전달 → **fix wave가 Critical 회귀를 새로 넣었다.**
- **어떤 테스트도 이 색을 단언하지 않아 319/319 green으로 조용히 통과했다.**

2차 fix에서 원복하고 **실효 색 단언 테스트**(`DefaultTextStyle.of(context).style.merge(widget.style)`로 Flutter의 `effectiveTextStyle`을 재현)를 web·admin 양쪽에 넣어 고정했다.

**교훈: 규칙을 적용할 때 그 규칙이 성립하는 전제를 확인하라. 그리고 "값이 같아 지금은 무해한" 것과 "구조가 옳은" 것을 구별하라.**

### 4.3 배선을 검증하지 않으면 뒤바꿔도 통과한다 — 이 브랜치에서 여섯 번

Task 3·5·8·10 + 최종 리뷰 I3 + 위 4.2. **화면·슬롯을 배선할 때마다 "이걸 지우거나 뒤바꾸면 실제로 red가 되는가"를 물어라.** 단언은 `find.text()`가 아니라 `tester.widget<T>(...)`로 위젯 필드를 읽어야 한다(브레드크럼 마지막 세그먼트·헤더 제목·레일 라벨이 **의도적으로 같은 문자열**이라 셸 포함 렌더 시 `findsOneWidget`이 깨진다).

### 4.4 영향 분석을 타입 grep으로만 하지 마라

Task 5에서 `NavigationRail` 참조만 세다가 `support_entrypoints_test`를 놓쳐 **④오류 신고·문의의 진입점이 위젯 트리에서 통째로 사라질 뻔했다**(5개 레포에 걸쳐 최근 완성한 기능이다). 구현자가 발견해 멈췄고, 테스트 완화가 아니라 크롬바를 살리는 쪽으로 해결했다.

### 4.5 운영

- **서브에이전트의 최종 메시지가 자주 비어서 온다.** 리포트를 파일로도 쓰게 지시하면 해결된다 — 모든 dispatch에 출력 파일 경로를 넣어라.
- 컨트롤러가 매 Task `git log --oneline <base>..HEAD` + `melos run test`를 **직접** 재확인했다. 구현자·리뷰어 보고를 그대로 믿지 않는다. **이번 세션에서 리뷰어가 컨트롤러의 오류(라이트/다크 라벨 뒤바뀜)를 독립 재계산으로 교정한 사례도 있다.**
- `melos`가 PATH에 없다 → `dart pub global run melos run <cmd>`.
- **`python`은 이 환경에서 스크립트를 실행하지 않는다**(스토어 스텁, 조용히 무동작). 대비 스크립트는 `py`로 실행하라.
- Bash 도구의 cwd가 호출 사이 유지되지 않는 경우가 있다 — 절대경로 또는 `cd <repo> &&`를 붙여라.

## 5. 다음 단계

**①전반 디자인 3단계**(`tag*`·`chart*` 배선 + 위 §3 이월 항목). 3단계 스펙의 「선행 수정」 절에 §3.1·§3.2·§3.3을 **명시적으로** 적어라 — 암묵적 이월은 같은 함정을 네 번째로 밟게 한다.
