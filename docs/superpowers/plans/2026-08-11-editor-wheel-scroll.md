# 작성 화면 에디터 휠 스크롤 해소 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 에디터 위에서 휠을 굴려도 페이지가 스크롤되게 하고, 툴바는 본문 편집 중 계속 보이게 한다.

**Architecture:** `QuillEditorConfig(scrollable: false)`로 에디터를 내용만큼 늘려 중첩 스크롤을 없앤다. 툴바는 `DpRichEditor`에서 분리해 두 작성 화면에서 `SliverPersistentHeader(pinned: true)`로 올린다. 툴바 높이는 라이브러리가 private으로 막아 두어 실측값(42.0)을 상수로 쓰고 테스트로 고정한다.

**Tech Stack:** Flutter · flutter_quill 11.5.1 · flutter_test · melos 7

**Spec:** `docs/superpowers/specs/2026-08-11-editor-wheel-scroll-design.md`

## Global Constraints

- 대상 레포는 `devpath-frontend` 하나다.
- 작업 브랜치는 `develop`에서 분기한다.
- **테스트를 먼저 쓰고 실패를 눈으로 확인한 뒤** 구현한다(CLAUDE.md 절대 조건 2).
- **추측하지 않는다.** 모르면 파일을 읽고 명령을 실행해 확인한다(절대 조건 1).
- 툴바 버튼 화이트리스트(`QuillSimpleToolbarConfig`의 show* 플래그 조합)를 **바꾸지 않는다.** 마크다운 무손실 표현이 그 근거다.
- 확인 명령: `melos run format`(0 changed를 눈으로) · `melos run analyze` · `melos run test`
- 실측 상수: **툴바 높이 42.0** · 구분선 1.0 · `DpRadius.input = 8` · 색은 `context.dpColors`의 `surface`·`border`

## File Structure

| 파일 | 책임 |
|---|---|
| `apps/web/test/features/community/post_create_page_test.dart` (수정) | 휠 전파 재현 테스트 추가 |
| `apps/web/lib/.../widgets/rich_editor.dart` (수정) | 툴바/본문 분리, `scrollable: false`, `minHeight`, 테두리 분할, 높이 상수 |
| `apps/web/test/features/community/rich_editor_test.dart` (수정) | 확장·최소높이·툴바 높이 상수 단언 |
| `apps/web/lib/.../presentation/post_create_page.dart` (수정) | 툴바를 `SliverPersistentHeader`로 |
| `apps/web/lib/.../presentation/question_create_page.dart` (수정) | 동일 |

---

### Task 1: 결함을 테스트로 고정한다

먼저 재현한다. 이 테스트가 red인 것이 이 작업의 근거다.

**Files:**
- Modify: `apps/web/test/features/community/post_create_page_test.dart`

**Interfaces:**
- Consumes: 기존 `_host`·`_bodyWith`·provider 오버라이드
- Produces: 없음

- [ ] **Step 1: 기존 테스트가 무엇을 하는지 읽는다**

`post_create_page_test.dart`를 끝까지 읽고 `_host`가 요구하는 `ProviderContainer` 오버라이드를 확인한다. 새 테스트는 **기존 테스트 중 하나와 같은 준비 코드**를 쓴다. 준비 코드를 추측해 새로 쓰지 않는다.

- [ ] **Step 2: 파일 상단 import에 다음을 더한다**

```dart
import 'package:flutter/gestures.dart';
```

`TestPointer`가 쓰는 `PointerDeviceKind`가 여기 있다.

- [ ] **Step 3: 재현 테스트를 파일 끝에 추가한다**

`<기존 테스트의 준비 코드>` 자리에는 Step 1에서 확인한 코드를 그대로 넣는다.

