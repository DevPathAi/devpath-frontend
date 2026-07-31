# 커뮤니티 제목 미리보기(excerpt) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 커뮤니티 피드 목록에 `excerpt`(본문 요약)를 추가하고, 웹에서 제목 hover 시 `OverlayPortal` 미리보기 카드를 띄운다.

**Architecture:** 백엔드(`devpath-community-svc`)는 `QuestionService.list()`가 이미 로드하는 `CommunityPost` 엔티티의 `body_md`를 순수 헬퍼 `Excerpts`로 평문화·절단해 `PostSummaryView.excerpt`에 담는다(추가 쿼리 없음). 프론트(`devpath-frontend`)는 dp_core `CommunityPostSummary`에 `excerpt`를 추가하고, `DpListRow`에 옵셔널 `preview` 슬롯(hover OverlayPortal)을 붙여 web `_postRow`가 소비한다. `shared` 발행 불필요(PostSummaryView는 community-svc 로컬 record).

**Tech Stack:** Java 21 · Spring Boot 4 · JUnit 5 + AssertJ · Flutter Web · freezed/json_serializable · Flutter `OverlayPortal`/`CompositedTransformFollower` · melos.

## Global Constraints

- **TDD 필수**(CLAUDE.md 규칙 2): 실패 테스트 선작성 → 최소 구현 → 통과 확인.
- **추측 금지**(규칙 1): 명세에 없는 코드 즉흥 구현 금지.
- **JSON 키 계약(백엔드 ↔ dp_core 일치)**: `excerpt`(String).
- **excerpt 규칙**: `body_md` 경량 평문화(선행 마크다운 마커 `#·>·-·*·N.` 제거, 인라인 `` ` * _ ~ `` 제거, 공백 collapse) 후 **최대 140자**, 초과 시 `…`. 빈/`null` 본문 → 빈 문자열.
- **미리보기 = 웹 전용 hover**: `MouseRegion`+`OverlayPortal`(터치 모바일은 hover 없어 미표시). `DpListRow`는 go_router/Riverpod 비의존 유지.
- **레포/브랜치**: 백엔드(Task 1~2)=`devpath-community-svc` 브랜치 `feat/community-excerpt`(Task 1에서 `develop` 분기) → 자체 `develop` PR. 프론트(Task 3~5)=`devpath-frontend` 브랜치 `feat/community-excerpt-preview`(이미 존재, spec 커밋 보유) → 자체 `develop` PR. **모든 git은 `git -C <레포 절대경로>`**. 백엔드 먼저 머지 권장.
- **검증 게이트**: 백엔드 `./gradlew test`(로컬 통합테스트는 `docker run pgvector/pgvector:pg16` postgres 필요; 순수 `ExcerptsTest`는 DB 불필요). 프론트 `melos run format`→`analyze`→`test`.
- **커밋 스테이징**: 명시적 파일 경로로 `git add`(무관한 untracked 혼입 방지).

## File Structure

**devpath-community-svc** (패키지 `ai.devpath.community.post`):
- `Excerpts.java` (신규) — 순수 요약 헬퍼.
- `dto/PostSummaryView.java` (수정) — `excerpt` 필드.
- `QuestionService.java` (수정) — `list()` `.map()`에서 excerpt 채움.
- 테스트: `ExcerptsTest`(신규·순수)·`QuestionServiceListExcerptTest`(신규·@SpringBootTest).

**devpath-frontend**:
- `packages/dp_core/lib/src/models/community_post.dart` (수정) — `CommunityPostSummary.excerpt`.
- `packages/dp_design/lib/src/data/dp_list_row.dart` (수정) — `preview` 슬롯 + `_HoverPreview`/`_PreviewCard`.
- `apps/web/lib/src/features/community/presentation/community_home_page.dart` (수정) — `_postRow`가 `preview` 전달.
- `apps/web/lib/src/data/web_mock_fixtures.dart` (수정) — `/community/posts` 목에 `excerpt`.
- 테스트: `community_post_test.dart`(수정)·`dp_list_row_test.dart`(수정)·`community_home_page_test.dart`(회귀 유지).

---

## Task 1: 백엔드 순수 excerpt 헬퍼

**Repo:** `devpath-community-svc`

**Files:**
- Create: `devpath-community-svc/src/main/java/ai/devpath/community/post/Excerpts.java`
- Test: `devpath-community-svc/src/test/java/ai/devpath/community/post/ExcerptsTest.java` (신규)

**Interfaces:**
- Produces: `Excerpts.from(String bodyMd, int maxLen) -> String`.

- [ ] **Step 1: 브랜치 분기(1회)**

```bash
git -C /d/workspace/dpa/devpath-community-svc fetch origin --quiet
git -C /d/workspace/dpa/devpath-community-svc checkout -b feat/community-excerpt origin/develop
```

- [ ] **Step 2: 실패 테스트 작성** — `ExcerptsTest.java`

```java
package ai.devpath.community.post;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class ExcerptsTest {
  @Test
  void stripsMarkdownMarkersAndCollapsesWhitespace() {
    String body = "# 제목\n\n> 인용\n- 항목 **굵게** `코드`\n여러   공백";
    assertThat(Excerpts.from(body, 140)).isEqualTo("제목 인용 항목 굵게 코드 여러 공백");
  }

  @Test
  void truncatesWithEllipsisWhenOverMax() {
    String out = Excerpts.from("가".repeat(200), 140);
    assertThat(out).hasSize(141); // 140자 + …
    assertThat(out).endsWith("…");
  }

  @Test
  void blankOrNullBodyReturnsEmpty() {
    assertThat(Excerpts.from("   ", 140)).isEmpty();
    assertThat(Excerpts.from(null, 140)).isEmpty();
  }
}
```

- [ ] **Step 3: 실패 확인**

```bash
cd /d/workspace/dpa/devpath-community-svc && ./gradlew test --tests '*ExcerptsTest' --console=plain 2>&1 | tail -8
```
Expected: 컴파일 에러(`Excerpts` 없음).

- [ ] **Step 4: 헬퍼 구현** — `Excerpts.java`

```java
package ai.devpath.community.post;

import java.util.regex.Pattern;

/** 목록 미리보기용 본문 요약(순수 로직, DB 비의존). 마크다운 마커 제거 + 공백 collapse + 절단. */
public final class Excerpts {
  private static final Pattern LINE_MARKERS =
      Pattern.compile("(?m)^\\s{0,3}(#{1,6}\\s+|>\\s?|[-*+]\\s+|\\d+\\.\\s+)");
  private static final Pattern INLINE_MARKS = Pattern.compile("[`*_~]");
  private static final Pattern WHITESPACE = Pattern.compile("\\s+");

  private Excerpts() {}

  public static String from(String bodyMd, int maxLen) {
    if (bodyMd == null || bodyMd.isBlank()) {
      return "";
    }
    String plain = LINE_MARKERS.matcher(bodyMd).replaceAll("");
    plain = INLINE_MARKS.matcher(plain).replaceAll("");
    plain = WHITESPACE.matcher(plain).replaceAll(" ").trim();
    return plain.length() <= maxLen ? plain : plain.substring(0, maxLen).trim() + "…";
  }
}
```

- [ ] **Step 5: 통과 확인**

```bash
cd /d/workspace/dpa/devpath-community-svc && ./gradlew test --tests '*ExcerptsTest' --console=plain 2>&1 | tail -6
```
Expected: PASS(3).

- [ ] **Step 6: 커밋**

```bash
git -C /d/workspace/dpa/devpath-community-svc add src/main/java/ai/devpath/community/post/Excerpts.java src/test/java/ai/devpath/community/post/ExcerptsTest.java
git -C /d/workspace/dpa/devpath-community-svc commit -m "feat(community): 목록 미리보기용 본문 요약 헬퍼 Excerpts"
```

---

## Task 2: 백엔드 계약 — PostSummaryView.excerpt + list 채움

**Repo:** `devpath-community-svc`

**Files:**
- Modify: `devpath-community-svc/src/main/java/ai/devpath/community/post/dto/PostSummaryView.java`
- Modify: `devpath-community-svc/src/main/java/ai/devpath/community/post/QuestionService.java`
- Test: `devpath-community-svc/src/test/java/ai/devpath/community/post/QuestionServiceListExcerptTest.java` (신규)

**Interfaces:**
- Consumes: `Excerpts.from`(Task 1).
- Produces: `PostSummaryView(long id, String boardType, String title, Long authorId, boolean solved, int upvoteCount, int replyCount, String excerpt)`; `GET /community/posts` 응답의 각 항목에 `excerpt`.

- [ ] **Step 1: 다른 생성자 소비자 확인**

```bash
grep -rn "new PostSummaryView(" /d/workspace/dpa/devpath-community-svc/src --include=*.java
```
Expected: `QuestionService.java`의 1곳만(그 외 있으면 함께 갱신).

- [ ] **Step 2: 실패 테스트 작성** — `QuestionServiceListExcerptTest.java`

```java
package ai.devpath.community.post;

import static org.assertj.core.api.Assertions.assertThat;

import ai.devpath.community.post.dto.CreatePostRequest;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
class QuestionServiceListExcerptTest {

  @Autowired PostService postService;
  @Autowired QuestionService questionService;

  @Test
  void listPopulatesExcerptFromBody() {
    postService.createPost(77L,
        new CreatePostRequest("FREE", "요약 테스트", "## 헤더\n**본문** 미리보기 내용", List.of()));

    var view = questionService.list(null, null, null).stream()
        .filter(v -> "요약 테스트".equals(v.title()))
        .findFirst()
        .orElseThrow();

    assertThat(view.excerpt()).isEqualTo("헤더 본문 미리보기 내용");
  }
}
```

- [ ] **Step 3: 실패 확인**

```bash
cd /d/workspace/dpa/devpath-community-svc && ./gradlew test --tests '*QuestionServiceListExcerptTest' --console=plain 2>&1 | tail -8
```
Expected: 컴파일 에러(`view.excerpt()` 없음).

- [ ] **Step 4: `PostSummaryView`에 excerpt 추가**

`PostSummaryView.java`를 다음으로 교체:
```java
package ai.devpath.community.post.dto;

public record PostSummaryView(long id, String boardType, String title, Long authorId,
    boolean solved, int upvoteCount, int replyCount, String excerpt) {}
```

- [ ] **Step 5: `QuestionService.list()` 채움**

`QuestionService.java`의 `list()` 안 `return new PostSummaryView(...)`(현재 7인자)를 8인자로 교체:
```java
          return new PostSummaryView(p.getId(), p.getBoardType(), p.getTitle(),
              p.getAuthorId(), solved, p.getUpvoteCount(), replyCount,
              Excerpts.from(p.getBodyMd(), 140));
```

- [ ] **Step 6: 통과 확인**(로컬 postgres 필요)

```bash
docker ps --format '{{.Names}}' | grep -q dpa-test-pg || docker run -d --name dpa-test-pg -e POSTGRES_USER=devpath -e POSTGRES_PASSWORD=localdev -e POSTGRES_DB=devpath -p 5432:5432 pgvector/pgvector:pg16
cd /d/workspace/dpa/devpath-community-svc && ./gradlew test --tests '*QuestionServiceListExcerptTest' --tests '*ExcerptsTest' --console=plain 2>&1 | tail -8
```
Expected: PASS. (로컬 DB 미기동이면 CI에 위임 — 순수 ExcerptsTest는 로컬 green.)

- [ ] **Step 7: 회귀 — PostSummaryView 소비 컴파일**

```bash
cd /d/workspace/dpa/devpath-community-svc && ./gradlew compileJava compileTestJava --console=plain 2>&1 | tail -4
```
Expected: BUILD SUCCESSFUL(다른 소비자 없음 확인됨).

- [ ] **Step 8: 커밋 + 푸시 + PR**

```bash
git -C /d/workspace/dpa/devpath-community-svc add src/main/java/ai/devpath/community/post/dto/PostSummaryView.java src/main/java/ai/devpath/community/post/QuestionService.java src/test/java/ai/devpath/community/post/QuestionServiceListExcerptTest.java
git -C /d/workspace/dpa/devpath-community-svc commit -m "feat(community): PostSummaryView.excerpt + list 본문 요약 채움"
git -C /d/workspace/dpa/devpath-community-svc push -u origin feat/community-excerpt
```
그 후 `feat/community-excerpt` → `develop` PR 생성(제목 `feat(community): 커뮤니티 목록 제목 미리보기 excerpt`). CI green + 사용자 승인 후 머지. **develop 직접 push 금지.**

---

## Task 3: dp_core CommunityPostSummary.excerpt

**Repo:** `devpath-frontend` (브랜치 `feat/community-excerpt-preview` — 이미 체크아웃, spec 보유)

**Files:**
- Modify: `devpath-frontend/packages/dp_core/lib/src/models/community_post.dart`
- Test: `devpath-frontend/packages/dp_core/test/models/community_post_test.dart` (기존 파일에 테스트 추가)

**Interfaces:**
- Consumes: 백엔드 JSON 계약(`excerpt`).
- Produces: dp_core `CommunityPostSummary.excerpt`(`@Default('') String`).

- [ ] **Step 1: 실패 테스트 작성** — `community_post_test.dart`의 첫 테스트(`boardType/replyCount 파싱`) 아래에 추가

```dart
  test('CommunityPostSummary.fromJson: excerpt 파싱 + 부재 시 빈 문자열', () {
    final withExcerpt = CommunityPostSummary.fromJson({
      'id': 1,
      'title': '자유글',
      'excerpt': '본문 미리보기 요약',
    });
    expect(withExcerpt.excerpt, '본문 미리보기 요약');

    final without = CommunityPostSummary.fromJson({'id': 2, 'title': 't'});
    expect(without.excerpt, '');
  });
```

- [ ] **Step 2: 실패 확인**

```bash
cd /d/workspace/dpa/devpath-frontend/packages/dp_core && dart test test/models/community_post_test.dart 2>&1 | tail -6
```
Expected: 컴파일 에러(`excerpt` getter 없음).

- [ ] **Step 3: `CommunityPostSummary`에 excerpt 추가** — `community_post.dart`

`CommunityPostSummary`의 `@Default(0) int replyCount,` 아래에 추가:
```dart
    @Default(0) int replyCount,
    @Default('') String excerpt,
```

- [ ] **Step 4: 코드 생성**

```bash
cd /d/workspace/dpa/devpath-frontend/packages/dp_core && dart run build_runner build --delete-conflicting-outputs 2>&1 | tail -4
```
Expected: `community_post.freezed.dart`·`.g.dart` 갱신.

- [ ] **Step 5: 통과 확인**

```bash
cd /d/workspace/dpa/devpath-frontend/packages/dp_core && dart test test/models/community_post_test.dart 2>&1 | tail -6
```
Expected: PASS.

- [ ] **Step 6: 전 패키지 분석(mobile 파급)**

```bash
cd /d/workspace/dpa/devpath-frontend && dart pub global run melos run analyze 2>&1 | tail -6
```
Expected: web·admin·mobile·dp_core·dp_design 전부 통과.

- [ ] **Step 7: 포맷 + 커밋**

```bash
cd /d/workspace/dpa/devpath-frontend && dart pub global run melos run format
git -C /d/workspace/dpa/devpath-frontend add packages/dp_core
git -C /d/workspace/dpa/devpath-frontend commit -m "feat(dp_core): CommunityPostSummary.excerpt 추가"
```

---

## Task 4: DpListRow preview 슬롯(OverlayPortal hover)

**Repo:** `devpath-frontend`

**Files:**
- Modify: `devpath-frontend/packages/dp_design/lib/src/data/dp_list_row.dart`
- Test: `devpath-frontend/packages/dp_design/test/data/dp_list_row_test.dart` (기존 파일에 테스트 추가)

**Interfaces:**
- Produces: `DpListRow({..., String? preview})`. `preview` 지정(비-blank) 시 제목 hover로 미리보기 카드(웹). 미지정 시 기존 동작.

- [ ] **Step 1: 실패 테스트 작성** — `dp_list_row_test.dart` 상단 import에 `import 'package:flutter/gestures.dart';` 추가 후, `main()` 안에 테스트 추가

```dart
  testWidgets('DpListRow: preview 지정 시 hover로 미리보기 등장', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: const Scaffold(
          body: Center(
            child: DpListRow(title: '제목 행', preview: '본문 미리보기 요약 텍스트'),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('본문 미리보기 요약 텍스트'), findsNothing); // 초기 미표시

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.text('제목 행')));
    await tester.pumpAndSettle();

    expect(find.text('본문 미리보기 요약 텍스트'), findsOneWidget); // hover 후 등장
  });
