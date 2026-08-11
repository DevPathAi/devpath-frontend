# 핸드오프 — ①디자인 2단계(셸 레이아웃) 완결, 3단계 이월 항목

> 작성 2026-08-05 · 브랜치 `feat/design-phase2-shell` → `develop` 머지
> 스펙 `docs/superpowers/specs/2026-08-03-design-shell-layout-design.md`
> 계획 `docs/superpowers/plans/2026-08-03-design-shell-layout.md` (12 Task)
> 직전 핸드오프 `handoff-2026-08-03-design-phase2-shell-task6-done.md`

## 0. ★먼저 읽어라 — 레포 상태★

**해소됨(2026-08-05 후속 세션).** 앞선 세션은 이 작업을 `develop`에 로컬 머지만 하고 push하지 않아, 원격 반영 방법이 미결로 남아 있었다. 후속 세션에서 사용자가 「브랜치 복원 → 정식 PR」을 선택해 다음을 수행했다:

- `feat/design-phase2-shell`을 머지 전 팁(`bbb6ba7`)에서 복원하고, 머지 커밋 위에 있던 이 문서의 §0 커밋을 cherry-pick해 얹었다
- 로컬 `develop`을 `origin/develop`으로 되돌렸다(머지 커밋 `2289587`·`c783f6d`는 폐기, reflog에 남아 있다)
- 브랜치를 push하고 `develop`으로 PR을 올렸다 — 레포 규칙(develop 직접 push 금지)을 지킨다

`.superpowers/sdd/2026-08-03-design-shell-layout/` 워크스페이스(ledger·brief·리뷰 전문)는 정리 시 삭제됐다 — **이 문서가 그 요약본이다.** 다른 계획의 워크스페이스는 그대로 남아 있다.

### 육안 확인도 수행됐다 (§2 참조)

목 모드 실빌드로 4폭 × 라이트·다크를 캡처해 확인했고 **결함 2건을 찾아 같은 브랜치에서 고쳤다.** 위젯 테스트 321건이 전부 green인 상태에서 발견된 것들이라, §4.2의 교훈("색을 단언하는 테스트가 0건이라 조용히 통과했다")이 레이아웃에서도 반복된 셈이다.

---

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

## 2. 육안 확인 — 수행 완료, 결함 2건 발견·수정

목 모드 릴리스 빌드를 정적 서버로 띄우고 헤드리스 크로미움으로 캡처했다. 4폭(500·700·1000·1400) × 라이트·다크 + 주요 화면(대시보드·경로·멘토·커뮤니티·설정·마이페이지·샌드박스).

**발견·수정한 결함 2건** (둘 다 위젯 테스트 321건이 green인 상태에서 통과하고 있었다):

1. **크롬바 우측 그룹이 우측에 붙지 않았다** — 오류 신고·계정 아이콘이 바 오른쪽 끝이 아니라 한참 왼쪽에 찍혔고, 여백이 폭에 비례해 커졌다(1000폭 약 148px → 1400폭 약 448px). `Flexible`(loose)이 flex 몫을 덜 쓰면 그 잔여가 `Spacer`(tight)로 재분배되지 않고 Row 끝에 남는 구조였다. 좌측 그룹을 `Expanded`로 묶고 `Spacer`를 없애 해결. **기존 우측 정렬 테스트는 60자짜리 crumbs를 써서 이 결함을 우회하고 있었다 — 자기 주석에 그 사실을 적어두고도 실제 앱 조건으로 재현하지 않았다.**
2. **브레드크럼 구분자 간격 비대칭** — '커뮤니티 · 게시판'에서 '·' 뒤가 약 100px 벌어졌다. 원인은 패딩이 아니라 `Center`였다(기본 `Center`는 부모가 주는 최대 폭까지 확장 → `Flexible` 몫의 한가운데로 라벨이 밀림). `widthFactor: 1` + 구분자 패딩의 링크 쪽 상쇄로 해결.

각 수정마다 red-repro를 먼저 세우고(316.5px→16px, 8.0 vs 99.75→대칭), 수정 후 **실빌드를 다시 캡처해 육안으로 재확인**했다.

**아직 안 한 것:** 전 라우트 재캡처해 1단계 캡처와 비교(스펙 §14). 셸 밖 4화면(login·beta-pending·consent·diagnostic)은 목 유저가 자동 인증되어 게이트를 통과하므로 이번 캡처 범위에서 빠졌다 — 확인하려면 픽스처를 임시로 손대야 한다.

