# 커뮤니티 자유/피드백 보드 웹 (하위 B) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Q&A만 있던 커뮤니티 웹에 자유(FREE)·피드백(FEEDBACK) 보드를 통합 피드+필터칩으로 노출하고, 일반 게시글 상세(마크다운·태그·추천·댓글)와 작성 UI를 추가한다.

**Architecture:** 백엔드(community-svc)는 목록 요약을 `boardType`+일반화된 `replyCount`로 확장하고 전-보드 혼합 목록을 제공한다(PR-A). 프론트(devpath-frontend `apps/web`)는 기존 Riverpod(Notifier)·go_router·freezed·`DpMarkdown` 패턴을 승계해 통합 피드·일반 게시글 상세/작성·댓글을 추가한다(PR-B). 프론트는 목 픽스처로 독립 검증한다.

**Tech Stack:** 백엔드=Java 21·Spring Boot 4.0.7·Gradle·JUnit5·MockMvc·실 DB(`devpath_citest`). 프론트=Flutter Web·Dart pub workspaces+melos 7·flutter_riverpod·go_router·freezed·flutter_test.

## Global Constraints

- 두 레포·두 브랜치: **community-svc**(`feat/community-feed-summary`, `D:\workspace\dpa\devpath-community-svc`, origin/develop 분기) · **devpath-frontend**(`feat/community-free-feedback-web`, `D:\workspace\dpa\devpath-frontend`, **이미 생성됨**). 모든 git/파일 명령은 절대경로 또는 `-C <repo>` 사용(cwd 리셋 주의).
- **Test-First**: 실패 테스트 먼저 → 최소 구현 → 통과 확인. 각 Task 끝에 커밋.
- 백엔드 빌드/테스트: `cd /d/workspace/dpa/devpath-community-svc && ./gradlew test --tests "<FQCN>"`. 실 DB `devpath_citest`(이미 존재). community-svc는 shared를 Maven 의존(마이그=shared JAR).
- 프론트 검증: 레포 루트에서 `dart pub global run melos run analyze` · `melos run test` · `melos run format`. 단일 테스트: `cd apps/web && flutter test test/<path>`.
- 프론트 패턴: 상태관리=`Notifier`+`NotifierProvider`, 데이터=`Provider<typedef>`(apiClient 경유, 목 분기 없음 — `MockHttpAdapter`가 픽스처 처리), 모델=freezed(`.freezed.dart`·`.g.dart` 코드생성=`dart run build_runner build --delete-conflicting-outputs`), UI=Material 위젯 직접+`context.dpColors`/`DpSpacing`/`DpIcons`/`DpMarkdown`.
- `apiClient`: `client.get<T>(path, {query})`·`client.post<T>(path, {body})`. bare 배열은 `get<List<dynamic>>`.
- 백엔드 계약(하위 A #28, 실측): `POST /community/posts {boardType,title,bodyMd,tags[]}`→`PostDetailView`; `GET /community/posts/{id}`→`PostDetailView(id,boardType,title,bodyMd,authorId,upvoteCount,downvoteCount,tags[],comments[])`; `POST /community/posts/{id}/comments {bodyMd}`→`CommentView(id,authorId,bodyMd,upvoteCount,createdAt)`; `POST /community/posts/{id}/vote {value}`→void(기존).

---

## PR-A — community-svc 백엔드

### Task 1: 목록 요약 확장(boardType + replyCount) + 전-보드 목록

**Files:**
- Modify: `src/main/java/ai/devpath/community/post/dto/PostSummaryView.java`
- Modify: `src/main/java/ai/devpath/community/post/CommunityPostRepository.java`
- Modify: `src/main/java/ai/devpath/community/post/QuestionService.java` (list 메서드, 현재 87–95행)
- Test: `src/test/java/ai/devpath/community/post/FeedMockMvcTest.java` (신규)

**Interfaces:**
- Produces: `PostSummaryView(long id, String boardType, String title, Long authorId, boolean solved, int upvoteCount, int replyCount)`; `GET /community/posts`(board 미지정)=전 보드 최신 혼합, `?board=FREE`=FREE만. replyCount=QNA는 답변수·FREE/FEEDBACK은 댓글수. → 프론트 PR-B가 소비.

- [ ] **Step 1: 브랜치 분기**

Run: `git -C D:/workspace/dpa/devpath-community-svc switch -c feat/community-feed-summary origin/develop`

- [ ] **Step 2: 실패 테스트 작성**

Create `src/test/java/ai/devpath/community/post/FeedMockMvcTest.java`:

```java
package ai.devpath.community.post;

import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class FeedMockMvcTest {

  @Autowired MockMvc mvc;

  private long createFree(String title) throws Exception {
    String body = mvc.perform(post("/community/posts")
            .with(jwt().jwt(j -> j.subject("500")))
            .contentType("application/json")
            .content("{\"boardType\":\"FREE\",\"title\":\"" + title + "\",\"bodyMd\":\"b\",\"tags\":[]}"))
        .andExpect(status().isCreated()).andReturn().getResponse().getContentAsString();
    return com.jayway.jsonpath.JsonPath.parse(body).read("$.id", Long.class);
  }

  @Test
  void feed_withoutBoard_returnsAllBoards_withBoardTypeAndReplyCount() throws Exception {
    long freeId = createFree("자유피드글");
    mvc.perform(post("/community/posts/" + freeId + "/comments")
            .with(jwt().jwt(j -> j.subject("501")))
            .contentType("application/json").content("{\"bodyMd\":\"댓글\"}"))
        .andExpect(status().isCreated());

    // board 미지정 = 전 보드. 방금 만든 FREE 글이 boardType=FREE·replyCount>=1로 포함.
    mvc.perform(get("/community/posts").with(jwt().jwt(j -> j.subject("500"))))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$[?(@.id == " + freeId + ")].boardType").value(
            org.hamcrest.Matchers.hasItem("FREE")))
        .andExpect(jsonPath("$[?(@.id == " + freeId + ")].replyCount").value(
            org.hamcrest.Matchers.hasItem(1)));
  }

  @Test
  void feed_boardFilter_returnsOnlyThatBoard() throws Exception {
    createFree("자유필터글");
    mvc.perform(get("/community/posts").param("board", "FREE")
            .with(jwt().jwt(j -> j.subject("500"))))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$[*].boardType").value(
            org.hamcrest.Matchers.everyItem(org.hamcrest.Matchers.is("FREE"))));
  }
}
```

- [ ] **Step 3: 실패 확인**

Run: `cd /d/workspace/dpa/devpath-community-svc && ./gradlew test --tests "ai.devpath.community.post.FeedMockMvcTest"`
Expected: FAIL(응답에 boardType/replyCount 없음 → JsonPath 불일치).

- [ ] **Step 4: PostSummaryView 확장**

Replace `src/main/java/ai/devpath/community/post/dto/PostSummaryView.java` 내용:

```java
package ai.devpath.community.post.dto;

public record PostSummaryView(long id, String boardType, String title, Long authorId,
    boolean solved, int upvoteCount, int replyCount) {}
```

- [ ] **Step 5: 전-보드 리포 메서드 추가**

`CommunityPostRepository.java`에 메서드 추가(기존 `findBoardNewest` 아래):

```java
  @org.springframework.data.jpa.repository.Query(
    "select p from CommunityPost p where p.status = 'PUBLISHED' order by p.id desc")
  java.util.List<CommunityPost> findAllBoardsNewest();
```

- [ ] **Step 6: QuestionService.list 갱신**

`QuestionService.list(String board, String tag, String sort)`(현재 87–95행)를 교체. `comments`(CommunityCommentRepository)를 생성자 주입에 추가해야 한다 — 필드·생성자에 `CommunityCommentRepository comments` 추가(기존 `answers`·`questions` 옆).

```java
  public List<PostSummaryView> list(String board, String tag, String sort) {
    List<CommunityPost> found = (board == null || board.isBlank() || "ALL".equals(board))
        ? posts.findAllBoardsNewest()
        : posts.findBoardNewest(board);
    return found.stream()
        .map(p -> {
          boolean isQna = "QNA".equals(p.getBoardType());
          int replyCount = isQna
              ? (int) answers.countByQuestionId(p.getId())
              : (int) comments.countByPostId(p.getId());
          boolean solved = isQna
              ? questions.findById(p.getId()).map(CommunityQuestion::isSolved).orElse(false)
              : false;
          return new PostSummaryView(p.getId(), p.getBoardType(), p.getTitle(),
              p.getAuthorId(), solved, p.getUpvoteCount(), replyCount);
        })
        .collect(Collectors.toList());
  }
```

> 확인: `CommunityCommentRepository.countByPostId(long)`(하위 A Task2)·`answers.countByQuestionId(long)`·`CommunityPost.getBoardType()` 존재. `answers.countByQuestionId` 반환형이 `long`이면 `(int)` 캐스팅(위 코드 반영).

- [ ] **Step 7: 통과 확인 + 전체 빌드**

Run: `cd /d/workspace/dpa/devpath-community-svc && ./gradlew test --tests "ai.devpath.community.post.FeedMockMvcTest"` → PASS.
Run: `cd /d/workspace/dpa/devpath-community-svc && ./gradlew build` → BUILD SUCCESSFUL(기존 목록/Q&A 테스트 회귀 없음). 기존 테스트가 `answerCount`를 참조하면 `replyCount`로 갱신(근본원인 규명 후).

- [ ] **Step 8: 커밋**

```bash
git -C D:/workspace/dpa/devpath-community-svc add \
  src/main/java/ai/devpath/community/post/dto/PostSummaryView.java \
  src/main/java/ai/devpath/community/post/CommunityPostRepository.java \
  src/main/java/ai/devpath/community/post/QuestionService.java \
  src/test/java/ai/devpath/community/post/FeedMockMvcTest.java
git -C D:/workspace/dpa/devpath-community-svc commit -m "feat(community): 목록 요약 boardType+replyCount 확장 + 전-보드 피드"
```

---

## PR-B — devpath-frontend `apps/web`

### Task 2: dp_core 모델 (요약 확장 + 게시글 상세 + 댓글)

**Files:**
- Modify: `packages/dp_core/lib/src/models/community_post.dart`
- Modify: `apps/web/lib/src/features/community/presentation/community_home_page.dart` (80행 라벨 — 컴파일 유지용 최소 수정)
- Modify: `apps/web/test/features/community/community_controller_test.dart` (헬퍼 `_p` — 컴파일 유지)
- Test: `packages/dp_core/test/models/community_post_test.dart` (신규 또는 기존에 케이스 추가)

**Interfaces:**
- Produces: `CommunityPostSummary(id, title, boardType, authorId?, solved, upvoteCount, replyCount)`; `CommunityPostDetail(id, boardType, title, bodyMd, authorId?, upvoteCount, downvoteCount, tags, comments)`; `CommunityComment(id, authorId?, bodyMd, upvoteCount, createdAt)`. → Task 3~8 소비.

- [ ] **Step 1: 실패 테스트 작성**

Create `packages/dp_core/test/models/community_post_test.dart`:

```dart
import 'package:dp_core/dp_core.dart';
import 'package:test/test.dart';

void main() {
  test('CommunityPostSummary.fromJson: boardType/replyCount 파싱', () {
    final s = CommunityPostSummary.fromJson({
      'id': 1, 'boardType': 'FREE', 'title': '자유글',
      'authorId': 42, 'solved': false, 'upvoteCount': 2, 'replyCount': 3,
    });
    expect(s.boardType, 'FREE');
    expect(s.replyCount, 3);
  });

  test('CommunityPostDetail.fromJson: 댓글 스레드 파싱', () {
    final d = CommunityPostDetail.fromJson({
      'id': 5, 'boardType': 'FEEDBACK', 'title': '피드백', 'bodyMd': '# 본문',
      'authorId': 7, 'upvoteCount': 1, 'downvoteCount': 0,
      'tags': ['dart'],
      'comments': [
        {'id': 10, 'authorId': 8, 'bodyMd': '댓글1', 'upvoteCount': 0, 'createdAt': '2026-07-29T00:00:00Z'},
      ],
    });
    expect(d.boardType, 'FEEDBACK');
    expect(d.tags, ['dart']);
    expect(d.comments.single.bodyMd, '댓글1');
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd /d/workspace/dpa/devpath-frontend/packages/dp_core && dart test test/models/community_post_test.dart`
Expected: FAIL(컴파일 — `boardType`/`CommunityPostDetail`/`replyCount` 없음).

- [ ] **Step 3: 모델 수정**

`packages/dp_core/lib/src/models/community_post.dart`의 `CommunityPostSummary`를 교체(주석 유지):

```dart
@freezed
abstract class CommunityPostSummary with _$CommunityPostSummary {
  const factory CommunityPostSummary({
    required int id,
    required String title,
    @Default('QNA') String boardType,
    int? authorId,
    @Default(false) bool solved,
    @Default(0) int upvoteCount,
    @Default(0) int replyCount,
  }) = _CommunityPostSummary;

  factory CommunityPostSummary.fromJson(Map<String, dynamic> json) =>
      _$CommunityPostSummaryFromJson(json);
}
```

같은 파일에 신규 모델 추가(파일 끝):

```dart
/// 일반 게시글 상세(`GET /community/posts/{id}` → `PostDetailView`, FREE/FEEDBACK).
/// Q&A와 달리 답변/채택이 없고 **댓글**로 소통한다.
@freezed
abstract class CommunityPostDetail with _$CommunityPostDetail {
  const factory CommunityPostDetail({
    required int id,
    required String boardType,
    required String title,
    required String bodyMd,
    int? authorId,
    @Default(0) int upvoteCount,
    @Default(0) int downvoteCount,
    @Default(<String>[]) List<String> tags,
    @Default(<CommunityComment>[]) List<CommunityComment> comments,
  }) = _CommunityPostDetail;

  factory CommunityPostDetail.fromJson(Map<String, dynamic> json) =>
      _$CommunityPostDetailFromJson(json);
}

/// 일반 게시글 댓글(`CommentView`). createdAt은 ISO-8601 문자열(표시용).
@freezed
abstract class CommunityComment with _$CommunityComment {
  const factory CommunityComment({
    required int id,
    int? authorId,
    required String bodyMd,
    @Default(0) int upvoteCount,
    required String createdAt,
  }) = _CommunityComment;

  factory CommunityComment.fromJson(Map<String, dynamic> json) =>
      _$CommunityCommentFromJson(json);
}
```

- [ ] **Step 4: 코드생성**

Run: `cd /d/workspace/dpa/devpath-frontend/packages/dp_core && dart run build_runner build --delete-conflicting-outputs`
Expected: `community_post.freezed.dart`·`.g.dart` 재생성(신규 모델 포함).

- [ ] **Step 5: 컴파일 유지 — 기존 참조 갱신**

`apps/web/lib/src/features/community/presentation/community_home_page.dart` 80행 `'답변 ${p.answerCount} · 추천 ${p.upvoteCount}'` → `'답변 ${p.replyCount} · 추천 ${p.upvoteCount}'` (Task 6에서 보드별 라벨로 재작성 예정, 지금은 컴파일만).

`apps/web/test/features/community/community_controller_test.dart` 8–9행 헬퍼 `answerCount: 1` → `replyCount: 1`.

- [ ] **Step 6: 통과 확인**

Run: `cd /d/workspace/dpa/devpath-frontend/packages/dp_core && dart test test/models/community_post_test.dart` → PASS.
Run(레포 루트): `dart pub global run melos run analyze` → 오류 0(위 참조 갱신으로 컴파일 유지).

- [ ] **Step 7: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add \
  packages/dp_core/lib/src/models/community_post.dart \
  packages/dp_core/lib/src/models/community_post.freezed.dart \
  packages/dp_core/lib/src/models/community_post.g.dart \
  packages/dp_core/test/models/community_post_test.dart \
  apps/web/lib/src/features/community/presentation/community_home_page.dart \
  apps/web/test/features/community/community_controller_test.dart
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(dp_core): 커뮤니티 요약 boardType/replyCount + 게시글 상세/댓글 모델"
```

---

### Task 3: 데이터 레이어 신규 provider (게시글 작성/상세/댓글)

**Files:**
- Modify: `apps/web/lib/src/features/community/data/community_source.dart`
- Test: `apps/web/test/features/community/community_source_posts_test.dart` (신규)

**Interfaces:**
- Consumes: Task 2 모델, 기존 `apiClientProvider`.
- Produces: `postCreateProvider`(`PostCreate`), `postDetailFetchProvider`(`PostDetailFetch`), `commentCreateProvider`(`CommentCreate`). → Task 5·7·8 소비.

- [ ] **Step 1: 실패 테스트 작성**

Create `apps/web/test/features/community/community_source_posts_test.dart`:

```dart
import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_api_client.dart';

void main() {
  test('postCreate: POST /community/posts + boardType/tags 바디', () async {
    final fake = FakeApiClient(postJson: {
      'id': 9, 'boardType': 'FREE', 'title': '자유글', 'bodyMd': 'b',
      'authorId': 1, 'upvoteCount': 0, 'downvoteCount': 0, 'tags': ['t'], 'comments': [],
    });
    final c = ProviderContainer(overrides: [apiClientProvider.overrideWithValue(fake)]);
    addTearDown(c.dispose);

    final view = await c.read(postCreateProvider)(
        boardType: 'FREE', title: '자유글', bodyMd: 'b', tags: ['t']);
    expect(fake.lastPath, '/community/posts');
    expect(fake.lastBody?['boardType'], 'FREE');
    expect(view.id, 9);
  });

  test('commentCreate: POST /community/posts/9/comments', () async {
    final fake = FakeApiClient(postJson: {
      'id': 30, 'authorId': 2, 'bodyMd': '댓글', 'upvoteCount': 0, 'createdAt': '2026-07-29T00:00:00Z',
    });
    final c = ProviderContainer(overrides: [apiClientProvider.overrideWithValue(fake)]);
    addTearDown(c.dispose);

    final view = await c.read(commentCreateProvider)(9, '댓글');
    expect(fake.lastPath, '/community/posts/9/comments');
    expect(view.bodyMd, '댓글');
  });
}
```

> `FakeApiClient`(support): 기존 테스트가 apiClient를 어떻게 대체하는지 먼저 확인하라. 기존 소스 테스트가 provider override 방식(예: `postDetailFetchProvider.overrideWithValue(...)`)만 쓰면, 위 대신 **각 provider를 inline override**해 요청 캡처하는 방식으로 맞춘다(기존 `community_source` 테스트 패턴 승계). apiClient 직접 페이크가 지원되지 않으면 이 Step의 테스트를 provider-override 스타일로 재작성(경로/바디 대신 반환값 검증). **명세가 부족하면 멈추고 기존 테스트 1개를 읽어 패턴을 확정한 뒤 진행.**

- [ ] **Step 2: 실패 확인**

Run: `cd /d/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/community/community_source_posts_test.dart`
Expected: FAIL(`postCreateProvider`/`commentCreateProvider` 미정의).

- [ ] **Step 3: provider 추가**

`community_source.dart`에 typedef + provider 추가(파일 끝, 기존 스타일 승계):

```dart
/// 일반 게시글 작성 `POST /community/posts {boardType,title,bodyMd,tags}` → `PostDetailView`.
typedef PostCreate =
    Future<CommunityPostDetail> Function({
      required String boardType,
      required String title,
      required String bodyMd,
      required List<String> tags,
    });

/// 일반 게시글 상세 `GET /community/posts/{id}` → `PostDetailView`.
typedef PostDetailFetch = Future<CommunityPostDetail> Function(int id);

/// 댓글 작성 `POST /community/posts/{id}/comments {bodyMd}` → `CommentView`.
typedef CommentCreate = Future<CommunityComment> Function(int postId, String bodyMd);

final postCreateProvider = Provider<PostCreate>((ref) {
  final client = ref.watch(apiClientProvider);
  return ({
    required String boardType,
    required String title,
    required String bodyMd,
    required List<String> tags,
  }) async {
    final json = await client.post<Map<String, dynamic>>(
      '/community/posts',
      body: {'boardType': boardType, 'title': title, 'bodyMd': bodyMd, 'tags': tags},
    );
    return CommunityPostDetail.fromJson(json);
  };
});

final postDetailFetchProvider = Provider<PostDetailFetch>((ref) {
  final client = ref.watch(apiClientProvider);
  return (id) async {
    final json = await client.get<Map<String, dynamic>>('/community/posts/$id');
    return CommunityPostDetail.fromJson(json);
  };
});

final commentCreateProvider = Provider<CommentCreate>((ref) {
  final client = ref.watch(apiClientProvider);
  return (postId, bodyMd) async {
    final json = await client.post<Map<String, dynamic>>(
      '/community/posts/$postId/comments',
      body: {'bodyMd': bodyMd},
    );
    return CommunityComment.fromJson(json);
  };
});
```

- [ ] **Step 4: 통과 확인**

Run: `cd /d/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/community/community_source_posts_test.dart` → PASS.

- [ ] **Step 5: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add \
  apps/web/lib/src/features/community/data/community_source.dart \
  apps/web/test/features/community/community_source_posts_test.dart
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(community): 게시글 작성/상세/댓글 데이터 provider"
```

---

### Task 4: 통합 피드 — 보드 필터 상태/컨트롤러

**Files:**
- Modify: `apps/web/lib/src/features/community/state/community_state.dart`
- Modify: `apps/web/lib/src/features/community/application/community_controller.dart`
- Test: `apps/web/test/features/community/community_controller_test.dart` (케이스 추가)

**Interfaces:**
- Produces: `CommunityBoard` enum(all/qna/free/feedback), `CommunityState.board`, `CommunityController.selectBoard(CommunityBoard)`. → Task 6 소비.

- [ ] **Step 1: 실패 테스트 추가**

`community_controller_test.dart`에 케이스 추가:

```dart
  test('selectBoard: 필터를 board 파라미터로 전달하고 재조회', () async {
    String? seenBoard;
    final c = ProviderContainer(
      overrides: [
        communityListProvider.overrideWithValue(({String? board, String? tag, String? sort}) async {
          seenBoard = board;
          return const [];
        }),
      ],
    );
    addTearDown(c.dispose);

    await c.read(communityControllerProvider.notifier).selectBoard(CommunityBoard.free);
    expect(seenBoard, 'FREE');
    expect(c.read(communityControllerProvider).board, CommunityBoard.free);
  });

  test('selectBoard.all: board=null(전체)로 조회', () async {
    String? seenBoard = 'sentinel';
    final c = ProviderContainer(
      overrides: [
        communityListProvider.overrideWithValue(({String? board, String? tag, String? sort}) async {
          seenBoard = board;
          return const [];
        }),
      ],
    );
    addTearDown(c.dispose);
    await c.read(communityControllerProvider.notifier).selectBoard(CommunityBoard.all);
    expect(seenBoard, isNull);
  });
```

- [ ] **Step 2: 실패 확인**

Run: `cd /d/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/community/community_controller_test.dart`
Expected: FAIL(`CommunityBoard`/`selectBoard`/`.board` 미정의).

- [ ] **Step 3: 상태 확장**

`community_state.dart`를 교체:

```dart
import 'package:dp_core/dp_core.dart';

enum CommunityPhase { loading, loaded, failed }

/// 보드 필터. all=전체(board 미전달), 나머지는 백엔드 boardType 값.
enum CommunityBoard {
  all(null, '전체'),
  qna('QNA', 'Q&A'),
  free('FREE', '자유'),
  feedback('FEEDBACK', '피드백');

  const CommunityBoard(this.value, this.label);
  final String? value;
  final String label;
}

class CommunityState {
  const CommunityState({
    this.posts = const [],
    this.phase = CommunityPhase.loading,
    this.board = CommunityBoard.all,
    this.error,
  });

  final List<CommunityPostSummary> posts;
  final CommunityPhase phase;
  final CommunityBoard board;
  final String? error;

  CommunityState copyWith({
    List<CommunityPostSummary>? posts,
    CommunityPhase? phase,
    CommunityBoard? board,
    String? error,
  }) => CommunityState(
        posts: posts ?? this.posts,
        phase: phase ?? this.phase,
        board: board ?? this.board,
        error: error,
      );
}
```

- [ ] **Step 4: 컨트롤러 확장**

`community_controller.dart`의 `CommunityController`에 `selectBoard` 추가하고 `load`가 현재 board를 사용하도록:

```dart
class CommunityController extends Notifier<CommunityState> {
  @override
  CommunityState build() => const CommunityState();

  Future<void> selectBoard(CommunityBoard board) async {
    state = state.copyWith(board: board);
    await load();
  }

  Future<void> load({String? tag, String? sort}) async {
    state = state.copyWith(phase: CommunityPhase.loading);
    try {
      final posts = await ref.read(communityListProvider)(
        board: state.board.value,
        tag: tag,
        sort: sort,
      );
      state = state.copyWith(posts: posts, phase: CommunityPhase.loaded);
    } on ApiException catch (e) {
      state = state.copyWith(phase: CommunityPhase.failed, error: e.message);
    }
  }
}
```

> 주의: 기존 `load({String? board, ...})` 시그니처에서 `board` 파라미터를 제거하고 `state.board.value`를 쓴다. 기존 테스트 `load(board: 'QNA', sort: ...)` 케이스는 `selectBoard(CommunityBoard.qna)` + sort 확인으로 갱신하거나 유지되도록 `load`에 `board` 옵션을 남기려면 대신 `selectBoard`로 위임. **기존 3번째 테스트(board/tag/sort 전달)를 selectBoard 기반으로 갱신**한다.

- [ ] **Step 5: 통과 확인**

Run: `cd /d/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/community/community_controller_test.dart` → PASS(신규+기존 갱신).

- [ ] **Step 6: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add \
  apps/web/lib/src/features/community/state/community_state.dart \
  apps/web/lib/src/features/community/application/community_controller.dart \
  apps/web/test/features/community/community_controller_test.dart
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(community): 통합 피드 보드 필터 상태/컨트롤러"
```

---

### Task 5: 일반 게시글 상세 컨트롤러 (게시글+댓글+추천)

**Files:**
- Create: `apps/web/lib/src/features/community/state/post_detail_state.dart`
- Create: `apps/web/lib/src/features/community/application/post_detail_controller.dart`
- Test: `apps/web/test/features/community/post_detail_controller_test.dart` (신규)

**Interfaces:**
- Consumes: Task 3 `postDetailFetchProvider`·`commentCreateProvider`, 기존 `communityVoteProvider`(`CommunityVoteTarget.post`).
- Produces: `PostDetailController`(family by int id): `load()`, `addComment(String)`, `upvote()`. `PostDetailState(detail?, phase, error, submitting)`. → Task 7 소비.

- [ ] **Step 1: 실패 테스트 작성**

Create `apps/web/test/features/community/post_detail_controller_test.dart`:

```dart
import 'package:devpath_web/src/features/community/application/post_detail_controller.dart';
import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/state/post_detail_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

CommunityPostDetail _detail({List<CommunityComment> comments = const []}) =>
    CommunityPostDetail(id: 9, boardType: 'FREE', title: 't', bodyMd: 'b', comments: comments);

void main() {
  test('load: 상세를 loaded로 채운다', () async {
    final c = ProviderContainer(overrides: [
      postDetailFetchProvider.overrideWithValue((id) async => _detail()),
    ]);
    addTearDown(c.dispose);

    await c.read(postDetailControllerProvider(9).notifier).load();
    final s = c.read(postDetailControllerProvider(9));
    expect(s.phase, PostDetailPhase.loaded);
    expect(s.detail?.id, 9);
  });

  test('addComment: 작성 후 상세를 재조회해 댓글 반영', () async {
    var calls = 0;
    final c = ProviderContainer(overrides: [
      postDetailFetchProvider.overrideWithValue((id) async {
        calls++;
        return _detail(comments: calls >= 2
            ? [const CommunityComment(id: 1, bodyMd: '새댓글', createdAt: 'x')]
            : const []);
      }),
      commentCreateProvider.overrideWithValue((postId, bodyMd) async =>
          const CommunityComment(id: 1, bodyMd: '새댓글', createdAt: 'x')),
    ]);
    addTearDown(c.dispose);

    final n = c.read(postDetailControllerProvider(9).notifier);
    await n.load();
    await n.addComment('새댓글');
    expect(c.read(postDetailControllerProvider(9)).detail?.comments.single.bodyMd, '새댓글');
  });
}
```

- [ ] **Step 2: 실패 확인**

Run: `cd /d/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/community/post_detail_controller_test.dart`
Expected: FAIL(컨트롤러/상태 미정의).

- [ ] **Step 3: 상태 작성**

Create `apps/web/lib/src/features/community/state/post_detail_state.dart`:

```dart
import 'package:dp_core/dp_core.dart';

enum PostDetailPhase { loading, loaded, failed }

class PostDetailState {
  const PostDetailState({
    this.detail,
    this.phase = PostDetailPhase.loading,
    this.submitting = false,
    this.error,
  });

  final CommunityPostDetail? detail;
  final PostDetailPhase phase;
  final bool submitting;
  final String? error;

  PostDetailState copyWith({
    CommunityPostDetail? detail,
    PostDetailPhase? phase,
    bool? submitting,
    String? error,
  }) => PostDetailState(
        detail: detail ?? this.detail,
        phase: phase ?? this.phase,
        submitting: submitting ?? this.submitting,
        error: error,
      );
}
```

- [ ] **Step 4: 컨트롤러 작성**

Create `apps/web/lib/src/features/community/application/post_detail_controller.dart`:

```dart
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/community_source.dart';
import '../state/post_detail_state.dart';

class PostDetailController extends FamilyNotifier<PostDetailState, int> {
  @override
  PostDetailState build(int arg) => const PostDetailState();

  Future<void> load() async {
    state = state.copyWith(phase: PostDetailPhase.loading);
    try {
      final detail = await ref.read(postDetailFetchProvider)(arg);
      state = state.copyWith(detail: detail, phase: PostDetailPhase.loaded);
    } on ApiException catch (e) {
      state = state.copyWith(phase: PostDetailPhase.failed, error: e.message);
    }
  }

  Future<void> addComment(String bodyMd) async {
    if (bodyMd.trim().isEmpty) return;
    state = state.copyWith(submitting: true);
    try {
      await ref.read(commentCreateProvider)(arg, bodyMd.trim());
      final detail = await ref.read(postDetailFetchProvider)(arg);
      state = state.copyWith(detail: detail, submitting: false);
    } on ApiException catch (e) {
      state = state.copyWith(submitting: false, error: e.message);
    }
  }

  Future<void> upvote() async {
    try {
      await ref.read(communityVoteProvider)(
        target: CommunityVoteTarget.post, id: arg, value: 1);
      await load();
    } on ApiException catch (e) {
      state = state.copyWith(error: e.message);
    }
  }
}

final postDetailControllerProvider =
    NotifierProvider.family<PostDetailController, PostDetailState, int>(
      PostDetailController.new,
    );
```

> 확인: `FamilyNotifier`/`NotifierProvider.family` API가 이 레포 riverpod 버전과 일치하는지 기존 family 사용처(예: `qna_detail_controller.dart`)를 읽어 시그니처를 맞춘다. 다르면 그 패턴을 따른다.

- [ ] **Step 5: 통과 확인**

Run: `cd /d/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/community/post_detail_controller_test.dart` → PASS.

- [ ] **Step 6: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add \
  apps/web/lib/src/features/community/state/post_detail_state.dart \
  apps/web/lib/src/features/community/application/post_detail_controller.dart \
  apps/web/test/features/community/post_detail_controller_test.dart
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(community): 일반 게시글 상세 컨트롤러(댓글/추천)"
```

---

### Task 6: 통합 피드 화면 (필터칩·보드 뱃지·라우팅·FAB)

**Files:**
- Modify: `apps/web/lib/src/features/community/presentation/community_home_page.dart`
- Modify: `apps/web/lib/src/data/web_mock_fixtures.dart` (GET /community/posts 혼합 응답)
- Test: `apps/web/test/features/community/community_home_page_test.dart` (케이스 추가/갱신)

**Interfaces:**
- Consumes: Task 4 `CommunityBoard`·`selectBoard`, 요약 `boardType`·`replyCount`.

- [ ] **Step 1: 목 픽스처 갱신**

`web_mock_fixtures.dart` `'GET /community/posts'`(51–79행) 응답을 3보드 혼합으로 교체(각 항목에 `boardType`·`replyCount` 포함):

```dart
  'GET /community/posts': (
    200,
    [
      {'id': 1, 'boardType': 'QNA', 'title': 'async/await가 헷갈려요', 'authorId': 42, 'solved': true, 'upvoteCount': 3, 'replyCount': 2},
      {'id': 10, 'boardType': 'FREE', 'title': '오늘 배운 것 공유', 'authorId': 8, 'solved': false, 'upvoteCount': 5, 'replyCount': 4},
      {'id': 20, 'boardType': 'FEEDBACK', 'title': '제 코드 리뷰 부탁해요', 'authorId': 17, 'solved': false, 'upvoteCount': 1, 'replyCount': 1},
    ],
  ),
```

- [ ] **Step 2: 실패 테스트 작성**

`community_home_page_test.dart`에 케이스 추가(위젯 테스트, 기존 파일 패턴 승계 — `ProviderScope`+override, `DpTheme.light()`):

```dart
  testWidgets('통합 피드: 필터칩 4개 + 보드 뱃지 렌더', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        communityListProvider.overrideWithValue(({String? board, String? tag, String? sort}) async => const [
          CommunityPostSummary(id: 10, title: '자유글', boardType: 'FREE', replyCount: 4, upvoteCount: 5),
        ]),
      ],
      child: MaterialApp(theme: DpTheme.light(), home: const CommunityHomePage()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('전체'), findsOneWidget);
    expect(find.text('자유'), findsWidgets); // 필터칩 + 뱃지
    expect(find.text('자유글'), findsOneWidget);
  });
```

- [ ] **Step 3: 실패 확인**

Run: `cd /d/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/community/community_home_page_test.dart`
Expected: FAIL(필터칩·뱃지 미구현).

- [ ] **Step 4: 화면 구현**

`community_home_page.dart`를 재작성한다. 핵심 요소(기존 Card/ListTile 구조 유지):
- `initState`에서 `load()`(현행 유지).
- body 최상단에 **필터칩 Row**: `CommunityBoard.values`를 `ChoiceChip`으로. selected=`s.board==b`, onSelected=`notifier.selectBoard(b)`.
- 카드 `title` Row 앞에 **보드 뱃지**: `_BoardBadge(p.boardType)` — 작은 `Container`(radius·`context.dpColors` 배경) + `Text(라벨)`. QNA='Q&A'/FREE='자유'/FEEDBACK='피드백'. QNA일 때만 `p.solved` 체크 아이콘 유지.
- subtitle 라벨: `'${p.boardType == "QNA" ? "답변" : "댓글"} ${p.replyCount} · 추천 ${p.upvoteCount}'`.
- onTap **라우팅**: `p.boardType == 'QNA' ? context.go('/community/${p.id}') : context.go('/community/post/${p.id}')`.
- **FAB 스피드다이얼**: `FloatingActionButton`을 눌렀을 때 `showModalBottomSheet`(또는 `MenuAnchor`)로 3항목 표시:
  - `질문하기` → `context.go('/community/new')`
  - `자유글` → `context.go('/community/new/post?board=FREE')`
  - `피드백 요청` → `context.go('/community/new/post?board=FEEDBACK')`
- 광고 슬롯(`AdSlotWidget(slot: 'COMMUNITY_FEED')`) 삽입 로직은 현행 유지.

뱃지 위젯(파일 하단 private):

```dart
class _BoardBadge extends StatelessWidget {
  const _BoardBadge(this.boardType);
  final String boardType;
  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final label = switch (boardType) { 'FREE' => '자유', 'FEEDBACK' => '피드백', _ => 'Q&A' };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DpSpacing.xs, vertical: 2),
      margin: const EdgeInsets.only(right: DpSpacing.xs),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: c.textSecondary)),
    );
  }
}
```

> `context.dpColors`의 실제 필드명(`surfaceVariant` 등)은 `dp_colors.dart`에서 확인해 존재하는 토큰을 쓴다(없으면 `surface`/`textSecondary`로 대체). FAB 스피드다이얼은 Material `MenuAnchor` 또는 `showModalBottomSheet` 중 기존 코드베이스에 쓰인 방식을 따른다.

- [ ] **Step 5: 통과 확인**

Run: `cd /d/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/community/community_home_page_test.dart` → PASS.

- [ ] **Step 6: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add \
  apps/web/lib/src/features/community/presentation/community_home_page.dart \
  apps/web/lib/src/data/web_mock_fixtures.dart \
  apps/web/test/features/community/community_home_page_test.dart
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(community): 통합 피드 화면(필터칩·보드 뱃지·라우팅·FAB)"
```

---

### Task 7: 일반 게시글 상세 화면 + 라우트

**Files:**
- Create: `apps/web/lib/src/features/community/presentation/post_detail_page.dart`
- Modify: `apps/web/lib/src/app/router.dart` (`/community/post/:id` 추가)
- Modify: `apps/web/lib/src/data/web_mock_fixtures.dart` (GET /community/posts/10, POST comments)
- Test: `apps/web/test/features/community/post_detail_page_test.dart` (신규)

**Interfaces:**
- Consumes: Task 5 `postDetailControllerProvider`, `DpMarkdown`.

- [ ] **Step 1: 목 픽스처 추가**

`web_mock_fixtures.dart`에 추가:

```dart
  'GET /community/posts/10': (
    200,
    {
      'id': 10, 'boardType': 'FREE', 'title': '오늘 배운 것 공유',
      'bodyMd': '# 공유\n\n오늘 `Riverpod`을 배웠어요.', 'authorId': 8,
      'upvoteCount': 5, 'downvoteCount': 0, 'tags': ['riverpod'],
      'comments': [
        {'id': 100, 'authorId': 42, 'bodyMd': '좋은 정리네요!', 'upvoteCount': 0, 'createdAt': '2026-07-29T00:00:00Z'},
      ],
    },
  ),
  'POST /community/posts/10/comments': (
    201,
    {'id': 101, 'authorId': 1, 'bodyMd': '새 댓글', 'upvoteCount': 0, 'createdAt': '2026-07-29T01:00:00Z'},
  ),
  'POST /community/posts/10/vote': (200, <String, dynamic>{}),
```

- [ ] **Step 2: 실패 테스트 작성**

Create `post_detail_page_test.dart`(위젯; 상세 로드→마크다운·댓글·작성 렌더). 컨트롤러를 override해 고정 상세 주입:

```dart
// ProviderScope override: postDetailFetchProvider → 고정 CommunityPostDetail(제목·bodyMd·comments 1건)
// MaterialApp(theme: DpTheme.light(), home: PostDetailPage(postId: '10'))
// 기대: 제목 텍스트·댓글 본문 텍스트·댓글 입력 필드(find.byType(TextField)) 존재.
```

(구체 위젯 테스트는 기존 `qna_detail_page_test.dart` 패턴을 그대로 승계해 작성 — override 대상만 `postDetailFetchProvider`로 교체.)

- [ ] **Step 3: 실패 확인**

Run: `cd /d/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/community/post_detail_page_test.dart`
Expected: FAIL(`PostDetailPage` 미정의).

- [ ] **Step 4: 화면 구현**

Create `post_detail_page.dart` — `ConsumerStatefulWidget`, 생성자 `PostDetailPage({required String postId})`, `int id = int.parse(postId)`. `initState`에서 `postDetailControllerProvider(id).notifier).load()`. build:
- `s.phase` switch: loading=`DpLoading()`, failed=`DpError(message, onRetry)`, loaded=본문.
- loaded 본문(스크롤): 제목(`Text`) → 태그 칩 Row(`d.tags.map(Chip)`) → 추천 버튼 Row(`IconButton(DpIcons.thumbUp?) + '${d.upvoteCount}'`, onPressed=`notifier.upvote()`) → `DpMarkdown(data: d.bodyMd)` → Divider → **댓글 섹션**: `d.comments.map`으로 각 댓글(작성자·`DpMarkdown(bodyMd)`·createdAt) → 하단 댓글 입력(`TextField` controller + 전송 버튼, onSubmit=`notifier.addComment(text)` 후 필드 clear, `s.submitting`이면 비활성).
- `qna_detail_page.dart`의 Scaffold/AppBar/여백 스타일을 승계.

> 아이콘(`DpIcons.thumbUp` 등)은 `dp_icons.dart`에서 존재하는 이름을 확인해 사용한다.

- [ ] **Step 5: 라우트 추가**

`router.dart`의 커뮤니티 블록(120행 `/community/:id` **앞**)에 추가:

```dart
          GoRoute(
            path: '/community/post/:id',
            builder: (_, state) =>
                PostDetailPage(postId: state.pathParameters['id']!),
          ),