```

- [ ] **Step 2: 실패 확인**

```bash
cd /d/workspace/dpa/devpath-frontend/packages/dp_design && flutter test test/data/dp_list_row_test.dart 2>&1 | tail -8
```
Expected: 컴파일 에러(`preview` 파라미터 없음).

- [ ] **Step 3: DpListRow에 preview 슬롯 + hover 위젯 구현** — `dp_list_row.dart`

파일 상단 import에 추가(`dp_colors`·`dp_tokens` 확장 사용):
```dart
import '../theme/dp_colors.dart';
import '../theme/dp_tokens.dart';
```
생성자에 `this.preview,` 추가 + 필드 `final String? preview;` 추가. 그리고 build의 `Text(title, style: text.titleSmall),`(제목 렌더)를 다음으로 교체:
```dart
                    (preview != null && preview!.trim().isNotEmpty)
                        ? _HoverPreview(
                            preview: preview!,
                            child: Text(title, style: text.titleSmall),
                          )
                        : Text(title, style: text.titleSmall),
```
파일 끝(클래스 밖)에 추가:
```dart
/// 제목 hover 시 OverlayPortal로 본문 미리보기(웹 전용 — MouseRegion hover).
class _HoverPreview extends StatefulWidget {
  const _HoverPreview({required this.preview, required this.child});

