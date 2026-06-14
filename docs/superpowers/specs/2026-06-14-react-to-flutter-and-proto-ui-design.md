# React → Flutter 전환 & web/admin/mobile 프로토 UI 설계

> 작성일: 2026-06-14 · 대상: `devpath-frontend` 모노레포 · 상태: 설계 승인 + 디자인 리뷰 반영(완성도 5/10→8/10)
> 제품: **DevPath AI** — 한국 개발자 대상 AI 학습 플랫폼(AI-LMS)
> 디자인 시스템 SSoT: [`DESIGN.md`](../../../DESIGN.md) · 디자인 리뷰 요약: [`2026-06-14-design-review-summary.md`](./2026-06-14-design-review-summary.md) · 디자인 결정(DD1~DD8)·상태 매트릭스·반응형·a11y는 본 문서 §9~§13.

## 0. 배경 & 확인된 사실

- 현재 `web`/`admin`은 **Vite + React 19 기본 스캐폴드**(제품 코드 없음), `mobile`은 **Flutter 기본 카운터 데모**. → 전환할 React 비즈니스 로직이 사실상 없음.
- 따라서 본 작업은 "React 코드 포팅"이 아니라 **프론트 스택을 Flutter/Dart로 통일하는 신규 구축 결정 + 프로토 UI 구축**이다.
- 점진적 스트랭글러 전환은 **이점이 없어 제외**(버릴 React 코드가 없음).
- 화면·기능·API 정의는 외부 public 레포 `DevPathAi/documents`, `DevPathAi/storyboard`에 존재(이 레포엔 없음). 본 스펙은 그 문서들에서 추출한 사실에 근거한다.

### 출처 문서 (DevPathAi/documents)
`01_프로젝트_계획서`, `02_ERD_문서`, `03_프로젝트_아키텍처_정의서`, `04_API_명세서`, `05_화면_흐름_시퀀스`, `06_화면_기능_정의서`, `07_요구사항_정의서`, `08_스토리_보드`, `10_환경_설정_템플릿`, `27_MVP_설계서`; `storyboard/storyboard.html`.

## 1. 핵심 결정 사항 (승인됨)

| # | 결정 | 선택 | 근거 |
|---|------|------|------|
| D1 | 통합 수준 | **공유 패키지 + 앱 3개 분리** (melos 모노레포) | 재사용과 관심사 분리 균형 |
| D2 | 전환 아키텍처 | **B′ — Flutter 앱 + Jaspr(Dart) 랜딩, 100% Dart** | Flutter 공식 SEO 권장안. 랜딩만 분리해 SEO·로딩 최적화하면서 Dart 단일 언어 유지 |
| D3 | 화면 로직 위치 | **앱별 소유** (공용 `dp_features` 레이어 없음) | 의존 그래프 단순화, 각 앱이 UX 완전 소유 |
| D4 | 마크다운/코드 렌더러 | **`dp_design` 공용** | web 콘텐츠 뷰어 + mobile 캐시 열람 공유 |
| D5 | 프로토 수준 | **목 API 연동 프로토** | 네비게이션 + 가짜 응답으로 SSE·에러처리까지 실제 흐름 검증 |
| D6 | 프로토 범위 | **골든 패스 + surface별 대표 화면** | YAGNI — 28개 전부 대신 아키텍처 증명에 필요한 화면 |

### B′ 결정의 공식 문서 근거 (Flutter docs, Context7 확인 2026)
- Flutter Web은 검색엔진 색인에 최적화되지 않음 → **정적/문서형은 Jaspr(Dart) 사용 또는 주 앱과 SEO 랜딩 분리** 권장.
- 렌더러: canvaskit / skwasm(`flutter build web --wasm`). 초기 다운로드·SEO 약점 → 공개 랜딩만 분리해 회피.
- Monaco 임베드: `HtmlElementView` + `registerViewFactory`(공식 메커니즘)로 Flutter Web에 실제 Monaco 임베드 가능. Sandbox는 web MVP 전용이라 모바일 영향 없음.

## 2. 모노레포 구조 & 스택