```dart
  // 에디터가 고정 높이 자체 스크롤이면 내부에 스크롤할 내용이 없어도 휠을
  // 흡수해 페이지가 멈춘다. 커서가 본문 위에 있을 때 화면이 고장난 것처럼 보인다.
  testWidgets('에디터 위에서 휠을 굴리면 페이지가 스크롤된다', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // <기존 테스트의 준비 코드: ProviderContainer 오버라이드 + addTearDown>
    final body = _bodyWith('짧은 본문');
    addTearDown(body.dispose);

    await tester.pumpWidget(_host(container, bodyController: body));
    await tester.pumpAndSettle();

    // 헤더 설명은 첫 sliver에 있어 페이지가 스크롤되면 위로 밀린다.
    final finder = find.text('자유롭게 쓰거나 코드 피드백을 요청하세요');
    final before = tester.getTopLeft(finder).dy;

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(tester.getCenter(find.byType(QuillEditor)));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 300)));
    await tester.pumpAndSettle();

    final after = tester.getTopLeft(finder).dy;

    expect(
      after,
      lessThan(before),
      reason: '에디터가 휠을 흡수하면 헤더가 제자리에 남는다(before=$before after=$after)',
    );
  });
```

- [ ] **Step 4: 실패를 확인한다**

```bash
cd apps/web && flutter test test/features/community/post_create_page_test.dart
```

Expected: 새 테스트만 **FAIL**. `after`가 `before`와 같아야 한다(헤더가 안 움직임). 기존 테스트는 전부 통과해야 한다.

**만약 통과한다면** 재현에 실패한 것이다. 그 경우 멈추고 보고한다 — 결함이 이미 없거나, 테스트가 다른 것을 재고 있다. 추측으로 진행하지 않는다.

- [ ] **Step 5: 커밋**

```bash
git add apps/web/test/features/community/post_create_page_test.dart
git commit -m "test(web): 에디터가 휠을 흡수해 페이지가 멈추는 것을 고정한다"
```

red 상태로 커밋한다. 다음 태스크가 green으로 만든다.

---

### Task 2: 에디터를 늘리고 툴바를 분리한다

**Files:**
- Modify: `apps/web/lib/src/features/community/presentation/widgets/rich_editor.dart`
- Modify: `apps/web/test/features/community/rich_editor_test.dart`

**Interfaces:**
- Consumes: 없음
- Produces:
  - `const double kDpRichEditorToolbarHeight = 42.0`
  - `class DpRichEditorToolbar extends StatelessWidget` — `{required QuillController controller}`
  - `class DpRichEditorBody extends StatefulWidget` — `{required QuillController controller, bool enabled, double minHeight}`
  - `class DpRichEditor extends StatelessWidget` — 위 둘을 `Column`으로 묶은 기존 형태

- [ ] **Step 1: 실패하는 테스트를 추가한다**

`rich_editor_test.dart` 끝에 추가한다. 상단 import에 `rich_editor.dart`가 이미 있다.

```dart
  // 라이브러리가 toolbarSize를 private으로 막아 두어 실측값을 상수로 쓴다.
  // 버전이 올라 높이가 바뀌면 여기서 red가 나 sliver 높이도 함께 고쳐야 함을 안다.
  testWidgets('툴바 실제 높이가 상수와 일치한다', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final c = QuillController.basic();
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(QuillSimpleToolbar)).height,
      kDpRichEditorToolbarHeight,
    );
  });

  testWidgets('빈 문서에서도 본문이 최소 높이를 지킨다', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final c = QuillController.basic();
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(DpRichEditorBody)).height,
      greaterThanOrEqualTo(260.0),
    );
  });

  // scrollable: false 라 내용이 길면 위젯 자체가 커진다. 내부 스크롤이 남아
  // 있으면 높이가 최소값에 고정돼 이 단언이 실패한다.
  testWidgets('내용이 길면 본문이 최소 높이보다 커진다', (tester) async {
    tester.view.physicalSize = const Size(1400, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final doc = Document()..insert(0, List.filled(80, '긴 본문 줄입니다.').join('\n'));
    final c = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(DpRichEditorBody)).height,
      greaterThan(260.0),
    );
  });
```

- [ ] **Step 2: 실패를 확인한다**

