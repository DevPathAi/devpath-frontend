# DESIGN.md — DevPath AI 프론트엔드 디자인 시스템

> 대상: `dp_design`(Material 3) 공용 디자인 시스템 + web/admin/mobile 앱.
> 출처: `/plan-design-review`(2026-06-14) 결정 + 승인된 와이어프레임 방향(인디고/slate/카드).
> 이 문서가 토큰의 단일 출처(Single Source of Truth). 모든 화면 디자인은 여기에 정렬한다.

## 0. 분류 & 원칙

- **앱 셸(web/admin/mobile)** = APP UI: 차분한 surface 위계, 강한 타이포, 적은 색, 최소 chrome. 카드는 "카드가 곧 인터랙션"일 때만.
- **landing(Jaspr)** = MARKETING: 별도 표현형 디자인(본 문서 범위 밖, 토큰만 공유).
- 보편 규칙: CSS/토큰 변수로 색 정의 · 기본 폰트 스택 금지 · 섹션당 한 가지 일 · 카드는 존재 이유 증명 · 본문 ≥16px & 대비 ≥4.5:1.

## 1. 컬러 토큰

프라이머리는 **잉크·앰버(T2)**. 따뜻한 무채색 그라운드에 앰버 하나를 액센트로 쓰며,
앰버는 **"성취"를 전담**한다(진행률·스트릭·1차 행동).

- `primary` 는 **채움 전용**, 텍스트는 `primaryText`(≥4.5:1), 12~14px 강조는 `primaryTextStrong`(≥7:1).
- **다크의 `onPrimary` 는 어두운 색**(`#1A1200`)이다 — 앰버 위 흰 텍스트는 2.2:1 로 미달한다.
- 면은 3단계(`bg` · `surface` · `surfaceMuted`), 사이드바는 전용 토큰 6종을 갖는다.
- `warning` 은 **진짜 경고 전용**이다. 서비스 상태(점검·한도·오프라인·부분실패)는 중립(`textSecondary`),
  의미 없는 구분용 색은 `chart4` 를 쓴다. 액센트와 계열이 가까워 용도를 좁혔다.
- 대비는 17조합 × 라이트·다크 = 34건을 실측해 미달 0건을 확인했다(2026-08-03).
  검증 스크립트: `docs/superpowers/specs/2026-08-03-token-contrast-check.py`
- `ColorScheme.fromSeed` 의 시드도 앰버(`#B45309`)로 교체했다(`dp_theme.dart`). 토큰만 바꾸고
  시드를 인디고로 남기면 `ColorScheme`가 파생하는 Material 색(예: `surfaceTint`·`secondaryContainer`)이
  옛 팔레트로 남는다 — 이번 작업에서 얻은 교훈이다.

32개 토큰 전부가 `DpColors`(`packages/dp_design/lib/src/theme/dp_colors.dart`)의 단일 클래스에 있으며,
이 문서의 값은 그 코드에서 그대로 옮긴 것이다(코드가 SSoT, 이 표는 사본).

**면 (Surface) — 3단계**
| 토큰 | 라이트 | 다크 | 용도 |
|---|---|---|---|
| `bg` | `#FAF9F7` | `#0F0E0C` | 본문 배경 |
| `surface` | `#FFFFFF` | `#1A1815` | 카드·패널 |
| `surfaceMuted` | `#F2F0EC` | `#231F1B` | 비활성·보조 면·검색 입력 |
| `border` | `#E2DED7` | `#332E28` | 구분선·카드 보더 |

**텍스트 — 3단계**
| 토큰 | 라이트 | 다크 | 용도 | 대비 비고 |
|---|---|---|---|---|
| `textPrimary` | `#1A1815` | `#EAE7E2` | 본문 | ✅ |
| `textSecondary` | `#615C54` | `#A09991` | 보조(최다 사용) | 라이트 6.30:1 ✅ |
| `textFaint` | `#918B81` | `#6F6961` | 메타·캡션 | 라이트 3.21:1 — UI 컴포넌트 기준(3:1) 통과, **본문 텍스트로 쓰지 않는다** |

