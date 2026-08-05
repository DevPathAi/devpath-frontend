# 디자인 토큰 개편 (T2 잉크·앰버) — 설계

> 작성 2026-08-03 · brainstorming 결과 · 후속 = writing-plans
> 범위: **토큰 계층만.** 화면 구조(레일·상단바·카드 위계) 개편은 후속 단계다.

DevPath의 색·타이포 토큰을 역할 기반으로 재구성하고, 팔레트를 인디고/slate에서 **잉크·앰버(T2)** 로 교체한다.

## 1. 왜 색 교체만으로는 부족한가

사용자 평가는 네 가지였다: **개성 없음 · 위계 밋밋 · 페이지마다 따로 놈 · 미완성 화면 많음.**

전 16개 라우트를 빌드해 캡처·검토한 결과, 원인이 팔레트가 아니라 **토큰 구조**에 있음을 확인했다.

현재 `DpColors`는 15개 토큰이고 **면(surface)이 하나뿐**이다. 그래서 카드·팝오버·비활성 영역·사이드바가 전부 같은 흰색으로 렌더된다. 깊이가 생길 수 없다. 차트도 `primary` 한 색만 쓴다. 참고로 shadcn/ui는 foreground 쌍 구조로 20개 이상을 두고 `card`·`popover`·`muted`·`accent`·`sidebar-*`·`chart-1~5`를 각각 분리한다.

**이 구조 변경이 색 선택보다 화면에 미치는 영향이 크다.**

### 실측으로 확인한 결함

| 결함 | 근거 |
|---|---|
| 목 픽스처 누락으로 3개 화면이 에러 | `/settings` · `/mypage` · `/content/:id` |
| 개발자 원문이 사용자에게 노출 | `no mock: GET /consents/me` 가 그대로 화면에 |
| 타입 스케일 미정의 3종 | `titleLarge` · `titleSmall` · `labelMedium` → Material 기본값(한글 행간 1.6 미적용) |
| 경로 화면 제목 중복·불일치 | 앱바 "학습 경로 생성" + 본문 "학습 경로" |

> ⚠️ 이 범위에서 **해결되지 않는 것**: 대시보드 Bento 그리드의 L자 빈 구멍, 경로 화면에 카드가 하나도 없는 문제, 레일 하단 700px 공백. 전부 레이아웃 문제이며 후속 단계로 넘긴다. 사용자가 "토큰만 먼저"를 선택했다.

## 2. 팔레트 — T2 잉크·앰버

프리뷰 14안 × 4구간 × 라이트/다크 = 112건을 비교해 선정했다. **라이트가 기본**, 다크는 같은 토큰을 재정의해 파생한다.

방향: 따뜻한 무채색 그라운드에 앰버 하나. 액센트가 드물게 등장할수록 강해진다는 원리를 그대로 쓴다. **앰버는 "성취"를 전담**한다 — 진행률·스트릭·1차 행동.

선정 근거(탈락안 대비):
- **L1 크림·코럴**: 개성은 가장 강하나, 이 앱은 Monaco·실행 로그·코드 렌더러가 **항상 다크**라 크림 배경과 큰 대비를 이룬다. 화면이 두 세계로 쪼개진다.
- **T5 카본·블루**: 대비와 접근성은 가장 좋으나 인디고→블루는 계열 이동이라 "개성 없음" 지적에 가장 소극적인 답이다.

## 3. 토큰 구조

### 3.1 신규 · 변경 목록

```
[면] 3단계 — 현재 surface 하나
  bg            본문 배경
  surface       카드·패널          (기존)
  surfaceMuted  비활성·보조 면      ★신규
[텍스트] 3단계 — 현재 2단계
  textPrimary   본문               (기존)
  textSecondary 보조               (기존, 최다 사용 55회)
  textFaint     메타·캡션          ★신규
[사이드바] 전용 — 현재 없음(본문과 같은 취급)
  railBg · railText · railMuted · railFaint · railActive · railBorder   ★신규 6
[액센트]
  accent        채움 전용          (기존 primary 를 개명하지 않고 유지)
  onAccent      채움 위 텍스트      (기존 onPrimary)
  accentText    링크·강조 텍스트    (기존 primaryText)
  accentSoft    연한 배경          ★신규
  accentLine    연한 보더          ★신규
[차트] — 현재 primary 하나로만 그림
  chart1 ~ chart5                                                      ★신규 5
[태그]
  tagBg · tagText                                                      ★신규 2
[유지] border · success · danger · warning · codeEditorBg · codeLogBg · codeText
```

