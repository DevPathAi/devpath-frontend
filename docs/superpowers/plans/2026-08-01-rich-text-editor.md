# 서식 텍스트 에디터(WYSIWYG) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 커뮤니티 작성 화면 2개(일반글·질문)의 본문 입력을 마크다운 원문 `TextField`에서 WYSIWYG 에디터로 바꾸되, 저장은 기존과 동일한 마크다운(`bodyMd`)으로 유지한다.

**Architecture:** `apps/web`에만 `flutter_quill`(에디터)·`markdown_quill`(Delta→마크다운)을 도입한다. 에디터 내부 표현은 Quill `Document`/`Delta`(메모리 전용)이고, 게시 직전 `DeltaToMarkdown`으로 마크다운 문자열을 산출해 기존 create provider에 그대로 넘긴다. 따라서 백엔드·`dp_core`·`shared`·상세 렌더(`DpMarkdown`)는 **전부 무변경**이다. 툴바는 마크다운으로 무손실 표현 가능한 버튼만 화이트리스트로 노출한다.

**Tech Stack:** Flutter 3.44.1 / Dart 3.12.1 · flutter_quill ^11 · markdown_quill ^4.3.0 · flutter_riverpod 3.x · go_router · flutter_test · melos 7

**참조 spec:** `docs/superpowers/specs/2026-07-31-rich-text-editor-design.md` (개정판 커밋 `a719f55`)

## Global Constraints

- **레포/브랜치**: `devpath-frontend` 단일. 브랜치 `feat/rich-text-editor`(**이미 존재**, spec 커밋 `9fc696a`·`a719f55` 보유) → `develop` PR. 백엔드 레포는 손대지 않는다.
- **모든 git 명령은 `git -C D:/workspace/dpa/devpath-frontend`**, 모든 flutter 명령은 `cd D:/workspace/dpa/devpath-frontend/apps/web && ...` 프리픽스로 실행한다. 도구 호출 사이 cwd가 리셋되므로 `cd` 후 별도 호출로 상대경로 명령을 내지 않는다.
- **TDD 필수**(CLAUDE.md 규칙 2): 실패 테스트 선작성 → 최소 구현 → 통과 확인. 테스트 없는 구현 변경 금지.
- **추측 금지**(CLAUDE.md 규칙 1): 명세에 없는 코드 즉흥 구현 금지. 명세가 부족하면 멈추고 `NEEDS_CONTEXT` 보고. 특히 **패키지 출력 형식을 상상해서 기대값을 쓰지 말 것** — Task 1은 실제 출력을 찍어 확인하는 단계를 포함한다.
- **계약 불변**: create provider의 `bodyMd`(마크다운 문자열) 시그니처는 그대로. `dp_core`·`packages/dp_design`·백엔드 파일을 수정하면 범위 이탈이다.
- **패키지 위치**: `flutter_quill`·`markdown_quill`은 **`apps/web/pubspec.yaml`에만** 추가한다(`dp_design`/`dp_core`/`apps/admin`/`apps/mobile` 금지).
- **`markdown` 패키지는 직접 의존으로 추가하지 않는다**. `md.Document`는 마크다운→Delta 로드(범위 외)에만 필요하며, markdown_quill이 전이 의존으로 가진다.
- **툴바 화이트리스트**(spec §5.2) — `QuillSimpleToolbarConfig`는 기본값 `true`인 플래그가 많으므로 차단 항목을 전부 명시한다:
  - ON: `showBoldButton`·`showItalicButton`·`showHeaderStyle`·`showListBullets`·`showListNumbers`·`showQuote`·`showCodeBlock`·`showInlineCode`·`showLink`·`showUndo`·`showRedo`
  - OFF: `showFontFamily`·`showFontSize`·`showColorButton`·`showBackgroundColorButton`·`showUnderLineButton`·`showListCheck`·`showSubscript`·`showSuperscript`·`showSmallButton`·`showLineHeightButton`·`showAlignmentButtons`·`showDirection`·`showIndent`·`showClearFormat`·`showSearchButton`
  - `showStrikeThrough`: **Task 1의 실측 결과로 결정**(마크다운 `~~…~~`로 변환되면 ON, 아니면 OFF).
- **localizations 필수**(spec §5.4): flutter_quill 11.x는 `FlutterQuillLocalizations.delegate` 등록을 요구한다. 앱 루트(`app.dart`)와 **Quill을 렌더하는 위젯 테스트의 `MaterialApp`** 양쪽에 배선해야 한다. `flutter_localizations`(SDK)는 추가하지 않고 `Default*Localizations`를 쓴다.
- **검증 게이트**(커밋 전마다): `melos run format`(`--set-exit-if-changed`라 미포맷이면 FAILED) → `melos run analyze` → `melos run test`. melos가 PATH에 없으면 `dart pub global run melos <cmd>`.
- **필수 AC**: Task 5의 **브라우저 한글 IME 스모크**를 통과하지 못하면 이 접근(Approach B)을 채택하지 않는다 → spec §6 Fork 3 폴백(마크다운 툴바+프리뷰)으로 전환하고 사용자에게 보고한다.

## File Structure

**신규**
- `apps/web/lib/src/features/community/presentation/widgets/` — 디렉토리 신설(현재 없음).
- `apps/web/lib/src/features/community/presentation/widgets/quill_markdown.dart` — 순수 변환 헬퍼 `quillToMarkdown`. 위젯 의존 없음, 단위 테스트 대상.
- `apps/web/lib/src/features/community/presentation/widgets/rich_editor.dart` — `DpRichEditor`(툴바 + 에디터 조합 위젯). flutter_quill을 아는 유일한 위젯 파일.
- `apps/web/test/features/community/quill_markdown_test.dart` — 변환 단위 테스트.
- `apps/web/test/features/community/rich_editor_test.dart` — 에디터 위젯 테스트.

**수정**
- `apps/web/pubspec.yaml` — 의존 2개 추가.
- `apps/web/lib/src/app/app.dart` — `localizationsDelegates` 추가.
- `apps/web/lib/src/features/community/presentation/post_create_page.dart` — 본문 입력 교체.
- `apps/web/lib/src/features/community/presentation/question_create_page.dart` — 본문 입력 교체.
- `apps/web/test/features/community/post_create_page_test.dart` — TextField 인덱스 재배치 + delegate.
- `apps/web/test/features/community/question_create_page_test.dart` — 동일.

**불변(수정 시 범위 이탈)**: `packages/dp_core/**`, `packages/dp_design/**`, `apps/admin/**`, `apps/mobile/**`, 모든 백엔드 레포.

---

## Task 1: 패키지 도입 + `quillToMarkdown` 변환 헬퍼

**Repo:** `devpath-frontend`

**Files:**
- Modify: `apps/web/pubspec.yaml`
- Create: `apps/web/lib/src/features/community/presentation/widgets/quill_markdown.dart`
- Test: `apps/web/test/features/community/quill_markdown_test.dart`

**Interfaces:**
- Produces: `String quillToMarkdown(QuillController controller)` — Quill 문서를 마크다운 문자열로 변환. Task 3·4가 `_submit()`에서 호출한다.
- Produces(결정): `showStrikeThrough` ON/OFF 결론 — Task 2의 툴바 설정이 이 결과를 사용한다.