**사이드바 전용** — 본문과 다른 위계. `DpAppShell`(`packages/dp_design/lib/src/shell/dp_app_shell.dart`)이
§9 셸 구조에서 배선한다.
| 토큰 | 라이트 | 다크 | 용도 |
|---|---|---|---|
| `railBg` | `#1A1815` | `#131210` | 사이드바 배경 |
| `railText` | `#F2F0EC` | `#EAE7E2` | 사이드바 활성·브랜드 |
| `railMuted` | `#A9A298` | `#948D85` | 사이드바 비활성 항목 |
| `railFaint` | `#9C958B` | `#8A837B` | 사이드바 섹션 레이블 |
| `railActive` | `#2F2B24` | `#231F1B` | 사이드바 활성 배경 |
| `railBorder` | `#2B2823` | `#2A2621` | 사이드바 내부 구분선 |

**액센트 (앰버)**
| 토큰 | 라이트 | 다크 | 용도 | 대비 비고 |
|---|---|---|---|---|
| `primary`(=accent) | `#B45309` | `#F59E0B` | 버튼 배경·진행바(**채움 전용**) | — |
| `onPrimary` | `#FFFFFF` | `#1A1200` | 채움 위 텍스트 | **다크는 반대 방향**(어두운 색, §위 참고) |
| `primaryText` | `#92400E` | `#FBBF24` | 링크·강조 텍스트 | 라이트 6.74:1 ✅ |
| `primaryTextStrong` | `#78350F` | `#FCD34D` | 12~14px 강조 텍스트 | 라이트 9.07:1 ✅ |
| `accentSoft` | `#FDF1E0` | `#2E2007` | 1차 카드 배경·뱃지 | — |
| `accentLine` | `#F2D0A0` | `#5C400E` | 1차 카드 보더 | — |

**시맨틱**
| 토큰 | 라이트 | 다크 | 용도 | 대비 비고 |
|---|---|---|---|---|
| `success` | `#15803D` | `#4ADE80` | 성공·해결됨 | ✅ |
| `warning` | `#A16207` | `#FCD34D` | **진짜 경고 전용**(서비스 상태·구분용 색은 사용 금지, 위 참고) | 라이트 on surface 4.92:1 — 34건 중 여유가 가장 적음, 조정 시 특히 주의 |
| `danger` | `#B91C1C` | `#F87171` | 에러·삭제·정지 | ✅ |

**태그**
| 토큰 | 라이트 | 다크 | 용도 |
|---|---|---|---|
| `tagBg` | `#F2F0EC` | `#231F1B` | 태그 배경 |
| `tagText` | `#524D45` | `#A09991` | 태그 텍스트 |

**차트** — 현재 `primary` 한 색만 쓰던 것을 5계열로 분리
| 토큰 | 라이트 | 다크 | 용도 |
|---|---|---|---|
| `chart1` | `#1D4ED8` | `#60A5FA` | 데이터 계열 1(파랑) |
| `chart2` | `#BE185D` | `#F472B6` | 데이터 계열 2(자홍) |
| `chart3` | `#7E22CE` | `#D8B4FE` | 데이터 계열 3(보라) |
| `chart4` | `#0F766E` | `#2DD4BF` | 대비 계열(틸) — **앰버와 계열이 멀어 구분용 색으로도 쓴다**(§위 warning 재배치 참고) |
| `chart5` | `#8B857D` | `#8B857D` | 중립 계열(라이트·다크 동일) |

**코드 (항상 다크, 토글 무관)**
| 토큰 | 값 | 용도 |
|---|---|---|
| `codeEditorBg` | `#1E1E1E` | Monaco 에디터(web 전용, 라이트·다크 공통) |
| `codeLogBg` | `#0D1117` | SSE 실행 로그(라이트·다크 공통) |
| `codeText` | 라이트 `#D4D4D4` / 다크 `#C9D1D9` | 코드/로그 텍스트(유일하게 값이 갈리는 코드 토큰) |

