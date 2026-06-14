# P4c — 콘텐츠 뷰어 + Sandbox(Monaco·실행 SSE·반응형) (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `apps/web`에 **콘텐츠 뷰어(CNT-001)** 와 **Sandbox(SBX-001)** 를 TDD로 구현한다 — 마크다운 콘텐츠 렌더, 그리고 **DD5 반응형 3/2/1 페인**(≥1240 에디터|실행로그|리뷰 / 1024–1239 2페인+로그접이 / <1024 세그먼트 탭) 안에 **Monaco 에디터(web 전용 임베드)** 와 **실행 로그 SSE 스트리밍**, `SANDBOX_UNAVAILABLE` 상태(편집 유지·실행만 비활성)를 얹는다.

**Architecture:** P4a 토대 위. Monaco는 `HtmlElementView`+`dart:ui_web` `registerViewFactory`로 임베드하되, web 전용 API가 VM 테스트(`flutter test`)를 깨지 않도록 **conditional import**(`stub`/`web`)로 격리 — 반응형 레이아웃·실행 컨트롤러는 Monaco 없이 결정적 테스트. 실행 로그는 `sandboxRunConnectProvider`(목=지연 emit / 실서버=`SseClient`)로 주입. AI 리뷰 패널은 P4c에서 **자리(placeholder)** 만, P4d에서 채운다.

**Tech Stack:** Flutter Web · flutter_riverpod 3.3 · go_router · `dart:ui_web`·`package:web`·`dart:js_interop`(Monaco) · dp_core(SseClient)·dp_design(DpMarkdown·DpSandboxUnavailable·상태위젯) · flutter_test.

---

> **선행:** P4a·P4b 구현 완료. **이 플랜은 REV-001(AI 코드리뷰)을 포함하지 않는다 → P4d.** P4c의 3페인 중 리뷰 칸은 placeholder.
> **참조:** 스펙 §1(D2 Monaco·B′)·§4(SBX 와이어프레임)·§9.3(반응형 SBX <1024/1024–1239/≥1240)·DD5. DESIGN.md §5(반응형)·§1(codeEditorBg·codeLogBg). 샘플(스펙 §7): `Flutter_SSE_실시간_스트림_구독`·`Flutter_재사용_다이얼로그_Confirm_Error`. Monaco/플랫폼뷰 API는 **Context7 검증**(`HtmlElementView`+`dart:ui_web` `platformViewRegistry`, `package:web`, `dart:js_interop`).
> **게이트(스펙 VERDICT):** DD5(SBX 반응형)는 아키텍처 영향 → 구현 전 `/plan-eng-review` 권장. 본 플랜 Task 3(반응형)·Task 4(Monaco)가 핵심.
> **YAGNI/추측 경계:** Monaco는 **index.html에 얇은 JS 셈(`createDevpathEditor`)** 을 두고 Dart는 그것만 호출(Monaco AMD 로더와 직접 씨름 금지). 실제 실행/언어/테마 옵션은 구현 시 조정. 콘텐츠/실행 응답 스키마는 외부 04_API_명세서로 정렬(본 플랜은 프로토 최소).

## P4c가 소비/수정하는 API

- P4a: `apiClientProvider`·`appConfigProvider`(providers), `routerProvider`(router), `webMockFixtures`(data).
- P4b: `SseEvent` 파싱 패턴, `pathSseConnectProvider`(참고 — 본 플랜은 `sandboxRunConnectProvider` 신설).
- dp_core(P2): `SseClient`·`SseEvent`·`MockSseSource`, `ApiClient.get`, `ApiException`/`ApiErrorCode`.
- dp_design(P3): `DpMarkdown`, `DpSandboxUnavailable`, `DpLoading`/`DpError`/`DpEmpty`, `DpIcons`, `DpSpacing`, `context.dpColors`(codeLogBg 등).

---

## File Structure (P4c에서 생성/수정)

```
apps/web/web/index.html                                       # (수정) Monaco CDN + createDevpathEditor 셈 — Task 4
apps/web/pubspec.yaml                                         # (수정) web 패키지 — Task 4
apps/web/lib/src/
├─ data/web_mock_fixtures.dart                                # (수정) GET /contents/:id — Task 1
├─ app/router.dart                                            # (수정) /content/:id·/sandbox 라우트 — Task 1·6
└─ features/
   ├─ content/
   │  ├─ application/content_controller.dart                  # 콘텐츠 로드 — Task 1
   │  ├─ state/content_state.dart                             # AsyncValue 대용 sealed — Task 1
   │  └─ presentation/content_page.dart                       # DpMarkdown — Task 1
   └─ sandbox/
      ├─ data/sandbox_run_source.dart                         # sandboxRunConnectProvider + 목 로그 — Task 5
      ├─ application/run_controller.dart                      # 실행 로그 SSE + SANDBOX_UNAVAILABLE — Task 5
      ├─ state/run_state.dart                                 # idle/running/done/unavailable — Task 5
      └─ presentation/
         ├─ sandbox_layout.dart                               # DD5 3/2/1 페인 — Task 3
         ├─ monaco_editor_view.dart                           # 공개 위젯(conditional import) — Task 4
         ├─ monaco_editor_view_stub.dart                      # 비웹/테스트 스텁 — Task 4
         ├─ monaco_editor_view_web.dart                       # 웹 구현(ui_web+web+js_interop) — Task 4
         └─ sandbox_page.dart                                 # 조립 + 라우트 — Task 6
apps/web/test/...                                             # 각 모듈 + 통합 스모크 — Task 1~7
```