### 캡처 절차 메모 (다음에 반복할 때)

- 목 유저는 `onboardingStatus: PENDING`이라 앱이 `/diagnostic`으로 리다이렉트된다. 셸 화면을 보려면 `web_mock_fixtures.dart`를 임시로 `DONE`으로 바꿔 빌드하고 **캡처 후 반드시 원복**한다(골든패스 테스트 2건이 `PENDING`을 전제한다).
- 앱 시작 시 `bootstrapSession()`이 목 `/auth/refresh`로 자동 인증하므로 로그인 클릭조차 필요 없다. URL만 바꿔가며 캡처하면 된다.
- 다크는 `ThemeMode.system` 기본인데 **CDP `Emulation.setEmulatedMedia`가 gstack browse의 allowlist에서 차단된다.** `theme_provider.dart`의 기본값을 임시로 `ThemeMode.dark`로 바꿔 따로 빌드하는 편이 확실하다.
- **재빌드해도 화면이 그대로면 서비스워커 캐시다.** 포트를 바꿔 새 origin으로 띄우면 우회된다(이번에 다크가 라이트로 찍혀 한 번 헛짚었다).
- 라우팅은 해시 전략(`usePathUrlStrategy()` 미호출)이라 `python -m http.server`로 충분하다 — SPA 폴백이 필요 없다. `python`은 이 환경에서 스텁이므로 `py`를 쓴다.

## 3. 3단계 이월 항목 (우선순위 순)

### 3.1 ★구조적 함정 — 최우선 검토★

**"앱이 `Theme.of(context).textTheme.*`를 Layer 2 슬롯에 넘기면, 그 슬롯이 `DefaultTextStyle.merge`로 공급하는 전경색이 항상 진다."**

`DpTheme`가 `textTheme.apply(bodyColor: c.textPrimary)`를 하므로 **모든 타이포 스케일이 non-null color를 이미 품고 있다**. 지금은 web·admin 브랜드 두 곳이 `copyWith(color: c.railText)`로 막고 있을 뿐, **새 슬롯(예: 레일 하단 상태 텍스트)이 생기면 같은 결함이 재발한다.**

해소 방향(3단계에서 결정): `DpNavRail`이 brand `Text` 스타일에 rail 전경색을 강제 적용하거나, `DpRailBrand` 같은 슬롯 전용 위젯을 제공.

### 3.2 I2 — `DpChromeBar` 우측 그룹 오버플로 (미해결, 명시 이월)

`packages/dp_design/lib/src/shell/dp_chrome_bar.dart` 우측(actions·account) 그룹이 non-flex 자식이라 폭 상한을 못 받는다. `RenderFlex`가 무한 주축 제약으로 측정 → `Spacer`/`Flexible`이 0이 되면 오버플로.

**국소 수정으로 해결되지 않는다:** `ConstrainedBox` 상한을 걸면 오버플로가 바깥 `Row`에서 안쪽 `Row`로 **이동**할 뿐이다(자식이 `Row(min)`이고 바 높이 46 고정이라 `DpPageHeader`의 `Wrap`처럼 줄바꿈으로 흡수하지 못한다). 실제로 fix wave에서 시도했다가 오버플로 임계를 `W < G+16` → `W < 2G`로 **넓혀** 원복했다.

**주의 — 우측 정렬 결함(§2-1)과 혼동하지 마라.** 그쪽은 해소됐고(`Spacer`→`Expanded`), I2는 그대로 남아 있다. 다만 `Spacer`가 가져가던 고정 몫이 사라져 오버플로 임계가 넓어지지는 않는다.

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

### 3.7 육안 확인이 새로 올린 항목 (수정하지 않음)

§2의 결함 2건은 고쳤다. 아래는 **의도적으로 남긴 것들**로, 판단이나 스펙 변경이 필요해 3단계 몫이다.