```

import 추가: `import '../features/community/presentation/post_detail_page.dart';`

- [ ] **Step 6: 통과 확인**

Run: `cd /d/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/community/post_detail_page_test.dart` → PASS.

- [ ] **Step 7: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add \
  apps/web/lib/src/features/community/presentation/post_detail_page.dart \
  apps/web/lib/src/app/router.dart \
  apps/web/lib/src/data/web_mock_fixtures.dart \
  apps/web/test/features/community/post_detail_page_test.dart
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(community): 일반 게시글 상세 화면 + 라우트"
```

---

### Task 8: 일반 게시글 작성 화면 + 라우트

**Files:**
- Create: `apps/web/lib/src/features/community/presentation/post_create_page.dart`
- Modify: `apps/web/lib/src/app/router.dart` (`/community/new/post` 추가)
- Modify: `apps/web/lib/src/data/web_mock_fixtures.dart` (POST /community/posts)
- Test: `apps/web/test/features/community/post_create_page_test.dart` (신규)

**Interfaces:**
- Consumes: Task 3 `postCreateProvider`.

- [ ] **Step 1: 목 픽스처 추가**

```dart
  'POST /community/posts': (
    201,
    {
      'id': 30, 'boardType': 'FREE', 'title': '새 자유글', 'bodyMd': '본문',
      'authorId': 1, 'upvoteCount': 0, 'downvoteCount': 0, 'tags': <String>[], 'comments': <Map<String, dynamic>>[],
    },
  ),
```