---

## Task 1: CNT-001 콘텐츠 뷰어 (`DpMarkdown`)

**Files:**
- Create: `apps/web/lib/src/features/content/state/content_state.dart`, `.../application/content_controller.dart`, `.../presentation/content_page.dart`
- Modify: `apps/web/lib/src/data/web_mock_fixtures.dart`(`GET /contents/:id`), `apps/web/lib/src/app/router.dart`(`/content/:id`)
- Test: `apps/web/test/features/content/content_controller_test.dart`

- [ ] **Step 1: 실패 테스트**

Create `apps/web/test/features/content/content_controller_test.dart`:
```dart
import 'package:devpath_web/src/features/content/application/content_controller.dart';
import 'package:devpath_web/src/features/content/state/content_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('콘텐츠 로드 성공 시 마크다운을 담는다', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(contentControllerProvider.notifier).load('c1');

    final s = container.read(contentControllerProvider);
    expect(s, isA<ContentLoaded>());
    expect((s as ContentLoaded).markdown, contains('#'));
  });
}
```

- [ ] **Step 2: 실패 확인** — Run: `cd apps/web && flutter test test/features/content/content_controller_test.dart ; cd ../..` → FAIL

- [ ] **Step 3: 구현 — `content_state.dart`**

Create `apps/web/lib/src/features/content/state/content_state.dart`:
```dart
sealed class ContentState {
  const ContentState();
}

class ContentLoading extends ContentState {
  const ContentLoading();
}

class ContentLoaded extends ContentState {
  const ContentLoaded(this.markdown);
  final String markdown;
}

class ContentFailed extends ContentState {
  const ContentFailed(this.message);
  final String message;
}
```

- [ ] **Step 4: 구현 — `content_controller.dart`**

Create `apps/web/lib/src/features/content/application/content_controller.dart`:
```dart
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../state/content_state.dart';

class ContentController extends Notifier<ContentState> {
  @override
  ContentState build() => const ContentLoading();

  Future<void> load(String id) async {
    state = const ContentLoading();
    try {
      final json = await ref
          .read(apiClientProvider)
          .get<Map<String, dynamic>>('/contents/$id');
      state = ContentLoaded(json['markdown'] as String);
    } on ApiException catch (e) {
      state = ContentFailed(e.message);
    }
  }
}

final contentControllerProvider =
    NotifierProvider<ContentController, ContentState>(ContentController.new);
```

- [ ] **Step 5: 목 픽스처 추가**

`apps/web/lib/src/data/web_mock_fixtures.dart`의 `webMockFixtures`에 추가:
```dart
  'GET /contents/c1': (
    200,
    {
      'markdown': '# 비동기 기초\n\nDart의 `Future`와 `async`/`await`로 비동기 흐름을 다룹니다.\n\n```dart\nFuture<int> answer() async => 42;\n```\n'
    },
  ),
```

- [ ] **Step 6: 구현 — `content_page.dart` + 라우트**

Create `apps/web/lib/src/features/content/presentation/content_page.dart`:
```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/content_controller.dart';
import '../state/content_state.dart';

class ContentPage extends ConsumerStatefulWidget {
  const ContentPage({super.key, required this.contentId});
  final String contentId;

  @override
  ConsumerState<ContentPage> createState() => _ContentPageState();
}

class _ContentPageState extends ConsumerState<ContentPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(contentControllerProvider.notifier).load(widget.contentId));
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(contentControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('학습 콘텐츠'),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/sandbox'),
            icon: const Icon(Icons.code),
            label: const Text('실습'),
          ),
        ],
      ),
      body: switch (s) {
        ContentLoading() => const DpLoading(),
        ContentFailed(:final message) => DpError(
            message: message,
            onRetry: () =>
                ref.read(contentControllerProvider.notifier).load(widget.contentId),
          ),
        ContentLoaded(:final markdown) => SingleChildScrollView(
            padding: const EdgeInsets.all(DpSpacing.lg),
            child: DpMarkdown(data: markdown),
          ),
      },
    );
  }
}
```
> `Icons.code`는 임시 — DD3 준수 위해 `DpIcons`에 `code` 추가가 이상적이나, '실습' 라벨 동반이라 P4c는 텍스트 우선. (후속 정리)

