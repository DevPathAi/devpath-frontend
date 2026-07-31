# 커뮤니티 제목 미리보기(excerpt) — 설계 (Design)

> 날짜: 2026-07-31 · 범위: 커뮤니티 피드 목록에서 제목 hover 시 본문 요약(excerpt) 미리보기 · 성격: UI/UX 로드맵 **Phase 3 이월**(백엔드 계약 확장) · 파급 레포: `devpath-community-svc` + `devpath-frontend`(`shared` 발행 불필요)

## 1. 배경 / 목표

UI/UX 로드맵 Phase 3(커뮤니티 피드)는 `DpListRow`·필터·Sliver를 완결했으나, **`CommunityPostSummary`에 본문/요약이 없어** 제목 hover 미리보기(OverlayPortal)를 이월했다(행별 상세 N+1 회피). 이번 작업은 목록 계약에 `excerpt`(본문 요약)를 추가해 **웹에서 제목 hover 시 본문 미리보기**를 제공한다.

- **완료 정의**: 웹 커뮤니티 피드에서 게시글 제목에 마우스를 올리면 본문 앞부분 요약이 카드로 뜬다. 모바일(터치)은 hover가 없어 미표시. 신규 이벤트/쿼리 없이 기존 저장 본문에서 파생.

## 2. 현재 상태 (검증된 사실, 2026-07-31 코드 실측)

- `GET /community/posts` → `questionService.list(board, tag, sort)` → `List<PostSummaryView>`. `PostSummaryView`(`ai.devpath.community.post.dto`, **community-svc 로컬 record**) = `id·boardType·title·authorId·solved·upvoteCount·replyCount`(7필드, 본문/요약 없음).
- **본문 존재**: `community_qna`·`community_feedback_and_comments` 마이그레이션 모두 `body_md TEXT NOT NULL`. `QuestionService.list()`는 **전체 `CommunityPost` 엔티티**를 로드(`posts.findAllBoardsNewest()`/`findBoardNewest(board)`)하고 `.map()`으로 `PostSummaryView` 생성 → `p.getBodyMd()` 즉시 사용 가능(`detail()`이 이미 사용). **excerpt 파생에 추가 쿼리·N+1 없음.**
- dp_core `CommunityPostSummary`(freezed) = 7필드(동일). web·mobile 소비. web `_postRow`(`community_home_page.dart:165`)가 `DpListRow`로 렌더.
- `DpListRow`(`dp_design/lib/src/data/dp_list_row.dart`) = `title·accentColor·badges·trailing·onTap`, `DpInteractiveCard`(hover/focus) 베이스. 제목은 `Text(title)`. **DpListRow는 web 커뮤니티에서만 사용**(admin/mobile 미사용).
- **mobile은 `CommunityPostSummary`를 소비**(community_source/page/state)하나 `DpListRow` 미사용 → excerpt 필드는 흐르되 미리보기 미표시.

## 3. 범위 / 비범위

**범위**: `excerpt` 필드(백엔드+dp_core) + `DpListRow` hover 미리보기(웹) + web 배선.

**비범위**:
- 모바일 excerpt 인라인 표시(별도 UX, 범위 외).
- excerpt 하이라이트·검색·풀 마크다운 렌더(미리보기는 평문 요약).
- hover 액션 버튼(추천/북마크 등) — Phase 3에서 이미 제외.

## 4. 데이터 계약 (신규 필드 1개, additive)

`PostSummaryView`·`CommunityPostSummary`에 `excerpt` 추가:

| 필드 | 타입 | 의미 |
|---|---|---|
| `excerpt` | `String` | 본문(`body_md`) 평문 요약(선행 ~140자, 말줄임 …). 빈 본문이면 빈 문자열. |

- 백엔드 record: `String excerpt`(비-null, 빈 문자열 허용). JSON `{"excerpt":"@Transactional 전파가 …"}`.
- dp_core: `@Default('') String excerpt`(부재/누락 시 빈 문자열).

## 5. 백엔드 설계 (devpath-community-svc, Java / Spring Boot 4) — `shared` 발행 불필요