```bash
cd apps/web && flutter test test/features/community/rich_editor_test.dart
```

Expected: 새 3건 FAIL(`kDpRichEditorToolbarHeight`·`DpRichEditorBody` 미정의). 기존 테스트는 통과.

- [ ] **Step 3: `rich_editor.dart`를 다시 쓴다**

파일 전체를 다음으로 바꾼다. 기존 주석(FocusNode 수명에 관한 것)은 **본문 위젯으로 옮겨 보존한다** — 그 사고의 기록이 사라지면 같은 실수가 반복된다.

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// 툴바 실제 높이(실측). `QuillSimpleToolbarConfig._toolbarSize` 가 private 이라
/// 외부에서 지정할 수 없어 측정값을 상수로 둔다. 작성 화면이 툴바를
/// `SliverPersistentHeader` 로 고정할 때 이 값을 쓴다.
/// `rich_editor_test.dart` 가 실제 높이와의 일치를 단언한다.
const double kDpRichEditorToolbarHeight = 42.0;

/// 툴바 아래 구분선 두께.
const double kDpRichEditorDividerHeight = 1.0;

/// 커뮤니티 작성 본문용 WYSIWYG 에디터(웹 전용)의 툴바.
///
/// 저장 계약은 마크다운(`bodyMd`)이므로 **마크다운으로 무손실 표현 가능한
/// 서식만** 노출한다(색·폰트·밑줄·정렬 등은 비활성). 변환은
/// `quillToMarkdown` 이 담당한다.
class DpRichEditorToolbar extends StatelessWidget {
  const DpRichEditorToolbar({super.key, required this.controller});

  final QuillController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(
          top: BorderSide(color: c.border),
          left: BorderSide(color: c.border),
          right: BorderSide(color: c.border),
        ),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DpRadius.input),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QuillSimpleToolbar(
            controller: controller,
            config: const QuillSimpleToolbarConfig(
              // ON — 마크다운 무손실
              showBoldButton: true,
              showItalicButton: true,
              showStrikeThrough: true,
              showHeaderStyle: true,
              showListBullets: true,
              showListNumbers: true,
              showQuote: true,
              showCodeBlock: true,
              showInlineCode: true,
              showLink: true,
              showUndo: true,
              showRedo: true,
              // OFF — 마크다운 비표현 또는 범위 외
              showFontFamily: false,
              showFontSize: false,
              showColorButton: false,
              showBackgroundColorButton: false,
              showUnderLineButton: false,
              showListCheck: false,
              showSubscript: false,
              showSuperscript: false,
              showSmallButton: false,
              showLineHeightButton: false,
              showAlignmentButtons: false,
              showDirection: false,
              showIndent: false,
              showClearFormat: false,
              showSearchButton: false,
              multiRowsDisplay: false,
            ),
          ),
          Divider(height: kDpRichEditorDividerHeight),
        ],
      ),
    );
  }
}

/// 본문 입력 영역.
///
/// `scrollable: false` 라 문서 전체 높이로 늘어난다. 자체 스크롤이 없으므로
/// **휠 이벤트가 바깥 스크롤로 전달된다** — 고정 높이였을 때는 내부에 스크롤할
/// 내용이 없어도 에디터가 휠을 흡수해 페이지가 멈췄다.
/// 반드시 스크롤 가능한 부모(작성 화면의 `CustomScrollView`) 안에 둔다.
class DpRichEditorBody extends StatefulWidget {
  const DpRichEditorBody({
    super.key,
    required this.controller,
    this.enabled = true,
    this.minHeight = 260,
  });

  final QuillController controller;

  /// 제출 중 입력 잠금.
  final bool enabled;

  /// 빈 문서에서도 확보할 최소 높이.
  final double minHeight;

  @override
  State<DpRichEditorBody> createState() => _DpRichEditorBodyState();
}