- [ ] **Step 2: 실패 테스트 작성**

Create `post_create_page_test.dart` — 기존 `question_create_page_test.dart` 패턴 승계. 기대: board 프리셋 라벨('자유'/'피드백') 표시, 제목/본문 입력 후 제출 시 `postCreateProvider` 호출(override로 캡처)·상세 라우트 이동. 최소: `PostCreatePage(board: 'FREE')` 렌더 시 제목/본문 `TextField` 2개 + 제출 버튼 존재.

- [ ] **Step 3: 실패 확인**

Run: `cd /d/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/community/post_create_page_test.dart`
Expected: FAIL(`PostCreatePage` 미정의).

- [ ] **Step 4: 화면 구현**

Create `post_create_page.dart` — `ConsumerStatefulWidget`, 생성자 `PostCreatePage({required String board})`(FREE/FEEDBACK). AppBar 제목=`board=='FEEDBACK' ? '피드백 요청' : '자유글 작성'`. 폼: 제목 `TextField`, 본문 `TextField`(multiline), 태그 입력(간단히 쉼표구분 `TextField` → `split(',')`). 제출 버튼 onPressed:
```dart
final view = await ref.read(postCreateProvider)(
    boardType: widget.board, title: _title.text.trim(),
    bodyMd: _body.text, tags: _tags.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList());
if (context.mounted) context.go('/community/post/${view.id}');
```
빈 제목/본문 방지(비활성 또는 스낵바). `question_create_page.dart`의 폼 스타일 승계(유사질문 체크는 제외 — Q&A 전용).

