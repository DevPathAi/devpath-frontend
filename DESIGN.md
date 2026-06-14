# DESIGN.md — DevPath AI 프론트엔드 디자인 시스템

> 대상: `dp_design`(Material 3) 공용 디자인 시스템 + web/admin/mobile 앱.
> 출처: `/plan-design-review`(2026-06-14) 결정 + 승인된 와이어프레임 방향(인디고/slate/카드).
> 이 문서가 토큰의 단일 출처(Single Source of Truth). 모든 화면 디자인은 여기에 정렬한다.

## 0. 분류 & 원칙

- **앱 셸(web/admin/mobile)** = APP UI: 차분한 surface 위계, 강한 타이포, 적은 색, 최소 chrome. 카드는 "카드가 곧 인터랙션"일 때만.
- **landing(Jaspr)** = MARKETING: 별도 표현형 디자인(본 문서 범위 밖, 토큰만 공유).
- 보편 규칙: CSS/토큰 변수로 색 정의 · 기본 폰트 스택 금지 · 섹션당 한 가지 일 · 카드는 존재 이유 증명 · 본문 ≥16px & 대비 ≥4.5:1.

## 1. 컬러 토큰

프라이머리는 인디고 유지(승인 방향). **단 인디고-500은 흰 배경 대비 ≈3.9:1로 WCAG AA 미달** → 채움(fill)용과 텍스트(text)용 토큰을 분리한다.

| 역할 | 토큰 | 값 | 용도 | 대비(on white) |
|---|---|---|---|---|
| Brand seed | `seedColor` | `#4f46e5` (indigo-600) | `ColorScheme.fromSeed` 시드 | — |
| Primary fill | `primary` | `#6366f1` (indigo-500) | 버튼 배경·진행바·강조 면 | 3.9:1 (면 전용, 텍스트 금지) |
| Primary text/link | `primaryText` | `#4f46e5` (indigo-600) | 링크·강조 텍스트 | ≈5.3:1 ✅ |
| Primary text (small) | `primaryTextStrong` | `#4338ca` (indigo-700) | 12~14px 강조 텍스트 | ≈7:1 ✅ |
| On-primary | `onPrimary` | `#ffffff` | primary fill 위 텍스트 | ✅ |

**Surface (라이트)**
| 토큰 | 값 | 용도 |
|---|---|---|
| `bg` | `#f8fafc` (slate-50) | 본문 배경 |
| `surface` | `#ffffff` | 카드·패널 |
| `border` | `#e2e8f0` (slate-200) | 구분선·카드 보더 |
| `textPrimary` | `#0f172a` (slate-900) | 본문 텍스트 (대비 ✅) |
| `textSecondary` | `#64748b` (slate-500) | 보조 텍스트 (≥4.5:1 ✅) |
| `navDark` | `#1e293b` / `#0f172a` | 좌측 내비 레일(web/admin) |

**Surface (다크)** — 전역 라이트/다크 토글 지원(프로토 범위 포함)
| 토큰 | 값 | 용도 |
|---|---|---|
| `bg` | `#0f172a` | 본문 배경 |
| `surface` | `#1e293b` | 카드·패널 |
| `border` | `#334155` | 구분선 |
| `textPrimary` | `#e2e8f0` | 본문 |
| `textSecondary` | `#94a3b8` | 보조 |
| `primaryText` | `#a5b4fc` (indigo-300) | 다크 위 링크(대비 ✅) |

**코드 surface (항상 다크, 토글 무관)**
| 토큰 | 값 | 용도 |
|---|---|---|
| `codeEditorBg` | `#1e1e1e` | Monaco 에디터(web 전용) |
| `codeLogBg` | `#0d1117` | SSE 실행 로그 |
| `codeText` | `#d4d4d4` / `#c9d1d9` | 코드/로그 텍스트 |

**시맨틱**
| 토큰 | 값 | 용도 | 대비 비고 |
|---|---|---|---|
| `success` | `#16a34a` | 성공·잘한점·캐시 | 텍스트 ✅ |
| `warning` | `#ca8a04` | 경고·보안 주의 | 텍스트 ✅(노랑 #eab308 텍스트 금지) |
| `danger` | `#dc2626` | 에러·밴·정지 | ✅ |
| `info` | `primaryText` | 안내 | ✅ |

> 모든 상태 칩(활성🟢/경고🟡/정지🔴)은 **색 + 텍스트 레이블 동시** 제공(색만으로 의미 전달 금지 — 색맹 대응).

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

> 본문 최소 14px(메타) / 주요 본문 16px. 11px 이하 보조 텍스트는 색 대비 ≥4.5:1 유지.

## 3. 간격 · 라운드 · 고도

- **간격(8pt 그리드)**: `4 · 8 · 12 · 16 · 24 · 32 · 48`. 컴포넌트 내부 패딩 12~16, 섹션 간 16~24.
- **라운드**: 칩 `12` · 버튼 `8` · 카드/패널 `10` · 입력 `8` · 다이얼로그 `12`.
- **고도/그림자**: 장식용 그림자 금지(APP UI). 보더(`border` 토큰) 우선, 그림자는 오버레이(드롭다운·다이얼로그·시트)에만.

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

## 9. 출처/샘플 매핑

`dp_design` 구현 시 적용할 Flutter 샘플(플랜 §7 참조): `Flutter_Material3_ThemeExtension_DesignToken`(토큰), `Flutter_EmptyState_빈상태`·`Flutter_Shimmer_Skeleton_Loader`·`Flutter_재사용_다이얼로그_Confirm_Error`(상태위젯).