> 모든 상태 칩(활성🟢/경고🟡/정지🔴)은 **색 + 텍스트 레이블 동시** 제공(색만으로 의미 전달 금지 — 색맹 대응).

### 1.1 차트 색

**`chart1~3`은 데이터 계열 색이고 브랜드 액센트가 아니다.** `primary`(앰버)는 브랜드가,
`chart*`는 데이터가 쓴다 — 3-A 시점에는 `chart1`이 `primary`와 값이 같아 둘을 구분할 수
없었고, 그래서 「차트를 `chart1`로 이관」해도 픽셀이 하나도 바뀌지 않았다.

계열 색을 바꿀 때는 `docs/superpowers/specs/2026-08-07-chart-palette-check.py`를 통과해야 한다:

- 배경 대비 ≥ 3:1 (`bg`·`surface` 각각)
- 색각 이상 시뮬 후 계열 간 dE76 ≥ 20 · 계열 간 hue차 ≥ 40°
- `primary`·`success`·`warning`·`danger`·`chart4`·`chart5`와 dE76 ≥ 25
- 계열 간 **명도** 대비는 기록만 한다 — 배경 대비와 동시에 만족할 수 없다(배경이 극단이라
  세 색이 모두 반대쪽 명도대로 몰린다)

`chart4`·`chart5`는 계열이 아니라 **구분용 보조색**이다. 계열이 4개 이상 필요한 화면은 색으로 가르지
말고 축·분할·직접 라벨링을 쓴다 — 색으로 구분 가능한 계열은 3~4개가 한계다. 실제로 주차별
진행률 차트는 12주를 계열이 아니라 **X축**에 둔다.

계열↔의미 매핑은 화면이 정한다(진행률 추세는 `READ`→chart1·`PRACTICE`→chart2·`QUIZ`→chart3).
**키는 서버 enum 원문이라 불변**이고 한국어 라벨만 표시용이다.

**미완료 트랙**(도넛의 미완료 조각·막대의 배경)은 `border`를 쓴다. 면에는 면 토큰(`surfaceMuted`)이
의미론상 맞아 보이지만, 카드(`surface`) 대비가 라이트 **1.14:1** · 다크 **1.08:1**로 `border`
(1.34 · 1.32)보다 낮아 **오히려 덜 보인다**(3-B 육안 확인 실측). 「토큰의 의미가 맞는가」와
「그 배경 위에서 보이는가」는 별개다 — **토큰을 교체할 때는 대비를 함께 계산한다.**

진행이 0%여도 트랙은 그린다. 막대만 그리면 높이가 0이라 화면에서 사라지는데, 경로를 막 만든
사용자는 **모든 주차가 0%**이므로 그것이 첫 화면이 된다.

## 2. 타이포그래피

- **본문/UI**: `Pretendard` (한글+라틴+숫자 일관, 가변폰트). 폴백: `Pretendard → Noto Sans KR → sans-serif`. **기본 Roboto 금지.**
- **코드/고정폭**: `D2Coding` (한글 고정폭). 폴백: `D2Coding → JetBrains Mono → monospace`. Monaco·코드 렌더러·실행 로그에 적용.
- **한글 line-height**: 본문 1.6, 제목 1.3 (한글 글리프는 라틴보다 큰 행간 필요).

Material 3 타입 스케일(Pretendard 적용):
| 스타일 | 크기/행간 | 용도 |
|---|---|---|
| displaySmall | 36/44 | 대시보드 KPI 숫자(예: "7일", "62%") |
| headlineSmall | 24/32 | 화면 제목 |
| titleMedium | 16/24 (w600) | 카드 제목·과제명 |
| bodyMedium | 14/22 (한글 1.6) | 본문 |
| bodySmall | 13/20 | 보조 정보·메타 |
| labelLarge | 14/20 (w600) | 버튼·탭 레이블 |
| titleLarge | 20/28 (w700) | 섹션 제목 |
| titleSmall | 14/20 (w600) | 카드 소제목 |
| labelMedium | 12/16 (w600) | 칩·뱃지 |