- [ ] **Step 5: 라우트 추가**

`router.dart`의 `/community/new`(117행) **뒤**, `/community/:id` 앞에 추가:

```dart
          GoRoute(
            path: '/community/new/post',
            builder: (_, state) => PostCreatePage(
                board: state.uri.queryParameters['board'] ?? 'FREE'),
          ),
```

import 추가: `import '../features/community/presentation/post_create_page.dart';`

- [ ] **Step 6: 통과 확인**

Run: `cd /d/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/community/post_create_page_test.dart` → PASS.

- [ ] **Step 7: 커밋**

```bash
git -C D:/workspace/dpa/devpath-frontend add \
  apps/web/lib/src/features/community/presentation/post_create_page.dart \
  apps/web/lib/src/app/router.dart \
  apps/web/lib/src/data/web_mock_fixtures.dart \
  apps/web/test/features/community/post_create_page_test.dart
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(community): 일반 게시글 작성 화면 + 라우트"
```

---

### Task 9: 통합 검증 + PR (2 레포)

- [ ] **Step 1: 프론트 전체 검증**

Run(레포 루트 `D:/workspace/dpa/devpath-frontend`): `dart pub global run melos run analyze` → 오류 0.
Run: `dart pub global run melos run test` → 전체 green.
Run: `dart pub global run melos run format` → 변경 없음(있으면 `melos run fix` 후 재확인·커밋).