```
devpath-frontend/
├─ melos.yaml                  # 모노레포 오케스트레이션
├─ pubspec.yaml                # workspace 루트 (Dart workspaces)
├─ packages/
│  ├─ dp_core/                 # ❶ 도메인·데이터 (UI 없음, 순수 Dart)
│  │   ├─ models/              #   엔티티/DTO + enum 백엔드 1:1 매핑 (freezed + json_serializable)
│  │   ├─ api/                 #   dio ApiClient, 엔드포인트 서비스, 커서 페이지네이션 Page<T>
│  │   ├─ sse/                 #   SseClient(POST+stream): 경로생성/멘토/Sandbox 로그
│  │   ├─ auth/                #   TokenStore(추상) + 401 큐잉 갱신 인터셉터
│  │   └─ error/               #   ApiException{code,message,traceId} + HTTP→예외 매핑
│  └─ dp_design/               # ❷ 디자인 시스템 (Material 3, 도메인 모름) — 토큰 SSoT=DESIGN.md
│      ├─ theme/               #   ThemeExtension 토큰(인디고 fill/text 분리·Pretendard/D2Coding·8pt·라운드), 라이트+다크 (DD1·DD2·DD6)
│      ├─ components/          #   버튼·입력·카드·차트·마크다운/코드 렌더러 + 상태위젯(Loading/Empty/Error + KillSwitch/Quota/SandboxUnavailable/Offline/SSE단계)
│      └─ icons/               #   Material Symbols 단일셋 (DD3)
├─ apps/
│  ├─ web/                     # 사용자 Flutter Web (로그인 이후 전 화면)
│  ├─ admin/                   # 관리자 Flutter Web (테이블·대시보드·모더레이션)
│  └─ mobile/                  # Flutter iOS/Android (기존 mobile/ 이전·정리)
└─ landing/                    # Jaspr (Dart) — 공개 랜딩, SEO·정적, 앱과 무상태 분리
```

**의존 규칙(단방향)**: `apps → {dp_core, dp_design}`, 그리고 `dp_core ⊥ dp_design`(상호 독립). `dp_design`은 `dp_core`를 의존하지 않으며, 앱이 모델→위젯 매핑을 담당.

### 스택 (전 앱 공통)
| 관심사 | 선택 | 근거 |
|--------|------|------|
| 상태관리 | **Riverpod** | 문서가 mobile에 지정 → 전 앱 통일 |
| 라우팅 | **go_router** | URL 라우팅·딥링크·온보딩 게이트(redirect) |
| HTTP | **dio** | 인터셉터로 토큰 갱신·에러 매핑·429 재시도 |
| SSE | dio + Stream 자체 클라이언트 | 경로생성/멘토/Sandbox 로그 |
| 모바일 로컬 | **drift** | 오프라인 캐시 |
| 코드에디터 | web만 **Monaco**(HtmlElementView) | Sandbox web MVP 전용 |
| 모노레포 | **melos** + Dart workspaces | 패키지·스크립트 일괄 |
| 랜딩 | **Jaspr** | Flutter 공식 SEO 권장, Dart 유지 |

### 앱별 구성 (feature-first, 화면 로직 앱별 소유)
- 각 feature = `presentation`(위젯) + `application`(Riverpod ViewModel) + `state`(불변 상태). 데이터·모델은 `dp_core`.
- **web**: 반응형 셸 — <840 하단탭 / ≥840 좌측 내비 레일(§9.3). 라우터 redirect 게이트. **SBX는 ≥1240 3-페인 / 840–1239 2-페인(로그 접이) / <1024 1-페인 세그먼트 탭**(DD5). `MonacoView`는 web 전용(터치 편집 제약 명시).
- **admin**: 좌측 영구 내비 + 데이터테이블 중심. `ADMIN`/`OWNER` 역할 가드.
- **mobile**: 하단 5탭 셸(StatefulShellRoute). 전용 화면 = 알림센터/오프라인/딥링크. drift 캐시 + FCM + `devpath://` 딥링크.
- **landing**: Jaspr 정적 생성, SEO 메타·OG·데모영상, CTA→web 앱. 앱과 상태 공유 없음.

> 디자인 토큰·타이포·아이콘·반응형·접근성·다크모드·상태 매트릭스의 단일 출처는 [`DESIGN.md`](../../../DESIGN.md)와 본 문서 §9. 본 절 컴포넌트는 그 토큰에 정렬한다. (Roboto 기본폰트 금지 → Pretendard/D2Coding, 이모지 → Material Symbols)

## 3. 데이터 흐름 & 에러 처리