> 본문 최소 14px(메타) / 주요 본문 16px. 11px 이하 보조 텍스트는 색 대비 ≥4.5:1 유지.

## 3. 간격 · 라운드 · 고도

- **간격(8pt 그리드)**: `4 · 8 · 12 · 16 · 24 · 32 · 48`. 컴포넌트 내부 패딩 12~16, 섹션 간 16~24.
- **라운드**: 칩 `12` · 버튼 `8` · 카드/패널 `10` · 입력 `8` · 다이얼로그 `12`.
- **고도/그림자**: 장식용 그림자 금지(APP UI). 보더(`border` 토큰) 우선, 그림자는 오버레이(드롭다운·다이얼로그·시트)에만.

**레이아웃 토큰(`AppTokens` — 밝기 무관)**
| 토큰 | 값 | 용도 |
|---|---|---|
| `contentMaxWidth` | 1440 | Large 본문 최대 폭 |
| `readableMaxWidth` | 880 | 문서·상세 읽기 폭 |
| `railWidth` | 256 | 확장 rail 폭 |
| `railCollapsedWidth` | 72 | Medium 접힘 rail 폭 |
| `panelRadius` | 10 | 패널 반경(=카드) |

> 소비: `context.appTokens`. 최대폭 제약은 `DpMaxWidth`, 상태 스타일은 `DpStateStyle`, 클릭 카드 베이스는 `DpInteractiveCard`, 텍스트 선택은 `DpSelectable`, 스크롤바는 `DpScrollbar`. (UI/UX 고도화 로드맵 Phase 0 산출.)

## 4. 아이콘

- **Material Symbols**(Rounded, weight 400) 단일 아이콘셋. `dp_design/icons`에 매핑.
- 와이어프레임의 이모지(하단탭 🏠🗺💬👥🔔 등)는 **전부 Material Symbols로 교체**(플랫폼별 렌더 불일치·AI 슬롭 제거).
- 예외: 스트릭🔥·배지🏅처럼 **감정 강조 1~2곳**만 의도적 이모지 허용(게이미피케이션 신호).

## 5. 반응형 (Material 3 window size class)

| 클래스 | 폭 | web 셸 | SBX(Sandbox) |
|---|---|---|---|
| Compact | <600 | 하단 탭 | 1-페인 탭 전환(에디터/실행/리뷰) |
| Medium | 600–839 | 하단 탭 또는 레일(접힘) | 1-페인 탭 전환 |
| Expanded | 840–1239 | 좌측 내비 레일 | 2-페인(에디터 | 리뷰), 로그 접이식 |
| Large | ≥1240 | 좌측 내비 레일(넓은 본문) | 3-페인(에디터 | 실행로그 | 리뷰) |

- **SBX 규칙**: 데스크톱(≥1024)=3-페인, 모바일웹(<1024)=상단 세그먼트 탭으로 1-페인씩 전환. Monaco는 web 전용 유지(터치 편집 제약 명시). "3열을 그대로 축소" 금지.
- "모바일은 스택" 금지 — 각 뷰포트는 의도적 레이아웃 전환.

## 6. 접근성 베이스라인 (필수)

- **대비**: 본문/링크 텍스트 ≥4.5:1(인디고는 `primaryText`/`primaryTextStrong` 사용), 큰 텍스트·UI 컴포넌트 ≥3:1.
- **터치 타깃**: ≥44×44 (하단탭·아이콘 버튼·칩).
- **키보드**: 전체 포커스 순서·가시 포커스 링(2px `primaryText` + 2px offset)·skip-to-content. **Monaco는 포커스 트랩 → `Esc`로 에디터 탈출** 명시.
- **스크린리더**: 시맨틱 랜드마크(`nav`/`main`/`complementary`), `lang="ko"`. **SSE 실시간 업데이트는 `aria-live="polite"` 영역**(경로생성 단계·실행로그·멘토 스트리밍)에서 고지. 로딩 `aria-busy`, 에러 즉시 announce.
- **상태 전달**: 색만으로 의미 전달 금지(텍스트 레이블 병행).
- **reduced-motion**: `prefers-reduced-motion` 존중 — 스트리밍 shimmer·entrance 모션 비활성화, 즉시 표시로 대체.

