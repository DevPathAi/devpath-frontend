# 디자인 2단계 — 셸 레이아웃 개편 (잉크 레일 · 2층 상단) — 설계

> 작성 2026-08-03 · brainstorming 결과 · 후속 = writing-plans
> 선행: [1단계 디자인 토큰 개편](2026-08-03-design-token-overhaul-design.md) (PR #103 · #104 머지 완료)
> 범위: **셸 구조와 화면 상단.** 개별 화면 본문의 레이아웃 재구성(대시보드 Bento 재배치·경로 카드화)은 3단계다.

1단계는 토큰을 32개로 늘렸지만 **15개가 소비처 0곳**으로 남았다. 특히 잉크 사이드바를 위해 만든 `rail*` 6종이 한 번도 쓰이지 않아, 팔레트의 절반이 화면에 존재하지 않는다. 2단계는 셸을 다시 만들어 이 토큰들이 제 자리를 찾게 한다.

## 1. 지금 무엇이 문제인가 (실측)

| 결함 | 실측 근거 |
|---|---|
| 화면마다 상단바를 따로 만든다 | `AppBar` 직접 생성 **web 12곳 · admin 5곳 · 셸 밖 4곳** — 높이·여백·색이 제각각 |
| 현재 위치를 알 수 없다 | 상단바에 제목 한 줄뿐. 「커뮤니티 → 게시글」 같은 계층이 화면에 없다 |
| 레일이 본문과 같은 흰 세계 | Material `NavigationRail` 기본값. `railBg` 등 6토큰 소비처 0 |
| 레일 하단이 비어 있다 | 목적지 5개 아래로 700px 공백(1240px 창 기준) |
| 명령 팔레트가 숨어 있다 | `Ctrl/Cmd+K`를 아는 사용자만 쓴다. 아이콘 버튼 하나가 전부 |
| 화면이 무엇을 하는 곳인지 설명이 없다 | 제목만 있고 부연 한 줄이 들어갈 자리가 구조적으로 없다 |

## 2. 결정 사항

brainstorming에서 프리뷰를 비교해 정했다.

| 항목 | 결정 | 탈락안 |
|---|---|---|
| 레일 | **잉크 배경 + 섹션 그룹 + 하단 계정 블록**. 활성 = `railActive` 면 + 앰버 좌측 인디케이터 2px | 평면 목록(앰버 채움이 레일에 상시 노출돼 액센트를 소모) · 밝은 레일(`rail*` 미사용, 다크 코드영역이 본문에 고립) |
| 상단 | **2층 — 얇은 크롬바 + 본문 페이지 헤더**. 크롬바에 **상시 검색 입력** 노출 | 단층 통합(설명 자리 없음) · 검색 아이콘만(숨은 기능 유지) |
| 레일 구성 | 학습 3(대시보드·경로·멘토) / 커뮤니티 1(게시판). **설정은 하단 계정 블록으로 이동** | 샌드박스 승격(단독 진입이 빈 에디터라 어색) |
| 구현 | `DpAppShell` 내부를 **통째로 교체**. web·admin이 같은 레일을 공유 | 분기 유지(dp_design에 두 경로가 영구히 남음) |
| admin | 레일 + 화면 5개 헤더까지 이관 | 레일만(상단이 예전 모습이라 과도기 느낌) |
| 셸 밖 4화면 | **최소 정합** — 같은 헤더·카드·여백 규칙만 적용 | 전면 재설계(2단계가 두 가지 일을 동시에 하게 됨) |
| 미소비 토큰 | 셸·헤더 이관 범위에서 자연히 만나는 것만. `tag*`·`chart*`는 **3단계 이월** | 15개 전부(사실상 화면 작업까지 포함) |

**커뮤니티 게시판 검색과 크롬바 전역 검색의 역할 구분은 후속 과제로 남긴다**(사용자 지정). 이번엔 둘이 공존한다.

## 3. 아키텍처 — 컴포넌트 3종 신설

`DpAppShell`이 지금은 `NavigationRail`을 직접 조립한다(`dp_app_shell.dart:70-85`). 셋으로 나눈다.

| 컴포넌트 | 위치 | 책임 |
|---|---|---|
| `DpNavRail` | `dp_design/src/shell/` | 브랜드 · 섹션 그룹 · 목적지 · 계정 블록 |
| `DpChromeBar` | `dp_design/src/shell/` | 브레드크럼 · 검색 · 전역 액션 |
| `DpPageHeader` | `dp_design/src/layout/` | 제목 · 설명 · 페이지 액션 |

셋 모두 **go_router·Riverpod 비의존**(로드맵 Layer 2 규칙). `DpAppShell`은 배치만 담당한다.

### 3.0 `DpAppShell` API 변경 — 기존 슬롯의 행선지

현재 `leading`·`trailing`·`accountSlot` 세 슬롯이 전부 레일에 붙는다(`dp_app_shell.dart:94-123`). 2층 구조에서는 갈 곳이 달라진다.

| 기존 슬롯 | 현재 내용(web) | 새 행선지 |
|---|---|---|
| `leading` | (미사용) | **삭제** — 브랜드는 `brand` 슬롯이 대신한다 |
| `trailing` | 오류 신고 · 검색 `IconButton` 2개 | **크롬바 `actions`** — 검색은 크롬바 검색 필드로 흡수되므로 오류 신고만 남는다 |
| `accountSlot` | 마이페이지 `IconButton` | **레일 계정 블록**(Compact에선 크롬바 아바타) |

새 시그니처:

```dart
DpAppShell({
  required List<DpDestination> destinations,
  required int selectedIndex,
  required ValueChanged<int> onSelect,
  required Widget body,
  Widget? brand,                       // 레일 상단
  Widget? account,                     // 레일 하단 / Compact 크롬바 우측
  List<DpCrumb> breadcrumb = const [], // 비면 크롬바 미렌더
  ValueChanged<String>? onCrumbTap,
  VoidCallback? onSearchTap,
  List<Widget> chromeActions = const [],
  bool? railExtended,
  VoidCallback? onToggleRail,
  bool constrainBodyAtLarge = true,
})
```

`breadcrumb`이 비면 크롬바를 렌더하지 않는다 — 기존 소비처가 크롬바 없이도 동작해 이관을 단계적으로 할 수 있다.

### 3.1 `DpDestination` — record → class

섹션 그룹에는 목적지별 `section` 필드가 필요한데, 현재는 record typedef라 **옵셔널 필드를 추가할 수 없다**(record는 모든 필드가 필수).

```dart
class DpDestination {
  const DpDestination({
    required this.icon,
    required this.label,
    this.section,          // null이면 그룹 없음(admin)
    this.badgeCount = 0,
  });
  final IconData icon;
  final String label;
  final String? section;
  final int badgeCount;
}
```

**섹션은 중첩 리스트가 아니라 평면 리스트 + 연속 `section` 그룹핑으로 처리한다.** `selectedIndex` 계산이 지금 그대로 유지돼 셸 로직과 기존 테스트가 덜 깨진다.

소비처는 4곳뿐이다(실측): `app_shell.dart:70` · `admin_shell.dart:69` · `dp_app_shell.dart:38` · `dp_app_shell_test.dart:6-7`.

### 3.2 `DpNavRail`

```dart
DpNavRail({
  required List<DpDestination> destinations,
  required int selectedIndex,
  required ValueChanged<int> onSelect,
  Widget? brand,          // 상단 브랜드 블록
  Widget? account,        // 하단 계정 블록
  bool extended = true,
  VoidCallback? onToggle,
})
```

- 배경 `railBg`, 우측 경계 `railBorder`
- 섹션 레이블: `railFaint`, 11px w600, letter-spacing 넓힘. **접힘(72px) 상태에서는 레이블 대신 구분선**(`railBorder`)
- 비활성 항목 `railMuted` / 활성 항목 `railText` + `railActive` 배경 + 앰버(`primary`) 좌측 인디케이터 2px
- 계정 블록은 `Spacer` 아래에 붙어 하단 공백을 메운다. 상단에 `railBorder` 구분선

### 3.3 `DpChromeBar`

```dart
typedef DpCrumb = ({String label, String? path});   // path == null이면 비클릭

DpChromeBar({
  required List<DpCrumb> breadcrumb,
  required ValueChanged<String> onCrumbTap,
  VoidCallback? onSearchTap,
  List<Widget> actions = const [],
  Widget? account,
  bool compact = false,
})
```

`DpCrumb`은 필드가 둘뿐이고 옵셔널 확장 계획이 없으므로 **record typedef를 유지**한다. `DpDestination`을 class로 바꾸는 것과 다른 판단인데, 그쪽은 `section`이라는 옵셔널 필드가 실제로 필요해서다.

- 높이 46px, 배경 `surface`, 하단 경계 `border`
- 브레드크럼: 세그먼트 `textSecondary`, 마지막 세그먼트 w600, 구분자 `·`는 `textFaint`
- **세그먼트는 `path`가 있을 때만 클릭 이동**한다. 「학습」·「계정」은 대응 라우트가 없어 텍스트로만 둔다
- 검색: `surfaceMuted` 배경 + `border` + 자리표시자 「검색」 + `Ctrl K` 뱃지. 최대폭 300

### 3.4 검색은 "가짜 입력"이다

크롬바의 검색 필드는 `TextField`가 아니라 **탭하면 기존 `DpCommandPalette`를 여는 버튼**이다(`OpenCommandPaletteIntent` 발화).

이렇게 하면 이미 검증된 팔레트 코드(`dp_command_palette.dart`)를 한 줄도 건드리지 않고 숨은 기능만 노출한다. 입력 상태를 두 곳에서 관리하는 문제도 생기지 않는다.

### 3.5 `DpPageHeader`

```dart
DpPageHeader({
  required String title,
  String? description,
  List<Widget> actions = const [],
  Widget? filters,      // admin users·ads의 AppBar.bottom 이관처
})
```

- 제목 **기존 `headlineSmall`(24/32 w600)** · 설명 `bodySmall`(13/20) `textSecondary` · 상하 여백 `DpSpacing.lg`/`md`
- 보조 액션 버튼은 `accentSoft` 배경 + `accentLine` 보더 + `primaryText` 텍스트
- `filters`가 있으면 설명 아래 행으로 렌더

**새 타입 스케일을 만들지 않는다.** 1단계가 정의한 9종(`displaySmall`·`headlineSmall`·`titleLarge`·`titleMedium`·`titleSmall`·`bodyMedium`·`bodySmall`·`labelLarge`·`labelMedium`·`labelSmall`)에서만 고른다. 미정의 스타일을 쓰면 Material 기본값으로 떨어져 한글 행간 1.6이 적용되지 않는다 — 1단계가 고친 결함이 되살아난다.

## 4. 레일 구성 (web)

```
DevPath                     ← 브랜드
학습                        ← railFaint 섹션 레이블
  대시보드   ▸활성
  학습 경로
  AI 멘토
커뮤니티
  게시판
      ⋮
──────────                  ← railBorder
김개발  설정 · 마이페이지     ← 계정 블록
```

목적지가 **5개 → 4개**로 줄고 설정이 계정 블록으로 내려간다. `kShellDestinations`에서 `/settings`를 제거한다.

계정 블록은 **`MenuAnchor`**로 「마이페이지」·「설정」 두 항목을 연다 — admin의 `DpDataTable` 행 메뉴에서 이미 쓰는 패턴이라 새 상호작용을 도입하지 않는다. 계정 블록 자체는 `DpAppShell`의 `account` 슬롯에 주입되므로 `DpNavRail`은 메뉴 내용을 모른다(Layer 2 규칙).

**샌드박스는 레일에 올리지 않는다.** 콘텐츠 화면의 「실습」 버튼으로만 진입한다(현행 유지) — 단독 진입은 문제 없는 빈 에디터로 들어가게 된다.

admin은 같은 `DpNavRail`을 `section` 없이 써서 평면 목록 + 계정 블록이 된다.

## 5. 화면 이관 — web 12

각 화면은 `Scaffold`를 유지하되 **`appBar`만 제거**하고 본문 최상단에 `DpPageHeader`를 넣는다. 커뮤니티 홈은 `CustomScrollView`의 첫 sliver로 들어가며 `PinnedHeaderSliver`(검색바·보드 필터)와 FAB는 건드리지 않는다.

| 라우트 | 헤더 제목 | 설명 | 액션 |
|---|---|---|---|
| `/dashboard` | 대시보드 | 이번 주 학습 현황과 다음 과제를 한눈에 봅니다 | — |
| `/path` | 학습 경로 | 진단 결과로 만든 12주 계획입니다 | — |
| `/content/:id` | 학습 콘텐츠 | 읽고 나면 바로 실습으로 이어집니다 | 「실습」→`/sandbox` |
| `/sandbox` | **실습 샌드박스** | 코드를 작성하고 바로 실행해 봅니다 | 언어 `DropdownButton` |
| `/mentor` | AI 멘토 | 막히는 부분을 물어보면 학습 맥락을 반영해 답합니다 | — |
| `/community` | 커뮤니티 | 질문하고 답하고 서로 피드백을 남깁니다 | — (FAB 유지) |
| `/community/new` | 질문하기 | 무엇을 시도했고 어디서 막혔는지 함께 적어주세요 | — |
| `/community/new/post` | (동적 `_pageTitle`) | 자유롭게 쓰거나 코드 피드백을 요청하세요 | — |
| `/community/post/:id` | 게시글 | — | — |
| `/community/:id` | Q&A | — | — |
| `/settings` | 설정 | 알림·동의·계정을 관리합니다 | — |
| `/mypage` | 마이페이지 | 프로필과 활동 기록입니다 | **설정 버튼 삭제**(계정 블록과 중복) |

**`Sandbox` → `실습 샌드박스`가 유일한 제목 변경이다.** 다른 화면이 전부 한국어인데 이 화면만 영문이라 튄다.

상세 화면 2건(`게시글`·`Q&A`)은 **설명을 두지 않는다.** 본문이 주인공인 화면에 부연을 넣으면 정작 읽어야 할 내용이 밀린다.

## 6. 화면 이관 — admin 5

| 라우트 | 헤더 제목 | 설명 | 액션 / 필터 |
|---|---|---|---|
| `/dashboard` | 운영 대시보드 | 서비스 지표를 요약합니다 | — |
| `/users` | 사용자 관리 | 가입 승인과 제재를 처리합니다 | `AppBar.bottom` 상태 필터 → `filters` 슬롯 |
| `/reports` | 신고 처리 | 커뮤니티 신고를 검토하고 판정합니다 | — |
| `/support` | 오류 신고·문의 | 사용자가 보낸 오류와 문의를 처리합니다 | — |
| `/ads` | 광고 관리 | 하우스·스폰서 광고를 운영합니다 | 액션=전역 노출 `Switch`+「광고 생성」 / `bottom` 필터 → `filters` 슬롯 |

`users`·`ads`는 `AppBar.bottom`에 48px 필터 바를 달고 있다(실측). 이것이 `DpPageHeader.filters` 슬롯이 필요한 이유다.

## 7. 브레드크럼 매핑

크롬바는 라우팅을 모른다. 앱의 `AppShell`/`AdminShell`이 경로 → 세그먼트로 변환해 주입한다.

```
/dashboard            → [학습, 대시보드]
/path                 → [학습, 학습 경로]
/content/:id          → [학습, 학습 콘텐츠]
/sandbox              → [학습, 실습 샌드박스]
/mentor               → [학습, AI 멘토]
/community            → [커뮤니티, 게시판(→/community)]
/community/post/:id   → [커뮤니티, 게시판(→/community), 게시글]
/community/:id        → [커뮤니티, 게시판(→/community), Q&A]
/community/new        → [커뮤니티, 게시판(→/community), 질문하기]
/community/new/post   → [커뮤니티, 게시판(→/community), 새 글]
/settings             → [계정, 설정]
/mypage               → [계정, 마이페이지]
```

admin은 섹션이 없으므로 단일 세그먼트(`[사용자 관리]`)를 쓴다.

### 7.1 ⚠️ 제목이 화면에 세 번 나온다

브레드크럼 마지막 세그먼트(「대시보드」) · 헤더 제목(「대시보드」) · 레일 목적지 라벨(「대시보드」)이 **같은 문자열로 한 화면에 공존**한다.

1단계가 고친 경로 화면의 제목 중복(앱바 + 본문에 같은 크기 제목 둘)과는 다르다. 셋은 크기와 역할이 분명히 다르다 — 12px 경로 표시 · 24px 페이지 제목 · 12px 내비 항목. 브레드크럼에서 현재 페이지를 빼면 「학습 ·」만 남아 오히려 어색하므로 **표준 관행대로 현재 페이지를 포함한다.**

다만 **테스트에는 실질적 영향이 있다.** `find.text('대시보드')`가 셋을 모두 잡아 `findsOneWidget`이 깨진다. 셸을 포함해 렌더하는 테스트는 텍스트가 아니라 **위젯 타입 또는 `Key`로 특정**해야 한다.

## 8. 반응형 4클래스

DESIGN.md §5의 기존 4-클래스를 그대로 따른다.

| 클래스 | 레일 | 크롬바 | 헤더 |
|---|---|---|---|
| Compact <600 | 하단 `NavigationBar` 4탭 | 마지막 세그먼트만 + 검색 아이콘 + 아바타 | 그대로 |
| Medium 600–839 | 접힘 72px, 섹션 레이블 → 구분선 | 전체 | 그대로 |
| Expanded 840–1239 | 펼침 256px | 전체 | 그대로 |
| Large ≥1240 | 펼침 + 본문 `contentMaxWidth` 제약(기존) | 전체 | 그대로 |

Compact에서 계정 블록은 레일이 없으므로 **크롬바 우측 아바타**로 옮겨간다. 아바타는 레일과 **같은 `MenuAnchor` 위젯을 그대로 받는다** — 앱이 `account` 슬롯 하나만 만들고 셸이 폭에 따라 어디에 놓을지 정한다. 두 벌을 만들지 않는다.

## 9. 셸 밖 4화면 — 최소 정합

`/login` · `/beta-pending` · `/consent` · `/diagnostic`. `AppBar`를 걷고 아래 구조로 통일한다.

```
Scaffold(bg)
  └ Center / ConstrainedBox(maxWidth: 440)
      ├ 브랜드 행: 로고 + DevPath   [우측: 로그인 화면만 테마 전환 버튼]
      ├ DpPageHeader(제목, 설명)
      └ 기존 본문 (surface 카드 · border · panelRadius)
```

| 라우트 | 제목 | 설명 |
|---|---|---|
| `/login` | 로그인 | GitHub 또는 Google 계정으로 시작하세요 |
| `/beta-pending` | 베타 대기 | 승인되면 알려드립니다 |
| `/consent` | 가입 전 동의 | 서비스 이용에 필요한 항목입니다 |
| `/diagnostic` | 실력 진단 | 몇 문항으로 현재 수준을 파악합니다 |

**흐름·입력 필드·검증 로직은 손대지 않는다.** 로그인 화면의 테마 전환 버튼은 유지하되 브랜드 행 우측으로 옮긴다(크롬바가 없어 갈 곳이 없다).

## 10. ⚠️ 토큰 배선 — `textFaint` 문제

`textFaint`(라이트 `#918B81`, 대비 3.21:1)를 브레드크럼과 헤더 설명에 쓰려 했으나, **1단계 스펙 §3.2가 "본문 텍스트로 쓰지 않는다"고 못박은 값이다.** 12px 보조 텍스트에 쓰면 WCAG 4.5:1 위반이다.

| 토큰 | 배선처 |
|---|---|
| `railBg`·`railText`·`railMuted`·`railFaint`·`railActive`·`railBorder` | `DpNavRail` |
| `surfaceMuted` | 크롬바 검색 필드 배경 |
| `accentSoft`·`accentLine` | 헤더 보조 액션 버튼, 크롬바 아바타 테두리 |
| `textFaint` | **구분자 `·`와 비활성 아이콘에만.** 텍스트 세그먼트는 `textSecondary` |
| `tagBg`·`tagText`·`chart1~5` | **3단계 이월** |

`textFaint`는 이번 범위에서 쓰임이 빈약하다. 억지로 텍스트에 넣느니 남겨둔다.

## 11. 테스트 전략

**신규 위젯 테스트**

- `DpNavRail` — 섹션 레이블 렌더 · 활성 인디케이터 · 계정 슬롯 · 접힘 시 레이블→구분선 전환 · `badgeCount>0` Badge 유지
- `DpChromeBar` — 브레드크럼 세그먼트 렌더 · `path` 있는 세그먼트만 탭 가능 · 검색 탭 → `OpenCommandPaletteIntent` 발화 · compact 축약
- `DpPageHeader` — 제목/설명/액션/filters 슬롯

**기존 테스트 갱신**

- `find.byType(NavigationRail)` **11지점**: dp_design 3 · web 5 · admin 3. (`golden_path_t1_realapi_test`의 것은 주석일 뿐 실제 의존이 아니다 — 실측으로 확인했다)
- admin 셸 테스트의 `find.text('운영 콘솔')` — `leading` → `brand` 슬롯 이동에 따라 갱신
- **`AppBar` 제목으로 화면을 찾는 테스트를 전수 조사해 갱신한다.** 17화면 이관의 최대 회귀 위험이며, 착수 시 `grep -rn "AppBar\|appBar" --include="*_test.dart"`로 목록을 먼저 확정한다
- `kShellDestinations` 5→4 축소에 따른 인덱스 의존 테스트

**대비 검증 확장**

1단계 스크립트(`2026-08-03-token-contrast-check.py`)에 레일 조합을 추가한다: `railText`/`railMuted`/`railFaint` on `railBg`, 활성 항목 `railText` on `railActive`. 라이트·다크 각각. **`railMuted`·`railFaint`는 UI 기준 3:1이 아니라 텍스트 기준 4.5:1로 단언한다** — 목적지 라벨과 섹션 레이블은 읽어야 하는 텍스트다.

**골든**: 팔레트가 아니라 구조가 바뀌므로 전부 리베이스한다. 새 골든은 추가하지 않는다.

**전 스위트**: web · dp_core · dp_design · admin · mobile 5패키지 green.

## 12. 작업 순서

```
dp_design
  DpDestination class화 → DpNavRail → DpChromeBar → DpPageHeader → DpAppShell 재구성
    └─→ web 셸 배선 (브레드크럼 매핑 · 계정 블록 · 검색 · kShellDestinations 4개로 축소)
          ├─→ web 12화면 헤더 이관
          ├─→ admin 셸 + 5화면 이관
          └─→ 셸 밖 4화면 최소 정합
                └─→ 대비 확장 + 골든 리베이스 + DESIGN.md 갱신
```

`dp_design`이 임계 경로다. 그 뒤 세 갈래는 서로 독립이다.

## 13. 범위 밖 (3단계 이후)

- **본문 레이아웃**: 대시보드 Bento L자 빈 구멍, 경로 화면 카드화, 커뮤니티 목록 밀도
- `tag*`·`chart*` 토큰 배선 (경로 태그 · 차트 축/값 부재)
- `primary` → `accent` 토큰 개명 (47파일 파급)
- **크롬바 전역 검색 ↔ 커뮤니티 게시판 검색의 역할 구분** (사용자 지정 후속)
- 1단계 잔여 결함: 마이페이지 enum 원문 노출(`CAREER_CHANGE`·`BACKEND_SPRING`) · 활동 카드 로드 실패 · `chart4` 겸용 별칭 토큰

## 14. 검증 방법

- `melos run analyze` · `melos run format` · `melos run test` 5패키지 green
- 대비 스크립트 재실행 — 레일 조합 포함 **미달 0건**
- web 재빌드 후 전 라우트 재캡처. 1단계 캡처와 나란히 비교
- 라이트·다크 각각에서 대시보드·커뮤니티·경로·설정 육안 확인
- **Compact·Medium·Expanded·Large 네 폭 모두에서 레일 전환 확인** — 접힘 상태의 섹션 구분선이 이번 개편의 유일한 새 분기다