- **`/community`에서 마지막 crumb '게시판'이 현재 페이지 자기 링크다.** 브레드크럼 관례상 현재 위치는 비링크여야 하는데, **스펙 §7이 `/community → [커뮤니티, 게시판(→/community)]`을 명시**하고 테스트가 그 값을 고정하고 있다. 코드가 스펙을 어긴 게 아니므로 임의로 바꾸지 않았다 — 고치려면 스펙 §7부터 바꿔라.
- **다크에서 레일 배경이 본문 배경과 거의 같다.** 「잉크 레일」의 요점이 레일을 어두운 잉크 면으로 분리하는 것인데, 다크에서는 경계선으로만 구분돼 그 정체성이 사라진다. §3.5의 「다크 팔레트에서 `textPrimary == railText` 우연 일치」와 같이 다룰 것.
- **접힘 레일에서 브랜드가 통째로 사라진다.** `DpNavRail`이 `if (extended && brand != null)`이라 로고 마크까지 숨긴다. 마크/워드마크를 나눠 접힘에서 마크만 남기려면 슬롯을 쪼개야 한다(§3.1의 슬롯 설계 문제와 같은 부류). **덧붙여 web은 `onToggleRail`을 넘기지 않아 사용자가 레일을 펼칠 방법이 없다** — medium(600~840)에서 접힘 고정이다.
- **마이페이지가 enum 원문을 노출한다**(`CAREER_CHANGE`·`BACKEND_SPRING`). 셸과 무관한 화면 이슈지만 눈에 띈다.
- **샌드박스의 탭(에디터/실행/리뷰)이 중앙 정렬**이라 좌측 정렬된 페이지 헤더와 어긋난다.

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

### 4.6 ★테스트가 결함을 알고도 우회한 사례★ (육안 확인이 잡아냈다)

우측 정렬 테스트는 **60자짜리 인위적인 crumbs**를 써야만 통과했다. 그리고 그 이유를 자기 주석에 이렇게 적어뒀다:

> crumbs가 짧으면 `Flexible`(loose fit)이 자기 몫을 다 소비하지 않아 남는 공간이 `Spacer` 뒤로 재분배되지 않고 바 맨 끝에 그대로 남는다 (…) 이 테스트는 그 사전 혼입 없이 group 자체의 우측 정렬만 검증한다.

**현상을 정확히 관찰해 적어놓고, "기존 특성 · 범위 밖"으로 분류한 뒤 그 조건을 피해 가는 테스트를 썼다.** 실제 앱의 crumbs는 예외 없이 짧아서 항상 그 경로를 탔는데도. 1400폭에서 448px 여백은 「기존 특성」이 아니라 그냥 결함이다.

**교훈: 테스트가 실제 사용 조건을 재현하지 못해 값을 조작해야 통과한다면, 그 조작 자체가 결함 신호다.** 「이 테스트는 X 없이 Y만 검증한다」는 주석을 쓰게 되면 멈추고 물어라 — X가 실제로는 항상 참인 조건이 아닌가?

부수 교훈 하나 더: 원인 진단이 처음엔 틀렸다. 브레드크럼 비대칭을 「링크 세그먼트의 패딩」으로 보고 패딩을 보정했는데 red가 그대로였고, 실패 수치(8.0 vs 99.75)를 보고서야 진짜 원인이 `Center`의 폭 확장임을 알았다. **red-repro의 실패 수치는 진단을 교정한다 — 통과 여부만 보지 말 것.**

### 4.5 운영

- **서브에이전트의 최종 메시지가 자주 비어서 온다.** 리포트를 파일로도 쓰게 지시하면 해결된다 — 모든 dispatch에 출력 파일 경로를 넣어라.
- 컨트롤러가 매 Task `git log --oneline <base>..HEAD` + `melos run test`를 **직접** 재확인했다. 구현자·리뷰어 보고를 그대로 믿지 않는다. **이번 세션에서 리뷰어가 컨트롤러의 오류(라이트/다크 라벨 뒤바뀜)를 독립 재계산으로 교정한 사례도 있다.**
- `melos`가 PATH에 없다 → `dart pub global run melos run <cmd>`.
- **`python`은 이 환경에서 스크립트를 실행하지 않는다**(스토어 스텁, 조용히 무동작). 대비 스크립트는 `py`로 실행하라.
- Bash 도구의 cwd가 호출 사이 유지되지 않는 경우가 있다 — 절대경로 또는 `cd <repo> &&`를 붙여라.

## 5. 다음 단계

**①전반 디자인 3단계**(`tag*`·`chart*` 배선 + 위 §3 이월 항목). 3단계 스펙의 「선행 수정」 절에 §3.1·§3.2·§3.3을 **명시적으로** 적어라 — 암묵적 이월은 같은 함정을 네 번째로 밟게 한다. §3.7(육안 확인이 새로 올린 항목)도 함께 넣되, 「자기 링크」 건은 **스펙 §7 수정이 선행**이라는 점을 적어라.