- **목 서버**: `ApiClient`에 dio `MockAdapter`(JSON 픽스처) 주입. **SSE 목**은 단계별 `Stream` emit(딜레이)으로 스트리밍 UX 재현. 목/실서버 토글 = 환경변수(`baseUrl`).
- **인증**: OAuth(목) → JWT access 30분/refresh 14일 → 401 시 dio 인터셉터가 `/auth/refresh` 큐잉 재시도 → `TokenStore`(web=httpOnly 쿠키/메모리, mobile=`flutter_secure_storage`).
- **게이트**: go_router `redirect` — 미인증→로그인, `ONBOARDING_INCOMPLETE(403)`→온보딩.
- **에러**: 공통 포맷 `{error:{code,message,trace_id,timestamp}}` → `ApiException` 매핑 → `dp_design` 상태 위젯. 특수 분기는 **전용 상태 위젯으로 처리**(DD4, 상태 매트릭스 §9.2): `AI_KILL_SWITCH_ACTIVE(503)`→KillSwitch '점검 중' 배너 + 대체 행동(캐시 열람/커뮤니티/저장), `QUOTA_EXCEEDED(429)`→Quota + `Retry-After` 카운트다운, `SANDBOX_UNAVAILABLE(503)`→실행만 비활성·코드 편집 유지.
- **SSE 중단 복구(DD8)**: 네트워크 끊김·60s 타임아웃 시 **완료 단계를 보존하고 끊긴 지점부터 재연결·이어하기**(전체 재시작 금지). `SseClient`가 단계 상태(connecting/streaming/partial/reconnecting/complete/failed)를 노출하고, 1st Aha 경로 생성·멘토 스트리밍이 이를 구독.
- **페이지네이션**: 커서 기반 `Page<T>{data,nextCursor,limit}`(limit 20/최대 100). 비동기 결과(AI 리뷰/시드답변)는 폴링/알림 후 조회.

### 백엔드 의존 요약 (core 모델 설계 기준)
- 스택: Spring Boot, PostgreSQL+pgvector, Redis, Kafka(Outbox). Base URL `…/api/v1`, JSON UTF-8.
- 통신: REST + **SSE**(`text/event-stream`, 권장 타임아웃 60s). WebSocket 명시 없음. 모바일 푸시 FCM.
- 권한 역할: `PUBLIC/AUTHENTICATED/LEARNER/PRO/ADMIN/OWNER` (+ 커뮤니티 평판 게이트).
- 환경변수: web `VITE_API_BASE_URL` 등 / mobile `--dart-define`(`API_BASE_URL`, dev 에뮬 `10.0.2.2:8080`) / `FCM_PROJECT_ID`.
- **enum 동기화 주의**: track/role/board_type/status 등 다수 enum을 백엔드와 1:1 매핑하고 unknown 값 방어.

## 4. 프로토 UI 범위 (확정)

### web — 골든 패스 (1st→2nd Aha)
랜딩(Jaspr) → OAuth(목) → 온보딩·진단(ONB-001/002) → **학습경로 SSE 생성(PATH-001)** → 콘텐츠 뷰어(CNT-001) → **Sandbox+Monaco(SBX-001)** → AI 코드리뷰(REV-001) → **AI 멘토 SSE(MEN-001)** → 대시보드(DASH-001) → 커뮤니티 홈/Q&A상세(COM-001/003)
- 증명: 인증·온보딩 게이트 · SSE 3종 · Monaco 임베드 · 마크다운 렌더 · 목 API · 로딩/빈/에러

### admin — 대표 3화면
운영 대시보드(A-004) · 사용자 관리·제재(A-002) · 신고 처리(A-006)
- 증명: 데이터테이블·필터·커서페이지네이션 · 차트 · 역할 가드

### mobile — 셸 + 대표 3화면
하단탭 셸 + 대시보드(DASH) + 알림센터(M-NTF-001) + 오프라인(M-OFF-001)
- 증명: StatefulShellRoute 탭 · drift 캐시 · FCM 스텁 · 딥링크