  final String preview;
  final Widget child;

  @override
  State<_HoverPreview> createState() => _HoverPreviewState();
}

class _HoverPreviewState extends State<_HoverPreview> {
  final _controller = OverlayPortalController();
  final _link = LayerLink();

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        onEnter: (_) => _controller.show(),
        onExit: (_) => _controller.hide(),
        child: OverlayPortal(
          controller: _controller,
          overlayChildBuilder: (context) => Positioned(
            width: 320,
            child: CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 4),
              child: _PreviewCard(text: widget.preview),
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(DpSpacing.md),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(context.appTokens.panelRadius),
        ),
        child: Text(
          text,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: c.textSecondary),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: 통과 확인**

```bash
cd /d/workspace/dpa/devpath-frontend/packages/dp_design && flutter test test/data/dp_list_row_test.dart 2>&1 | tail -8
```
Expected: PASS(기존 2 + 신규 1).

- [ ] **Step 5: 포맷 + 커밋**

```bash
cd /d/workspace/dpa/devpath-frontend && dart pub global run melos run format
git -C /d/workspace/dpa/devpath-frontend add packages/dp_design/lib/src/data/dp_list_row.dart packages/dp_design/test/data/dp_list_row_test.dart
git -C /d/workspace/dpa/devpath-frontend commit -m "feat(dp_design): DpListRow preview 슬롯(OverlayPortal hover 미리보기)"
```

---

## Task 5: web _postRow 배선 + 목 픽스처 + 게이트 + PR

**Repo:** `devpath-frontend`

**Files:**
- Modify: `devpath-frontend/apps/web/lib/src/features/community/presentation/community_home_page.dart`
- Modify: `devpath-frontend/apps/web/lib/src/data/web_mock_fixtures.dart`
- Test: `devpath-frontend/apps/web/test/features/community/community_home_page_test.dart` (회귀 유지 — 필요 시 확인만)

**Interfaces:**
- Consumes: `DpListRow.preview`(Task 4), `CommunityPostSummary.excerpt`(Task 3).
- Produces: web 커뮤니티 피드 제목 hover 미리보기(목 모드에서 실데이터 렌더).

- [ ] **Step 1: `_postRow`가 preview 전달** — `community_home_page.dart`

`_postRow`의 `DpListRow(` 호출에 `title: post.title,` 아래로 추가:
```dart
      title: post.title,
      preview: post.excerpt.isEmpty ? null : post.excerpt,
```

- [ ] **Step 2: 목 픽스처에 excerpt 추가** — `web_mock_fixtures.dart`의 `'GET /community/posts'` 리스트 각 항목에 `excerpt` 키 추가

id 1 항목:
```dart
        'replyCount': 2,
        'excerpt': 'async/await는 Future를 순차적으로 다루는 문법입니다. 이벤트 루프와 마이크로태스크 큐를 이해하면…',
```
id 10 항목:
```dart
        'replyCount': 4,
        'excerpt': '오늘은 Riverpod의 Notifier와 AsyncNotifier 차이를 정리했습니다. 상태 복원과 자동 폐기까지…',
```
id 20 항목:
```dart
        'replyCount': 1,
        'excerpt': '로그인 폼 검증 로직에 대한 리뷰 부탁드립니다. 특히 IME 전각 처리와 디바운스 부분이 고민입니다.',
```

- [ ] **Step 3: 커뮤니티 피드 회귀 테스트 확인**

```bash
cd /d/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/community/community_home_page_test.dart 2>&1 | tail -8
```
Expected: PASS(기존 테스트 유지 — preview는 hover 시에만 등장, 기본 렌더 불변).

- [ ] **Step 4: 프론트 전체 게이트**

```bash
cd /d/workspace/dpa/devpath-frontend && dart pub global run melos run format 2>&1 | tail -3
cd /d/workspace/dpa/devpath-frontend && dart pub global run melos run analyze 2>&1 | tail -4
cd /d/workspace/dpa/devpath-frontend && dart pub global run melos run test 2>&1 | tail -6
```
Expected: format 0 changed·analyze 전 패키지 통과·test 전 패키지 SUCCESS.

- [ ] **Step 5: 커밋 + 푸시 + PR**

```bash
git -C /d/workspace/dpa/devpath-frontend add apps/web/lib/src/features/community/presentation/community_home_page.dart apps/web/lib/src/data/web_mock_fixtures.dart
git -C /d/workspace/dpa/devpath-frontend commit -m "feat(web): 커뮤니티 피드 제목 hover 미리보기 배선 + 목 픽스처"
git -C /d/workspace/dpa/devpath-frontend push -u origin feat/community-excerpt-preview
```
그 후 `feat/community-excerpt-preview` → `develop` PR(제목 `feat(web): 커뮤니티 제목 미리보기`). CI(`analyze-test`) green + 사용자 승인 후 머지.

---

## 통합 검증(양 레포 머지 후)

- 백엔드·프론트 PR 각각 CI green + 사용자 승인 → 머지(백엔드 먼저). 로컬 목 모드는 Task 5 픽스처로 즉시 hover 확인.
- 실서버 스모크(선택): `cd apps/web && flutter run -d chrome --dart-define-from-file=.env.local` → 커뮤니티 피드 제목 hover 시 실 excerpt 카드.
