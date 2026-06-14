# Eng Review 요약 — P4(web)·P6(mobile) 아키텍처 게이트

> 일자: 2026-06-14 · 대상: `2026-06-14-react-to-flutter-and-proto-ui-design.md` 스펙 + P4a~f·P6 플랜
> 방식: 플랜별 심층 리뷰(7) → 시니어 아키텍트 종합 → 사용자 결정 4건(D1~D4 전부 추천안 A 승인)
> 판정: **조건부 착수 승인** — 아래 D1~D4 결정 반영 + 필수 수정(F4·F5·F6) 후 구현. 코드는 아직 미존재(docs 단계).

스펙 §6·§13이 지정한 아키텍처 게이트(DD5 반응형·DD6 다크·DD8 SSE 재연결)에 대한 VERDICT. 디자인 리뷰(5/10→8/10)와 짝을 이루는 **필수 엔지니어링 게이트**.

## 0. 종합 진단

플랜 7개는 계약 정합도가 높고(plain Notifier 통일·family 미사용·dio-free·커서 Page<T>·상태매트릭스·theme 규약이 **시그니처 단위까지** 일치), TDD 실패-우선이 전 태스크에 명시됨. **스코프 축소 불필요.** 계약 위반은 feature 로컬이 아니라 **공유 스트리밍 기반 미설계**에서 파생된다 — 그래서 P4b/P4e/P4c 구현 *전*에 중앙 결정이 필요(retrofit 회피). 이것이 본 게이트의 핵심.

## 1. 사용자 결정 (D1~D4 — 전부 추천안 A 승인)

### D1 — SSE 스트리밍 기반을 P2에 단일 구축 ✅
P2에 **단일 출처 기반**을 세우고 모든 feature가 구독한다:
- `SseStage`(connecting/streaming/partial/reconnecting/complete/failed) **단일 출처** — feature가 자체 enum으로 갈아끼우지 않음.
- `ApiClient.sse(path,{body})` **팩토리** 추가 → 앱이 `client.dio`를 직접 만지지 않음(F2 해소).
- 공유 **resume/단계상태 모델**(완료보존·partial·reconnecting) — P4b·P4e·P4c가 재사용.
- **해소 대상:** F1(enum 3중분기), F2(dio 직접접근). P2 `SseStage` 死값 문제 종결.

### D2 — DD8 핵심 구현 + 재개키 보류 ✅
- `MockSseSource.failAfter:int?`(N단계 후 throw) 추가 → **중단 주입 가능**.
- `pathSseConnectProvider`/멘토 소스가 플래그로 중단 목을 켜 **골든패스 통합테스트에 중단→이어하기→완료** 1케이스 포함(스펙 §5 충족).
- onError에서 `ApiException.isKillSwitch/isQuota` 분기 → **중간 503/429를 partial로 오분류 금지**(F4). KILL_SWITCH는 점검배너, partial 아님.
- 60s 무이벤트 → partial 전환(`.timeout(config.sseTimeout)`), 단위테스트 1개.
- **재개키:** 실서버 `id:`/`Last-Event-ID` 프로토콜은 **백엔드 합의 전까지 `fromStep` 유지**, 플랜·TODO에 "백엔드 합의 후 전환" 명시(추측 금지).

### D3 — query-aware MockHttpAdapter 보강 ✅
dp_core `MockHttpAdapter`가 query(cursor/필터)를 인지하도록 키 매칭 보강. → P4f 페이지네이션 다중페이지(F8)와 D2 SSE 중단 데모가 **앱 목 모드에서 실제 동작**(눈으로 확인 가능). 기존 후속 T 후보를 게이트로 승급.

### D4 — P6 재연결 동기화 최소구현 + OAuth 이관 ✅
- `watchContents` 기반 StreamProvider로 **재연결 자동 동기화 최소 구현** + `isOfflineProvider` off 전이 시 재동기화 1케이스(§9.2 PARTIAL 충족).
- `ConnectivityService` **인터페이스화**(FCM `PushService`와 동일 교체 경계, F3).
- **OAuth 콜백 딥링크(스펙 §8)·`flutter_secure_storage` TokenStore는 후속 인증 Task로 명시 이관** — 리스크 절에 경계 1줄(외부브라우저+`devpath://callback`이 5탭 딥링크와 충돌 없음) 기록. 침묵 금지.

## 2. 필수 수정 (계약 필수 · 저비용 · 결정 불요)