### 승인된 와이어프레임 방향
- **web 셸**: 데스크톱 좌측 내비 레일 + 카드형 대시보드(스트릭/진행률/다음과제 단일 CTA/배지).
- **PATH-001**: SSE 4단계 생성 로딩 → 12주 타임라인 + 이번 주 과제 3개 + 멘토 rationale.
- **SBX-001**: 반응형(≥1240 3-페인: Monaco 에디터 | SSE 실행로그 | AI 리뷰 / 840–1239 2-페인+로그 접이 / <1024 1-페인 세그먼트 탭 — DD5). AI 리뷰: 신뢰도·잘한점·개선(라인·심각도)·보안 + 피드백·멘토질문.
- **admin**: 좌측 영구 내비 + 검색/필터 + 테이블 + 우측 상세·제재 패널(경고/7일/30일/밴).
- **mobile**: 하단 5탭(홈/경로/멘토/커뮤니티/알림), 알림센터, 오프라인(drift 캐시·재연결 동기화).

> 와이어프레임 원본: `.superpowers/brainstorm/sess1/content/web-wireframes.html`, `admin-mobile-wireframes.html`.
> 전체 MVP 화면 목록은 부록 A 참조 — 동일 패턴으로 확장.
>
> **프로토는 전역 라이트/다크 토글 포함(DD6)**, 접근성 베이스라인 적용(DD7, §9.4). 화면별 상호작용 상태(Loading/Empty/Error/Success/Partial)는 §9.2 상태 매트릭스를 따른다.

## 5. 테스트 전략 (CLAUDE.md 절대조건 2: Test-First)

> **CLAUDE.md 갱신 필요**: CLAUDE.md의 "Vitest + React Testing Library 설정" 지침은 React 기준이며, Flutter 전환으로 **무효화**된다. 아래 Flutter 테스트 스택으로 대체하고 CLAUDE.md를 갱신한다.

| 레이어 | 테스트 | 도구 |
|--------|--------|------|
| `dp_core` 모델/매핑/에러 | 유닛(JSON 직렬화, enum unknown 방어, 에러 매핑) | `test`(순수 Dart), `mocktail` |
| `dp_core` api/sse/auth | 유닛(목 어댑터: 인터셉터·SSE 파싱·토큰 갱신) | `test`, `mocktail`, dio MockAdapter |
| `dp_design` 위젯 | 위젯 + golden 테스트(상태위젯·폼·버튼) | `flutter_test` |
| 앱 feature | ViewModel 유닛 + 화면 위젯 테스트(Riverpod override) | `ProviderContainer` override |
| 골든 패스 | 통합 테스트(목 서버 Aha 플로우 E2E) | `integration_test` |

**워크플로**: 기능마다 실패 테스트 먼저 → 최소 구현 → `melos run test`로 통과 눈으로 확인(조건 2·3).

**디자인 리뷰 반영 추가 테스트**
- **다크 변형(DD6)**: 골든 화면·상태 위젯은 라이트/다크 2벌 golden 테스트 → **golden 수 약 2배**(구축 §6 일정 반영).
- **신규 상태 위젯(DD4·§9.2)**: KillSwitch·Quota·SandboxUnavailable·Offline·SSE단계 각각 위젯 테스트(카피·1차행동·맥락 검증).
- **SBX 반응형(DD5)**: 375 / 1024 / 1240px 위젯 테스트로 페인 전환 확인.
- **SSE 중단(DD8)**: 목 SSE 중간 중단 주입 → 완료 단계 유지 + 재연결·이어하기 통합 테스트.
- **a11y(DD7)**: 대비 토큰 단위 테스트, Monaco `Esc` 탈출 · SSE `aria-live` 수동 검증.

## 6. 구축 단계 (점진, 각 단계 테스트 동반)

1. **모노레포 골격**: melos + workspace, 빈 `dp_core`/`dp_design`/`apps/*`/`landing`, CI(`melos analyze/test`). 기존 `web`/`admin` 스캐폴드 제거, `mobile/` → `apps/mobile/` 이전.
2. **`dp_core`**: 모델·enum·`ApiClient`·`SseClient`·`auth`·`error` + 목 어댑터 (테스트 우선).
3. **`dp_design`**: 테마 토큰·상태위젯·폼·마크다운/코드 렌더러 (위젯·golden 테스트).
4. **web 골든패스**: 셸+라우팅 게이트 → 진단 → PATH(SSE) → 콘텐츠 → Sandbox(Monaco) → 리뷰 → 멘토(SSE) → 대시보드 → 커뮤니티.
5. **admin 대표 3화면**: 셸 → 사용자관리 → 운영대시보드 → 신고처리.
6. **mobile 셸 + 대표 3화면**: 하단탭 → 대시보드 → 알림 → 오프라인(drift).
7. **landing(Jaspr)**: SEO 랜딩 → web 앱 연결.
8. **통합 테스트 + 목/실서버 토글 정리**.