**기존 토큰명을 하나도 바꾸지 않는다.** `primary`·`primaryText`·`primaryTextStrong`·`onPrimary`는 이름을 유지하고 값만 교체한다. `dpColors`를 쓰는 **47개 파일을 건드리지 않고** 팔레트가 바뀐다. 신규 토큰은 추가만 한다.

> `primary`라는 이름이 앰버를 가리키는 것이 어색하지만, 개명하면 47개 파일이 diff에 들어와 리뷰가 불가능해진다. 개명은 후속 단계에서 화면 작업과 함께 한다.

### 3.2 라이트 (기본)

| 토큰 | 값 | 용도 |
|---|---|---|
| `bg` | `#FAF9F7` | 본문 배경(따뜻한 무채색) |
| `surface` | `#FFFFFF` | 카드·패널 |
| `surfaceMuted` | `#F2F0EC` | 비활성·보조 면·검색 입력 |
| `border` | `#E2DED7` | 구분선 |
| `textPrimary` | `#1A1815` | 본문 |
| `textSecondary` | `#615C54` | 보조 (대비 6.30:1 ✅) |
| `textFaint` | `#918B81` | 메타 (대비 3.21:1 — **UI 컴포넌트 기준 3:1 통과. 본문 텍스트로 쓰지 않는다**) |
| `railBg` | `#1A1815` | 사이드바 배경 |
| `railText` | `#F2F0EC` | 사이드바 활성·브랜드 |
| `railMuted` | `#A9A298` | 사이드바 비활성 항목 |
| `railFaint` | `#9C958B` | 사이드바 섹션 레이블 (대비 5.98:1 — 2026-08-05 Task 12에서 3.95:1→상향) |
| `railActive` | `#2F2B24` | 사이드바 활성 배경 |
| `railBorder` | `#2B2823` | 사이드바 내부 구분선 |
| `primary`(=accent) | `#B45309` | 버튼 배경·진행바 (**면 전용**) |
| `onPrimary` | `#FFFFFF` | 채움 위 텍스트 |
| `primaryText` | `#92400E` | 링크·강조 텍스트 (대비 6.74:1 ✅) |
| `primaryTextStrong` | `#78350F` | 12~14px 강조 (대비 9.07:1 ✅) |
| `accentSoft` | `#FDF1E0` | 1차 카드 배경·뱃지 |
| `accentLine` | `#F2D0A0` | 1차 카드 보더 |
| `success` | `#15803D` | 성공·해결됨 |
| `warning` | `#A16207` | **진짜 경고만**(§4) |
| `danger` | `#B91C1C` | 에러·삭제 |
| `tagBg` | `#F2F0EC` | 태그 배경 |
| `tagText` | `#524D45` | 태그 텍스트 |
| `chart1` | `#B45309` | 강조 계열 |
| `chart2` | `#F2D0A0` | 보조 계열 |
| `chart3` | `#78350F` | 3계열 |
| `chart4` | `#0F766E` | 대비 계열(틸) |
| `chart5` | `#8B857D` | 중립 계열 |
| `codeEditorBg` | `#1E1E1E` | (유지) |
| `codeLogBg` | `#0D1117` | (유지) |
| `codeText` | `#D4D4D4` | (유지) |

### 3.3 다크 (파생)

| 토큰 | 값 |
|---|---|
| `bg` | `#0F0E0C` |
| `surface` | `#1A1815` |
| `surfaceMuted` | `#231F1B` |
| `border` | `#332E28` |
| `textPrimary` | `#EAE7E2` |
| `textSecondary` | `#A09991` |
| `textFaint` | `#6F6961` |
| `railBg` | `#131210` |
| `railText` | `#EAE7E2` |
| `railMuted` | `#948D85` |
| `railFaint` | `#8A837B` |
| `railActive` | `#231F1B` |
| `railBorder` | `#2A2621` |
| `primary`(=accent) | `#F59E0B` |
| `onPrimary` | `#1A1200` |
| `primaryText` | `#FBBF24` |
| `primaryTextStrong` | `#FCD34D` |
| `accentSoft` | `#2E2007` |
| `accentLine` | `#5C400E` |
| `success` | `#4ADE80` |
| `warning` | `#FCD34D` |
| `danger` | `#F87171` |
| `tagBg` | `#231F1B` |
| `tagText` | `#A09991` |
| `chart1` | `#F59E0B` |
| `chart2` | `#78350F` |
| `chart3` | `#FCD34D` |
| `chart4` | `#2DD4BF` |
| `chart5` | `#8B857D` |
| `codeEditorBg` · `codeLogBg` | (유지) |
| `codeText` | `#C9D1D9` |