- [ ] **Step 1: 브랜치 확인**

이 브랜치는 이미 존재하고 spec 커밋 2개를 보유한다. 새로 만들지 말고 최신 상태만 맞춘다.

```bash
git -C D:/workspace/dpa/devpath-frontend fetch origin
git -C D:/workspace/dpa/devpath-frontend checkout feat/rich-text-editor
git -C D:/workspace/dpa/devpath-frontend status --short
git -C D:/workspace/dpa/devpath-frontend log --oneline -2
```

Expected: 워킹트리 clean, HEAD = `a719f55 docs(spec): 서식 에디터 spec 검토 반영…`

- [ ] **Step 2: 패키지 추가 + 해석 결과 실측**

```bash
cd D:/workspace/dpa/devpath-frontend/apps/web && flutter pub add flutter_quill markdown_quill
```

Expected: 성공. 해석된 실제 버전을 확인해 기록한다:

```bash
cd D:/workspace/dpa/devpath-frontend/apps/web && flutter pub deps --style=compact 2>&1 | grep -E "flutter_quill|markdown_quill|markdown "
```

기대(spec §5.1 실측): `flutter_quill 11.5.x`, `markdown_quill 4.3.0`, `markdown 7.x`(전이).
**해석이 실패하거나 flutter_quill이 11 미만으로 내려가면** 여기서 멈추고 spec §5.1 폴백(flutter_quill을 markdown_quill 지원 버전으로 핀)을 적용한 뒤 결과를 보고한다.

`pubspec.yaml`에 `markdown`이 직접 추가됐다면 제거한다(Global Constraints).

- [ ] **Step 3: 변환 출력 실측용 임시 테스트 작성**

markdown_quill의 실제 출력 문자열을 **추측하지 않고 눈으로 확인**하기 위한 일회용 테스트다. 기대값 없이 출력만 찍는다.

Create `apps/web/test/features/community/quill_markdown_test.dart`:

```dart
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:markdown_quill/markdown_quill.dart';

/// 실측용 임시 헬퍼 — Step 6에서 lib 쪽 quillToMarkdown 으로 교체한다.
String _convert(Document doc) => DeltaToMarkdown().convert(doc.toDelta());

void main() {
  test('PROBE: 서식별 마크다운 출력 실측', () {
    void probe(String label, void Function(Document d) build) {
      final doc = Document();
      build(doc);
      // ignore: avoid_print
      print('--- $label ---\n${_convert(doc)}<<<END');
    }

    probe('bold', (d) {
      d.insert(0, '굵게');
      d.format(0, 2, Attribute.bold);
    });
    probe('italic', (d) {
      d.insert(0, '기울임');
      d.format(0, 3, Attribute.italic);
    });
    probe('strike', (d) {
      d.insert(0, '취소선');
      d.format(0, 3, Attribute.strikeThrough);
    });
    probe('h1', (d) {
      d.insert(0, '제목');
      d.format(2, 1, Attribute.h1);
    });
    probe('h2', (d) {
      d.insert(0, '제목2');
      d.format(3, 1, Attribute.h2);
    });
    probe('bullet', (d) {
      d.insert(0, '항목');
      d.format(2, 1, Attribute.ul);
    });
    probe('ordered', (d) {
      d.insert(0, '항목');
      d.format(2, 1, Attribute.ol);
    });
    probe('quote', (d) {
      d.insert(0, '인용');
      d.format(2, 1, Attribute.blockQuote);
    });
    probe('codeBlock', (d) {
      d.insert(0, 'final x = 1;');
      d.format(12, 1, Attribute.codeBlock);
    });
    probe('inlineCode', (d) {
      d.insert(0, 'code');
      d.format(0, 4, Attribute.inlineCode);
    });
    probe('link', (d) {
      d.insert(0, 'DevPath');
      d.format(0, 7, LinkAttribute('https://leva.ai.kr'));
    });
    probe('plain-hangul', (d) {
      d.insert(0, '한글 본문입니다');
    });
  });
}
```

- [ ] **Step 4: 실측 테스트 실행 — 출력 기록**

```bash
cd D:/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/community/quill_markdown_test.dart
```

Expected: PASS(단언이 없으므로) + 각 서식의 실제 마크다운 출력이 콘솔에 표시됨.

**출력 전문을 그대로 기록한다.** 특히 확인할 것:
1. 굵게가 `**…**`인지 `__…__`인지
2. **취소선이 `~~…~~`로 나오는지, 아니면 서식이 사라지는지** → `showStrikeThrough` ON/OFF 결정 근거
3. 블록 요소 뒤 개행 개수(`\n` 하나인지 둘인지) — 기대값에 그대로 반영
4. `Attribute.h1`/`ul` 등의 블록 포맷 적용 오프셋이 위 코드대로 동작하는지(에러 없이 변환되는지)

**Step 3의 코드가 예외를 던지면** 오프셋 문제이므로, 예외 메시지를 근거로 `format` 오프셋만 조정한다(도큐먼트 끝의 개행에 블록 속성을 적용해야 한다). 변환 결과를 임의로 가정해 넘어가지 않는다.

- [ ] **Step 5: 실측 결과로 기대값을 고정한 실패 테스트로 교체**

Step 4에서 **실제로 관찰한 문자열**로 기대값을 채운다. 아래는 골격이며, `expect`의 우변은 관찰값으로 채운다(관찰값과 다르면 관찰값이 정답이다).

Rewrite `apps/web/test/features/community/quill_markdown_test.dart`:

```dart
import 'package:devpath_web/src/features/community/presentation/widgets/quill_markdown.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

QuillController _controllerOf(void Function(Document d) build) {
  final doc = Document();
  build(doc);
  return QuillController(
    document: doc,
    selection: const TextSelection.collapsed(offset: 0),
  );
}

void main() {
  test('굵게 → 마크다운 강조', () {
    final c = _controllerOf((d) {
      d.insert(0, '굵게');
      d.format(0, 2, Attribute.bold);
    });
    addTearDown(c.dispose);
    // Step 4 관찰값으로 채운다 (예: '**굵게**')
    expect(quillToMarkdown(c).trim(), '<STEP4_OBSERVED_BOLD>');
  });

  test('제목(H1) → 마크다운 헤딩', () {
    final c = _controllerOf((d) {
      d.insert(0, '제목');
      d.format(2, 1, Attribute.h1);
    });
    addTearDown(c.dispose);
    expect(quillToMarkdown(c).trim(), '<STEP4_OBSERVED_H1>');
  });

  test('불릿 목록 → 마크다운 리스트', () {
    final c = _controllerOf((d) {
      d.insert(0, '항목');
      d.format(2, 1, Attribute.ul);
    });
    addTearDown(c.dispose);
    expect(quillToMarkdown(c).trim(), '<STEP4_OBSERVED_UL>');
  });

  test('인용 → 마크다운 blockquote', () {
    final c = _controllerOf((d) {
      d.insert(0, '인용');
      d.format(2, 1, Attribute.blockQuote);
    });
    addTearDown(c.dispose);
    expect(quillToMarkdown(c).trim(), '<STEP4_OBSERVED_QUOTE>');
  });

  test('인라인 코드 → 백틱', () {
    final c = _controllerOf((d) {
      d.insert(0, 'code');
      d.format(0, 4, Attribute.inlineCode);
    });
    addTearDown(c.dispose);
    expect(quillToMarkdown(c).trim(), '<STEP4_OBSERVED_INLINE_CODE>');
  });

  test('링크 → 마크다운 링크', () {
    final c = _controllerOf((d) {
      d.insert(0, 'DevPath');
      d.format(0, 7, LinkAttribute('https://leva.ai.kr'));
    });
    addTearDown(c.dispose);
    expect(quillToMarkdown(c).trim(), '<STEP4_OBSERVED_LINK>');
  });

  test('취소선 변환 여부 고정 — showStrikeThrough 결정 근거', () {
    final c = _controllerOf((d) {
      d.insert(0, '취소선');
      d.format(0, 3, Attribute.strikeThrough);
    });
    addTearDown(c.dispose);
    // 관찰값이 '~~취소선~~' 이면 툴바 ON, '취소선'(서식 소실)이면 OFF.
    expect(quillToMarkdown(c).trim(), '<STEP4_OBSERVED_STRIKE>');
  });

  test('한글 평문은 그대로 보존된다', () {
    final c = _controllerOf((d) => d.insert(0, '한글 본문입니다'));
    addTearDown(c.dispose);
    expect(quillToMarkdown(c).trim(), '한글 본문입니다');
  });

  test('빈 문서는 공백만 남는다', () {
    final c = QuillController.basic();
    addTearDown(c.dispose);
    expect(quillToMarkdown(c).trim(), isEmpty);
  });
}
```

- [ ] **Step 6: 테스트 실행 — 실패 확인**

```bash
cd D:/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/community/quill_markdown_test.dart
```

Expected: FAIL — `Error: Couldn't resolve the package 'devpath_web' … quill_markdown.dart` 또는 `quillToMarkdown isn't defined`(파일 미생성).

- [ ] **Step 7: 헬퍼 구현**

Create `apps/web/lib/src/features/community/presentation/widgets/quill_markdown.dart`:

```dart
import 'package:flutter_quill/flutter_quill.dart';
import 'package:markdown_quill/markdown_quill.dart';

/// Quill 문서(Delta)를 마크다운 문자열로 변환한다.
///
/// 저장 계약은 기존과 동일한 `bodyMd`(마크다운)이므로, 에디터의 Delta 는
/// 메모리 전용 표현이고 게시 직전 이 함수로 마크다운을 산출한다.
/// 툴바는 마크다운으로 무손실 표현 가능한 서식만 노출한다(`DpRichEditor`).
String quillToMarkdown(QuillController controller) =>
    DeltaToMarkdown().convert(controller.document.toDelta());
```

- [ ] **Step 8: 테스트 실행 — 통과 확인**

```bash
cd D:/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/community/quill_markdown_test.dart
```

Expected: PASS (9 tests). 실패하면 기대값이 아니라 **관찰값이 정답**이므로 Step 4 출력과 대조해 기대값을 고친다.

- [ ] **Step 9: 게이트 + 커밋**

```bash
cd D:/workspace/dpa/devpath-frontend && melos run format
cd D:/workspace/dpa/devpath-frontend && melos run analyze
git -C D:/workspace/dpa/devpath-frontend add apps/web/pubspec.yaml apps/web/lib/src/features/community/presentation/widgets/quill_markdown.dart apps/web/test/features/community/quill_markdown_test.dart pubspec.lock apps/web/pubspec.lock
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(web): Quill Delta→마크다운 변환 헬퍼 + flutter_quill 도입"
```

주: `pubspec.lock`은 워크스페이스 구성에 따라 루트에만 있을 수 있다. `git status --short`로 실제 변경 파일을 확인해 add 대상을 맞춘다.

**보고 항목**(다음 Task가 사용): 해석된 flutter_quill/markdown_quill 버전, **`showStrikeThrough` ON/OFF 결론과 근거 출력**.

---

## Task 2: `DpRichEditor` 위젯 + localizations 배선

**Repo:** `devpath-frontend`

**Files:**
- Create: `apps/web/lib/src/features/community/presentation/widgets/rich_editor.dart`
- Modify: `apps/web/lib/src/app/app.dart`
- Test: `apps/web/test/features/community/rich_editor_test.dart`

**Interfaces:**
- Consumes: 없음(Task 1의 헬퍼는 여기서 쓰지 않는다).
- Produces: `class DpRichEditor extends StatelessWidget` — 생성자 `const DpRichEditor({super.key, required QuillController controller, bool enabled = true, double height = 260})`. Task 3·4가 본문 입력 위젯으로 사용한다.

- [ ] **Step 1: 실패 테스트 작성**

Create `apps/web/test/features/community/rich_editor_test.dart`:

```dart
import 'package:devpath_web/src/features/community/presentation/widgets/rich_editor.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(QuillController controller) => MaterialApp(
  theme: DpTheme.light(),
  localizationsDelegates: const [
    DefaultCupertinoLocalizations.delegate,
    DefaultMaterialLocalizations.delegate,
    DefaultWidgetsLocalizations.delegate,
    FlutterQuillLocalizations.delegate,
  ],
  home: Scaffold(body: DpRichEditor(controller: controller)),
);

void main() {
  testWidgets('툴바와 에디터를 렌더한다', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final c = QuillController.basic();
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    expect(find.byType(QuillSimpleToolbar), findsOneWidget);
    expect(find.byType(QuillEditor), findsOneWidget);
  });

  testWidgets('마크다운 비표현 서식 버튼을 노출하지 않는다', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final c = QuillController.basic();
    addTearDown(c.dispose);

    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    // 색/폰트/정렬/검색 등은 화이트리스트에서 제외됐다.
    expect(find.byType(QuillToolbarColorButton), findsNothing);
    expect(find.byType(QuillToolbarFontFamilyButton), findsNothing);
    expect(find.byType(QuillToolbarFontSizeButton), findsNothing);
    expect(find.byType(QuillToolbarSearchButton), findsNothing);
  });

  testWidgets('enabled=false 면 입력을 흡수한다', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final c = QuillController.basic();
    addTearDown(c.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        localizationsDelegates: const [
          DefaultCupertinoLocalizations.delegate,
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        home: Scaffold(
          body: DpRichEditor(controller: c, enabled: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final absorber = tester.widget<AbsorbPointer>(
      find.descendant(
        of: find.byType(DpRichEditor),
        matching: find.byType(AbsorbPointer),
      ).first,
    );
    expect(absorber.absorbing, isTrue);
  });
}
```