> **디자인 리뷰 태스크 매핑(§12 T1~T7)**: 3단계(dp_design)에 **T1**(토큰 ThemeExtension 라이트+다크)·**T2**(신규 상태위젯)·**T6**(Material Symbols 교체); 4단계(web)에 **T3**(SBX 반응형)·**T5**(SSE 이어하기)·**T7**(빈상태 카피·1차행동); 전 단계 공통 **T4**(a11y 베이스라인). **다크모드(DD6)로 golden 테스트 약 2배** — 3단계 이후 일정에 반영.
> **착수 전 게이트(필수)**: DD5(반응형)·DD6(다크 전역 토글)·DD8(SSE 재연결)은 아키텍처 영향 → 구현 착수 전 `/plan-eng-review` 실행 권장(리뷰 리포트 VERDICT, §13 하단).

## 7. 참고 샘플 코드 매핑

> 경로: `D:\workspace\develop-study-documents\Sample Codes` (Flutter 샘플 .md 모음). **구현 단계에서 각 파일 내용을 읽어 적용**한다(파일명 기준 매핑).

**dp_core**
- auth → `Flutter_Dio_Bearer_Auth_QueuedInterceptor_401_Refresh`, `Flutter_Sealed_AuthState_Riverpod_KeepAlive_인증`
- api → `Flutter_API_Client_지수백오프_재시도`, `Flutter_Service_Base_제네릭_응답파싱`, `Flutter_Repository_FutureProvider_Family_PageResponse_페이지네이션`, `Flutter_AsyncBodyBuilder_제네릭_비동기_빌더`
- sse → `Flutter_SSE_실시간_스트림_구독`
- error → `Flutter_Sealed_Class_예외계층_DioException_매퍼`, `Flutter_예외계층_에러코드매핑`, `Flutter_도메인_예외계층_AppException`
- models → `Flutter_불변_모델_copyWith_JSON직렬화`, `Flutter_Dart3_Record_반환_NotifierProvider`

**dp_design**
- theme → `Flutter_Material3_ThemeExtension_DesignToken`
- 상태 위젯 → `Flutter_EmptyState_빈상태`, `Flutter_Shimmer_Skeleton_Loader`, `Flutter_재사용_다이얼로그_Confirm_Error`
- 폼/입력 → `Flutter_커스텀_텍스트필드`, `Flutter_Generic_커스텀_드롭다운/라디오그룹`, `Flutter_Enum_Props_커스텀_버튼_로딩`, `Flutter_FormWrapper`, `Flutter_SnackBar_폼제출_피드백`, `Flutter_StatefulWidget_폼_유효성검증_DatePicker`
- 리스트/레이아웃 → `Flutter_GridView_반응형_카드`, `Flutter_리스트_아이템_카드`, `Flutter_MetaRow`, `Flutter_TextLink`

**앱 라우팅/상태**
- mobile 하단탭 → `Flutter_GoRouter_StatefulShellRoute_탭_네비게이션`
- 인증 게이트 → `Flutter_GoRouter_인증_리다이렉트_라우팅`
- Riverpod → `Flutter_Riverpod_비동기_상태관리`, `Flutter_Riverpod_코드생성_NotifierProvider_CRUD`, `Flutter_ConsumerStatefulWidget_CRUD_화면`
- mobile 오프라인 → `Flutter_Dio_Offline_Cache_Interceptor`, `Flutter_SharedPreferences_Riverpod_KeepAlive_영속성`

**적용 보류/확인 필요 (추측 금지)**
- `Flutter_WebSocket_STOMP_*`: 백엔드 문서는 **SSE**만 명시(WS 없음) → **미적용 후보**. 실시간은 SSE 클라이언트 사용.
- `Flutter_AppFlowyEditor_리치텍스트_에디터_통합`: Monaco가 아님 → Sandbox는 Monaco 임베드. AppFlowyEditor는 커뮤니티 글쓰기/마크다운 작성에 한해 검토.
- 보안 샘플(`Certificate_Pinning`, `RSA_AES_GCM`, `구조화_로깅`): 프로토 범위 밖, 운영화 단계에서 검토.