`apps/web/lib/src/app/router.dart` ShellRoute에 라우트 추가(import 포함):
```dart
GoRoute(
  path: '/content/:id',
  builder: (_, state) => ContentPage(contentId: state.pathParameters['id']!),
),
```

- [ ] **Step 7: 통과 확인** — Run: `cd apps/web && flutter test test/features/content ; cd ../..` → PASS

- [ ] **Step 8: 커밋**
```bash
git add apps/web/lib/src/features/content apps/web/lib/src/data/web_mock_fixtures.dart apps/web/lib/src/app/router.dart apps/web/test/features/content
git commit -m "feat(web): 콘텐츠 뷰어(CNT-001, DpMarkdown)"
```

---

## Task 2: 실행 상태 모델 (`RunState`)

**Files:**
- Create: `apps/web/lib/src/features/sandbox/state/run_state.dart`
- Test: `apps/web/test/features/sandbox/run_state_test.dart`

- [ ] **Step 1: 실패 테스트**

Create `apps/web/test/features/sandbox/run_state_test.dart`:
```dart
import 'package:devpath_web/src/features/sandbox/state/run_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('append는 로그 라인을 누적한다', () {
    const s = RunRunning(logs: ['a']);
    expect(s.appended('b').logs, ['a', 'b']);
  });
}
```

- [ ] **Step 2: 실패 확인** — Run: `cd apps/web && flutter test test/features/sandbox/run_state_test.dart ; cd ../..` → FAIL

- [ ] **Step 3: 구현**

Create `apps/web/lib/src/features/sandbox/state/run_state.dart`:
```dart
sealed class RunState {
  const RunState();
}

class RunIdle extends RunState {
  const RunIdle();
}

class RunRunning extends RunState {
  const RunRunning({this.logs = const []});
  final List<String> logs;
  RunRunning appended(String line) => RunRunning(logs: [...logs, line]);
}

class RunDone extends RunState {
  const RunDone({this.logs = const []});
  final List<String> logs;
}

/// SANDBOX_UNAVAILABLE(503) — 실행만 비활성, 편집 유지(DD4/§9.2).
class RunUnavailable extends RunState {
  const RunUnavailable();
}
```

- [ ] **Step 4: 통과 확인** — Run: `cd apps/web && flutter test test/features/sandbox/run_state_test.dart ; cd ../..` → PASS

- [ ] **Step 5: 커밋**
```bash
git add apps/web/lib/src/features/sandbox/state apps/web/test/features/sandbox/run_state_test.dart
git commit -m "feat(web): Sandbox 실행 상태 모델(RunState)"
```

---

## Task 3: DD5 반응형 레이아웃 (`SandboxLayout`)

> Monaco 없이 슬롯(editor/log/review 위젯)을 받아 폭에 따라 3/2/1 페인 전환 — 결정적 위젯 테스트.

**Files:**
- Create: `apps/web/lib/src/features/sandbox/presentation/sandbox_layout.dart`
- Test: `apps/web/test/features/sandbox/sandbox_layout_test.dart`

- [ ] **Step 1: 실패 테스트(폭별 페인)**

Create `apps/web/test/features/sandbox/sandbox_layout_test.dart`:
```dart
import 'package:devpath_web/src/features/sandbox/presentation/sandbox_layout.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Size size) => MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        theme: DpTheme.light(),
        home: const Scaffold(
          body: SandboxLayout(
            editor: Text('EDITOR'),
            log: Text('LOG'),
            review: Text('REVIEW'),
          ),
        ),
      ),
    );

void main() {
  testWidgets('≥1240: 3페인 동시 표시', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(const Size(1400, 900)));
    expect(find.text('EDITOR'), findsOneWidget);
    expect(find.text('LOG'), findsOneWidget);
    expect(find.text('REVIEW'), findsOneWidget);
  });

  testWidgets('<1024: 세그먼트 탭(1페인) — 기본 EDITOR만', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(const Size(800, 900)));
    expect(find.byType(SegmentedButton<int>), findsOneWidget);
    expect(find.text('EDITOR'), findsOneWidget);
    expect(find.text('REVIEW'), findsNothing); // 다른 탭은 미표시
  });
}
```

- [ ] **Step 2: 실패 확인** — Run: `cd apps/web && flutter test test/features/sandbox/sandbox_layout_test.dart ; cd ../..` → FAIL

- [ ] **Step 3: 구현**