| # | 플랜 | 문제 | 수정 | 근거 |
|---|------|------|------|------|
| **F4** | P4b | onError가 종류불문 partial → KILL_SWITCH도 "이어서 생성"(무한실패) | `isKillSwitch/isQuota` 분기(D2에 포함) | P4b L820 / §9.2 PATH행 |
| **F5** | P4c | Monaco `registerViewFactory` viewType 무한증식+dispose 누수; 1페인 탭 전환 시 에디터 코드 소실; **DD7 Esc 탈출 미구현** | 공개위젯 StatefulWidget화+viewType 1회+dispose 훅; 1페인 `IndexedStack`; Esc 핸들러(셈)+dart Focus+a11y 테스트 | P4c §4.3·§5.3-A·§4.4 |
| **F6** | P4d | `const DpKillSwitch()`로 대체행동 버려짐(P3 지원); Retry-After 정적 텍스트+`?? 0`→"0초" 오안내 | alt-action 1개 배선(비용≈0); null 안전 문구 분기; 카운트다운 or "정적 표시" 명시 강등 | P4d §4.2·§4.3 |
| **F9** | P4e | 토큰당 리스트 얕은복사+버블 Key 없음 → 긴 답변 시 visible 버블 전체 재빌드 | 버블 ValueKey + 마지막 메시지 분리 위젯 | P4e §4.1 |

## 3. 플랜별 반영 체크리스트 (구현 전 플랜 수정)

- **P2 (dp_core)** — D1 기반(SseStage 단일출처·`ApiClient.sse()`·공유 resume), D2 `MockSseSource.failAfter` + 스트림 중간 에러 정규화(T-SSE-ERR-NORMALIZE 잔여), D3 query-aware `MockHttpAdapter`.
- **P4b** — SseStage 구독(자체 PathPhase 폐기 또는 reconnecting 추가), F4 분기, 60s 타임아웃, 중단주입 통합테스트, PARTIAL "나머지 스켈레톤"(kPathStageLabels 전체+currentIndex), done+`/onboarding`→`/path` 게이트, copyWith 혼합 null 시맨틱 주석, "4단계 vs 라벨 3개" 카피 정합.
- **P4c** — F5 일괄(Monaco 생명주기+IndexedStack+Esc), `ApiClient.sse()` 사용(client.dio 제거), RunController 재진입 가드, 반응형 경계 4값(1023/1024/1239/1240) 테스트, 콘텐츠 Shimmer/캐시배너 매트릭스.
- **P4d** — F6 일괄, 비동기 폴링 deferral 리스크 명시 + `CodeReview`에 `id`/`status` 자리 선확보, Quota/Failed/Loading 렌더 테스트.
- **P4e** — D1 공유 추상 채택(MentorStatus→SseStage 또는 partial 포함), 재개/재전송 UI, F9, 빈/부분 버블 잔류 처리, 취소 경쟁조건(targetIndex 캡처) + 테스트.
- **P4f** — D3로 다중페이지 데모, loadMore 에러 UI 표시(현재 무음), ERROR 위젯테스트(최소 1화면), Task6 E2E를 P4 종료 후 별도 통합 태스크로 분리, "시ام" 오타·P4a 로드맵 표 stale 정정.
- **P6** — D4 일괄(동기화 최소구현+ConnectivityService+OAuth/secure_storage 이관 명시), 딥링크 path→page 단위테스트, Task4를 4a(셸/라우터)·4b(통합)로 분할(TDD red→green이 Task 내 닫히게), 죽은 코드(pushService/watchContents 미소비) 배선.

## 4. 수용(as-is) — 결정·수정 불요
- 파일 수 8개 초과(P4a 13 등): feature-first + 테스트 가능성 분할로 정당, 과설계 아님.
- web 토큰 메모리 저장·StatefulShellRoute 미승격·온보딩 명령형 이동: 프로토 범위 의도적 deferral(플랜이 리스크로 인지).
- 피드백 👍👎 no-op·후속질문 미구현: YAGNI 선언됨(단 P4e SUCCESS 후속질문은 슬롯만 권장).

## 5. UNRESOLVED
- **0** — D1~D4 사용자 승인 완료. 단 **실서버 SSE 재개 프로토콜(Last-Event-ID)·온보딩 문항·OAuth 콜백 흐름은 백엔드/외부문서 합의 대기**(추측 금지로 보류 명시, TODOS 등록).
