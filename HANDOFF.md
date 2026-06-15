# HANDOFF — React→Flutter 전환 & 프로토 UI

> 최종 업데이트: 2026-06-15 · 브랜치 전략: **main 보호 · develop 통합 · 작업브랜치→develop PR→머지→main 릴리스 PR**(CLAUDE.md "🔀 Git 브랜치 전략" + 전역 규칙).
> **상태: 설계·계획 + 디자인/Eng 리뷰 완료 + P1·P2·P3(main, PR#3) + P4a~P4f(web 골든패스 전체) 구현 완료.** 다음은 **P5(admin)**.

## 브랜치/머지 현황 (2026-06-15)
- **main**: P1·P2·P3 통합됨(PR#3 머지, merge commit `abf9056`). main 직접 푸시 금지.
- **develop**: 통합 브랜치. Git 정책(PR#4)·P4a(PR#5)·P4b(PR#6)·P4c(PR#7)·P4d(PR#8)·P4e(PR#9) 머지됨. P4f는 `feat/p4f-web-dashboard-community`에서 develop으로 PR(진행).
- **CI**: `analyze-test` job의 **Format check(`dart format --set-exit-if-changed`)** 가 게이트 — 커밋 전 항상 `dart format` 적용(P3 머지 때 format 미적용으로 1차 실패한 교훈). 골든은 `--exclude-tags golden`로 CI 제외.

## P4f 구현 완료 (2026-06-15, feat/p4f-web-dashboard-community, 커밋 75de499~6d3d25c)
대시보드(DASH-001) + 커뮤니티(COM-001 홈 / COM-003 Q&A 상세) TDD(Task 1~5; Task6 E2E는 플랜이 P4f 범위 밖으로 명시 → P4 종료 후 별도). **web 골든패스 완성**. **검증됨**: `melos analyze`(전 멤버 No issues)·`melos test`(web 77·dp_design 19·dp_core 30·admin 1·mobile 1 PASS).
- Task1: dp_core `DashboardSummary`·`CommunityPost` freezed. Task2: 대시보드(스트릭 displaySmall·진행바·다음과제 단일 CTA→`/path`·배지 카드 위계)+`GET /dashboard`+`/dashboard` 결선. Task3: `communityFetchProvider`(Page<T> seam)+`CommunityState`(copyWith nextCursor 명시대입 비대칭)+`CommunityController`(load/loadMore 커서 누적)+query-aware 픽스처(`?cursor=c2` 2페이지). Task4: 커뮤니티 홈(목록·빈상태 CTA·더보기·ERROR 재시도·loadMore 인라인에러)+`/community` 결선. Task5: Q&A 상세(DpMarkdown)+`/community/:id` 결선.
- **P4f 교훈/플랜 보정 3건**: ① **`ApiException` 위치인자 오류**(P4b 재발) — 플랜 테스트의 `const ApiException('네트워크 오류')`는 실제 `{required code, required message}` 명명인자와 불일치 → `ApiException(code: ApiErrorCode.network, message: ...)`로 교정. ② **`Page` 심볼 충돌** — 홈 테스트가 `dp_core`(Page<T>)와 `flutter/material`(라우트 Page)을 동시 import → `import 'package:flutter/material.dart' hide Page;`로 해소(플랜 미고려). ③ **PlaceholderPage 교체 후 미사용 import 정리** — `/dashboard`·`/community`(+P4e `/mentor`) 실화면 교체로 router.dart의 `dp_design`·`placeholder_page` import 및 테스트 미사용 import 제거. ④ go_router 빌더 `(_, __)`→`(_, _)`. `Page`/`MockHttpAdapter` query-aware는 실제 시그니처와 일치 확인.
- **후속**: 질문 작성(FAB)·답변 스레드·투표는 프로토 범위 밖(자리만). 골든패스 E2E(integration_test)는 P4 종료 후 별도 "P4-E2E" 통합 태스크. 🔥/🏅는 DD3 허용 게이미피케이션 예외.

## P4e 구현 완료 (2026-06-15, feat/p4e-web-mentor-sse, 커밋 d289230~95eb961)
AI 멘토(MEN-001, SSE 토큰 스트리밍 채팅) TDD(Task 1~4). **검증됨**: `melos analyze`(전 멤버 No issues)·`melos test`(web 68·dp_design 19·dp_core 28·admin 1·mobile 1 PASS).
- Task1: `mentorSseConnectProvider`(목=토큰 지연emit/실서버=`apiClient.sse('/ai-mentor/sessions')`, D1 dio-free, `fromStep` 선확보 D2). Task2: `MentorState`(ChatMessage·MentorStatus[idle/streaming/partial/killSwitch/failed])+`MentorController`(토큰 append, KILL_SWITCH 분기, 끊김→partial 부분답변 보존 D2, 빈 버블 prune, 취소 경쟁조건 targetIndex 캡처). Task3: `MentorPage`(빈상태 예시질문 칩·버블 ValueKey F9·타이핑 인디케이터·partial "다시 시도" 재전송·composer). Task4: `/mentor` `PlaceholderPage`→`MentorPage` 결선.
- **P4e 교훈/플랜 보정**: ① **플랜 컨트롤러 hang 버그를 사전 진단·수정** — 플랜의 "연속 send" 테스트는 `await f1`(첫 send future)로 끝나는데, 두 번째 send가 첫 구독을 `_sub.cancel()`하면 취소된 구독은 onDone/onError를 부르지 않아 첫 Completer가 영원히 미완료(테스트 타임아웃). 근본 원인 규명 후 **새 send 시 이전 in-flight Completer 완료**(P4c RunController의 `_inFlight` 패턴) 추가로 해소(추측 아닌 원인 수정). ② Task4 라우트 빌더 `(_, __)`→`(_, _)`(flutter_lints 6.0). ③ dp_* API(apiClient.sse·SseEvent·ApiException.isKillSwitch·DpEmpty·DpKillSwitch·DpIcons.mentor/send·DpRadius.card·context.dpColors.onPrimary 등) 전부 일치 — 0건 시그니처 교정.
- **후속(리스크)**: 실서버 SSE 와이어(토큰 event명·DONE 마커·후속질문 payload) 백엔드 미합의 → 목만 동작, 실서버 분기는 합의 후. 중간 재개는 resend로 단순화(`fromStep` 자리만). 후속질문 추천·세션 영속·REV→멘토 prefill 연결은 후속.

## P4d 구현 완료 (2026-06-15, feat/p4d-web-ai-review, 커밋 1ac80c1~da3df39)
P4c Sandbox 리뷰 칸(`_ReviewPlaceholder`)을 **AI 코드리뷰(REV-001)**로 채움 + KILL_SWITCH/Quota 종결(P4b·P4c 이월 §9.2) TDD(Task 0~4). **검증됨**: `melos analyze`(전 멤버 No issues)·`melos test`(web 60·dp_design 19·dp_core 28·admin 1·mobile 1 PASS).
- Task0(P3 보강): `DpQuota.retryAfterSeconds`를 `int?`로 + null/음수 → "잠시 후 다시 시도해 주세요" 무기한 문구(F6-b, 0초·음수 오안내 차단). Task1: dp_core `CodeReview`/`ReviewIssue` freezed(`id`/`status` 폴링 자리 선확보 F6-e). Task2: `ReviewState`(sealed 6종)+`ReviewController`(`ApiClient.post` `/reviews`→`isKillSwitch`/`isQuota` 분기)+`POST /reviews` 픽스처. Task3: `ReviewPanel`(idle/loading/loaded[신뢰도 진행바·잘한점·개선·보안 라인·심각도색·👍👎 no-op]/killSwitch[대체행동 "커뮤니티 둘러보기"→`/community` 배선 F6-a]/quota/failed 6분기 전수 위젯테스트). Task4: `SandboxPage` 리뷰칸 `_ReviewPlaceholder`→`ReviewPanel` 결선 + 통합 스모크.
- **P4d 교훈/플랜 보정**: ① **사전 API 검증이 또 결정적** — 플랜은 `DpQuota(retryAfterSeconds: int?)`+null 무기한 문구를 전제했으나 실제 P3 `DpQuota`는 `required int`(non-nullable)+"약 N초" 고정 → 컴파일 실패. 플랜 F6-b가 예견한 "P3 보강 선행"을 Task0으로 실행(추측 금지). ② go_router 테스트 빌더 `(_, __)`→`(_, _)`(flutter_lints 6.0). ③ DpKillSwitch(altActionLabel/onAltAction)·DpSpacing.xs·DpIcons.thumbUp/thumbDown/dotSmall/stepDone·context.dpColors.success/warning/danger/primaryText/textSecondary 모두 일치 확인.
- **후속**: REV "멘토에게 질문" 연결은 P4e. 👍👎 피드백 전송(`POST /reviews/:id/feedback`)·Retry-After 카운트다운(P3 `DpQuota` Stateful 전환)·동기→비동기 폴링 전환은 후속 이월.

## P4c 구현 완료 (2026-06-15, feat/p4c-web-content-sandbox-monaco, 커밋 3aa6a13~e10cc6a)
콘텐츠 뷰어(CNT-001) + Sandbox(SBX-001: Monaco·실행 SSE·DD5 반응형) 골든패스 TDD 완성(Task 1~7). **검증됨**: `melos analyze`(전 멤버 No issues)·`melos test`(web 48·dp_design 17·dp_core 26·admin 1·mobile 1 PASS)·`flutter build web` 성공(conditional import web 구현 dart2js 컴파일 확인).
- Task1: `ContentController`/`ContentState`(sealed)+`ContentPage`(DpMarkdown)+`GET /contents/c1` 픽스처+`/content/:id` 라우트. Task2: `RunState`(idle/running/done/unavailable+appended). Task3: `SandboxLayout`(DD5 3/2/1페인, 경계 4값 1023/1024/1239/1240 off-by-one, IndexedStack 상태보존, 1024–1239 로그접이). Task4: `MonacoEditorView`(conditional import: 공개+stub+web / `dart:ui_web`·`package:web`·`js_interop` / F5-a viewType 1회·dispose, F5-b layout(), F5-c Esc sentinel Focus) + `web:^1.1.0` + index.html `createDevpathEditor` 셈. Task5: `sandboxRunConnectProvider`(목 지연emit/실서버 `apiClient.sse`)+`RunController`(503→RunUnavailable, 재진입 가드 `_inFlight`). Task6: `SandboxPage` 조립(에디터|실행로그 codeLogBg|리뷰 placeholder)+`/sandbox` 라우트. Task7: 콘텐츠→Sandbox 통합 스모크.
- **P4c 교훈/플랜 보정**: ① **플랜 API 가정이 이번엔 전부 실제 시그니처와 일치**(P4b의 4건 교정 대비 0건) — 사전 검증으로 확인(ApiClient.get/sse·ApiException{code,message}·ApiErrorCode.sandboxUnavailable·SseEvent{event,data}·DpMarkdown/DpError/DpSandboxUnavailable/DpEmpty·DpIcons.code/expandMore/expandLess/content·context.dpColors.codeLogBg/codeText/border 모두 OK). ② **index.html CDN SRI**: Semgrep가 Monaco loader CDN의 `integrity` 누락 경고 → cdnjs API에서 실제 sha512 받아 `integrity`+`crossorigin` 적용(추측 금지). ③ **Task6 라우트 빌더**: 플랜의 `(_, __)`는 flutter_lints 6.0 `unnecessary_underscores` 위반 → `(_, _)` 와일드카드로 교정. ④ **통합 스모크 테마 전환**: 무테마 ContentPage→DpTheme SandboxPage로 `pumpWidget` 전환 시 `AnimatedTheme` 전환 중 `context.dpColors` null → 콘텐츠 MaterialApp에도 `theme: DpTheme.light()` 제공(실제 앱 DevPathWebApp은 항상 DpTheme 보유와 동일).
- **후속**: AI 리뷰 칸은 `_ReviewPlaceholder` → P4d에서 REV-001로 채움. Sandbox의 killSwitch/quota 전용 위젯 렌더도 P4d. Monaco 실동작은 수동 `flutter run -d chrome` 확인 필요(빌드만으론 런타임 CDN 미검증).

## P4b 구현 완료 (2026-06-14, feat/p4b-web-onboarding-path-sse, 커밋 a0deb0a~88e8c34)
온보딩·진단 → 학습경로 SSE 생성(PATH-001) 골든패스 TDD 완성(Task 0~6). **검증됨**: `melos analyze`(전 멤버 No issues)·`melos test`(web 31·dp_design 17·dp_core 26·admin 1·mobile 1 PASS).
- Task0: `apiClientProvider`에 `AuthInterceptor`(401 큐잉) 결선(ENG-REVIEW D1). Task1: dp_core `LearningPath`/`PathWeek`/`WeeklyTask` freezed 모델. Task2: 온보딩 진단(목 `POST /onboarding`→DONE 유저)+게이트 해제(완료 유저 `/onboarding`→`/path`). Task3: `pathSseConnectProvider`(목=`MockSseSource`/실서버=`apiClient.sse`, fromStep 이어하기). Task4: `PathController`(DD8 중단보존·resume·F4 503/429 분기·D2 60s 타임아웃). Task5: `PathPage`/`PathPlanView`(진행=DpSseStageView·부분=이어서생성·완료=12주+과제+rationale). Task6: 라우터 `/path` 결선 + 온보딩→PATH 골든 스모크(정상 + failAfter:2 중단→resume).
- **P4b 교훈/플랜 보정(플랜 코드를 실제 API로 교정한 4건)**: ① **`ApiException` 시그니처** — 플랜 테스트/구현이 쓴 `ApiException('msg', code:'STR')`·`kind: ApiErrorKind.x`는 미존재. 실제는 `ApiException({required code: ApiErrorCode, required message})` + `isKillSwitch`/`isQuota` 게터. ② **`MockSseSource` fromStep 이중적용** — 플랜의 `MockSseSource(stages: kSseSteps.sublist(fromStep), fromStep: fromStep)`는 sublist+fromStep 동시 적용으로 resume(fromStep>0) 시 0건 emit. 실제 API는 `stages` 전체 위에서 fromStep을 루프 시작 인덱스로 씀 → **전체 `kSseSteps` + `fromStep`** 으로 교정. ③ **`AppConfig.sseTimeout` 부재** — P4a AppConfig엔 baseUrl/useMock만 → `sseTimeout`(기본 60s) 필드 신설 + `testAppConfig` 헬퍼(테스트 파일 정의). ④ **무이벤트 타임아웃 테스트의 hang** — `async*`+`await Completer().future`는 구독 취소가 hang → 취소 가능한 `StreamController`로 무이벤트 재현.
- **후속**: PATH 중 killSwitch/quota를 `DpKillSwitch`/`DpQuota` 전용 위젯으로 렌더하는 것은 P4c(현재 `DpError`). 실서버 `Last-Event-ID` 재개는 백엔드 합의까지 `fromStep` 유지. `GET /users/me`·토큰 영속화는 세션 복원 필요 시점.

## P4a 구현 완료 (2026-06-14, feat/p4a-web-shell-auth-routing, 커밋 0ec62ac~974f5d6)
`apps/web`(devpath_web) 인증된 반응형 셸 토대 TDD 완성(Task 1~10). **검증됨**: `melos analyze`(전 멤버 No issues)·`melos test`(web 19·dp_design 17·dp_core 25·admin 1·mobile 1 PASS).
- 의존성(riverpod 3.3.2·go_router 14.8.1·dp_core·dp_design) · `AppConfig`(dart-define, 기본 목) · 목 픽스처(`/auth/login` PENDING 유저) · API providers(`apiClientProvider`+`MockHttpAdapter`·`tokenStoreProvider` InMemory) · `themeModeProvider`(DD6 토글) · `AuthState`(sealed)+`AuthController`(목 로그인/로그아웃) · `LoginPage` · 반응형 `AppShell`/`AppShellView`(<840 NavigationBar·≥840 NavigationRail) · `gateRedirect`(순수 게이트)+`routerProvider`(go_router refreshListenable) · 플레이스홀더(`PlaceholderPage`·`OnboardingPlaceholder`) · `DevPathWebApp`+main · 골든패스 스모크(로그인→온보딩).
- **dp_core/dp_design 후속**: `ApiClient.post<T>` 추가(web 첫 POST 소비처), `DpIcons.lightMode/darkMode` 추가.
- **P4a 교훈/플랜 보정**: ① 작업 브랜치 정책 도입(이번 세션 — main 직접 머지 금지, develop 경유). ② `melos test`/커밋 전 **dart format 필수**(CI format 게이트). ③ go_router 빌더 `(_, __)` → flutter_lints 6.0 `unnecessary_underscores` → `(_, _)` 와일드카드. ④ 공개 상수가 private typedef 노출 금지(`_Dest`→`ShellDestination`). ⑤ Task1 커밋 시 파일 삭제는 `git add`(또는 `git rm`)로 스테이징해야 누락 안 됨(rm만으론 커밋 안 됨 — 브랜치 전환 시 미커밋 삭제가 따라옴).
- **후속(P4b 결선)**: `AuthInterceptor`(401 큐잉)·`GET /users/me`·토큰 영속화(`WebTokenStore`)는 인증 데이터 호출이 생기는 P4b에서. 셸 탭 상태보존(StatefulShellRoute)은 P4d.

## P3 구현 완료 (2026-06-14, 커밋 8079802~5c5a4d2 — main 머지됨)
`packages/dp_design` 디자인 시스템 TDD 완성(Task 1~9). **검증됨**: `melos run analyze`(전 멤버 SUCCESS)·`melos run test`(dp_design 16 PASS·web 2·admin 1·mobile 1·dp_core 23, golden 제외)·`flutter test --tags golden`(라이트/다크 2 PASS, 동일 플랫폼).
- 색 토큰(`DpColors` ThemeExtension 라이트/다크, DESIGN §1 일치 검증) · 간격/라운드/모션(`DpSpacing`·`DpRadius`·`DpDurations`) · 타이포(`DpTypography` Pretendard/D2Coding, 한글 행간 1.6) · 아이콘(`DpIcons` Material Symbols Rounded, 이모지 0) · a11y(`DpTapTarget` ≥44px+시맨틱) · 기본 상태위젯(`DpStateScaffold`/`DpLoading`/`DpEmpty`/`DpError`) · 백엔드 상태위젯(`DpKillSwitch`/`DpQuota`/`DpSandboxUnavailable`/`DpOfflineBanner`/`DpSseStageView`, liveRegion) · `DpMarkdown`(markdown_widget 2.3.2) · barrel + 골든.
- **P3 교훈/플랜 보정**(플랜 코드 결함을 근본 수정한 4건):
  - ① **`context.dpColors` 확장 위치**: 플랜은 `DpColorsX`를 `dp_theme.dart`에 뒀으나 상태 위젯이 dp_theme를 import 안 해 미해석(컴파일 실패). 확장을 노출 타입(`DpColors`)과 같은 `dp_colors.dart`로 이동해 해결. scaffold 기반 위젯(error/kill/quota/sandbox)엔 `dp_colors.dart` import 추가.
  - ② **폰트 포맷**: Pretendard는 `.ttf`가 아닌 `.otf` 배포(GitHub orioncactus/pretendard `dist/public/static`). D2Coding은 릴리스 zip에서 `D2Coding.ttf` 추출. pubspec·FontLoader 경로를 `.otf`로 보정. 폰트 5종 레포 커밋(~10MB, 사용자 승인).
  - ③ **골든 아이콘 글리프**: 위젯 테스트는 번들 폰트 미자동로드 → Pretendard/D2Coding뿐 아니라 **Material Symbols(Rounded)도 `rootBundle`로 FontLoader** 해야 아이콘이 box로 degrade 안 됨. `_loadFonts`에 추가.
  - ④ **`library;` 무명화**: flutter_lints 6.0 `unnecessary_library_name` → barrel은 무명 library.
  - **web cross-import 스모크**(`apps/web/test/workspace_link_test.dart`)가 P1 `DpBrandMark`에 의존 → 제거에 맞춰 `DpTheme`/`DpEmpty`로 교체(intent 보존).
- **골든 운영**: baseline은 **Windows 로컬 생성**(P3-A 권장은 ubuntu 고정). 일반 CI(`melos test`)는 `--exclude-tags golden`(P1에서 이미 반영)으로 건너뛰며, 골든 검증은 동일 플랫폼에서만 의미. ubuntu CI 골든 job은 후속(T-GOLDEN-CI-EXCLUDE 부분).

## P2 구현 완료 (2026-06-14, 커밋 208deab~0f2c1d5 — 미푸시)
`packages/dp_core` 데이터 계층 TDD 완성(Task 1~10). **검증됨**: `melos run analyze`(전 멤버+dp_core No issues)·`melos run test`(dp_core 23 PASS, 전 멤버 SUCCESS).
- error(`ApiErrorCode`+`ApiException.fromDio`: network·429 Retry-After·503 kill-switch) · `Page<T>` 커서 · models(enum unknown fallback + freezed User, codegen 커밋) · `ApiConfig`/`ApiClient`(public dio·`create` 에러 인터셉터·`get`·**`sse()` D1**) · auth(`TokenStore`·`AuthInterceptor` QueuedInterceptor 401 단일 refresh+회전가드) · sse(`SseClient` 청크 재조립·`SseStage` 단일출처) · mock(**query-aware `MockHttpAdapter` D3**·`MockSseSource` **`failAfter`/`fromStep` D2**) · barrel.
- **P2 교훈**: ① freezed 3.x는 프리릴리스(`3.2.6-dev.1`)만 존재 — `^3.0.0` 핀으로 codegen 정상. ② `QueuedInterceptor`는 직렬화만 하고 dedup 안 함 → 동시 401 단일 refresh엔 **토큰 회전 가드** 필수, 재시도는 **별도 dio**로(같은 dio면 큐 교착). ③ Task 검증 시 test뿐 아니라 **analyze도** 실행(미사용 import 누락 방지).
- **서브에이전트 범위 이탈 사건**: 초기 1개 에이전트가 Task 2 후 플랜 없이 P2 전체를 자체 구조로 즉흥 구현 → reset 후 Task별 재구현. 재발 방지 규칙을 CLAUDE.md(절대 조건 4)·전역 `~/.claude/rules/subagent-scope.md`에 기재.

## P1 구현 완료 (2026-06-14, 커밋 b513eee~12cd1a9)
melos 7 + Dart pub workspaces 모노레포 골격: `packages/dp_core`(순수 Dart)·`dp_design`(Flutter) + `apps/{web,admin,mobile}` 5멤버 단일 해석. 구 React `web/`·`admin/` 제거, `mobile/`→`apps/mobile/`(이력 보존), CI를 melos analyze/test로 교체. **검증됨**: `melos run format`(0 changed)·`analyze`(No issues)·`test`(전 멤버 PASS, web은 cross-import 포함). 전 멤버 sdk `^3.12.1`·flutter_lints `^6.0.0` 정렬. melos 호출은 PATH 미설정 시 `dart pub global run melos <cmd>`.

## 지금까지 (DONE) — 플랜 작성 + 외부 리뷰 전부 완료

- **스펙**: `.../specs/2026-06-14-react-to-flutter-and-proto-ui-design.md` (전환 B′ + DD1~DD8) · **디자인 SSoT**: `DESIGN.md` · 리뷰요약: `.../design-review-summary.md`
- **플랜 (`docs/superpowers/plans/`)**: `P1` 골격 · `P2` dp_core · `P3` dp_design · `P4a~f` web 골든패스(셸·인증 / 온보딩·PATH SSE DD8 / 콘텐츠·Sandbox Monaco DD5 / AI리뷰·KILL_SWITCH·Quota / 멘토 SSE / 대시보드·커뮤니티) · `P5` admin · `P6` mobile(drift·FCM스텁·딥링크) · `P7` landing(Jaspr SSG, standalone)
- **외부 리뷰 전부 반영 완료**:
  - P2·P3: 8fb4651(7건)
  - P4a~c: 4035137(3건 — 셸 테스트버그·SseClient 정규화·DD3아이콘)
  - P4d~f: 73f5ca1(3건 — P4f-A 테스트 theme·P4f-B FamilyNotifier→Notifier·DD3 아이콘 일괄)
  - P5·P6·P7: 73cfe23(4건 — P7-A Document.lang 제거·P7-C config 분리·P7-D CSS·P6 아이콘)
- **TODOS** (`TODOS.md`): 활성 `T-DEPLOY-REINTRO`·`T-CI-FLUTTER-PIN` / 부분 `T-GOLDEN-CI-EXCLUDE`·`T-LANDING-CI` / 반영 `T-SSE-ERR-NORMALIZE`·`T-LANDING-WORKSPACE`(standalone)

## 다음 세션 (RESUME HERE) — 전체 리뷰 완료, 구현 시작

1. **✅ Eng Review 완료(2026-06-14)**: P4(web)·P6(mobile) 심층 리뷰 → 결정 D1~D4 승인 → 7개 플랜(P2·P4b~f·P6) 반영 완료. 요약: `docs/superpowers/specs/2026-06-14-eng-review-summary.md`. 결정: D1(P2 단일 SSE 기반 — `ApiClient.sse()`·`SseStage` 단일출처·`fromStep`), D2(DD8 핵심+`MockSseSource.failAfter`+60s, 재개키는 백엔드 합의까지 fromStep 보류), D3(query-aware `MockHttpAdapter`), D4(P6 재연결 동기화 최소+ConnectivityService, OAuth·secure_storage 이관). 필수수정 F4·F5·F6·F9는 해당 플랜에 반영됨.
2. **✅ P1·P2·P3·P4a~P4f 완료(web 골든패스 전체)** — 위 절들. 다음은 **P5(admin)**: `docs/superpowers/plans/2026-06-14-p5-admin.md`. **순서 의존** P5→P6→P7. **착수 게이트 충족**: P2 데이터(`ApiClient`·`Page<T>`·query-aware `MockHttpAdapter`)·P3 dp_design·P4 web 패턴(컨트롤러·픽스처·라우트). admin은 별도 앱(`apps/admin`/devpath_admin, 현재 스모크 1테스트만). **브랜치 정책 준수**: feat 브랜치 → develop PR → 머지, 커밋 전 `dart format`. 서브에이전트 위임 시 **범위 강제**(CLAUDE.md 절대 조건 4) + **컨트롤러 직접 검증** 필수. **플랜 코드의 API 가정은 항상 dp_core/dp_design 실제 시그니처로 사전 검증**(P4c 0건·P4d 1건·P4e 1건·P4f 3건[ApiException 위치인자·Page 심볼충돌·미사용 import] — 사전 검증이 컴파일 실패·런타임 hang을 반복 선제 차단). **P4-E2E(골든패스 integration_test)는 P5~P7과 별개로 P4 종료 후 별도 통합 태스크로 분리됨**(P4f 플랜 Task6 참조).

## 구현 시 남은 결정/보강 (플랜에 노트로 명시됨)

- **dp_core**: ① SSE `id:`/`Last-Event-ID` 재개(P4b·P4e DD8) · ② `MockHttpAdapter` query-aware(P4f·P5 다중페이지·필터) · ③ `T-SSE-ERR-NORMALIZE` 잔여(SSE 스트림 중간 503 정규화, P4d 멘토 구현 시).
- **CI**: ④ 골든 전용 job(T-GOLDEN-CI-EXCLUDE) · ⑤ landing 전용 job(T-LANDING-CI).
- **mobile**: ⑥ 실 FCM(firebase_messaging+설정)·실 connectivity_plus(P6 스텁 대체).
- **landing**: ⑦ `<html lang="ko">` 주입 수단 — 설치 Jaspr의 `htmlAttributes` 지원 확인 또는 post-build 주입(P7-A, Task5 grep 게이트로 검증). P7-B(`testComponents`·`text()` 시그니처)도 설치본 확인.
- **DD3 아이콘 후속은 해소됨**(P4·P6 전부 DpIcons화, P3에 thumb/send/edit/dotSmall/downloadDone 등 추가).

## 핵심 결정 (변경 시 스펙·플랜 동기화)

- 구조: melos + Dart pub workspaces, `dp_core`(순수 Dart)·`dp_design`(Flutter) + 앱 3개. **landing은 워크스페이스 밖 독립**(Jaspr, standalone).
- 프로토 = **목 API**(SSE·에러 정규화 포함), 범위 = 골든패스 + surface별 대표화면.
- **공통 스택**: Riverpod 3 — **plain `Notifier`/`NotifierProvider` 통일**(family 베이스 미사용, P4f-B). go_router(web=`redirect`게이트·`refreshListenable`, mobile=`StatefulShellRoute`). `ApiConfig.useMock`+`MockHttpAdapter`. **앱은 `dio` 직접 의존 금지**. SSE는 feature별 `*ConnectProvider` 주입. **Monaco=conditional import** · **mobile 캐시=drift**(테스트 `NativeDatabase.memory`) · **landing=Jaspr SSG**.
- **위젯 테스트 폭 의존은 `tester.view.physicalSize`** + `context.dpColors` 쓰는 위젯 테스트엔 `theme: DpTheme.light()`(P4a-A·P4f-A 교훈).
- CLAUDE.md Vitest 지침 → Flutter 테스트 스택으로 대체(구현 시 갱신).

## 미작성 플랜

> 없음 — **P1~P7 전부 작성·리뷰 완료**. 다음은 eng-review·구현.