Create `apps/web/lib/src/features/sandbox/presentation/sandbox_layout.dart`:
```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

/// DD5/§9.3: ≥1240 3페인 · 1024–1239 2페인(에디터|리뷰)+로그 접이 · <1024 세그먼트 탭.
class SandboxLayout extends StatefulWidget {
  const SandboxLayout({
    super.key,
    required this.editor,
    required this.log,
    required this.review,
  });

  final Widget editor;
  final Widget log;
  final Widget review;

  @override
  State<SandboxLayout> createState() => _SandboxLayoutState();
}

class _SandboxLayoutState extends State<SandboxLayout> {
  int _tab = 0; // <1024 세그먼트: 0=editor 1=log 2=review
  bool _logOpen = true; // 1024–1239 로그 접이

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final c = context.dpColors;

    Widget pane(Widget child) =>
        Container(decoration: BoxDecoration(border: Border.all(color: c.border)), child: child);

    if (w >= 1240) {
      return Row(children: [
        Expanded(flex: 5, child: pane(widget.editor)),
        Expanded(flex: 3, child: pane(widget.log)),
        Expanded(flex: 4, child: pane(widget.review)),
      ]);
    }

    if (w >= 1024) {
      return Column(children: [
        Expanded(
          child: Row(children: [
            Expanded(flex: 6, child: pane(widget.editor)),
            Expanded(flex: 5, child: pane(widget.review)),
          ]),
        ),
        // 로그 접이
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _logOpen = !_logOpen),
            icon: Icon(_logOpen ? Icons.expand_more : Icons.expand_less),
            label: Text(_logOpen ? '실행 로그 접기' : '실행 로그 펼치기'),
          ),
        ),
        if (_logOpen) SizedBox(height: 160, child: pane(widget.log)),
      ]);
    }

    // <1024: 세그먼트 탭 1페인
    final panes = [widget.editor, widget.log, widget.review];
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(DpSpacing.sm),
        child: SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('에디터')),
            ButtonSegment(value: 1, label: Text('실행')),
            ButtonSegment(value: 2, label: Text('리뷰')),
          ],
          selected: {_tab},
          onSelectionChanged: (s) => setState(() => _tab = s.first),
        ),
      ),
      Expanded(child: pane(panes[_tab])),
    ]);
  }
}
```
> `Icons.expand_more/less`는 임시(접이 토글). DD3 엄격 적용 시 `DpIcons`로 이관(후속).

- [ ] **Step 4: 통과 확인** — Run: `cd apps/web && flutter test test/features/sandbox/sandbox_layout_test.dart ; cd ../..` → PASS

- [ ] **Step 5: 커밋**
```bash
git add apps/web/lib/src/features/sandbox/presentation/sandbox_layout.dart apps/web/test/features/sandbox/sandbox_layout_test.dart
git commit -m "feat(web): Sandbox DD5 반응형 레이아웃(3/2/1 페인)"
```

---

## Task 4: Monaco 에디터 임베드 (conditional import)

> web 전용 API(`dart:ui_web`·`package:web`·`dart:js_interop`)를 stub/web로 격리 → `flutter test`(VM)는 stub로 통과, web 빌드만 실제 Monaco.

**Files:**
- Modify: `apps/web/pubspec.yaml`(`web` 패키지), `apps/web/web/index.html`(Monaco 셈)
- Create: `apps/web/lib/src/features/sandbox/presentation/monaco_editor_view.dart`(공개), `monaco_editor_view_stub.dart`, `monaco_editor_view_web.dart`
- Test: `apps/web/test/features/sandbox/monaco_editor_view_test.dart`(stub 경로)

- [ ] **Step 1: 실패 테스트(테스트=VM=stub: 코드 미리보기 렌더)**

Create `apps/web/test/features/sandbox/monaco_editor_view_test.dart`:
```dart
import 'package:devpath_web/src/features/sandbox/presentation/monaco_editor_view.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('비웹(테스트)에서는 stub가 초기 코드를 보여준다', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: DpTheme.light(),
      home: const Scaffold(
        body: MonacoEditorView(initialCode: 'void main() {}'),
      ),
    ));
    expect(find.textContaining('void main()'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 실패 확인** — Run: `cd apps/web && flutter test test/features/sandbox/monaco_editor_view_test.dart ; cd ../..` → FAIL

- [ ] **Step 3: `pubspec.yaml`에 `web` 추가**

`apps/web/pubspec.yaml`의 `dependencies:`에 추가:
```yaml
  web: ^1.1.0   # 하한 가이드 — Monaco 임베드(DOM) 용. bootstrap 결과로 확정
```
Run: `melos bootstrap`

- [ ] **Step 4: 공개 위젯 — `monaco_editor_view.dart`**

Create `apps/web/lib/src/features/sandbox/presentation/monaco_editor_view.dart`:
```dart
import 'package:flutter/widgets.dart';

import 'monaco_editor_view_stub.dart'
    if (dart.library.js_interop) 'monaco_editor_view_web.dart' as impl;

/// 코드 에디터. web=Monaco 임베드, 그 외(테스트 포함)=stub.
class MonacoEditorView extends StatelessWidget {
  const MonacoEditorView({super.key, required this.initialCode, this.onChanged});
  final String initialCode;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) =>
      impl.buildMonacoEditor(initialCode: initialCode, onChanged: onChanged);
}
```

- [ ] **Step 5: 스텁 — `monaco_editor_view_stub.dart`**

Create `apps/web/lib/src/features/sandbox/presentation/monaco_editor_view_stub.dart`:
```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

