# ①전반 디자인 3-A 설계 — 셸 결함 해소 + `tag*` 배선

> 작성 2026-08-06 · 브랜치 `feat/design-phase3a-shell-fixes` → `develop`
> 선행 핸드오프 `docs/superpowers/handoff-2026-08-05-design-phase2-shell-complete.md`
> 선행 스펙 `specs/2026-08-03-design-shell-layout-design.md`(2단계) · `specs/2026-08-03-design-token-overhaul-design.md`(1단계)
> 후속 `3-B`(차트 다중 시리즈, 별도 스펙 — §9)

## 1. 배경과 범위

2단계(셸 레이아웃, PR #106)가 `AppBar` 21곳을 「잉크 레일 + 크롬바 + 페이지 헤더」 3층 셸로 통일하면서 이월 항목을 남겼다. 이 스펙은 그 이월분과 육안 확인이 새로 올린 항목을 해소하고, 1단계가 정의했으나 배선되지 않은 `tagBg`/`tagText` 토큰을 실제 화면에 연결한다.

**범위: `devpath-frontend` 단일 레포. 백엔드 계약 변경 없음.** 차트 팔레트(`chart1~5`)와 다중 시리즈는 백엔드 집계 확장이 필요해 3-B로 분리했다(§9).

### 1.1 이 스펙이 교정하는 선행 문서의 오류

착수 전 실측에서 핸드오프의 사실관계 두 건이 틀렸음을 확인했다. **아래를 근거로 삼아라.**

| 선행 문서의 서술 | 실측 결과 |
|---|---|
| 핸드오프 §3.5 「`tag*`·`chart*` 미배선」 | `chart4`는 이미 3곳 배선(`community_home_page.dart:257`·`:343`, `admin/reports_page.dart:113`). 미배선은 `chart1·2·3·5`와 `tagBg`·`tagText` |
| 핸드오프 §3.2 「admin 필터 `Row`(`'상태:'` + `ChoiceChip` 5개)」 | 그 구조는 `users_page.dart:70`·`ads_page.dart:53`에 있다. `reports`·`support`는 `SegmentedButton`이며 헤더 **밖** 별도 `Padding`에 있다(§6.2) |

`chart1`에 대해서도 3-B 착수 전 알아야 할 실측이 있다 — §9.1.

## 2. 목표와 비목표

**목표**

1. 새 슬롯이 생겨도 재발하지 않도록 브랜드 전경색 함정을 **구조적으로** 닫는다
2. 셸이 좁은 폭·다크·접힘 상태에서 정보를 잃지 않게 한다
3. `tagBg`·`tagText`를 단일 지점에서 배선한다
4. 위젯 테스트가 green인 상태에서도 남는 시각 결함을 육안 확인으로 잡는다

**비목표**

- 차트 색·다중 시리즈(3-B)
- 백엔드 계약·DTO 변경
- 새 화면·새 기능 추가
- 2단계 셸 구조(3층) 자체의 재설계

## 3. 브랜드 슬롯 — `DpRailBrand` 신설

### 3.1 문제

`DpTheme`가 `textTheme.apply(bodyColor: c.textPrimary)`를 하므로 **모든 타이포 스케일이 non-null color를 품는다.** `Text`는 `style.inherit == true`일 때 `DefaultTextStyle.style.merge(style)`이고 merge는 `style`의 non-null을 취하므로, `DpNavRail._withRailForeground`(`dp_nav_rail.dart:75-82`)가 공급하는 `railText`는 앱이 `titleSmall`을 넘기는 순간 진다. 라이트 팔레트는 `textPrimary`(`#1A1815`) == `railBg`(`#1A1815`)라 **대비 1.00:1, 브랜드 완전 비가시**가 된다.

지금은 web·admin 두 호출부가 `copyWith(color: c.railText)`로 막고 있을 뿐이다. 슬롯이 하나 늘면 같은 결함이 재발한다.

부수 결함: `DpNavRail._buildTop`이 `if (extended && brand != null)`(`dp_nav_rail.dart:93`)이라 **접힘 상태에서 브랜드가 통째로 사라진다.** 로고 마크까지 숨는다.

### 3.2 설계

`brand`를 **Widget 슬롯이 아니라 데이터**로 받는다. 앱이 색을 넘길 통로 자체를 없앤다.

```dart
/// 레일 브랜드 **데이터**. 위젯이 아니다 — 앱이 TextStyle을 넘길 통로를
/// 두지 않는 것이 이 타입의 존재 이유다. 색·타이포는 DpNavRail이 정한다.
class DpRailBrand {
  const DpRailBrand({required this.mark, required this.wordmark});

  /// 접힘 상태에서도 남는 로고 마크(아이콘·이미지).
  final Widget mark;
  /// 펼침 상태에서만 보이는 워드마크 문자열. **String이다** — 앱이 Text를
  /// 만들 수 없으므로 스타일을 실을 수 없다.
  final String wordmark;
}
```

- `DpNavRail.brand`의 타입을 `Widget?` → `DpRailBrand?`로 좁힌다
- `DpNavRail._buildTop`의 조건에서 `extended &&`를 제거한다 — 접힘에서도 `mark`는 남는다
- **`DpNavRail`이 `brand.mark`·`brand.wordmark`를 읽어 직접 렌더한다.** `DpRailBrand`를 위젯으로 만들면 `extended`를 전달할 경로가 필요해지고, 그 경로가 다시 앱이 스타일을 실을 틈이 된다 — 데이터로 두는 이유가 여기 있다
- 워드마크 스타일 = `titleSmall.copyWith(color: c.railText)`를 **컴포넌트 안에서** 적용

### 3.3 호출부

- `apps/web/.../shell/app_shell.dart` · `apps/admin/.../shell/admin_shell.dart` 두 곳의 brand 조립을 `DpRailBrand(mark: …, wordmark: 'DevPath')`로 교체
- `apps/web/.../common/presentation/brand_row.dart`의 `brandRow`는 **셸 밖 4화면(login·beta-pending·consent·diagnostic) 전용**이라 그대로 둔다. 다만 §6.4의 non-flex `Text` 오버플로는 여기서 고친다

### 3.4 회귀 고정

2단계에서 이 색이 **319/319 green인 채로 Critical 회귀를 통과**시켰다. 실효색 단언을 유지·확장한다:

- `DefaultTextStyle.of(context).style.merge(widget.style)`로 Flutter의 `effectiveTextStyle`을 재현해 워드마크 실효색이 `railText`임을 단언 — 라이트·다크 각 1건
- **다크 팔레트에서 `textPrimary == railText`인 우연 일치** 때문에 다크 분기 가드가 현재 무력하다. §5의 `railBg` 재조정과 함께 이 일치가 유지되는지 확인하고, 유지된다면 테스트 주석에 그 사실과 무력함을 명시한다(숨기지 않는다)
- `extended: false`에서 `mark`는 찾히고 `wordmark` 문자열은 찾히지 않음을 단언

## 4. 크롬바 — 그룹 축약과 오버플로 (I2)

### 4.1 문제

`DpChromeBar`(`dp_chrome_bar.dart:96-111`)의 우측 그룹(actions·account)은 non-flex 자식이라 `RenderFlex`가 무한 주축 제약으로 먼저 측정한다. actions가 늘면 오버플로한다. 2단계 fix wave에서 `ConstrainedBox` 상한을 시도했다가 **오버플로가 바깥 `Row`에서 안쪽 `Row`로 이동할 뿐**이라 원복했다(임계가 `W < G+16` → `W < 2G`로 오히려 넓어졌다). 바 높이가 46 고정이고 자식이 `Row(min)`이라 `DpPageHeader`의 `Wrap` 방식으로는 흡수되지 않는다.

### 4.2 설계

**우측 그룹에 폭 상한을 주되, 상한을 넘으면 줄바꿈이 아니라 `MenuAnchor`로 접는다.**

- `actions`가 자연폭으로 상한을 넘으면 앞에서부터 들어갈 수 있는 만큼만 바에 남기고, 나머지를 오버플로 메뉴(⋯ 버튼) 항목으로 옮긴다
- `account`는 **항상 바에 남긴다**(계정 진입점이 메뉴 뒤로 숨으면 접근성이 나빠진다)
- crumbs 쪽 `Expanded`는 유지한다 — 2단계의 우측 정렬 수정(`Spacer` → `Expanded`)을 되돌리지 않는다
- 오버플로 판정에는 `LayoutBuilder`로 받은 최대폭을 쓴다

`actions`를 `List<Widget>`로 두면 메뉴 항목으로 옮길 때 라벨을 알 수 없다. **`DpChromeAction({required Widget icon, required String label, required VoidCallback onPressed})` 데이터형을 신설**하고 `actions`의 타입을 `List<DpChromeAction>`으로 바꾼다. 바에 남을 때는 `IconButton`, 메뉴로 갈 때는 `MenuItemButton(child: Text(label))`로 렌더한다.

### 4.3 red-repro를 어떻게 세우는가 — ★2단계 교훈 반영★

2단계에서 우측 정렬 테스트가 **60자짜리 인위적 crumbs를 써야만 통과**했고, 그 조건을 피해 간 탓에 실제 앱 조건의 결함을 놓쳤다. 같은 함정을 다시 밟지 않기 위해 이 기능의 테스트 조건을 명시한다.

- **정당한 조건**: `DpChromeBar`에 actions를 N개 주입하는 것. 이 컴포넌트의 공개 API가 임의 개수를 받으므로, 다수 actions는 **컴포넌트 계약 그 자체**이지 결함을 피해 가려고 조작한 값이 아니다
- **금지**: 특정 폭에서만 통과하도록 crumbs 길이나 라벨 길이를 조정하는 것
- 단언은 `find.text()`가 아니라 `tester.widget<T>(…)`로 위젯 필드를 읽는다(2단계 §4.3 — 브레드크럼·헤더·레일 라벨이 의도적으로 같은 문자열이라 `findsOneWidget`이 깨진다)
- 오버플로 없음(`tester.takeException()`이 null)을 여러 폭(500·700·1000·1400)에서 단언한다

### 4.4 현재 도달 가능성 (정직한 기록)

현재 앱에서 actions는 web 1개(오류 신고)·admin 0개라 **실제 화면에서는 어느 폭에서도 오버플로하지 않는다.** 이 작업은 스펙 §3.0이 `trailing`의 행선지로 지정한 슬롯을 미리 견고하게 만드는 것이다. 코드 주석에 「현재 조건 미도달」을 명시해, 다음 세션이 이 코드를 「실제 결함을 고친 것」으로 오해하지 않게 한다.

## 5. 다크 레일 배경 재조정

### 5.1 문제

다크 팔레트에서 `railBg`(`#131210`)가 본문 `bg`(`#0F0E0C`)보다 오히려 **밝다.** 「잉크 레일」의 요점은 레일을 어두운 잉크 면으로 분리하는 것인데, 다크에서는 경계선으로만 구분돼 정체성이 사라진다.

### 5.2 설계

- 다크 `railBg`를 본문보다 확실히 어두운 값으로 내린다(구체값은 구현 시 대비 계산으로 확정)
- `railText`·`railMuted`·`railFaint`·`railActive`·`railBorder`의 대비를 **대비 검증 스크립트로 재계산**한다(`specs/2026-08-03-token-contrast-check.py`, `py`로 실행 — `python`은 이 환경에서 스텁이다)
- **미달 0건**을 유지한다. 미달이 생기면 전경색도 함께 올린다
- 라이트 `railBg`는 건드리지 않는다(라이트에서는 이미 잉크 면으로 동작한다)

### 5.3 부수 확인

§3.4의 다크 가드 무력화(`textPrimary == railText` 우연 일치)가 이 변경으로 해소되는지 확인한다. 해소되지 않으면 그대로 두되 테스트 주석에 남긴다.

## 6. 화면 조정

### 6.1 페이지 헤더 스크롤 거동 — 화면 유형별 규칙

현재 커뮤니티 홈만 `SliverToBoxAdapter`(`community_home_page.dart:131`)라 스크롤과 함께 사라지고 나머지는 고정이다. 고정 헤더는 `AppBar`(56px)의 약 2배 세로를 점유한다.

**실측 결과 「전부 스크롤」은 성립하지 않는다.** 화면이 두 부류로 갈린다:

| 유형 | 화면 | 처리 |
|---|---|---|
| **문서형** — 본문이 스크롤 축을 가짐 | web `dashboard`·`path`·`content`·`mypage`·`settings`, 커뮤니티 `home`(완료)·`post_detail`·`qna_detail`·`post_create`·`question_create`, admin `dashboard`·`reports` | `CustomScrollView` + `SliverToBoxAdapter`로 헤더를 스크롤에 실는다 |
| **뷰포트 고정형** — 본문이 남은 높이를 꽉 채움 | web `mentor`(채팅 리스트 + 하단 입력창, Phase 5 하단추종 `ScrollController`)·`sandbox`(탭 + Monaco 에디터), admin `users`·`ads`·`support`(`DpDataTable` = data_table_2 자체 뷰포트) | **헤더 고정 유지** |

뷰포트 고정형에서 헤더를 `SliverFillRemaining`으로 감싸면 남은 높이를 전부 차지해 **바깥 스크롤 여지가 0이 되므로 헤더는 결국 고정이다.** 코드만 복잡해지고 결과가 같으므로 하지 않는다.

**규칙을 `DESIGN.md` §9(셸 구조)에 절로 추가한다:** 「본문이 스크롤 축을 가지면 페이지 헤더도 함께 스크롤한다. 본문이 뷰포트를 꽉 채우면 헤더는 고정한다.」 일관성의 기준은 **모든 화면 동일**이 아니라 **화면 유형별 동일**이다.

### 6.2 필터 배치 통일

| 화면 | 현재 | 처리 |
|---|---|---|
| `users_page.dart:70` · `ads_page.dart:53` | 헤더 `filters` 슬롯, `Row(['상태:'/'슬롯:', ChoiceChip × N])` | 슬롯 유지. `Row` → 줄바꿈 가능한 형태로 (아래) |
| `reports_page.dart:39-58` · `support_page.dart:~40` | 헤더 **밖** 별도 `Padding` + `Align` + `SegmentedButton` | 헤더 `filters` 슬롯으로 이동 |

`DpPageHeader`의 `filters` 슬롯(`dp_page_header.dart:92-98`)이 자식을 그대로 놓기 때문에 `Row`가 compact에서 오버플로한다. **슬롯이 자식을 `Wrap`으로 감싸도록** 바꾸면 4화면이 한 번에 해소된다. 라벨(`'상태:'`)과 칩들을 `Wrap`의 형제로 두어야 줄바꿈이 실제로 일어난다.

`ChoiceChip`과 `SegmentedButton` 두 패턴의 공존은 이번 범위에서 통일하지 않는다 — 선택 개수·의미가 달라(users는 상태 다수, reports는 3택) 위젯 교체는 별도 판단이 필요하다. **배치만 통일한다.**

### 6.3 compact 하단 바 무강조

`DpAppShell`의 compact 분기가 `selectedIndex ?? 0`(`dp_app_shell.dart:91`)으로 클램프한다. `NavigationBar.selectedIndex`가 non-null `int`라 불가피했다. 그래서 compact에서 `/settings`·`/mypage`·`/content/:id`·`/sandbox`는 여전히 「대시보드」를 강조한다.

**설계:** `selectedIndex`가 null일 때만 `NavigationBarTheme`으로 감싸 `indicatorColor`를 투명으로 두고, 선택 라벨·아이콘 색을 비선택과 같게 덮는다. 인덱스는 0으로 클램프하되 **시각적 강조가 사라져** 비-compact 레일의 무강조 거동과 일치한다.

`Semantics`의 `selected`도 함께 꺼야 스크린리더가 잘못된 위치를 읽지 않는다.

### 6.4 나머지 화면 조정

| 항목 | 위치 | 처리 |
|---|---|---|
| 마지막 crumb 자기 링크 | `dp_chrome_bar.dart:137` | `isLast`면 `path`가 있어도 비링크로 렌더. **앱 데이터 불변** — `app_shell.dart:43-45`의 `[_crumbCommunity, _crumbBoard]`는 그대로 두고, 2단계 스펙 §7의 표기만 「마지막 세그먼트는 비링크」로 갱신 |
| web 레일 접힘 고정 | `app_shell.dart` | `onToggleRail` 미전달이라 medium(600~840)에서 펼칠 방법이 없다. `AppShellView`를 `StatefulWidget`으로 바꿔 펼침 상태를 보유하고 `railExtended`·`onToggleRail`을 넘긴다 |
| `brandRow` non-flex `Text` | `common/presentation/brand_row.dart` | `Spacer`와 같은 `Row`의 non-flex 자식이라 좁은 폭에서 오버플로. `Flexible` + `ellipsis` |
| 샌드박스 탭 중앙 정렬 | `sandbox_layout.dart:79-81` | `Column`의 기본 `crossAxisAlignment`(center)로 `SegmentedButton`이 중앙에 놓여 좌측 정렬된 페이지 헤더와 어긋난다. `Align(centerLeft)`로 좌측 정렬 |
| 마이페이지 enum 원문 노출 | `mypage_page.dart:63-72,176-192` | `_goals`(`JOB`·`CAREER_CHANGE`·`UPSKILL`·`SIDE_PROJECT`)·`_tracks`(`BACKEND_SPRING` 등)가 드롭다운에 원문 그대로 나온다. **값은 그대로 두고 표시 라벨만** 한국어로 매핑(전송 payload `learningGoal`·`targetTrack`은 불변) |
| 커뮤니티 작성 문구 중복 | `post_create_page.dart:126` · `question_create_page.dart:163` | 헤더 설명과 본문 안내가 사실상 같은 말이다(2단계 계획이 본문 수정을 금지해 생긴 결과). 본문 안내를 제거하거나 서로 다른 정보를 담게 정리 |
| 원시 숫자 여백 | `beta_pending_page.dart:87,95,101,104` | `SizedBox(height: 16)`·`24` → `DpSpacing` |

## 7. `tag*` 배선 — `DpTag` 신설

### 7.1 실측

`tagBg`·`tagText`는 `dp_colors.dart`의 정의·`copyWith`·`lerp` 외에 참조가 **0건**이다. 한편 배선 후보 3곳이 각자 다른 방식으로 같은 것을 그리고 있다:

| 위치 | 현재 |
|---|---|
| `post_detail_page.dart:140` | `Chip(label: Text('#$t'))` — 맨 Material `Chip`, M3 기본색 노출 |
| `dashboard_body.dart:177` | `Chip(label: Text(b))` — 동일 |
| `admin/reports_page.dart:173-189` `_chip` | `Container` 배경에 `c.border`(**경계선 토큰을 면에 쓰는 의미 오용**), 텍스트 `tone ?? c.textSecondary` |

### 7.2 설계

`dp_design` Layer 2에 **`DpTag`** 를 신설한다.

```dart
/// 중립 태그 칩. 배경 tagBg / 전경 tagText.
/// [tone]이 주어지면 전경만 덮는다(admin 신고 카테고리·위험도 구분용).
class DpTag extends StatelessWidget {
  const DpTag({super.key, required this.label, this.tone});
  final String label;
  final Color? tone;
}
```

- 위 3곳을 `DpTag`로 교체한다. admin `_chip`의 `tone` 호출부(`c.chart4`·`c.danger`)는 그대로 동작한다
- **커뮤니티 보드 뱃지(`community_home_page.dart:255-262`·`:341-348`)는 교체하지 않는다** — `border`/`chart4`/`primary`로 보드를 구분하는 **의미 있는** 색이라 중립 태그로 바꾸면 정보가 사라진다
- 대비 검증: `tagText` on `tagBg`를 대비 스크립트 대상에 추가한다

## 8. 문서·테스트 정합

### 8.1 admin 제목 단일 출처화

`admin_shell.dart:44`의 `_headerTitleFor`가 「단일 출처」라 주석돼 있으나 실제로는 **private**이고 admin 5화면이 각자 문자열 리터럴을 박는다(예: `reports_page.dart:36` `'신고 처리'`). 출처가 둘이라 한쪽만 고치면 브레드크럼과 헤더가 조용히 어긋난다. 경로 리터럴도 `kAdminDestinations`와 이중 관리된다.

**설계:** `AdminDestination` 레코드에 `headerTitle` 필드를 추가해 `kAdminDestinations`를 유일한 출처로 만들고, `_headerTitleFor`를 그것을 조회하는 형태로 바꾼다. **경로 리터럴의 이중 관리도 같이 해소되므로 public 맵 승격보다 이쪽을 택한다.** admin 5화면의 제목 리터럴을 제거하고 셸이 주입하거나 `kAdminDestinations`를 참조하게 한다.

### 8.2 주석 정확성

- `dp_chrome_bar_test.dart`의 우측 정렬 테스트 주석이 "group을 flex 참여자로 바꾸면서"라 하나 원복으로 더는 flex 참여자가 아니다(테스트 자체는 유효)
- `app_shell.dart`·`admin_shell.dart`의 주석이 인용한 `dp_nav_rail.dart:91`이 실제로는 `:75-82`(정의)·`:94`(brand 적용). §3의 `DpRailBrand` 도입으로 이 주석들은 어차피 다시 쓰인다
- `dp_chrome_bar.dart:50-62`의 I2 주석을 §4의 결과로 갱신한다 — 「미해결」이 아니라 「축약으로 해소, 단 현재 조건 미도달」

### 8.3 커버리지 공백

| 공백 | 처리 |
|---|---|
| 다크 테마 렌더 테스트가 거의 없다 | `DpNavRail`·`DpChromeBar` 각 1건 이상. §5의 `railBg` 변경이 대비 스크립트 수치 단언에만 의존하지 않게 한다 |
| `path_title_test.dart`가 `PathPage`가 아니라 테스트가 직접 조립한 `Column`을 렌더한다 | **동어반복 테스트**(검증 대상 텍스트를 만들 위젯이 하나뿐이라 `findsOneWidget`이 구조적으로 항상 참). 실제 `PathPage`를 렌더하도록 고친다 |
| `sandbox_page.dart`의 헤더 `title`/`description` 미커버 | 2단계 스펙 §5가 지정한 유일한 제목 변경(`Sandbox` → `실습 샌드박스`)이 회귀 고정 없이 남아 있다. 단언 추가 |

## 9. 3-B 예고 — 차트 다중 시리즈 (별도 스펙)

3-A 완료 후 착수한다. **여기 적은 실측을 다시 조사하지 마라.**

### 9.1 ★`chart1`은 `primary`와 값이 완전히 같다★

| 팔레트 | `primary` | `chart1` |
|---|---|---|
| 라이트 | `#B45309` | `#B45309` |
| 다크 | `#F59E0B` | `#F59E0B` |

따라서 「Bar·Line을 `chart1`로 이관하면 다크에서 `primary` 중복이 풀린다」(핸드오프 §6.4 옵션 1)는 **성립하지 않는다.** 값이 같아 픽셀 변화가 0이고 중복도 그대로다. 3-B에서 데이터 색과 브랜드 액센트를 실제로 가르려면 **`chart1` 값 자체를 재정의**해야 하며, 그러면 대비 재검증이 따라온다.

### 9.2 현재 차트 3종

| 위젯 | 차트 | 색 |
|---|---|---|
| `weekly_activity_card.dart:99` | BarChart(최근 7일 완료 수) | `c.primary` 단색 |
| `progress_trend_card.dart:63,68` | LineChart(14일 누적%) | `c.primary` + 채움 alpha 0.12 |
| `progress_donut.dart:33,39` | PieChart(완료/미완료) | 완료 `c.primary` / 미완료 **`c.border`**(경계선 토큰을 데이터 면에 쓰는 의미 오용 — §7.1의 admin `_chip`과 같은 부류) |

### 9.3 결정된 방향

**계열 축은 「과제 유형별 + 마일스톤(주차)별」 둘 다**(사용자 결정). 차트 3종이 모두 다중 계열로 바뀌고 범례가 신설된다.

**백엔드 비용은 낮다 — 스키마 마이그레이션도 `devpath-shared` 발행도 필요 없다:**

- `path_weekly_tasks`에 `task_type VARCHAR(20) NOT NULL CHECK (task_type IN ('READ','PRACTICE','QUIZ'))`와 `completed_at TIMESTAMPTZ`가 **이미 있다**(`V202606181006__learning_path_schema.sql:62,65,68`). 유형별 일별 집계가 SQL만으로 나온다
- 마일스톤별 진행률은 **백엔드 확장조차 불필요**하다 — `/paths/current`가 `milestones[].tasks[].completed`를 이미 준다(`LearningPathView`·`MilestoneView`·`WeeklyTaskView`)
- 확장 대상: `learning-svc`의 `DashboardService.summary`·`DashboardTimeseries`·`DailyActivity`/`ProgressPoint` DTO + `dp_core`의 대응 모델
- 지난 「대시보드 시계열」 작업과 같은 패턴이다 — 백엔드 DTO의 `date`는 `String` ISO를 유지한다(jsr310 미해결 회피)

`track`(`BACKEND_SPRING`·`FRONTEND_REACT`·`MOBILE_FLUTTER`·`DEVOPS`·`FULLSTACK`)은 계열 축으로 쓰지 않는다 — 사용자당 ACTIVE 경로가 1개라 대부분 단일 계열이 된다.

## 10. 검증

### 10.1 자동

- `melos run analyze` 이슈 0 · `melos run format` clean
- `melos run test` 전 패키지 green (2단계 기준선: web 321 · admin 60 · dp_design 134 · mobile 100 · dp_core 97)
- 대비 스크립트 미달 **0건** — `py docs/superpowers/specs/2026-08-03-token-contrast-check.py`
- 각 결함마다 **red-repro 선행**. 실패 수치를 읽는다 — 2단계에서 통과 여부만 보다가 브레드크럼 원인을 패딩으로 오진했고, 실패값(8.0 vs 99.75)을 보고서야 `Center`의 폭 확장이 진짜 원인임을 알았다

### 10.2 육안 확인 — 독립 Task로 못박는다

2단계에서 **위젯 테스트 321건이 전부 green인 상태에서 레이아웃 결함 2건**이 나왔다(크롬바 우측 448px 여백·브레드크럼 비대칭). 이번에도 Task로 넣는다.

- 4폭(500·700·1000·1400) × 라이트·다크 × 주요 화면
- **셸 밖 4화면(login·beta-pending·consent·diagnostic)도 이번엔 포함한다** — 2단계에서 목 유저 자동 인증 탓에 빠졌다. 픽스처를 임시로 손대야 한다
- 절차는 핸드오프 §2 「캡처 절차 메모」를 그대로 따른다:
  - 목 유저 `onboardingStatus: PENDING` → `/diagnostic` 리다이렉트. 셸을 보려면 `web_mock_fixtures.dart`를 임시 `DONE`으로 바꿔 빌드하고 **캡처 후 반드시 원복**(골든패스 테스트 2건이 `PENDING`을 전제)
  - 다크는 CDP `Emulation.setEmulatedMedia`가 gstack browse allowlist에서 차단 → `theme_provider.dart` 기본값을 임시 `ThemeMode.dark`로 별도 빌드
  - 재빌드해도 화면이 그대로면 서비스워커 캐시 → **포트를 바꿔 새 origin으로** 우회
  - 해시 라우팅이라 `py -m http.server`로 충분(`python`은 스텁)

## 11. 위험

| 위험 | 완화 |
|---|---|
| `DpRailBrand`가 `brand` 타입을 좁혀 호출부가 깨진다 | 호출부는 web·admin 2곳뿐. 컴파일 에러로 즉시 드러난다 |
| `railBg` 변경이 대비 미달을 유발 | 스크립트 재계산을 같은 Task에 넣는다. 미달이면 전경색도 조정 |
| 문서형 12화면 sliver 전환이 스크롤 회귀를 만든다 | 화면별로 기존 스크롤 테스트를 먼저 확인하고, 없으면 전환 전에 세운다 |
| 크롬바 축약이 도달 불가 조건이라 검증이 인위적으로 흐른다 | §4.3의 조건 규칙을 따른다. 컴포넌트 계약(actions N개)은 정당, 폭·라벨 길이 조작은 금지 |
| 서브에이전트가 범위를 넘는다 | Task별 경계 명시 + 컨트롤러가 `git log`·테스트를 직접 재확인(CLAUDE.md §6) |

## 12. 산출물

- `packages/dp_design`: `DpRailBrand`·`DpTag`·`DpChromeAction` 신설, `DpNavRail`·`DpChromeBar`·`DpAppShell`·`DpPageHeader` 수정, 다크 `railBg` 조정
- `apps/web`: 셸 배선(brand·레일 토글·`DpChromeAction` 전환), 문서형 **9화면** sliver 전환(커뮤니티 홈은 이미 sliver라 제외), 마이페이지 라벨, 샌드박스 탭 정렬, 작성 2화면 문구, `brandRow`, `beta_pending` 여백
- `apps/admin`: 셸 배선, 제목 단일 출처화, 필터 슬롯 통일, 문서형 **2화면** sliver 전환
- 문서: `DESIGN.md` 헤더 스크롤 규칙 절, 2단계 스펙 §7 표기 갱신, 주석 교정
- 테스트: red-repro + 다크 렌더 + 실효색 + 동어반복 해소 + 미커버 헤더