class _DpRichEditorBodyState extends State<DpRichEditorBody> {
  // QuillEditor.basic 은 focusNode/scrollController 를 넘기지 않으면 build 마다
  // 새 인스턴스를 만든다(pub cache flutter_quill-11.5.1 editor.dart:163-164).
  // 이 위젯이 StatelessWidget 이던 시절엔 상위에서 setState 가 발화할 때마다
  // 통째로 교체돼 FocusNode 도 매번 새로 생성됐고, 아무도 dispose 하지 않아
  // 포커스·IME 연결이 끊겼다(질문 작성 화면의 유사질문 패널 삽입이 대표 사례).
  // State 가 두 컨트롤을 소유·해제해 인스턴스를 안정시킨다.
  //
  // scrollController 는 scrollable: false 여도 QuillEditor 생성자가 요구한다
  // (캐럿 추적에 쓴다). 제거하면 컴파일되지 않는다.
  late final FocusNode _focusNode;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    return AbsorbPointer(
      absorbing: !widget.enabled,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: c.border),
            right: BorderSide(color: c.border),
            bottom: BorderSide(color: c.border),
          ),
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(DpRadius.input),
          ),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: widget.minHeight),
          child: Padding(
            padding: const EdgeInsets.all(DpSpacing.sm),
            child: QuillEditor.basic(
              controller: widget.controller,
              focusNode: _focusNode,
              scrollController: _scrollController,
              config: const QuillEditorConfig(scrollable: false),
            ),
          ),
        ),
      ),
    );
  }
}

/// 툴바와 본문을 한 덩어리로 쓰는 형태.
///
/// 작성 화면은 툴바를 고정하기 위해 둘을 따로 배치하지만, 스크롤 부모가 없는
/// 곳에서는 이 위젯을 쓴다.
class DpRichEditor extends StatelessWidget {
  const DpRichEditor({
    super.key,
    required this.controller,
    this.enabled = true,
    this.minHeight = 260,
  });

  final QuillController controller;
  final bool enabled;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DpRichEditorToolbar(controller: controller),
        DpRichEditorBody(
          controller: controller,
          enabled: enabled,
          minHeight: minHeight,
        ),
      ],
    );
  }
}
```

★기존 `height` 파라미터가 `minHeight`로 바뀐다.★ 호출부에서 `height:`를 쓰고 있으면 컴파일이 깨지므로 Step 4에서 확인한다.

- [ ] **Step 4: 호출부를 확인한다**

```bash
cd apps/web && grep -rn "DpRichEditor(" lib test
```

`height:` 인자를 쓰는 곳이 있으면 `minHeight:`로 바꾼다. 없으면 그대로 둔다.

- [ ] **Step 5: 통과를 확인한다**

```bash
cd apps/web && flutter test test/features/community/rich_editor_test.dart
```

Expected: 기존 + 신규 3건 전부 PASS.

- [ ] **Step 6: Task 1의 재현 테스트를 다시 돌린다**

```bash
cd apps/web && flutter test test/features/community/post_create_page_test.dart
```

Expected: **휠 테스트가 이제 통과한다.** 중첩 스크롤이 사라졌기 때문이다. 이 시점에서 이미 결함은 해소된다 — 툴바 고정(Task 3)은 그로 인한 UX 손실을 메우는 작업이다.

통과하지 않으면 멈추고 원인을 조사한다.

- [ ] **Step 7: 커밋**

```bash
git add apps/web/lib/src/features/community/presentation/widgets/rich_editor.dart apps/web/test/features/community/rich_editor_test.dart
git commit -m "fix(web): 에디터를 내용만큼 늘려 휠 이벤트가 페이지로 가게 한다"
```

---

### Task 3: 툴바를 고정한다

**Files:**
- Modify: `apps/web/lib/src/features/community/presentation/post_create_page.dart`
- Modify: `apps/web/lib/src/features/community/presentation/question_create_page.dart`
- Modify: `apps/web/test/features/community/post_create_page_test.dart`

**Interfaces:**
- Consumes: Task 2의 `DpRichEditorToolbar`·`DpRichEditorBody`·`kDpRichEditorToolbarHeight`·`kDpRichEditorDividerHeight`
- Produces: 없음

- [ ] **Step 1: 실패하는 테스트를 추가한다**

`post_create_page_test.dart` 끝에 추가한다.

```dart
  // 에디터가 늘어나면 툴바가 위로 사라진다. 긴 글을 쓰는 동안 서식 버튼에
  // 닿으려면 매번 올라가야 하므로 고정한다.
  testWidgets('페이지를 스크롤해도 툴바가 화면에 남는다', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // <기존 테스트의 준비 코드: ProviderContainer 오버라이드 + addTearDown>
    final body = _bodyWith(List.filled(80, '긴 본문 줄입니다.').join('\n'));
    addTearDown(body.dispose);

    await tester.pumpWidget(_host(container, bodyController: body));
    await tester.pumpAndSettle();

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(tester.getCenter(find.byType(QuillEditor)));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, 400)));
    await tester.pumpAndSettle();

    // 고정돼 있으면 화면 안(0 이상)에 남는다. 함께 스크롤되면 음수로 밀려난다.
    final top = tester.getTopLeft(find.byType(DpRichEditorToolbar)).dy;

    expect(top, greaterThanOrEqualTo(0.0), reason: '툴바가 위로 밀려났다(top=$top)');
    expect(find.byType(DpRichEditorToolbar), findsOneWidget);
  });