/// 비웹/테스트: 읽기전용 코드 미리보기(Monaco 미로드).
Widget buildMonacoEditor({
  required String initialCode,
  ValueChanged<String>? onChanged,
}) =>
    Container(
      color: const Color(0xFF1E1E1E), // DESIGN codeEditorBg
      padding: const EdgeInsets.all(DpSpacing.md),
      child: SingleChildScrollView(
        child: Text(
          initialCode,
          style: DpTypography.code.copyWith(color: const Color(0xFFD4D4D4)),
        ),
      ),
    );
```

- [ ] **Step 6: 웹 구현 — `monaco_editor_view_web.dart`**

Create `apps/web/lib/src/features/sandbox/presentation/monaco_editor_view_web.dart`:
```dart
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// index.html이 정의하는 셈: createDevpathEditor(container, code, onChange).
@JS('createDevpathEditor')
external void _createDevpathEditor(
  web.HTMLElement container,
  String initialCode,
  JSFunction onChange,
);

int _seq = 0;

Widget buildMonacoEditor({
  required String initialCode,
  ValueChanged<String>? onChanged,
}) {
  final viewType = 'monaco-${_seq++}';
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
    final container = (web.document.createElement('div') as web.HTMLDivElement)
      ..style.width = '100%'
      ..style.height = '100%';
    final cb = ((JSString v) => onChanged?.call(v.toDart)).toJS;
    _createDevpathEditor(container, initialCode, cb);
    return container;
  });
  return HtmlElementView(viewType: viewType);
}
```

- [ ] **Step 7: `index.html`에 Monaco 셈 추가**

`apps/web/web/index.html`의 `</body>` 직전에 추가:
```html
<script src="https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.52.2/min/vs/loader.min.js"></script>
<script>
  require.config({ paths: { vs: 'https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.52.2/min/vs' }});
  window.createDevpathEditor = function (container, code, onChange) {
    require(['vs/editor/editor.main'], function () {
      var editor = monaco.editor.create(container, {
        value: code, language: 'dart', theme: 'vs-dark',
        automaticLayout: true, minimap: { enabled: false }, fontSize: 14,
      });
      editor.onDidChangeModelContent(function () { onChange(editor.getValue()); });
    });
  };
</script>
```
> 버전·CDN은 가이드. 오프라인/CSP 환경이면 Monaco를 `web/`에 번들. AMD 로더는 셈 안에서만 다루고 Dart는 `createDevpathEditor`만 호출.

- [ ] **Step 8: 통과 확인(VM=stub)** — Run: `cd apps/web && flutter test test/features/sandbox/monaco_editor_view_test.dart ; cd ../..` → PASS
- [ ] **Step 8b: web 분석 확인** — Run: `cd apps/web && flutter analyze ; cd ../..` → 이슈 없음(conditional import 해석)

- [ ] **Step 9: 커밋**
```bash
git add apps/web/pubspec.yaml apps/web/web/index.html apps/web/lib/src/features/sandbox/presentation/monaco_editor_view.dart apps/web/lib/src/features/sandbox/presentation/monaco_editor_view_stub.dart apps/web/lib/src/features/sandbox/presentation/monaco_editor_view_web.dart apps/web/test/features/sandbox/monaco_editor_view_test.dart pubspec.lock
git commit -m "feat(web): Monaco 에디터 임베드(conditional import + index.html 셈)"
```

---

## Task 5: 실행 로그 SSE + SANDBOX_UNAVAILABLE (`RunController`)

**Files:**
- Create: `apps/web/lib/src/features/sandbox/data/sandbox_run_source.dart`, `.../application/run_controller.dart`
- Test: `apps/web/test/features/sandbox/run_controller_test.dart`

- [ ] **Step 1: 실패 테스트(로그 누적 + 503 unavailable)**

Create `apps/web/test/features/sandbox/run_controller_test.dart`:
```dart
import 'package:devpath_web/src/features/sandbox/application/run_controller.dart';
import 'package:devpath_web/src/features/sandbox/data/sandbox_run_source.dart';
import 'package:devpath_web/src/features/sandbox/state/run_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Stream<SseEvent> _logs(List<String> lines) async* {
  for (final l in lines) {
    yield SseEvent(event: 'log', data: l);
  }
}