> 다크의 `onPrimary`가 `#1A1200`(어두운 갈색)인 이유: 앰버 `#F59E0B` 위에 흰 텍스트를 얹으면 대비가 2.2:1로 미달한다. 어두운 텍스트를 써야 10:1을 넘는다. **라이트와 다크의 `onPrimary`가 반대 방향**이라는 점이 이 팔레트의 유일한 함정이다.

## 4. ★앰버 ↔ 경고 충돌 — 의미 재배치로 해소

앰버를 액센트로 쓰면 기존 `warning`(#CA8A04)과 색상환에서 겹친다. **처음에는 `warning` 토큰 제거를 제안했으나, 실측 결과 9회·10개 파일에서 쓰이고 있어 부적절함이 드러났다.**

대신 쓰임을 셋으로 갈라 재배치한다.

| 부류 | 현재 위치 | 조치 |
|---|---|---|
| **서비스 상태**(사용자 잘못 아님) | `DpKillSwitch`("AI 기능이 잠시 점검 중이에요") · `DpQuota` · `DpSandboxUnavailable` · `DpOfflineBanner` | `textSecondary` 기반 **중립**으로 이동 |
| **구분용 색**(의미 없음) | 커뮤니티 `FEEDBACK` 보드색(2) · 경로 약점 태그(2) · admin 신고 카테고리 칩(1) | `chart4`(틸) 또는 `tagBg/tagText`로 이동 |
| **진짜 경고** | `review_panel.dart:80` severity `'warning'`(백엔드 계약값) | `warning` 유지 |

재배치 후 `warning`은 **한 곳만 남는다.** 액센트와 나란히 등장할 일이 사실상 사라져 충돌이 실질적으로 해소된다.

`warning` 값은 라이트 `#A16207`로 유지한다(액센트 `#B45309`보다 채도가 낮고 명도가 높아 나란히 놓아도 구분된다).

## 5. 타입 스케일 보완

현재 6종만 정의돼 `titleLarge`·`titleSmall`·`labelMedium`이 Material 기본값으로 떨어진다(한글 행간 1.6 미적용). 3종을 추가한다.

| 스타일 | 크기/행간 | 용도 | 현재 사용처 |
|---|---|---|---|
| `titleLarge` | 20 / 28 (w700) | 섹션 제목 | 1곳 |
| `titleSmall` | 14 / 20 (w600) | 카드 소제목 | 4곳 |
| `labelMedium` | 12 / 16 (w600) | 칩·뱃지 | 2곳 |

`fontFamily`는 이미 `ThemeData`에 전역 설정돼 있어 미정의 스타일도 Pretendard로 렌더된다 — 문제는 폰트가 아니라 **크기·행간**이다.

## 6. 함께 고칠 결함

토큰과 무관하지만 작고 독립적이며, "미완성 화면이 많다"는 지적의 실체다.

### 6.1 목 픽스처 3건

`web_mock_fixtures.dart`에 추가한다. 목 모드가 기본값(`USE_MOCK=true`)이라 이 픽스처가 없으면 화면이 에러로 뜬다.

- `GET /consents/me` — 설정
- `GET /users/me/profile` — 마이페이지
- `POST /contents/:id/progress` — 학습 콘텐츠

### 6.2 개발자 원문 노출 차단

`MockHttpAdapter`가 픽스처 미등록 시 `no mock: GET /consents/me`를 `error.message`에 실어 보내고, 그 문자열이 그대로 사용자 화면에 렌더된다.

**조치**: 메시지를 사용자용 카피로 바꾸고, 원문은 `code`에만 남긴다. 프로토 진단이 필요하므로 `assert`로 콘솔에는 계속 출력한다.

### 6.3 경로 화면 제목 중복

`path_page.dart`가 앱바에 "학습 경로 생성", 본문에 "학습 경로"를 동시에 렌더한다. 본문 제목을 제거하고 앱바 제목을 "학습 경로"로 통일한다.

## 7. 마이그레이션 전략 — 무회귀가 최우선

`dpColors`는 **47개 파일**에서 쓰인다. 사용 빈도 실측:

```
textSecondary 55 · border 18 · surface 15 · primary 15 · success 11
danger 11 · primaryText 10 · warning 9 · textPrimary 4 · onPrimary 3 · bg 2
```

**전략: 기존 이름 유지 + 신규 추가.** 값만 바뀌므로 47개 파일 중 §4 재배치 대상 10곳만 수정된다.

`DpColors`는 `ThemeExtension`이라 필드 추가 시 `copyWith`·`lerp`도 함께 갱신해야 한다. 셋이 어긋나면 테마 전환 애니메이션에서 일부 토큰이 튄다.

## 8. 테스트 전략

- **대비 검증 테스트**(신규): 라이트·다크 각각에서 텍스트/배경 조합의 WCAG 대비를 계산해 단언한다. `textPrimary`/`textSecondary`/`primaryText` on `bg`·`surface`는 ≥4.5:1, `onPrimary` on `primary`는 ≥4.5:1, `textFaint`·`railFaint`는 ≥3:1. **다크의 `onPrimary`가 어두운 색이라는 반전**을 이 테스트가 지킨다.

> ✅ **이 팔레트는 실측으로 검증했다.** 스펙 작성 중 17개 조합 × 라이트·다크 = **34건을 계산해 미달 0건**을 확인했다(2026-08-03). 가장 여유가 적은 것은 라이트 `warning` on `surface` **4.92:1**, 다음이 `textFaint` on `bg` **3.21:1**이다. 이 둘은 값을 조정할 때 특히 주의한다. 최초 초안에 적었던 수치는 추정이었고 실측과 달라 전부 교체했다.
- **토큰 3종 일관성 테스트**: `DpColors`의 필드 수와 `copyWith`·`lerp`가 다루는 필드 수가 같은지 단언한다(리플렉션 대신 명시적 목록 비교).
- **타입 스케일 테스트**: 추가한 3종이 `null`이 아니고 지정한 크기·행간을 갖는지.
- **골든 테스트는 이번 범위에서 갱신만** 한다(팔레트가 바뀌므로 전부 리베이스 필요). 새 골든을 추가하지 않는다.
- 기존 5패키지 스위트(web 291 · dp_core 88 · dp_design 61 · admin 50 · mobile 100)가 **전부 통과**해야 한다.

## 9. 작업 순서

```
dp_design 토큰(DpColors 확장 + 값 교체 + DpTypography 3종)
  └─→ dp_design 상태위젯 warning 재배치(4곳)
        └─→ web·admin warning 재배치(5곳) + 결함 수정 3건
              └─→ 골든 리베이스 + 전 스위트 확인
                    └─→ DESIGN.md 갱신
```

`dp_design`이 임계 경로다. 앱은 토큰을 소비만 하므로 그 뒤는 병렬 가능하다.

## 10. 범위 밖 (후속 단계)

- **레이아웃 구조**: 레일 섹션 구분·브랜드 로고, 상단바 브레드크럼, 대시보드 Bento 그리드 재배치, 경로 화면 카드화, 커뮤니티 목록 미리보기·메타
- `primary` → `accent` 토큰 개명(47개 파일 파급)
- 커뮤니티 FAB의 데스크톱 대체 패턴
- admin 앱 별도 검토(이번엔 web과 같은 토큰을 그대로 받는다)

> 이 범위만으로는 **"위계가 밋밋하다"와 "페이지마다 따로 논다"가 해결되지 않는다.** 색은 바뀌지만 대시보드의 L자 빈 구멍과 경로 화면의 카드 부재는 그대로 남는다. 사용자가 단계적 진행을 선택했고, 1단계 머지 후 실제 화면을 다시 보고 2단계 범위를 정한다.

## 11. 검증 방법

- `melos run analyze` · `melos run format` · `melos run test` 5패키지 green
- **web 재빌드 후 전 라우트 재캡처**하여 1단계 전/후를 나란히 비교한다(이번 세션의 캡처 스크립트 재사용)
- 라이트·다크 각각에서 대시보드·커뮤니티·경로·설정을 육안 확인