- [ ] **Step 2: 백엔드 최종 빌드**

Run: `cd /d/workspace/dpa/devpath-community-svc && ./gradlew build` → BUILD SUCCESSFUL.

- [ ] **Step 3: community-svc PR-A push + develop PR**

```bash
git -C D:/workspace/dpa/devpath-community-svc push -u origin feat/community-feed-summary
cd /d/workspace/dpa/devpath-community-svc && gh pr create --base develop --head feat/community-feed-summary \
  --title "feat(community): 목록 요약 boardType+replyCount + 전-보드 피드" \
  --body "통합 피드 프론트(하위 B)용. PostSummaryView에 boardType+replyCount(QNA=답변/일반=댓글) + 전-보드 목록. spec: devpath-frontend/docs/superpowers/specs/2026-07-29-community-free-feedback-web-design.md"
```

- [ ] **Step 4: frontend PR-B push + develop PR**

```bash
cd /d/workspace/dpa/devpath-frontend && git push -u origin feat/community-free-feedback-web
gh pr create --base develop --head feat/community-free-feedback-web \
  --title "feat(community): 자유/피드백 보드 웹(통합 피드+댓글)" \
  --body "통합 피드(필터칩·보드 뱃지·라우팅·FAB) + 일반 게시글 상세(마크다운·태그·추천·댓글)+작성. 목 픽스처로 검증. 백엔드 계약=community-svc PR-A(boardType/replyCount) 의존. spec/plan docs/superpowers/{specs,plans}/2026-07-29-community-free-feedback-web*."
```