- **`Excerpts` 순수 헬퍼**(신규, 예: `ai.devpath.community.post.Excerpts`): `static String from(String bodyMd, int maxLen)` — 경량 평문화 후 절단.
  - 평문화(Fork 1b): 선행 마크다운 마커 제거(헤딩 `#{1,6}`·인용 `>`·불릿 `-*+`·번호목록), 강조/코드 마크 `` ` * _ ~ `` 제거, 개행·연속 공백을 단일 공백으로 collapse, trim.
  - 절단: `<= maxLen`이면 그대로, 초과면 `maxLen`자 + `…`.
  - null/blank 본문 → 빈 문자열.
  - **순수 로직 → DB 불필요 단위 테스트**(TDD 씨앗).
- `PostSummaryView`에 `excerpt` 필드 추가. `QuestionService.list()`의 `.map()`에서 `Excerpts.from(p.getBodyMd(), 140)` 채움.
- `detail()` 등 다른 소비처는 불변(excerpt는 목록 전용).

## 6. 프론트 설계 (devpath-frontend)

- **dp_core**: `CommunityPostSummary`에 `@Default('') String excerpt` 추가(freezed 재생성). **mobile 파급** → `melos analyze` 전 패키지 확인(additive+기본값이라 안전).
- **dp_design `DpListRow`**: 옵셔널 `String? preview` 슬롯 추가. 지정(비-null·비-blank) 시 제목을 `MouseRegion`+`OverlayPortal`로 감싸 hover 미리보기(Fork 2A):
  - `OverlayPortalController` + `CompositedTransformTarget`/`CompositedTransformFollower`(제목 아래 anchor)로 위치.
  - `MouseRegion.onEnter`→`controller.show()`, `onExit`→`controller.hide()`. **웹/데스크톱 hover에서만 발화**(모바일 터치는 hover 없음 → 미표시).
  - 미리보기 카드: `surface`+`border`+`panelRadius` 토큰, 최대폭 제한, `excerpt` 텍스트(2~3줄, `maxLines`+ellipsis). go_router/Riverpod 비의존 유지.
  - `preview` 미지정 시 기존 동작 그대로(회귀 보존).
- **web**: `_postRow`가 `DpListRow(preview: post.excerpt.isEmpty ? null : post.excerpt, ...)` 전달.

## 7. 결정 기록 (Forks)

- **Fork 1 — excerpt 포맷 = 경량 평문화 후 140자**(원문 마크다운 절단 아님). 미리보기가 `#`·`**` 노이즈 없이 깔끔. 백엔드 순수 헬퍼로 파생.
- **Fork 2 — hover 미리보기 = `OverlayPortal` 스타일 카드**(Flutter `Tooltip` 아님). 로드맵 Phase 3 원 의도·디자인된 카드·2~3줄 excerpt에 적합. 웹 전용(hover).
- **Fork 3 — 모바일 = 미리보기 미표시**(excerpt 필드는 흐르되 DpListRow 미사용). 웹 전용, 모바일 인라인은 범위 외.

## 8. 검증 / 테스트 전략 (TDD, CLAUDE.md 규칙 2)

- **백엔드**: `Excerpts` 순수 단위 테스트(마크다운 마커 제거·공백 collapse·140자 말줄임·빈 본문). `QuestionService.list` excerpt 채움 통합 테스트(`@SpringBootTest`, 로컬은 `pgvector/pgvector:pg16` 컨테이너로 postgres 기동 — 마이그레이션이 `CREATE EXTENSION vector` 요구). 로컬 postgres 미기동 시 순수 헬퍼가 TDD 타깃, list SQL은 CI.
- **프론트**: dp_core JSON 라운드트립(excerpt), `DpListRow` preview 위젯 테스트(마우스 hover 시 미리보기 텍스트 등장·미지정 시 미표시·onTap 회귀), web `_postRow` 회귀(기존 커뮤니티 테스트 유지).
- **게이트**: 백엔드 `./gradlew test`. 프론트 `melos run format`→`analyze`→`test`.

## 9. 작업 분해 / 레포 / 브랜치

- **레포 2곳**: `devpath-community-svc`(Excerpts 헬퍼+PostSummaryView+list) · `devpath-frontend`(dp_core+DpListRow+web). `shared` 발행 불필요(PostSummaryView는 community-svc 로컬 record).
- **브랜치**: frontend `feat/community-excerpt-preview`(spec/plan/구현 동일 브랜치) → `develop` PR. community-svc `feat/community-excerpt` → 자체 `develop` PR. 백엔드 먼저 머지 권장(계약 확정).
- **순서**: 백엔드 excerpt 파생·계약 확정 → dp_core → DpListRow preview → web 배선(dp_core/web은 목 데이터로 병행 가능).

## 10. 참조

- 로드맵 spec(이월 근거): `devpath-frontend/docs/superpowers/specs/2026-07-30-web-admin-uiux-elevation-roadmap-design.md`
- 핸드오프: `documents/docs/superpowers/handoff-2026-07-31-uiux-roadmap-complete-next-contract-expansion.md`(§B)
- 선행 작업 A(대시보드 시계열, 동형 계약확장): `2026-07-31-dashboard-timeseries-design.md`
- 관련 코드: `devpath-community-svc/.../post/{CommunityController,QuestionService}.java`·`.../post/dto/PostSummaryView.java`·`.../post/CommunityPost.java` · `devpath-frontend/packages/dp_core/lib/src/models/community_post.dart`·`packages/dp_design/lib/src/data/dp_list_row.dart`·`apps/web/lib/src/features/community/presentation/community_home_page.dart`