```

상단 import에 `rich_editor.dart`를 더한다:

```dart
import 'package:devpath_web/src/features/community/presentation/widgets/rich_editor.dart';
```

- [ ] **Step 2: 실패를 확인한다**

Run: `cd apps/web && flutter test test/features/community/post_create_page_test.dart`
Expected: 새 테스트 FAIL — 툴바가 본문과 함께 스크롤돼 위로 밀려난다.

- [ ] **Step 3: sliver 델리게이트를 만든다**

`post_create_page.dart` 파일 하단(클래스 밖)에 추가한다. `question_create_page.dart`도 같은 것을 쓰므로 **공용 위치**가 낫다 — `widgets/rich_editor.dart` 끝에 두고 두 화면이 가져다 쓴다.

`rich_editor.dart` 끝에 추가:

```dart
/// 작성 화면에서 툴바를 상단에 고정하기 위한 sliver 델리게이트.
///
/// 높이는 실측 상수로 고정한다(`QuillSimpleToolbarConfig` 가 크기를 노출하지
/// 않는다). 툴바 자체가 배경색을 채우므로 본문이 뒤로 지나가도 겹쳐 보이지 않는다.
class DpRichEditorToolbarHeader extends SliverPersistentHeaderDelegate {
  const DpRichEditorToolbarHeader({required this.controller});

  final QuillController controller;

  static const double height =
      kDpRichEditorToolbarHeight + kDpRichEditorDividerHeight;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return DpRichEditorToolbar(controller: controller);
  }

  @override
  bool shouldRebuild(covariant DpRichEditorToolbarHeader oldDelegate) =>
      oldDelegate.controller != controller;
}
```

- [ ] **Step 4: `post_create_page.dart`의 sliver 구성을 바꾼다**

`build`의 주석 두 줄을 사실에 맞게 고친다:

```dart
    // 문서형 화면 — 헤더를 첫 sliver로 실어 폼과 함께 스크롤시킨다(DESIGN.md §9).
    // 본문 에디터는 자체 스크롤이 없어(scrollable: false) 페이지 스크롤과
    // 경쟁하지 않는다. 툴바만 pinned sliver로 상단에 고정한다.