void main() {
  test('실행: 로그를 누적하고 done', () async {
    final c = ProviderContainer(overrides: [
      sandboxRunConnectProvider
          .overrideWithValue(() => _logs(['컴파일 중…', '테스트 통과'])),
    ]);
    addTearDown(c.dispose);

    await c.read(runControllerProvider.notifier).run('print(1);');

    final s = c.read(runControllerProvider);
    expect(s, isA<RunDone>());
    expect((s as RunDone).logs, ['컴파일 중…', '테스트 통과']);
  });

  test('SANDBOX_UNAVAILABLE이면 RunUnavailable', () async {
    final c = ProviderContainer(overrides: [
      sandboxRunConnectProvider.overrideWithValue(() =>
          Stream<SseEvent>.error(const ApiException(
              code: ApiErrorCode.sandboxUnavailable, message: '점검'))),
    ]);
    addTearDown(c.dispose);

    await c.read(runControllerProvider.notifier).run('print(1);');
    expect(c.read(runControllerProvider), isA<RunUnavailable>());
  });
}
```

- [ ] **Step 2: 실패 확인** — Run: `cd apps/web && flutter test test/features/sandbox/run_controller_test.dart ; cd ../..` → FAIL

- [ ] **Step 3: 구현 — `sandbox_run_source.dart`**

Create `apps/web/lib/src/features/sandbox/data/sandbox_run_source.dart`:
```dart
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';

/// 실행 로그 SSE 스트림 생성기.
typedef SandboxRunConnect = Stream<SseEvent> Function();

const List<String> _kMockRunLog = [
  '> dart run main.dart',
  '컴파일 중…',
  '테스트 1/2 통과',
  '테스트 2/2 통과',
  '완료 (0.8s)',
];

final sandboxRunConnectProvider = Provider<SandboxRunConnect>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMock) {
    return () async* {
      for (final line in _kMockRunLog) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        yield SseEvent(event: 'log', data: line);
      }
    };
  }
  final client = ref.watch(apiClientProvider);
  return () => SseClient(client.dio).connect('/sandbox/run');
});
```

- [ ] **Step 4: 구현 — `run_controller.dart`**

Create `apps/web/lib/src/features/sandbox/application/run_controller.dart`:
```dart
import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sandbox_run_source.dart';
import '../state/run_state.dart';

class RunController extends Notifier<RunState> {
  StreamSubscription<SseEvent>? _sub;

  @override
  RunState build() {
    ref.onDispose(() => _sub?.cancel());
    return const RunIdle();
  }

  Future<void> run(String code) {
    _sub?.cancel();
    final done = Completer<void>();
    state = const RunRunning();

    _sub = ref.read(sandboxRunConnectProvider)().listen(
      (e) {
        final s = state;
        if (s is RunRunning) state = s.appended(e.data);
      },
      onError: (Object err) {
        if (err is ApiException && err.code == ApiErrorCode.sandboxUnavailable) {
          state = const RunUnavailable();
        } else {
          final msg = err is ApiException ? err.message : err.toString();
          state = RunDone(logs: [..._logsOf(state), '실행 오류: $msg']);
        }
        if (!done.isCompleted) done.complete();
      },
      onDone: () {
        final s = state;
        if (s is RunRunning) state = RunDone(logs: s.logs);
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );

    return done.future;
  }

  List<String> _logsOf(RunState s) =>
      s is RunRunning ? [...s.logs] : (s is RunDone ? [...s.logs] : <String>[]);
}

final runControllerProvider =
    NotifierProvider<RunController, RunState>(RunController.new);
```
> web은 `dio` 직접 의존 금지(P4a 결정) → `RunController`는 `ApiException`만 해제. 실서버 `SseClient` 에러가 `DioException(error: ApiException)`로 오면 `sandboxUnavailable` 판정이 누락되므로, **dp_core `SseClient.connect`가 실패를 `ApiException`으로 정규화**하도록 보강해야 한다(get/post 헬퍼와 동일 규약 — 리스크/후속 참조). 목 테스트는 `ApiException` 직접 emit이라 OK.

- [ ] **Step 5: 통과 확인** — Run: `cd apps/web && flutter test test/features/sandbox/run_controller_test.dart ; cd ../..` → PASS

- [ ] **Step 6: 커밋**
```bash
git add apps/web/lib/src/features/sandbox/data apps/web/lib/src/features/sandbox/application apps/web/test/features/sandbox/run_controller_test.dart
git commit -m "feat(web): Sandbox 실행 로그 SSE + SANDBOX_UNAVAILABLE"
```

---

## Task 6: Sandbox 조립 (`SandboxPage`) + 라우트

> 레이아웃(Task 3) + Monaco(Task 4) + 실행(Task 5) 결합. 리뷰 칸은 P4d 자리표시. 실행로그=codeLogBg, SANDBOX_UNAVAILABLE이면 실행 패널만 `DpSandboxUnavailable`.

**Files:**
- Create: `apps/web/lib/src/features/sandbox/presentation/sandbox_page.dart`
- Modify: `apps/web/lib/src/app/router.dart`(`/sandbox`)
- Test: `apps/web/test/features/sandbox/sandbox_page_test.dart`

- [ ] **Step 1: 실패 테스트(에디터·실행·리뷰자리 존재 + 실행 시 로그)**

Create `apps/web/test/features/sandbox/sandbox_page_test.dart`:
```dart
import 'package:devpath_web/src/features/sandbox/data/sandbox_run_source.dart';
import 'package:devpath_web/src/features/sandbox/presentation/monaco_editor_view.dart';
import 'package:devpath_web/src/features/sandbox/presentation/sandbox_page.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Stream<SseEvent> _logs(List<String> lines) async* {
  for (final l in lines) {
    yield SseEvent(event: 'log', data: l);
  }
}