**주의**: `QuillToolbarColorButton` 등 버튼 타입명이 실제 export와 다르면 **분석 에러로 즉시 드러난다**. 그때는 `flutter_quill` 소스에서 실제 타입명을 확인해 맞춘다(추측으로 다른 이름을 넣지 않는다). 타입이 export되지 않는다면 해당 단언을 **툴바 설정 객체 검증**으로 대체한다 — 즉 `tester.widget<QuillSimpleToolbar>(find.byType(QuillSimpleToolbar)).config.showColorButton` 이 `false` 임을 확인한다.

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
cd D:/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/community/rich_editor_test.dart
```

Expected: FAIL — `rich_editor.dart` 미존재로 컴파일 에러.

- [ ] **Step 3: `DpRichEditor` 구현**

Create `apps/web/lib/src/features/community/presentation/widgets/rich_editor.dart`:

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// 커뮤니티 작성 본문용 WYSIWYG 에디터(웹 전용).
///
/// 저장 계약은 마크다운(`bodyMd`)이므로 툴바는 **마크다운으로 무손실 표현
/// 가능한 서식만** 노출한다(색·폰트·밑줄·정렬 등은 비활성). 변환은
/// `quillToMarkdown` 이 담당한다.
class DpRichEditor extends StatelessWidget {
  const DpRichEditor({
    super.key,
    required this.controller,
    this.enabled = true,
    this.height = 260,
  });

  final QuillController controller;

  /// 제출 중 입력 잠금.
  final bool enabled;

  /// 에디터 영역 고정 높이(내부 스크롤).
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    return AbsorbPointer(
      absorbing: !enabled,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(DpRadius.input),
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
                showStrikeThrough: false,
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
            const Divider(height: 1),
            SizedBox(
              height: height,
              child: Padding(
                padding: const EdgeInsets.all(DpSpacing.sm),
                child: QuillEditor.basic(controller: controller),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**`showStrikeThrough`는 Task 1 Step 4 실측 결과를 반영한다** — 마크다운 `~~…~~`로 변환됐다면 `true`로 바꾸고, 아니면 위처럼 `false`를 유지한다.

**dp_design 토큰은 2026-08-01 실측으로 확정됐다**(`packages/dp_design/lib/src/theme/`): `DpColors.border`·`DpColors.textSecondary` 존재(`context.dpColors`로 접근), `DpSpacing.{xs:4, sm:8, md:12, lg:16}` 존재, **`DpRadius`는 `{chip, button, card, input, dialog}`뿐이라 `DpRadius.sm`은 없다** — 입력 요소이므로 `DpRadius.input`을 쓴다.

- [ ] **Step 4: 테스트 실행 — 통과 확인**

```bash
cd D:/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/community/rich_editor_test.dart
```

Expected: PASS (3 tests).

`FlutterQuillLocalizations` 관련 예외가 나면 테스트 host의 delegate 배선을 확인한다(Step 1 코드에 이미 포함돼 있다).

- [ ] **Step 5: 앱 루트에 localizations 배선**

Modify `apps/web/lib/src/app/app.dart` — `MaterialApp.router`에 `localizationsDelegates`를 추가한다(현재 이 항목이 아예 없다):

```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/theme_provider.dart';
import 'router.dart';