## 7. 모션

- **SSE 단계 reveal**: 각 단계 fade+check-in 200ms. reduced-motion=즉시.
- **Skeleton→Content**: `Flutter_Shimmer_Skeleton_Loader` 사용, 150ms 크로스페이드.
- **스트리밍 텍스트**: 토큰 append(문자 단위 애니메이션 금지 — 성능). 멘토/리뷰 스트리밍 동일.
- 모션은 위계·분위기 개선에만. 장식 모션 금지.

## 8. 상태 위젯 (dp_design 공용)

Loading/Empty/Error 외에 다음 전용 상태를 dp_design에 추가:
- **KillSwitch('점검 중')**: AI 기능(`AI_KILL_SWITCH_ACTIVE` 503) 인라인 배너 — 점검 안내 + 대체 행동(캐시 콘텐츠/커뮤니티/저장) 유도.
- **Quota('한도 초과')**: `QUOTA_EXCEEDED` 429 + `Retry-After` 카운트다운 + 업그레이드 안내.
- **SandboxUnavailable**: `SANDBOX_UNAVAILABLE` 503 — 코드 보기는 유지, 실행만 비활성 안내.
- **OfflineBanner**: 오프라인 + 캐시 표시(drift) + 재연결 자동 동기화 고지.
- **SSE 단계 상태**: connecting / streaming(단계별) / partial(중단·단계 보존) / reconnecting / complete / failed.

각 상태는 **사용자가 보는 것** 기준으로 설계: 따뜻한 카피 + 단일 1차 행동 + 맥락. "결과 없음" 같은 빈 문구 금지.

## 9. 셸 구조

화면마다 따로 만들던 `AppBar`를 **잉크 레일 + 크롬바 + 페이지 헤더** 3층 셸로 통일한다
(`DpAppShell`, `packages/dp_design/lib/src/shell/dp_app_shell.dart`). **화면은 `Scaffold.appBar`를
지정하지 않는다** — 제목·브레드크럼·검색·계정 메뉴는 전부 셸이 공급한다.

**3종과 책임**
| 컴포넌트 | 위치 | 책임 |
|---|---|---|
| `DpNavRail` | 좌측 고정 | 목적지 내비게이션. Expanded(256px)/Collapsed(72px) 두 상태, 브랜드·계정 메뉴 슬롯 |
| `DpChromeBar` | 상단(46px) | 브레드크럼 + 검색 트리거 + 화면별 액션 슬롯 |
| `DpPageHeader` | 본문 최상단 | 화면 제목(`headlineSmall`)·설명·1차 액션·필터 슬롯 |

- **레일 섹션 그룹**: `DpNavRail.destinations`는 평면 `List<DpDestination>`이다. 별도 그룹 구조를
  두지 않고, **연속으로 같은 `section` 값을 가진 항목끼리** 렌더 시점에 묶어 레이블을 붙인다
  (`dp_nav_rail.dart`의 `_buildItems`). Expanded 상태는 섹션 레이블 텍스트(`railFaint`)를,
  **Collapsed 상태는 레이블 대신 구분선**(`railBorder`)을 넣는다 — 이번 개편의 유일한 접힘 분기다.
- **크롬바 검색은 명령 팔레트 트리거다.** `DpChromeBar`의 검색 필드는 `TextField`가 아니라
  `onSearchTap`을 호출하는 버튼이며, 실제 입력은 기존 `DpCommandPalette`가 받는다. 입력 상태를
  두 곳에서 관리하지 않기 위한 선택이다.
- **`textFaint`는 구분자·비활성 아이콘 전용이다.** 대비 3.21:1(UI 컴포넌트 기준)이라 읽어야 하는
  텍스트에 쓰지 않는다 — 크롬바 브레드크럼의 `·` 구분자가 유일한 소비처다(§1 참고). 레일 섹션
  레이블처럼 **읽어야 하는 텍스트**는 전용 토큰(`railFaint`, ≥4.5:1)을 쓴다.