> 주의: PR-B의 통합 피드는 PR-A의 `boardType`/`replyCount` 계약에 의존한다(실 서버 기준). 목 픽스처로 CI/로컬은 독립 green. 실배포 정합은 PR-A 선행 머지 권장.

---

## Self-Review

**1. Spec coverage:** 통합 피드+필터칩=Task4·6, 보드 뱃지·boardType 라우팅=Task6, FAB 스피드다이얼=Task6, 일반 상세(마크다운·태그·추천·댓글)=Task5·7, 작성=Task8, 백엔드 요약 확장(boardType+replyCount+전보드)=Task1, 모델=Task2, 데이터 provider=Task3, 목 픽스처=Task6·7·8, 테스트=각 Task, 범위 밖(댓글 추천/수정·페이지네이션 등) 미포함. ✅

**2. Placeholder scan:** 백엔드·모델·데이터·상태·컨트롤러·라우트·픽스처는 실제 코드. 위젯 3종(Task6·7·8 화면)은 구조+핵심 로직+정확한 provider/경로/위젯명 제시하되 세부 스타일은 기존 페이지 패턴 승계 명시(dp_design이 Material 직접 사용이라 픽셀 스펙 불요). Task3/5/7/8 테스트는 기존 테스트 파일 패턴 승계 지시 — 실행자는 해당 기존 파일을 읽어 확정. ✅

**3. Type consistency:** `CommunityPostSummary(boardType, replyCount)`·`CommunityPostDetail(...comments:List<CommunityComment>)`·`CommunityComment(createdAt:String)`·`CommunityBoard(value:String?, label)`·`PostDetailController.load/addComment/upvote`·`postDetailControllerProvider(int)`·`postCreateProvider/postDetailFetchProvider/commentCreateProvider` 시그니처가 Task 간 일치. 백엔드 `PostSummaryView(id,boardType,title,authorId,solved,upvoteCount,replyCount)`가 프론트 요약과 필드 일치. ✅

**4. 리스크:** riverpod family API(FamilyNotifier)·apiClient 페이크·dp_colors/dp_icons 토큰명은 실행자가 기존 사용처를 읽어 확정(각 Task에 지시 명시). 라우트 선언 순서(`/community/new/post`·`/community/post/:id`가 `/community/:id`보다 먼저) 명시. `list` 기본값 QNA→ALL 계약 변경은 프론트 필터 기본 '전체'와 정합. ✅