3단계 계획에는 **육안 확인을 Task로 넣어라.** 이번에 위젯 테스트 321건 green 상태에서 레이아웃 결함 2건이 나왔다(§2·§4.6). 절차는 §2 끝의 「캡처 절차 메모」를 그대로 쓰면 된다.

---

## 6. 3단계 착수 준비 — 브레인스토밍을 여기서 멈췄다

PR #106 머지 후 3단계 스펙 작성을 시작했다가 **사용자 판단으로 다음 세션에 넘겼다.** 아래는 그때까지 실측한 내용이다 — **같은 조사를 반복하지 마라.**

### 6.1 확정된 것

**범위: 결함 해소와 토큰 배선을 한 스펙에 담는다**(사용자 승인). 둘 다 셸·대시보드를 건드리므로 한 번에 검증하는 편이 낫다는 판단이다.

### 6.2 ★토큰 현황 실측 — §3.5의 「`tag*`·`chart*` 미배선」은 부정확하다★

| 토큰 | 실제 상태 |
|---|---|
| `chart4` | **이미 배선돼 있다.** `community_home_page.dart:257`·`:343`(FEEDBACK 보드 뱃지 accent) · `admin/reports_page.dart:113`(신고 카테고리 칩 tone). `dp_colors.dart:99` 주석대로 「앰버의 대비 계열(틸)이라 구분용 색으로도 쓴다」가 실제로 지켜지고 있다 |
| `chart1`·`chart2`·`chart3`·`chart5` | 미배선 |
| `tagBg`·`tagText` | **완전 미배선** — `dp_colors.dart`의 정의·`copyWith`·`lerp` 외에 참조가 없다 |

**차트 3종은 전부 `c.primary` 단색이다**(차트 팔레트를 두고 쓰지 않는다):
- `dashboard/widgets/weekly_activity_card.dart:99` — BarChart(최근 7일)
- `dashboard/widgets/progress_trend_card.dart:63`·`:68` — LineChart(14일 누적%, 채움은 alpha 0.12)
- `dashboard/widgets/progress_donut.dart:33` — PieChart(완료/미완료)

### 6.3 `tag*` 배선 후보 (실측 위치)

- **`community/post_detail_page.dart:140` — `Chip(label: Text('#$t'))`.** 맨 Material `Chip`이라 M3 기본색이 그대로 나온다. `tagBg`/`tagText`가 들어갈 가장 명확한 자리다
- `dashboard/widgets/dashboard_body.dart:72` — `_BadgeStrip`(「첫 경로」·「7일 연속」)
- `admin/reports_page.dart`의 `_chip(context, label, {tone})` — 이미 `tone` 파라미터가 있어 기본 톤만 바꾸면 된다
- 커뮤니티 보드 뱃지(`community_home_page.dart:255-262`·`:341-348`) — 현재 `border`/`chart4`/`primary`로 분기한다. `tag*`로 옮길지 지금 구성을 유지할지 판단이 필요하다

### 6.4 ★미결 질문 — 여기서 멈췄다★

**차트 팔레트를 어디까지 적용할 것인가.** `chart1~5`는 본래 다중 시리즈 구분용인데 현재 차트는 전부 단일 시리즈다. 선택지를 그대로 옮긴다:

1. **차트 3종 전부 팔레트로 이관**(제안했던 안) — 도넛 완료/미완료 = `chart1`/`chart5`, Bar·Line = `chart1`. 시각적 변화는 작지만 「데이터 색은 차트 팔레트, 브랜드 액센트는 `primary`」로 체계가 갈린다. **다크에서 `primary`(앰버)가 액센트와 데이터에 중복 사용되는 문제도 함께 풀린다**
2. **도넛만 2색 구분** — 실제로 구분이 필요한 도넛만 바꾸고 Bar·Line은 `primary` 유지(차트=브랜드색 정체성을 유지하는 쪽)
3. **다중 시리즈까지 확장**(예: 트랙별 진행률) — **백엔드 계약 확장이 필요해 범위가 크게 늘어난다.** 3단계에 넣을 거라면 별도 하위 작업으로 떼어라

이 질문에 답이 나오면 스펙 작성을 이어갈 수 있다. 나머지(§3 이월 + §3.7)는 이미 정리돼 있다.