```

`SliverList.list`의 자식 목록에서 `DpRichEditor(...)`를 빼고, 그 자리에서 sliver를 나눈다. 제목까지를 첫 `SliverList`, 툴바를 `SliverPersistentHeader`, 본문을 `SliverToBoxAdapter`, 나머지를 두 번째 `SliverList`로 둔다.

좌우 여백은 기존 `SliverPadding`이 주던 것이므로 각 조각에 같은 `EdgeInsets.symmetric(horizontal: DpSpacing.lg)`를 준다. 상하 여백은 첫 조각의 `top`, 마지막 조각의 `bottom`에만 준다.

```dart
        slivers: [
          SliverToBoxAdapter(
            child: DpPageHeader(
              title: _pageTitle,
              description: '자유롭게 쓰거나 코드 피드백을 요청하세요',
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              DpSpacing.lg,
              DpSpacing.lg,
              DpSpacing.lg,
              0,
            ),
            sliver: SliverList.list(
              children: [
                TextField(
                  controller: _titleCtrl,
                  enabled: !_submitting,
                  decoration: const InputDecoration(
                    labelText: '제목',
                    hintText: '제목을 입력하세요',
                    border: OutlineInputBorder(),
                  ),
                ),
                // 본문 안내 문구는 헤더 설명과 같은 말이라 제거했다(3-A Task 14-3).
                const SizedBox(height: DpSpacing.md),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: DpSpacing.lg),
            sliver: SliverPersistentHeader(
              pinned: true,
              delegate: DpRichEditorToolbarHeader(controller: _bodyController),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: DpSpacing.lg),
            sliver: SliverToBoxAdapter(
              child: DpRichEditorBody(
                key: const ValueKey('post-body-editor'),
                controller: _bodyController,
                enabled: !_submitting,
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              DpSpacing.lg,
              DpSpacing.md,
              DpSpacing.lg,
              DpSpacing.lg,
            ),
            sliver: SliverList.list(
              children: [
                // <기존 목록의 나머지: 태그 TextField 이하 전부>
              ],
            ),
          ),
        ],
```

`<기존 목록의 나머지>`는 현재 파일에 있는 `DpRichEditor` 다음 자식들을 **순서 그대로** 옮긴다. 새로 쓰지 않는다.

`ValueKey('post-body-editor')`를 본문 위젯으로 옮긴 것에 주의한다 — 기존 테스트가 이 키를 찾을 수 있다. Step 6에서 확인한다.

- [ ] **Step 5: `question_create_page.dart`도 같은 방식으로 바꾼다**

주석을 같은 문구로 고치고, sliver를 네 조각으로 나눈다. 이 화면은 제목 아래에 **유사 질문 패널(`if (_similar.isNotEmpty)`)** 이 있으므로 그 블록은 **첫 `SliverList`(제목 조각)에 그대로 둔다.**

본문 에디터의 `ValueKey`가 있으면 함께 옮긴다.

- [ ] **Step 6: 통과를 확인한다**

```bash
cd apps/web && flutter test test/features/community/
```

Expected: 두 화면 테스트와 rich_editor 테스트 전부 통과.

깨지는 것이 있으면 **테스트를 고치지 말고** 무엇이 달라졌는지 먼저 본다. 특히 `ValueKey`·`find.byType(DpRichEditor)`를 쓰는 단언은 위젯이 쪼개져 못 찾을 수 있다. 그 경우 **찾는 대상을 새 위젯으로 바꾸는 것이 옳은 수정**이다(동작이 아니라 구조가 바뀐 것이므로).

- [ ] **Step 7: 커밋**

```bash
git add apps/web/lib/src/features/community/presentation/ apps/web/test/features/community/
git commit -m "feat(web): 작성 화면에서 본문 툴바를 상단에 고정한다"
```

---

### Task 4: 전체 검증 · 육안 확인 · PR

**Files:** 없음

- [ ] **Step 1: 모노레포 전체 검증**

```bash
dart pub global run melos run format
dart pub global run melos run analyze
dart pub global run melos run test
```

`format`은 `--set-exit-if-changed`라 **실제로 파일을 고치고 exit 1을 낸다.** 한 번 더 돌려 **`0 changed`를 눈으로 확인**한다.

- [ ] **Step 2: 육안 확인 — ★이 태스크의 핵심★**

작성 화면 두 개를 캡처해 확인한다. 확인할 것:

1. **툴바와 본문이 붙어 있을 때 하나의 상자로 보이는가** — 테두리를 쪼갰으므로 이음매가 보이면 안 된다
2. **스크롤 중 툴바가 상단에 남는가**
3. **★본문을 지나 태그 입력까지 내려갔을 때 툴바가 남는 모습이 어떤가★** — 스펙 §4.3의 알려진 부작용이다. 이 캡처를 사용자에게 보여 판단을 받는다
4. 빈 문서에서 에디터가 지금과 비슷한 크기인가

캡처는 릴리스 빌드로 뜬 로컬 서버에서 한다. CanvasKit은 브라우저 스크롤이 없으므로 **뷰포트 높이를 키워** 찍는다(핸드오프 §3.2).

- [ ] **Step 3: PR을 만든다**

```bash
git push -u origin <브랜치명>
gh pr create --base develop --title "fix(web): 에디터 위 휠 스크롤 무반응을 해소한다" --body "<스펙 링크·변경 요약·캡처>"
```

- [ ] **Step 4: CI 확인 후 머지**

```bash
gh pr checks <번호>
```

★`--watch`가 API 504로 끊길 수 있다.★ 그 경우 머지 명령을 바로 내지 말고 `gh pr checks <번호>`로 **완료 상태를 다시 확인**한 뒤 머지한다.

- [ ] **Step 5: 라이브 반영은 릴리스 대기**

이 레포는 이미지 빌드·배포가 `main` 전용이다. `develop` 머지로는 라이브가 바뀌지 않는다. 릴리스는 별도 작업이다.

---

## Self-Review

**스펙 커버리지**

| 스펙 항목 | 태스크 |
|---|---|
| §4.1 에디터 확장(`scrollable: false`·`minHeight`) | Task 2 |
| §4.2 툴바 분리·고정·테두리 분할·배경색 | Task 2 Step 3, Task 3 Step 3·4 |
| §4.3 알려진 부작용 확인 | Task 4 Step 2-3 |
| §4.4 틀린 주석 교정 | Task 3 Step 4·5 |
| §5 휠 전파 재현 | Task 1 |
| §5 확장·최소높이·툴바 높이 상수 | Task 2 Step 1 |
| §5 툴바 고정 | Task 3 Step 1 |
| §5 기존 보호 | Task 2 Step 5, Task 3 Step 6 |
| §6 검증·육안 | Task 4 |
| §7 위험 전부 | 각 태스크의 확인 단계 |

**빠진 것을 하나 찾아 고쳤다.** 스펙은 `height` 파라미터가 `minHeight`로 바뀌는 것을 다루지 않았다. 호출부가 `height:`를 쓰고 있으면 컴파일이 깨지므로 Task 2 Step 4에 확인 단계를 넣었다.

**재현 실패 시의 처리를 명시했다.** Task 1 Step 4에서 테스트가 통과해 버리면 결함이 이미 없거나 테스트가 다른 것을 재는 것이다. 그 경우 **멈추고 보고**한다 — 재현하지 못한 결함을 고치면 무엇을 고쳤는지 알 수 없다.

**Task 2가 끝나는 시점에 결함이 이미 해소된다는 것을 명시했다**(Step 6). Task 3은 그로 인한 UX 손실을 메우는 작업이라, 만약 Task 3이 어려워지면 Task 2까지만으로도 원래 목적은 달성된다.

**타입·이름 일관성** — `kDpRichEditorToolbarHeight`·`kDpRichEditorDividerHeight`·`DpRichEditorToolbar`·`DpRichEditorBody`·`DpRichEditorToolbarHeader`가 Task 2에서 정의되고 Task 3에서 그대로 쓰인다. `DpRichEditorToolbarHeader.height`가 두 상수의 합이다.

**준비 코드를 추측하지 않게 했다.** Task 1·3의 테스트에 `<기존 테스트의 준비 코드>` 자리를 두고, Step 1에서 기존 파일을 읽어 그대로 쓰게 했다. provider 오버라이드를 지어내면 테스트가 엉뚱한 이유로 실패한다.