- **셸을 쓰는 화면은 `AppBar`를 만들지 않는다.** 제목 3중 노출(앱바 제목 + 브레드크럼 + 본문 제목)을
  막기 위해 화면은 `DpPageHeader`로만 제목을 낸다. `Scaffold` 자체는 화면이 계속 쓸 수 있으나
  `backgroundColor`를 별도로 지정하면 크롬바 아래 색이 셸과 어긋나므로 지정하지 않는다. (`DpAppShell`을
  쓰지 않는 `apps/mobile`은 이 규칙 밖이다 — 기존 `Scaffold.appBar`를 그대로 쓴다.)

### 9.1 페이지 헤더의 스크롤 거동

일관성의 기준은 「모든 화면 동일」이 아니라 **「화면 유형별 동일」** 이다.

- **문서형** — 본문이 스크롤 축을 가지는 화면. 페이지 헤더도 `CustomScrollView`의
  `SliverToBoxAdapter`로 실어 **본문과 함께 스크롤**한다. 크롬바(46px 고정)에
  브레드크럼이 있으므로 헤더가 사라져도 위치를 잃지 않는다.
  (web `dashboard`·`path`·`content`·`mypage`·`settings`, 커뮤니티 `home`·`post_detail`·
  `qna_detail`·`post_create`·`question_create`, admin `dashboard`·`reports`)
- **뷰포트 고정형** — 본문이 남은 높이를 꽉 채우는 화면. 헤더를 **고정**한다.
  (web `mentor`(채팅 + 하단 입력창)·`sandbox`(탭 + 에디터),
  admin `users`·`ads`·`support`(`DpDataTable` 자체 뷰포트))

뷰포트 고정형에서 헤더를 `SliverFillRemaining`으로 감싸면 남은 높이를 전부 차지해
**바깥 스크롤 여지가 0이 되므로 헤더는 결국 고정이다.** 코드만 복잡해지고 결과가 같으므로
하지 않는다.

**문서형으로 전환할 때 함께 지켜야 하는 것**

- 로딩·실패 분기도 sliver 계약을 져야 한다(`SliverFillRemaining`). 비-sliver 자식을 넣으면
  `RenderViewport expected a child of type RenderSliver`로 터진다 — 회귀 테스트의 RED 근거로 쓸 수 있다.
- 스크롤 진행률을 데이터로 쓰는 화면(`content`)은 헤더 높이만큼 축이 길어지므로 보정이 필요하다.
- **`semanticChildCount`를 함께 옮긴다.** `ListView(children:)`·`GridView.count`는 이 값을 자동으로
  채우지만 `CustomScrollView`는 기본 `null`이라, 전환하면 스크린리더가 읽던 「N개 중 X번째」가
  조용히 사라진다. 시각 회귀가 0이라 육안 확인·위젯 테스트 어디에도 걸리지 않는다.
  세는 대상은 화면마다 다르므로(리스트 항목 수 / 본문 1 / 카드 수) 일괄 상수로 때우지 않는다.
- 헤더 스크롤을 검증하는 테스트는 **「본문이 헤더보다 길다」를 산술로 검산**한다.
  필요조건은 줄 수가 아니라 `maxScrollExtent > 헤더 높이`다. 드래그 **전에** 헤더가 실제로
  보이는지도 함께 고정한다 — 그러지 않으면 「헤더가 아예 렌더되지 않는」 회귀가
  `findsNothing` 경로로 조용히 통과한다.

## 10. 출처/샘플 매핑

`dp_design` 구현 시 적용할 Flutter 샘플(플랜 §7 참조): `Flutter_Material3_ThemeExtension_DesignToken`(토큰), `Flutter_EmptyState_빈상태`·`Flutter_Shimmer_Skeleton_Loader`·`Flutter_재사용_다이얼로그_Confirm_Error`(상태위젯).