void main() {
  testWidgets('넓은 화면에서 에디터(stub)+실행 버튼 노출, 실행 시 로그 표시', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final c = ProviderContainer(overrides: [
      sandboxRunConnectProvider.overrideWithValue(() => _logs(['실행 결과: OK'])),
    ]);
    addTearDown(c.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: SandboxPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(MonacoEditorView), findsOneWidget);
    await tester.tap(find.text('실행'));
    await tester.pumpAndSettle();
    expect(find.textContaining('실행 결과: OK'), findsOneWidget);
  });
}
```
> `MaterialApp(home:)` 기본 테마로도 충분(SandboxPage 내부에서 `context.dpColors` 쓰면 `DpTheme.light()` 필요 — 테스트 호스트에 `theme: DpTheme.light()` 추가).

- [ ] **Step 2: 실패 확인** — Run: `cd apps/web && flutter test test/features/sandbox/sandbox_page_test.dart ; cd ../..` → FAIL

- [ ] **Step 3: 구현 — `sandbox_page.dart`**

Create `apps/web/lib/src/features/sandbox/presentation/sandbox_page.dart`:
```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/run_controller.dart';
import '../state/run_state.dart';
import 'monaco_editor_view.dart';
import 'sandbox_layout.dart';

const _kInitialCode = 'void main() {\n  print(\'hello devpath\');\n}\n';

class SandboxPage extends ConsumerStatefulWidget {
  const SandboxPage({super.key});

  @override
  ConsumerState<SandboxPage> createState() => _SandboxPageState();
}

class _SandboxPageState extends ConsumerState<SandboxPage> {
  String _code = _kInitialCode;

  @override
  Widget build(BuildContext context) {
    final run = ref.watch(runControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sandbox'),
        actions: [
          FilledButton(
            onPressed: run is RunRunning
                ? null
                : () => ref.read(runControllerProvider.notifier).run(_code),
            child: const Text('실행'),
          ),
          const SizedBox(width: DpSpacing.md),
        ],
      ),
      body: SandboxLayout(
        editor: MonacoEditorView(
          initialCode: _kInitialCode,
          onChanged: (v) => _code = v,
        ),
        log: _LogPane(run: run),
        review: const _ReviewPlaceholder(),
      ),
    );
  }
}

/// 실행 로그(codeLogBg). SANDBOX_UNAVAILABLE이면 전용 안내(편집은 유지).
class _LogPane extends StatelessWidget {
  const _LogPane({required this.run});
  final RunState run;

  @override
  Widget build(BuildContext context) {
    if (run is RunUnavailable) return const DpSandboxUnavailable();
    final logs = switch (run) {
      RunRunning(:final logs) => logs,
      RunDone(:final logs) => logs,
      _ => const <String>[],
    };
    return Container(
      color: context.dpColors.codeLogBg,
      padding: const EdgeInsets.all(DpSpacing.md),
      child: logs.isEmpty
          ? Text('실행 결과가 여기에 표시됩니다.',
              style: DpTypography.code
                  .copyWith(color: context.dpColors.codeText))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final l in logs)
                    Text(l,
                        style: DpTypography.code
                            .copyWith(color: context.dpColors.codeText)),
                ],
              ),
            ),
    );
  }
}

/// AI 리뷰 칸 — P4d에서 REV-001로 채움.
class _ReviewPlaceholder extends StatelessWidget {
  const _ReviewPlaceholder();

  @override
  Widget build(BuildContext context) => const DpEmpty(
        icon: DpIcons.content,
        title: 'AI 리뷰',
        message: '코드를 실행하면 리뷰가 제공됩니다. (P4d)',
      );
}
```

- [ ] **Step 4: `/sandbox` 라우트 추가**

`apps/web/lib/src/app/router.dart` ShellRoute에 추가(import 포함):
```dart
GoRoute(path: '/sandbox', builder: (_, __) => const SandboxPage()),
```

- [ ] **Step 5: 통과 확인** — Run: `cd apps/web && flutter test test/features/sandbox/sandbox_page_test.dart ; cd ../..` → PASS

- [ ] **Step 6: 커밋**
```bash
git add apps/web/lib/src/features/sandbox/presentation/sandbox_page.dart apps/web/lib/src/app/router.dart apps/web/test/features/sandbox/sandbox_page_test.dart
git commit -m "feat(web): SandboxPage 조립(Monaco+실행로그+리뷰자리) + 라우트"
```

---

## Task 7: 통합 스모크 + 전체 검증

**Files:**
- Create: `apps/web/test/content_sandbox_smoke_test.dart`

- [ ] **Step 1: 통합 스모크(콘텐츠 → 실습 → Sandbox 실행)**

Create `apps/web/test/content_sandbox_smoke_test.dart`:
```dart
import 'package:devpath_web/src/features/content/presentation/content_page.dart';
import 'package:devpath_web/src/features/sandbox/data/sandbox_run_source.dart';
import 'package:devpath_web/src/features/sandbox/presentation/sandbox_page.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Stream<SseEvent> _logs(List<String> l) async* {
  for (final x in l) {
    yield SseEvent(event: 'log', data: x);
  }
}