/// web 앱 루트: 라우터 + 전역 테마(라이트/다크 토글, DD6).
class DevPathWebApp extends ConsumerWidget {
  const DevPathWebApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'DevPath AI',
      debugShowCheckedModeBanner: false,
      theme: DpTheme.light(),
      darkTheme: DpTheme.dark(),
      themeMode: mode,
      // flutter_quill 11.x 는 이 delegate 등록을 요구한다(에디터 툴팁·다이얼로그).
      localizationsDelegates: const [
        DefaultCupertinoLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}
```

- [ ] **Step 6: 전체 스위트로 회귀 확인**

```bash
cd D:/workspace/dpa/devpath-frontend/apps/web && flutter test
```

Expected: 전부 PASS. 이 시점에는 작성 페이지를 아직 안 건드렸으므로 기존 테스트가 깨지면 안 된다. 깨진다면 원인이 delegate 추가이므로 로그를 읽고 근본 원인을 규명한다(임시방편 금지).

- [ ] **Step 7: 게이트 + 커밋**

```bash
cd D:/workspace/dpa/devpath-frontend && melos run format
cd D:/workspace/dpa/devpath-frontend && melos run analyze
git -C D:/workspace/dpa/devpath-frontend add apps/web/lib/src/features/community/presentation/widgets/rich_editor.dart apps/web/lib/src/app/app.dart apps/web/test/features/community/rich_editor_test.dart
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(web): DpRichEditor(제약 툴바) + flutter_quill localizations 배선"
```

---

## Task 3: 일반글 작성 화면 통합

**Repo:** `devpath-frontend`

**Files:**
- Modify: `apps/web/lib/src/features/community/presentation/post_create_page.dart`
- Test: `apps/web/test/features/community/post_create_page_test.dart` (기존 파일 갱신)

**Interfaces:**
- Consumes: `quillToMarkdown(QuillController)` (Task 1), `DpRichEditor({required controller, enabled, height})` (Task 2).
- Produces: `PostCreatePage({super.key, required String board, @visibleForTesting QuillController? bodyController})` — 테스트가 본문 문서를 결정적으로 주입하기 위한 선택적 파라미터. 라우터 호출부(`board`만 전달)는 불변이다.

**배경(왜 controller 주입인가):** 기존 테스트는 `tester.enterText(find.byType(TextField).at(1), '본문 내용')`으로 본문을 넣었다. 본문이 `QuillEditor`가 되면 `TextField`가 아니므로 이 방식이 성립하지 않고, flutter_quill은 `EditableText`를 쓰지 않아 `enterText`가 동작한다는 보장이 없다. 테스트가 본문을 결정적으로 제어하도록 controller를 주입한다.

- [ ] **Step 1: 실패 테스트로 갱신**

Rewrite `apps/web/test/features/community/post_create_page_test.dart`:

```dart
import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/presentation/post_create_page.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

CommunityPostDetail _created(int id, String board) =>
    CommunityPostDetail(id: id, boardType: board, title: '새 글', bodyMd: '본문');

/// 본문 문서를 미리 채운 컨트롤러(에디터 입력 시뮬레이션 대체).
QuillController _bodyWith(String text) {
  final doc = Document()..insert(0, text);
  return QuillController(
    document: doc,
    selection: const TextSelection.collapsed(offset: 0),
  );
}

Widget _host(
  ProviderContainer c, {
  String board = 'FREE',
  QuillController? bodyController,
}) {
  final router = GoRouter(
    initialLocation: '/community/new/post',
    routes: [
      GoRoute(
        path: '/community/new/post',
        builder: (_, _) =>
            PostCreatePage(board: board, bodyController: bodyController),
      ),
      GoRoute(
        path: '/community/post/:id',
        builder: (_, state) => Text('상세: ${state.pathParameters['id']}'),
      ),
    ],
  );
  return UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(
      theme: DpTheme.light(),
      localizationsDelegates: const [
        DefaultCupertinoLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      routerConfig: router,
    ),
  );
}

void _wideView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('FREE 프리셋: 제목/태그 TextField + 본문 에디터 + 게시 버튼 렌더', (tester) async {
    _wideView(tester);
    final c = ProviderContainer(
      overrides: [
        postCreateProvider.overrideWithValue(
          ({
            required boardType,
            required title,
            required bodyMd,
            required tags,
          }) async => _created(30, boardType),
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    expect(find.text('자유글 작성'), findsOneWidget); // AppBar
    // 본문이 QuillEditor 로 바뀌어 TextField 는 제목/태그 2개만 남는다.
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.byType(QuillEditor), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '게시'), findsOneWidget);
  });

  testWidgets('FEEDBACK 프리셋: AppBar 라벨이 "피드백 요청"', (tester) async {
    _wideView(tester);
    final c = ProviderContainer(
      overrides: [
        postCreateProvider.overrideWithValue(
          ({
            required boardType,
            required title,
            required bodyMd,
            required tags,
          }) async => _created(31, boardType),
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c, board: 'FEEDBACK'));
    await tester.pumpAndSettle();

    expect(find.text('피드백 요청'), findsOneWidget);
  });

  testWidgets('제목·본문 입력 후 게시하면 postCreate(boardType) 호출 + 상세로 이동', (
    tester,
  ) async {
    _wideView(tester);
    String? seenBoard, seenTitle, seenBody;
    List<String>? seenTags;
    final body = _bodyWith('본문 내용');
    addTearDown(body.dispose);
    final c = ProviderContainer(
      overrides: [
        postCreateProvider.overrideWithValue(({
          required String boardType,
          required String title,
          required String bodyMd,
          required List<String> tags,
        }) async {
          seenBoard = boardType;
          seenTitle = title;
          seenBody = bodyMd;
          seenTags = tags;
          return _created(30, boardType);
        }),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c, bodyController: body));
    await tester.pumpAndSettle();

    // 인덱스 재배치: 0=제목, 1=태그 (본문은 controller 주입)
    await tester.enterText(find.byType(TextField).at(0), '새 자유글');
    await tester.enterText(find.byType(TextField).at(1), 'dart, async');

    await tester.tap(find.widgetWithText(FilledButton, '게시'));
    await tester.pumpAndSettle();

    expect(seenBoard, 'FREE');
    expect(seenTitle, '새 자유글');
    expect(seenBody, '본문 내용'); // 평문은 마크다운 변환 후에도 동일
    expect(seenTags, ['dart', 'async']);
    expect(find.text('상세: 30'), findsOneWidget);
  });

  testWidgets('제목/본문 비면 게시하지 않고 안내', (tester) async {
    _wideView(tester);
    var createCalls = 0;
    final c = ProviderContainer(
      overrides: [
        postCreateProvider.overrideWithValue(({
          required String boardType,
          required String title,
          required String bodyMd,
          required List<String> tags,
        }) async {
          createCalls++;
          return _created(30, boardType);
        }),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '게시'));
    await tester.pumpAndSettle();

    expect(createCalls, 0);
    expect(find.textContaining('제목과 본문'), findsOneWidget);
  });

  testWidgets('본문에 서식이 있으면 마크다운으로 변환돼 저장된다', (tester) async {
    _wideView(tester);
    String? seenBody;
    final doc = Document()..insert(0, '굵게');
    doc.format(0, 2, Attribute.bold);
    final body = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
    addTearDown(body.dispose);
    final c = ProviderContainer(
      overrides: [
        postCreateProvider.overrideWithValue(({
          required String boardType,
          required String title,
          required String bodyMd,
          required List<String> tags,
        }) async {
          seenBody = bodyMd;
          return _created(30, boardType);
        }),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c, bodyController: body));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '제목');
    await tester.tap(find.widgetWithText(FilledButton, '게시'));
    await tester.pumpAndSettle();

    // Task 1 Step 4 관찰값(굵게)과 동일해야 한다.
    expect(seenBody, '<STEP4_OBSERVED_BOLD>');
  });
}
```

`<STEP4_OBSERVED_BOLD>`는 Task 1에서 관찰한 실제 문자열로 채운다.

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
cd D:/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/community/post_create_page_test.dart
```

Expected: FAIL — `PostCreatePage`에 `bodyController` 파라미터가 없어 컴파일 에러.

- [ ] **Step 3: 페이지 구현**

Modify `apps/web/lib/src/features/community/presentation/post_create_page.dart`:

```dart
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/community_source.dart';
import 'widgets/quill_markdown.dart';
import 'widgets/rich_editor.dart';

/// 일반 게시글(FREE/FEEDBACK) 작성. `POST /community/posts {boardType,title,bodyMd,tags[]}`
/// → 상세로 이동. 본문은 WYSIWYG 에디터로 입력하고 게시 시 마크다운으로 변환한다.
class PostCreatePage extends ConsumerStatefulWidget {
  const PostCreatePage({
    super.key,
    required this.board,
    @visibleForTesting this.bodyController,
  });

  /// 보드 프리셋 — 'FREE'(자유) | 'FEEDBACK'(피드백 요청).
  final String board;

  /// 테스트에서 본문 문서를 결정적으로 주입하기 위한 선택 파라미터.
  /// null 이면 페이지가 직접 생성·해제한다.
  @visibleForTesting
  final QuillController? bodyController;

  @override
  ConsumerState<PostCreatePage> createState() => _PostCreatePageState();
}

class _PostCreatePageState extends ConsumerState<PostCreatePage> {
  final _titleCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  late final QuillController _bodyController;
  late final bool _ownsBodyController;
  bool _submitting = false;

  bool get _isFeedback => widget.board == 'FEEDBACK';
  String get _pageTitle => _isFeedback ? '피드백 요청' : '자유글 작성';

  @override
  void initState() {
    super.initState();
    final injected = widget.bodyController;
    _ownsBodyController = injected == null;
    _bodyController = injected ?? QuillController.basic();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _tagsCtrl.dispose();
    if (_ownsBodyController) _bodyController.dispose();
    super.dispose();
  }

  List<String> _parseTags() => _tagsCtrl.text
      .split(RegExp(r'[,\s]+'))
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final isBodyEmpty = _bodyController.document.toPlainText().trim().isEmpty;
    if (title.isEmpty || isBodyEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('제목과 본문을 입력해 주세요.')));
      return;
    }
    final body = quillToMarkdown(_bodyController).trim();
    setState(() => _submitting = true);
    try {
      final created = await ref.read(postCreateProvider)(
        boardType: widget.board,
        title: title,
        bodyMd: body,
        tags: _parseTags(),
      );
      if (mounted) context.go('/community/post/${created.id}');
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_pageTitle)),
      body: ListView(
        padding: const EdgeInsets.all(DpSpacing.lg),
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
          const SizedBox(height: DpSpacing.md),
          Text(
            _isFeedback
                ? '리뷰받고 싶은 코드/프로젝트와 궁금한 점을 적어주세요'
                : '나누고 싶은 이야기를 적어주세요',
            style: TextStyle(color: context.dpColors.textSecondary),
          ),
          const SizedBox(height: DpSpacing.xs),
          DpRichEditor(controller: _bodyController, enabled: !_submitting),
          const SizedBox(height: DpSpacing.md),
          TextField(
            controller: _tagsCtrl,
            enabled: !_submitting,
            decoration: const InputDecoration(
              labelText: '태그',
              hintText: '쉼표 또는 공백으로 구분 (예: dart, flutter)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: DpSpacing.lg),
          FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: const Icon(DpIcons.send, size: 18),
            label: Text(_submitting ? '게시 중…' : '게시'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 테스트 실행 — 통과 확인**

```bash
cd D:/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/community/post_create_page_test.dart
```

Expected: PASS (5 tests).

- [ ] **Step 5: 게이트 + 커밋**

```bash
cd D:/workspace/dpa/devpath-frontend && melos run format
cd D:/workspace/dpa/devpath-frontend && melos run analyze
git -C D:/workspace/dpa/devpath-frontend add apps/web/lib/src/features/community/presentation/post_create_page.dart apps/web/test/features/community/post_create_page_test.dart
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(web): 일반글 작성 본문을 WYSIWYG 에디터로 전환"
```

---

## Task 4: 질문 작성 화면 통합

**Repo:** `devpath-frontend`

**Files:**
- Modify: `apps/web/lib/src/features/community/presentation/question_create_page.dart`
- Test: `apps/web/test/features/community/question_create_page_test.dart` (기존 파일 갱신)

**Interfaces:**
- Consumes: `quillToMarkdown(QuillController)` (Task 1), `DpRichEditor` (Task 2), Task 3에서 확립한 `bodyController` 주입 패턴.
- Produces: `QuestionCreatePage({super.key, @visibleForTesting QuillController? bodyController})`. 라우터 호출부(`const QuestionCreatePage()`)는 불변이다.

**주의:** 이 페이지는 유사질문 디바운스(`_onTitleChanged`)와 `LcsContextCard`를 함께 가진다. **본문 입력 외 로직은 한 줄도 바꾸지 않는다.**

- [ ] **Step 1: 실패 테스트로 갱신**

Rewrite `apps/web/test/features/community/question_create_page_test.dart`. 기존 5개 테스트의 의도를 보존하되 본문 입력만 controller 주입으로 바꾸고, host에 delegate를 추가한다:

```dart
import 'package:devpath_web/src/features/community/data/community_source.dart';
import 'package:devpath_web/src/features/community/data/lcs_source.dart';
import 'package:devpath_web/src/features/community/presentation/question_create_page.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

CommunityQuestionDetail _created(int id) =>
    CommunityQuestionDetail(id: id, title: '새 질문', bodyMd: '본문');

QuillController _bodyWith(String text) {
  final doc = Document()..insert(0, text);
  return QuillController(
    document: doc,
    selection: const TextSelection.collapsed(offset: 0),
  );
}

LcsDraft _draft() => LcsDraft(
  draftId: 'snap_test',
  expiresAt: DateTime(2026, 6, 26, 23, 59),
  content: const {
    'recent_activity': [
      {'language': 'dart', 'status': 'SUCCESS'},
    ],
  },
  fieldsAvailable: const ['recent_activity'],
);

Widget _host(ProviderContainer c, {QuillController? bodyController}) {
  final router = GoRouter(
    initialLocation: '/community/new',
    routes: [
      GoRoute(
        path: '/community/new',
        builder: (_, _) => QuestionCreatePage(bodyController: bodyController),
      ),
      GoRoute(
        path: '/community/:id',
        builder: (_, state) => Text('상세: ${state.pathParameters['id']}'),
      ),
    ],
  );
  return UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(
      theme: DpTheme.light(),
      localizationsDelegates: const [
        DefaultCupertinoLocalizations.delegate,
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      routerConfig: router,
    ),
  );
}

/// 에디터·맥락 카드가 폼 높이를 늘리므로 모든 테스트에 큰 화면을 준다.
void _wideView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('제목 입력(디바운스) 시 유사질문 패널을 안내한다', (tester) async {
    _wideView(tester);
    final c = ProviderContainer(
      overrides: [
        similarQuestionsProvider.overrideWithValue(
          (q) async => [const SimilarQuestion(questionId: 2, title: '비슷한 질문')],
        ),
        questionCreateProvider.overrideWithValue(
          ({required title, required bodyMd, required tags}) async =>
              _created(99),
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'async');
    await tester.pump(const Duration(milliseconds: 450)); // 디바운스 발화
    await tester.pumpAndSettle();

    expect(find.text('💡 비슷한 질문'), findsOneWidget);
    expect(find.text('비슷한 질문'), findsOneWidget);
  });

  testWidgets('제목·본문 입력 후 게시하면 작성 API 호출 + 상세로 이동', (tester) async {
    _wideView(tester);
    String? seenTitle, seenBody;
    List<String>? seenTags;
    final body = _bodyWith('본문 내용');
    addTearDown(body.dispose);
    final c = ProviderContainer(
      overrides: [
        similarQuestionsProvider.overrideWithValue((q) async => const []),
        questionCreateProvider.overrideWithValue(({
          required String title,
          required String bodyMd,
          required List<String> tags,
        }) async {
          seenTitle = title;
          seenBody = bodyMd;
          seenTags = tags;
          return _created(99);
        }),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c, bodyController: body));
    await tester.pumpAndSettle();

    // 인덱스 재배치: 0=제목, 1=태그 (본문은 controller 주입)
    await tester.enterText(find.byType(TextField).at(0), '새 질문');
    await tester.enterText(find.byType(TextField).at(1), 'dart, async');

    await tester.tap(find.widgetWithText(FilledButton, '질문 게시'));
    await tester.pumpAndSettle();

    expect(seenTitle, '새 질문');
    expect(seenBody, '본문 내용');
    expect(seenTags, ['dart', 'async']);
    expect(find.text('상세: 99'), findsOneWidget); // 작성 후 상세 이동
  });

  testWidgets('제목/본문 비면 게시하지 않고 안내', (tester) async {
    _wideView(tester);
    var createCalls = 0;
    final c = ProviderContainer(
      overrides: [
        similarQuestionsProvider.overrideWithValue((q) async => const []),
        questionCreateProvider.overrideWithValue(({
          required String title,
          required String bodyMd,
          required List<String> tags,
        }) async {
          createCalls++;
          return _created(99);
        }),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '질문 게시'));
    await tester.pumpAndSettle();

    expect(createCalls, 0);
    expect(find.textContaining('제목과 본문'), findsOneWidget);
  });

  testWidgets('맥락 카드: 토글을 켜면 draft 미리보기 필드를 노출', (tester) async {
    _wideView(tester);
    final c = ProviderContainer(
      overrides: [
        similarQuestionsProvider.overrideWithValue((q) async => const []),
        questionCreateProvider.overrideWithValue(
          ({required title, required bodyMd, required tags}) async =>
              _created(99),
        ),
        lcsDraftProvider.overrideWithValue(
          ({List<String> requestedFields = const [], int? contentId}) async =>
              _draft(),
        ),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    // fieldsAvailable(recent_activity) → 한글 라벨 칩
    expect(find.text('최근 활동'), findsOneWidget);
  });

  testWidgets('맥락 첨부 후 게시하면 commit(questionId·visibility)을 호출', (tester) async {
    _wideView(tester);
    int? seenAttachedTo;
    String? seenDraftId, seenVisibility;
    final body = _bodyWith('본문 내용');
    addTearDown(body.dispose);
    final c = ProviderContainer(
      overrides: [
        similarQuestionsProvider.overrideWithValue((q) async => const []),
        questionCreateProvider.overrideWithValue(
          ({
            required String title,
            required String bodyMd,
            required List<String> tags,
          }) async => _created(99),
        ),
        lcsDraftProvider.overrideWithValue(
          ({List<String> requestedFields = const [], int? contentId}) async =>
              _draft(),
        ),
        lcsCommitProvider.overrideWithValue(({
          required String draftId,
          required int attachedToId,
          required String visibility,
        }) async {
          seenDraftId = draftId;
          seenAttachedTo = attachedToId;
          seenVisibility = visibility;
          return 7;
        }),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(_host(c, bodyController: body));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch)); // 맥락 첨부 on → draft 로드
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '새 질문');
    await tester.tap(find.widgetWithText(FilledButton, '질문 게시'));
    await tester.pumpAndSettle();

    expect(seenDraftId, 'snap_test');
    expect(seenAttachedTo, 99); // 게시 응답 questionId
    expect(seenVisibility, 'answerers_only'); // 기본 노출범위
  });
}
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
cd D:/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/community/question_create_page_test.dart
```

Expected: FAIL — `QuestionCreatePage`에 `bodyController` 파라미터가 없어 컴파일 에러.

- [ ] **Step 3: 페이지 구현**

Modify `apps/web/lib/src/features/community/presentation/question_create_page.dart` — 아래 5곳만 바꾸고 유사질문·LCS 로직은 그대로 둔다.

1) import 추가:

```dart
import 'package:flutter_quill/flutter_quill.dart';

import 'widgets/quill_markdown.dart';
import 'widgets/rich_editor.dart';
```

2) 위젯 생성자에 선택 파라미터 추가:

```dart
class QuestionCreatePage extends ConsumerStatefulWidget {
  const QuestionCreatePage({super.key, @visibleForTesting this.bodyController});

  /// 테스트에서 본문 문서를 결정적으로 주입하기 위한 선택 파라미터.
  /// null 이면 페이지가 직접 생성·해제한다.
  @visibleForTesting
  final QuillController? bodyController;

  @override
  ConsumerState<QuestionCreatePage> createState() =>
      _QuestionCreatePageState();
}
```

3) State의 `_bodyCtrl` 필드를 교체하고 `initState`를 추가:

```dart
  final _titleCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  late final QuillController _bodyController;
  late final bool _ownsBodyController;

  @override
  void initState() {
    super.initState();
    final injected = widget.bodyController;
    _ownsBodyController = injected == null;
    _bodyController = injected ?? QuillController.basic();
  }
```

4) `dispose` 갱신:

```dart
  @override
  void dispose() {
    _debounce?.cancel();
    _titleCtrl.dispose();
    _tagsCtrl.dispose();
    if (_ownsBodyController) _bodyController.dispose();
    super.dispose();
  }
```

5) `_submit()`의 본문 취득·빈 검사 교체:

```dart
    final title = _titleCtrl.text.trim();
    final isBodyEmpty = _bodyController.document.toPlainText().trim().isEmpty;
    if (title.isEmpty || isBodyEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('제목과 본문을 입력해 주세요.')));
      return;
    }
    final body = quillToMarkdown(_bodyController).trim();
```

6) `build()`의 본문 `TextField`(현재 `labelText: '본문 (Markdown)'`) 블록을 교체:

```dart
          const SizedBox(height: DpSpacing.md),
          Text(
            '상황과 시도한 내용을 적어주세요',
            style: TextStyle(color: c.textSecondary),
          ),
          const SizedBox(height: DpSpacing.xs),
          DpRichEditor(controller: _bodyController, enabled: !_submitting),
```

(`c`는 이 `build()`가 이미 보유한 `context.dpColors`다.)

- [ ] **Step 4: 테스트 실행 — 통과 확인**

```bash
cd D:/workspace/dpa/devpath-frontend/apps/web && flutter test test/features/community/question_create_page_test.dart
```

Expected: PASS (5 tests).

- [ ] **Step 5: 게이트 + 커밋**

```bash
cd D:/workspace/dpa/devpath-frontend && melos run format
cd D:/workspace/dpa/devpath-frontend && melos run analyze
git -C D:/workspace/dpa/devpath-frontend add apps/web/lib/src/features/community/presentation/question_create_page.dart apps/web/test/features/community/question_create_page_test.dart
git -C D:/workspace/dpa/devpath-frontend commit -m "feat(web): 질문 작성 본문을 WYSIWYG 에디터로 전환"
```

---

## Task 5: 전체 검증 + 한글 IME 브라우저 스모크(필수 AC) + PR

**Repo:** `devpath-frontend`

**Files:**
- Create: `docs/superpowers/reports/2026-08-01-rich-text-editor-smoke.md`

**Interfaces:**
- Consumes: Task 1~4 전부.
- Produces: 스모크 리포트 + `develop` PR. IME 실패 시 **폴백 전환 판단 근거**.

- [ ] **Step 1: 모노레포 전체 게이트**

```bash
cd D:/workspace/dpa/devpath-frontend && melos run format
cd D:/workspace/dpa/devpath-frontend && melos run analyze
cd D:/workspace/dpa/devpath-frontend && melos run test
```

Expected: 5개 패키지 전부 PASS. 실패하면 로그를 읽어 근본 원인을 규명한다(CLAUDE.md 규칙 3).

- [ ] **Step 2: 웹 빌드 스모크**

flutter_quill 도입으로 번들이 커지므로 빌드가 실제로 성공하는지 확인한다.

```bash
cd D:/workspace/dpa/devpath-frontend/apps/web && flutter build web
```

Expected: 성공. 출력의 번들 크기를 기록한다(도입 비용 근거).

- [ ] **Step 3: 브라우저 한글 IME 스모크 — 필수 AC**

```bash
cd D:/workspace/dpa/devpath-frontend/apps/web && flutter run -d chrome
```

브라우저에서 다음을 **직접 조작해** 확인하고, 각 항목의 결과를 기록한다:

1. `/community/new/post`(자유글 작성)로 이동
2. 본문 에디터에 **한글을 타이핑** — 조합 중 글자가 깨지거나 자모가 분리되지 않는지, 중복 입력이 없는지
3. 한글 텍스트를 드래그 선택 후 **굵게** 적용 — 서식이 즉시 보이는지
4. **제목(H1)·불릿 목록·인용·코드블록** 각각 적용 — 렌더 확인
5. 제목 입력 후 **게시** — 상세 화면에서 `DpMarkdown`이 서식을 올바로 렌더하는지
6. `/community/new` (질문 작성)에서 2~5 반복 + 유사질문 패널·맥락 카드가 여전히 동작하는지

**판정:**
- 2번(한글 IME)이 실패하면 → **이 접근을 채택하지 않는다.** 여기서 멈추고 spec §6 Fork 3 폴백(Approach A: 마크다운 툴바+프리뷰)으로 전환할지 사용자에게 보고·확인받는다. 실패 증상(자모 분리/중복 입력/조합 중 깨짐)을 구체적으로 기록한다.
- 2번이 통과하고 3~6 중 일부만 실패하면 → 해당 항목의 근본 원인을 규명해 수정하고 이 Step을 다시 수행한다.

- [ ] **Step 4: 스모크 리포트 작성**

Create `docs/superpowers/reports/2026-08-01-rich-text-editor-smoke.md`:

```markdown
# 서식 에디터(WYSIWYG) 검증 리포트 — 2026-08-01

## 패키지 해석 결과
- flutter_quill: <실측 버전>
- markdown_quill: <실측 버전>
- markdown(전이): <실측 버전>

## 변환 실측(Task 1)
| 서식 | 출력 마크다운 |
|---|---|
| 굵게 | <관찰값> |
| 기울임 | <관찰값> |
| 취소선 | <관찰값> → showStrikeThrough = <ON|OFF> |
| H1/H2 | <관찰값> |
| 불릿/번호 | <관찰값> |
| 인용 | <관찰값> |
| 코드블록/인라인코드 | <관찰값> |
| 링크 | <관찰값> |

## 자동 검증
- `melos run format` / `analyze` / `test`: <결과>
- `flutter build web`: <성공 여부 + 번들 크기>

## 브라우저 한글 IME 스모크 (필수 AC)
| 항목 | 결과 | 비고 |
|---|---|---|
| 한글 타이핑(조합) | <PASS/FAIL> | |
| 굵게 적용 | <PASS/FAIL> | |
| 제목/목록/인용/코드블록 | <PASS/FAIL> | |
| 게시 → 상세 마크다운 렌더 | <PASS/FAIL> | |
| 질문 작성(유사질문·맥락카드 회귀) | <PASS/FAIL> | |

**판정:** <채택 | Fork 3 폴백 전환>
```

- [ ] **Step 5: 커밋 + push + PR**

```bash
cd D:/workspace/dpa/devpath-frontend && melos run format
git -C D:/workspace/dpa/devpath-frontend add docs/superpowers/reports/2026-08-01-rich-text-editor-smoke.md
git -C D:/workspace/dpa/devpath-frontend commit -m "docs(report): 서식 에디터 변환 실측·한글 IME 스모크 리포트"
git -C D:/workspace/dpa/devpath-frontend push origin feat/rich-text-editor
```

PR 생성(base = `develop`, main 직접 금지):

```bash
gh pr create --repo DevPathAi/devpath-frontend --base develop --head feat/rich-text-editor \
  --title "feat(web): 커뮤니티 작성 본문 WYSIWYG 에디터(저장은 마크다운 유지)" \
  --body "$(cat <<'BODY'
## 요약
커뮤니티 작성 화면 2개(일반글·질문)의 본문 입력을 flutter_quill 기반 WYSIWYG 에디터로 전환했다. 저장은 기존과 동일한 마크다운(`bodyMd`)이라 **백엔드·dp_core·shared·상세 렌더는 무변경**이다.

## 변경
- `apps/web`에 `flutter_quill`·`markdown_quill` 도입(다른 앱/패키지 무영향)
- `quillToMarkdown` 변환 헬퍼 + 단위 테스트(실제 출력 실측으로 기대값 고정)
- `DpRichEditor` — 마크다운 무손실 서식만 노출하는 제약 툴바
- `app.dart`에 `FlutterQuillLocalizations.delegate` 배선(flutter_quill 11 요구)
- 작성 페이지 2개 통합 + 기존 위젯 테스트 인덱스 재배치

## 검증
- `melos run format` / `analyze` / `test` green
- `flutter build web` 성공
- 브라우저 한글 IME 스모크: 리포트 `docs/superpowers/reports/2026-08-01-rich-text-editor-smoke.md`

🤖 Generated with [Claude Code](https://claude.com/claude-code)
BODY
)"
```

- [ ] **Step 6: CI green 확인 후 사용자 승인 대기**

```bash
gh pr checks --repo DevPathAi/devpath-frontend <PR번호> --watch
```

CI가 green이면 **사용자에게 보고하고 머지 승인을 받는다. 임의 머지 금지.**

---

## Self-Review

**1. spec 커버리지**

| spec 항목 | 담당 Task |
|---|---|
| §5.1 패키지 도입 + 버전 실측 + `markdown` 직접 의존 제외 | Task 1 Step 2 |
| §5.2 `DpRichEditor` 위치·구성 | Task 2 Step 3 |
| §5.2 툴바 화이트리스트 전체 열거 | Global Constraints + Task 2 Step 3 |
| §5.2 `showStrikeThrough` 미확정 → 실측 결정 | Task 1 Step 4 → Task 2 Step 3 |
| §5.3 `quillToMarkdown` 헬퍼 | Task 1 Step 7 |
| §5.3 작성화면 2개 통합(빈 검사 포함) | Task 3·4 |
| §5.4 localizations(앱 + 테스트 host) | Task 2 Step 5 + Task 3·4 테스트 host |
| §7 단위 테스트(변환) | Task 1 Step 5 |
| §7 위젯 테스트(DpRichEditor) | Task 2 Step 1 |
| §7 기존 테스트 인덱스 재배치 | Task 3 Step 1 · Task 4 Step 1 |
| §7 브라우저 한글 IME 스모크(필수 AC) | Task 5 Step 3 |
| §7 게이트 + `flutter build web` | Task 5 Step 1·2 |
| §6 Fork 3 폴백 판단 | Task 5 Step 3 판정 |
| §8 브랜치·PR | Task 1 Step 1 · Task 5 Step 5 |

누락 없음.

**2. 플레이스홀더 점검**

의도적으로 남긴 자리표시자는 `<STEP4_OBSERVED_*>` 뿐이며, 이는 **Task 1 Step 4에서 실제 관찰한 값으로 채우도록 절차가 지정된** 실측 산출물이다(추측 금지 규칙의 귀결). 그 외 모든 코드 블록은 실행 가능한 완성 코드다.

**3. 타입 일관성**

- `quillToMarkdown(QuillController) → String` — Task 1 정의, Task 3·4에서 동일 시그니처로 호출.
- `DpRichEditor({required QuillController controller, bool enabled, double height})` — Task 2 정의, Task 3·4에서 `controller`·`enabled`만 사용(둘 다 정의된 파라미터).
- `bodyController` 선택 파라미터 — Task 3에서 도입, Task 4에서 동일 이름·타입(`QuillController?`)으로 반복.
- `_ownsBodyController` 소유권 플래그 — Task 3·4 동일 규칙(주입받으면 dispose하지 않음. 테스트가 `addTearDown(body.dispose)`로 해제).

**4. 알려진 불확실성(구현 중 실측으로 해소, 각 Task에 대응 지시 포함)**

- markdown_quill의 정확한 출력 문자열 → Task 1 Step 4에서 실측.
- `Document.format` 블록 속성 오프셋 → Task 1 Step 4에서 예외 시 조정 지시.
- `QuillToolbar*Button` 타입 export 여부 → Task 2 Step 1에 대체 검증(config 필드 확인) 명시.
- ~~dp_design 토큰명~~ → **해소**: 2026-08-01 실측으로 `DpRadius.input`·`DpSpacing.{xs,sm,md,lg}`·`c.border`·`c.textSecondary` 확정(Task 2 Step 3 반영 완료).