## 8. 미해결/후속 결정 (문서에 명시 없음 — 구현 전 확정 필요)
- 모바일 OAuth 콜백 흐름 — 외부 브라우저(AppAuth/flutter_web_auth) + `devpath://` 콜백 딥링크가 유력안이나 문서 미명시 → Eng Review에서 확정.
- 모바일 refresh 토큰 저장(웹 httpOnly 쿠키 패턴 적용 불가) → `flutter_secure_storage`로 결정(본 스펙 채택).
- 결제(PAY) 화면: 명명 규칙엔 있으나 인벤토리 정의가 문서에 없음 → 프로토 범위 제외, 별도 확인.
- **디자인 미해결: 0** — `/plan-design-review`로 DD1~DD8 확정(§9, DESIGN.md). 단 **Eng Review 미실행(필수 아키텍처 게이트)** → 구현 착수 전 `/plan-eng-review` 권장(§13 VERDICT).

## 부록 A — 전체 MVP 화면 목록 (확장 대상)
- **web(18)**: LAND-001, AUTH-001, ONB-001/002/003, PATH-001/002, CNT-001, SBX-001, REV-001, MEN-001, COM-001~008, DASH-001. (COM-009/010=Phase 2)
- **admin(7 + Should 3)**: A-001~006, A-COM-001 / Should: A-007(진단문항), A-008(Sandbox 악용로그), A-009(공지).
- **mobile 전용(3)**: M-NTF-001, M-OFF-001, M-DEEP-001. (+ Web/Mobile 공용: AUTH/ONB-001/PATH-001·002/MEN-001/DASH-001)

## 9. 디자인 결정 (plan-design-review 2026-06-14)

> 디자인 시스템 단일 출처는 신규 [`DESIGN.md`](../../../DESIGN.md). 아래는 이 플랜에 직접 박는 결정.