void main() {
  testWidgets('콘텐츠 로드 후 Sandbox 실행 로그까지', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final c = ProviderContainer(overrides: [
      sandboxRunConnectProvider.overrideWithValue(() => _logs(['OK'])),
    ]);
    addTearDown(c.dispose);

    // 콘텐츠
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(home: ContentPage(contentId: 'c1')),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('비동기 기초'), findsWidgets);

    // Sandbox 실행
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: DpTheme.light(), home: const SandboxPage()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('실행'));
    await tester.pumpAndSettle();
    expect(find.textContaining('OK'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 전체 검증**

Run (레포 루트):
```bash
melos run analyze
melos run test
```
Expected: `devpath_web` 포함 `analyze` 이슈 없음(conditional import·web 패키지 해석), `test` 전 멤버 PASS(골든 제외). Monaco web 코드는 VM 테스트에서 미컴파일 경로(stub 사용)라 영향 없음.

- [ ] **Step 3: (선택) web 빌드 확인**

Run: `cd apps/web && flutter build web ; cd ../..`
Expected: 빌드 성공(실제 Monaco는 런타임 CDN 로드 — 빌드시 미검증, `flutter run -d chrome`로 수동 확인 권장).

- [ ] **Step 4: 커밋**
```bash
git add apps/web/test/content_sandbox_smoke_test.dart
git commit -m "test(web): 콘텐츠→Sandbox 실행 통합 스모크"
```

---

## 검증 기준 (Definition of Done)

- [ ] `melos run analyze` — `devpath_web` 이슈 없음(conditional import 포함)
- [ ] `melos run test` — content·run-state·sandbox-layout·monaco(stub)·run-controller·sandbox-page·smoke PASS
- [ ] CNT: 마크다운+코드블록 렌더(DpMarkdown), 로딩/에러 상태
- [ ] SBX 반응형(DD5): ≥1240 3페인 / 1024–1239 2페인+로그접이 / <1024 세그먼트 탭 — 위젯 테스트로 폭별 검증
- [ ] Monaco: web 빌드에서 실제 에디터 임베드(`flutter run -d chrome` 수동), VM 테스트는 stub로 통과(conditional import)
- [ ] 실행: SSE 로그 누적 표시(codeLogBg), `SANDBOX_UNAVAILABLE`→`DpSandboxUnavailable`(편집 유지·실행만 비활성)

## 리스크 / 후속 (명시)

- **REV-001 미포함**: AI 코드리뷰는 P4d(리뷰 칸 채움 + KILL_SWITCH/Quota). P4c 3페인의 리뷰 칸은 `_ReviewPlaceholder`.
- **Monaco 런타임 의존**: CDN 로드(`createDevpathEditor` 셈) 전제 → 오프라인/CSP 환경은 Monaco를 `web/`에 번들. 빌드만으론 에디터 동작 미검증(수동 `flutter run -d chrome`). 실패 시 stub와 동일 폴백 고려(후속).
- **터치 편집 제약**: Monaco는 web 전용(스펙 §2). 모바일웹(<1024)은 세그먼트 탭으로 에디터 노출하나 터치 편집 한계 — 안내 문구 후속.
- **임시 아이콘**: `Icons.code`/`expand_more` 등 일부 Material Icons 사용 → DD3 단일 Symbols 준수 위해 `DpIcons` 이관(후속, dp_design 추가).
- **dp_core SseClient 에러 정규화 필요**: web dio-free 유지를 위해 `SseClient.connect`가 실패 시 `ApiException`을 throw하도록 dp_core 보강 필요(현재 P2는 미정규화). 미보강 시 실서버 경로의 `SANDBOX_UNAVAILABLE`/`KILL_SWITCH`가 일반 오류로 처리됨(목은 영향 없음). P2 후속(T 후보).
- **실행 의미는 목**: `_kMockRunLog`는 고정 로그. 실제 컴파일/테스트 실행·결과 파싱은 백엔드 `/sandbox/run` 연동 시(스펙 §3 SSE 실행로그).
- **eng-review 게이트**: DD5 반응형은 아키텍처 영향 → 구현 전 `/plan-eng-review` 권장.
