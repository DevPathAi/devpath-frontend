# 커뮤니티 자유/피드백 보드 웹 (하위 B) 설계

> 커뮤니티 하위 A(백엔드 FREE/FEEDBACK 보드 + 댓글, community-svc #28·shared #52 머지 완료)의 프론트엔드. 통합 피드 + 일반 게시글 상세/작성 + 댓글 UI를 웹(`apps/web`)에 추가한다.

## 목표

Q&A만 있던 커뮤니티에 **자유(FREE)·피드백(FEEDBACK)** 보드를 노출한다. 하나의 통합 피드에서 보드 필터칩으로 전환하고, 항목 유형(Q&A/자유/피드백)을 뱃지로 구분하며, 일반 게시글은 상세에서 **댓글**로 소통한다.

## 사용자 결정 (brainstorm)

1. **정보구조 = 통합 피드 + 필터칩** — `/community` 한 화면에 `[전체|Q&A|자유|피드백]` 필터칩. 항목에 보드 뱃지. (백엔드 요약 확장 필요)
2. **작성 진입 = FAB 스피드다이얼** — FAB 탭 → `[질문하기|자유글|피드백 요청]` 메뉴 → 해당 작성 페이지.
3. **일반 게시글 기능 = 제목+본문(마크다운)+댓글 + 게시글 추천(upvote) + 태그.**

## 범위 & 분해 (2 PR)

- **PR-A (community-svc)**: 통합 피드용 목록 요약 확장(`boardType` + 일반화된 `replyCount`) + 전-보드 목록 모드.
- **PR-B (devpath-frontend `apps/web`)**: 통합 피드 UI + 일반 게시글 상세/작성 + 댓글.

계약 우선: 프론트는 목 픽스처로 독립 개발/테스트하되, 실 계약은 PR-A가 확정한다. PR-A 선행 머지 권장.

---

## PR-A — community-svc 백엔드 확장

### 현황 (실측)
- `QuestionService.list(board, tag, sort)`: `board` 미지정 시 `"QNA"` 기본, `posts.findBoardNewest(b)`로 **단일 보드** 반환. 요약 매핑은 `solved`(questions), `answerCount`(answers)로 **Q&A 형태**.
- `PostSummaryView(long id, String title, Long authorId, boolean solved, int upvoteCount, int answerCount)` — **`boardType` 없음**.
- `community_posts.board_type ∈ {QNA,FREE,PROJECT,STUDY,ALUMNI,FEEDBACK}` (shared #52로 FEEDBACK 추가됨). 일반 게시글 댓글 = `community_comments`(#28).

### 변경
1. **`PostSummaryView` 확장**: `answerCount` → **`replyCount`**(일반화: QNA=답변 수, FREE/FEEDBACK=댓글 수) + **`boardType`** 필드 추가. `upvoteCount`·`solved` 유지.
   - 최종: `PostSummaryView(long id, String boardType, String title, Long authorId, boolean solved, int upvoteCount, int replyCount)`.
2. **전-보드 목록 모드**: `list(board,...)`에서 `board`가 `null`/blank/`"ALL"`이면 **전 보드 최신 혼합** 반환(기존 기본값 QNA → ALL로 변경). 특정 보드 값이면 그 보드만.
   - 신규 리포 메서드 `CommunityPostRepository.findAllBoardsNewest()`(status='PUBLISHED' 전 보드 최신순).
   - 매핑: 각 post의 `boardType`은 엔티티에서, `replyCount`는 `"QNA".equals(boardType) ? answers.countByQuestionId(id) : comments.countByPostId(id)`.
3. **주의**: `list` 기본값이 QNA→ALL로 바뀐다. 기존 프론트 `communityListProvider`는 board 무인자 호출 시 Q&A만 기대했으므로, PR-B에서 필터 기본을 "전체"로 맞춘다(계약 동시 변경).

### 테스트 (Test-First, MockMvc 실 DB)
- `전체 피드`: FREE·FEEDBACK·QNA 각 1건 시드 → `GET /community/posts`(board 미지정)가 **3건 모두** 반환·각 `boardType` 정확·QNA는 replyCount=답변수/일반은 댓글수.
- `보드 필터`: `GET /community/posts?board=FREE` → FREE만.
- 기존 Q&A 목록 회귀: `board=QNA`가 기존과 동일 동작.

### 파일
- Modify: `PostSummaryView.java`, `QuestionService.java`(list 매핑), `CommunityPostRepository.java`(findAllBoardsNewest).
- Test: `FeedMockMvcTest.java`(신규) + 기존 목록 테스트 갱신.

---

## PR-B — devpath-frontend `apps/web`

기존 커뮤니티 feature 패턴 승계: `data/`(source provider)→`application/`(Notifier)→`state/`→`presentation/`. Riverpod·go_router·freezed·`DpMarkdown`(dp_design)·`web_mock_fixtures.dart`.

### 모델 (dp_core)
- `CommunityPostSummary`: **`String boardType`** 추가, `answerCount`→**`replyCount`**(freezed·json).
- 신규 **`CommunityPostDetail`**: `int id, String boardType, String title, String bodyMd, int? authorId, int upvoteCount, int downvoteCount, List<String> tags, List<CommunityComment> comments` (← 백엔드 `PostDetailView` #28).
- 신규 **`CommunityComment`**: `int id, int? authorId, String bodyMd, int upvoteCount, String createdAt` (← 백엔드 `CommentView` #28).
- freezed 코드생성(`.freezed.dart`·`.g.dart`) 재생성.

### 데이터 (`community_source.dart`) — 신규 provider
- `postCreateProvider`: `({required String boardType, required String title, required String bodyMd, required List<String> tags})` → `POST /community/posts` → `CommunityPostDetail`.
- `postDetailFetchProvider`: `(int id)` → `GET /community/posts/{id}` → `CommunityPostDetail`.
- `commentCreateProvider`: `(int postId, String bodyMd)` → `POST /community/posts/{id}/comments` → `CommunityComment`.
- 목록: 기존 `communityListProvider`에 board 인자 유지("전체"=board 생략). (게시글 추천은 기존 `communityVoteProvider(target: post)` 재사용.)

### 상태·컨트롤러
- **통합 피드**: `CommunityState`에 **`board` 필터**(enum: all/qna/free/feedback) 추가. `CommunityController.load(board)`가 필터 반영. 필터칩 탭 → 재조회.
- 신규 **`PostDetailController`**(`application/post_detail_controller.dart`) + `PostDetailState`: 게시글+댓글 로드, 댓글 작성(작성 후 상세 갱신), 게시글 추천(vote 후 upvoteCount 반영).

### 프레젠테이션·라우팅
- **`community_home_page.dart`(개편)**: 상단 **필터칩 4개**(`전체/Q&A/자유/피드백`) + 카드에 **보드 뱃지**(자유/피드백/Q&A) + `replyCount` 라벨(Q&A="답변 N"/일반="댓글 N") + **boardType 기반 라우팅**(QNA→`/community/:id`, FREE/FEEDBACK→`/community/post/:id`). **FAB 스피드다이얼**(질문하기→`/community/new`, 자유글→`/community/new/post?board=FREE`, 피드백→`?board=FEEDBACK`).
- 신규 **`post_detail_page.dart`** (`/community/post/:id`): `DpMarkdown` 본문 + 태그 칩 + **추천 버튼**(upvoteCount) + **댓글 목록**(작성자·본문·시각) + **댓글 작성 입력**(빈값 방지·로그인 필요 시 우아 처리).
- 신규 **`post_create_page.dart`** (`/community/new/post`): board 프리셋(query `board`), 제목·본문(마크다운)·태그 입력, 제출 → 상세로 이동.
- **라우터**(`app/router.dart`): `/community/new/post`·`/community/post/:id` 추가. 선언 순서 = `/community/new` → `/community/new/post` → `/community/post/:id` → `/community/:id`(정적 세그먼트가 `:id`보다 먼저).

### 목 픽스처 (`web_mock_fixtures.dart`)
- 추가: `GET /community/posts`(전체=혼합 3보드 응답으로 갱신), `GET /community/posts/{id}`(일반 상세+댓글), `POST /community/posts`, `POST /community/posts/{id}/comments`. 기존 `POST /community/posts/1/vote` 재사용.

### 테스트 (Test-First, `flutter_test`+`ProviderContainer`)
- 데이터: 각 신규 provider inline override로 요청 경로·바디·역직렬화 검증.
- 컨트롤러: 피드 필터 전환 재조회, PostDetailController 댓글 작성 후 상태 갱신·추천 반영.
- 위젯: 통합 피드 보드 뱃지·필터칩·boardType 라우팅, 상세 마크다운·댓글 렌더·작성, 작성 페이지 제출. `melos run analyze/test/format` green.

---

## 범위 밖 (YAGNI)
- 댓글 추천·수정·삭제(백엔드 엔드포인트 없음), 게시글 수정·삭제, 페이지네이션, 실시간 갱신.
- 모바일 앱(`apps/mobile`)·admin — 웹만.
- PROJECT/STUDY/ALUMNI 보드(현재 미노출 유지).

## 롤아웃
- PR-A(community-svc) → develop 머지 + (필요시 배포)로 실 계약 확정. PR-B(frontend) → develop 머지.
- 로컬 개발/CI는 목 픽스처로 프론트 독립 검증(실 서비스 불요).