### 9.1 확정된 디자인 결정
| # | 결정 | 선택 | 근거 |
|---|------|------|------|
| DD1 | 프라이머리 색 | **인디고 유지 + 텍스트용 어두운 변형 분리** | `#6366f1`은 흰 배경 대비 ≈3.9:1(AA 미달) → fill=indigo-500, 텍스트/링크=indigo-600/700(`primaryText`) |
| DD2 | 타이포 | **본문 Pretendard + 코드 D2Coding** | 한글 우선·기본 Roboto 금지. Monaco/코드 렌더는 한글 고정폭 |
| DD3 | 아이콘 | **Material Symbols 단일셋** | 이모지 디자인요소 제거(슬롭#7·렌더 불일치). 스트릭🔥·배지🏅만 의도적 예외 |
| DD4 | AI_KILL_SWITCH UX | **전용 '점검 중' 상태 + 대체 행동** | 핵심 가치 다운 순간 → 캐시열람/커뮤니티/저장 유도로 goodwill 보존 |
| DD5 | SBX 반응형 | **데스크톱 3-페인 / 모바일웹 1-페인 탭** | 375px에 3열 불가. 세그먼트 탭으로 전환, Monaco는 web 전용 |
| DD6 | 다크모드 | **전역 라이트/다크 토글 프로토 포함** | 개발자 타겟층 다크 기대. 골든 화면·상태위젯 다크 변형 테스트 동반(범위 확대 채택) |
| DD7 | 접근성 | **베이스라인 a11y 플랜 명문화** | 대비 4.5:1·터치 44px·키보드(Monaco Esc)·SSE `aria-live`·시맨틱 랜드마크 |
| DD8 | SSE 중단 | **단계 보존 + 재연결/이어하기** | 1st Aha 중단 시 완료 단계 유지하고 끊긴 지점부터 이어 생성(전체 재시작 아님) |

### 9.2 상호작용 상태 테이블 (사용자가 보는 것 기준)
| 기능 | LOADING | EMPTY | ERROR | SUCCESS | PARTIAL |
|---|---|---|---|---|---|
| PATH 생성(SSE) | 4단계 체크인+진행바, 단계 카피 | (해당없음·항상 생성) | 끊김→완료단계 유지+"이어서 생성" 재연결 / `KILL_SWITCH`→점검배너+대체행동 | 12주 로드맵+이번주 과제3+멘토 rationale | 일부 단계만 완료, 나머지 스켈레톤 |
| 콘텐츠 뷰어 | Shimmer 스켈레톤 | "아직 콘텐츠 없음"+추천 경로 CTA | 재시도 / 오프라인→캐시 배너 | 마크다운 렌더 | — |
| Sandbox 실행 | 실행로그 스트리밍(connecting…) | 코드 미작성 안내 | `SANDBOX_UNAVAILABLE`→실행만 비활성, 편집 유지 | 테스트 통과/실패 요약 | 일부 테스트 결과 스트림 |
| AI 코드리뷰 | "리뷰 생성 중"+신뢰도 placeholder | — | `KILL_SWITCH`→점검배너 / `QUOTA`(429)→한도+Retry-After 카운트 | 신뢰도·잘한점·개선(라인·심각도)·보안+👍👎 | 항목별 점진 노출 |
| AI 멘토(SSE) | 타이핑 인디케이터 | "첫 질문을 해보세요" 예시질문 | 끊김→재연결 / `KILL_SWITCH`→점검배너 | 스트리밍 답변+후속질문 | 부분 답변+재개 |
| 커뮤니티 Q&A | 리스트 스켈레톤 | "첫 질문을 남겨보세요"+작성 CTA | 재시도 | 목록/상세 | 커서 다음 페이지 로딩 |
| 알림센터(mobile) | 스켈레톤 | "새 알림 없음"+따뜻한 일러스트 | 재시도 | 읽음/안읽음 구분 | — |
| 오프라인(mobile) | — | "캐시된 콘텐츠 없음" | — | drift 캐시 목록 | 재연결 자동 동기화 |
| admin 테이블 | 행 스켈레톤 | "조건에 맞는 사용자 없음"+필터 초기화 | 재시도 | 테이블+상세패널 | 커서 "더 보기" |

> 빈 상태는 기능이다 — 따뜻한 카피 + 단일 1차 행동 + 맥락. "결과 없음" 단독 금지.

### 9.3 반응형 명세 (값 확정)
- **Breakpoint(M3 window class)**: Compact <600 / Medium 600–839 / Expanded 840–1239 / Large ≥1240.
- **web 셸**: <840 하단탭 · ≥840 좌측 내비 레일.
- **SBX**: <1024 1-페인 세그먼트 탭 · 1024–1239 2-페인(에디터|리뷰, 로그 접이식) · ≥1240 3-페인.
- **admin**: 데스크톱 전용(≥1024) 가정, 좁은 폭은 가로 스크롤 테이블 + 상세 패널 모달 전환.

### 9.4 접근성 베이스라인 (DESIGN.md §6 요약)
대비 본문/링크 ≥4.5:1 · 터치 ≥44px · 키보드 포커스 순서+가시 링+Monaco `Esc` 탈출+skip-to-content · 시맨틱 랜드마크+`lang="ko"` · SSE `aria-live="polite"` · 색+텍스트 병행 · `prefers-reduced-motion` 존중.

## 10. NOT in scope (디자인 — 명시적 보류)
- **landing(Jaspr) 표현형 디자인 토큰**: MARKETING 규칙 별도, 본 리뷰는 앱 셸(APP UI)만. 랜딩 디자인은 별도 세션.
- **차별화 브랜드 색 탐색**: 인디고 확정, distinctive seed 탐색은 /design-shotgun 후속(DD1).
- **커스텀 아이콘셋**: Material Symbols 채택, 자체 아이콘 디자인은 프로덕션화 단계(DD3).
- **고급 모션·마이크로인터랙션**: SSE/스켈레톤 핵심 모션만, 화면 전환 고급 모션은 후속.
- **결제(PAY) 화면**: 인벤토리 문서 부재 → 프로토 제외(플랜 §8 유지).

## 11. What already exists (재사용 대상)
- **승인된 와이어프레임**: `.superpowers/brainstorm/sess1/content/web-wireframes.html`, `admin-mobile-wireframes.html` — 인디고/slate/카드 방향, 3-페인 SBX, 대시보드 위계(스트릭→진행률→단일 CTA→배지). 레이아웃 그대로 계승.
- **`dp_design` 컴포넌트 목록**(플랜 §2): 상태위젯(Loading/Empty/Error)·폼·차트 래퍼·마크다운/코드 렌더러. 토큰만 DESIGN.md로 채움.
- **Flutter 샘플 매핑**(플랜 §7): 토큰=`Material3_ThemeExtension_DesignToken`, 상태=`EmptyState`·`Shimmer_Skeleton`·`재사용_다이얼로그`.

## 12. Implementation Tasks
> 본 리뷰 findings에서 합성. Claude Code/Codex로 실행, 체크박스로 진행.

- [ ] **T1 (P1, human: ~3h / CC: ~20min)** — dp_design/theme — DESIGN.md 토큰을 Material3 ThemeExtension으로 코드화(라이트+다크, Pretendard/D2Coding, 8pt 간격, 라운드)
  - Surfaced by: Pass 5 — DESIGN.md 부재·토큰 미명세 (DD1·DD2·DD6)
  - Files: `packages/dp_design/lib/theme/`, `pubspec`(폰트 에셋)
  - Verify: golden 테스트로 라이트/다크 토큰 렌더 확인
- [ ] **T2 (P1, human: ~2h / CC: ~15min)** — dp_design/components — KillSwitch·Quota·SandboxUnavailable·Offline·SSE단계 상태 위젯 추가
  - Surfaced by: Pass 2 — 백엔드 503/429 상태 UX 무명세 (DD4·상태테이블 §9.2)
  - Files: `packages/dp_design/lib/components/states/`
  - Verify: 각 상태 위젯 위젯 테스트(카피·1차행동·맥락)
- [ ] **T3 (P1, human: ~2h / CC: ~15min)** — apps/web/sandbox — SBX 반응형(데스크톱 3-페인 / 모바일웹 1-페인 세그먼트 탭) 구현
  - Surfaced by: Pass 6 — SBX 3-페인 모바일 collapse 무명세 (DD5)
  - Files: `apps/web/lib/features/sandbox/presentation/`
  - Verify: 375px/1024px/1240px 위젯 테스트로 페인 전환 확인
- [ ] **T4 (P1, human: ~3h / CC: ~25min)** — 공통 — a11y 베이스라인(대비·44px·키보드·Monaco Esc·SSE aria-live·랜드마크)
  - Surfaced by: Pass 6 — 접근성 전무 (DD7)
  - Files: `packages/dp_design/`, `apps/web/lib/features/{sandbox,mentor,path}/`
  - Verify: Monaco Esc 탈출·SSE 영역 aria-live 수동 검증 + 대비 토큰 단위 테스트
- [ ] **T5 (P1, human: ~2h / CC: ~15min)** — apps/web/path — SSE 중단 시 단계 보존 + 재연결/이어하기 UX
  - Surfaced by: Pass 2·3 — SSE 중단 복구 무설계 (DD8)
  - Files: `apps/web/lib/features/path/`, `packages/dp_core/lib/sse/`
  - Verify: 목 SSE 중간 중단 주입 → 완료 단계 유지+재연결 통합 테스트
- [ ] **T6 (P2, human: ~1h / CC: ~10min)** — 공통 — 이모지→Material Symbols 교체(하단탭·상태·배지)
  - Surfaced by: Pass 4 — 이모지 디자인요소(슬롭#7) (DD3)
  - Files: `packages/dp_design/lib/icons/`, mobile 셸·상태위젯
  - Verify: 하단탭·상태 아이콘 렌더 위젯 테스트
- [ ] **T7 (P2, human: ~1h / CC: ~10min)** — apps/web — 빈 상태 카피·1차행동 일괄 적용(상태테이블 §9.2)
  - Surfaced by: Pass 2 — 빈 상태 미설계
  - Files: 각 feature presentation
  - Verify: 빈 상태 위젯 테스트(카피 존재·CTA)

## 13. TODOS (후속 디자인 부채)
- **차별화 브랜드 색 탐색** (/design-shotgun): 인디고 SaaS 인상 탈피. DD1 확정 후 선택.
- **landing(Jaspr) MARKETING 디자인**: 별도 세션, 앱 토큰 공유.
- **고급 모션·마이크로인터랙션**: 화면 전환·게이미피케이션 모션.
- **커스텀 아이콘셋**: 브랜드 정체성, 프로덕션화 단계.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | — | — |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 0 | — | — |
| Design Review | `/plan-design-review` | UI/UX gaps | 1 | ISSUES_OPEN | score: 5/10 → 8/10, 8 decisions |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

- **UNRESOLVED:** 0 (8개 디자인 결정 모두 사용자 승인·플랜 반영)
- **VERDICT:** Design Review 완료(5/10 → 8/10). **Eng Review 미실행 — 필수 게이트, 구현 전 `/plan-eng-review` 필요** (DD5 반응형·DD8 SSE 재연결·다크모드 전역 토글은 아키텍처 영향 있음).
