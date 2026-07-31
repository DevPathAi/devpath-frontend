# UI/UX Phase 5 — mentor 채팅 자동 스크롤 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** mentor 채팅에 하단-근처 추종 자동 스크롤을 추가해 답변 스트리밍이 항상 보이게 한다(사용자가 위로 스크롤 중이면 억제). 계약 불변.

**Architecture:** `mentor_page.dart`(Layer 3)만 변경. `_MentorPageState`에 `ScrollController`를 추가하고 `ref.listen`으로 메시지 증가·스트리밍 토큰 갱신을 감지해 하단으로 따라간다. dp_design 신규 없음. `MentorController`/`MentorState`/SSE 소스 불변.

**Tech Stack:** Flutter Web, Riverpod 3, SDK `ScrollController`. 검증 SSoT = spec `docs/superpowers/specs/2026-07-31-uiux-phase5-mentor-scroll-design.md`.

## Global Constraints

- **계약 불변**: `MentorController`(`send`·`retry`)·`MentorState`(`messages`·`status`·`error`·`references`)·`mentor_sse_source`·백엔드 SSE 계약 변경 금지.
- **기존 mentor 동작 유지**: 스트리밍 최적화(`ValueKey`·`isStreamingTail`)·SSE 상태(partial/failed/killSwitch)·참고자료·Composer.
- **content·diagnostic 변경 금지**(spec §1.4).
- **토큰만 사용**·**게이트**: `melos run analyze`(0 issues)·`melos run test`(pass)·`melos run format`(clean). PATH 미설정 시 `dart pub global run melos <cmd>`.
- **커밋**: Conventional Commits. 메시지 끝에 `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

## Task 1: mentor 자동 스크롤 (ScrollController + 하단-근처 추종)

**Files:**
- Modify: `apps/web/lib/src/features/mentor/presentation/mentor_page.dart`
- Test: `apps/web/test/features/mentor/mentor_page_test.dart` (자동 스크롤 2 테스트 추가)

**Interfaces:**
- Consumes: `ScrollController`(SDK), `MentorController`·`MentorState`·`ChatMessage`·`MentorStatus`.
- Produces: mentor `ListView.builder`가 `_scroll`에 연결되고, 메시지 증가·꼬리 갱신 시 하단 근처면 자동 추종.

- [ ] **Step 1: Write the failing tests**

`mentor_page_test.dart` 상단 import에 controller/state를 추가:

```dart
import 'package:devpath_web/src/features/mentor/application/mentor_controller.dart';
import 'package:devpath_web/src/features/mentor/state/mentor_state.dart';
```

파일 `main()`에 아래 Fake와 2개 테스트를 추가(기존 3개 SSE 테스트는 그대로 둔다). Fake는 `main()` 위(top-level)에 둔다:

```dart
// 상태를 직접 주입/추가할 수 있는 MentorController 대역(자동 스크롤 결정적 검증용).
class _FakeMentor extends MentorController {
  _FakeMentor(this._initial);
  final MentorState _initial;

  @override
  MentorState build() => _initial;

  void push(String text) => state = MentorState(
    messages: [
      ...state.messages,
      ChatMessage(fromUser: false, text: text),
    ],
    status: state.status,
    error: state.error,
    references: state.references,
  );
}

MentorState _manyMessages() => MentorState(
  messages: [
    for (var i = 0; i < 24; i++)
      ChatMessage(
        fromUser: i.isEven,
        text: '메시지 $i · 스크롤을 만들기 위한 충분히 긴 본문 텍스트를 넣는다.',
      ),
  ],
  status: MentorStatus.idle,
);

ListView _listView(WidgetTester tester) =>
    tester.widget<ListView>(find.byType(ListView));
```

테스트:

```dart
  testWidgets('하단 근처에서 새 메시지 → 자동으로 하단까지 스크롤', (tester) async {
    tester.view.physicalSize = const Size(500, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fake = _FakeMentor(_manyMessages());
    final c = ProviderContainer(
      overrides: [mentorControllerProvider.overrideWith(() => fake)],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(theme: DpTheme.light(), home: const MentorPage()),
      ),
    );
    await tester.pumpAndSettle();

    final ctrl = _listView(tester).controller!;
    ctrl.jumpTo(ctrl.position.maxScrollExtent); // 하단 근처
    await tester.pump();

    fake.push('스트리밍으로 들어온 새 답변 메시지');
    await tester.pumpAndSettle();

    expect(
      ctrl.position.pixels,
      closeTo(ctrl.position.maxScrollExtent, 1.0),
    );
  });

  testWidgets('위로 스크롤한 상태 → 새 메시지가 와도 자동 스크롤 억제', (tester) async {
    tester.view.physicalSize = const Size(500, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fake = _FakeMentor(_manyMessages());
    final c = ProviderContainer(
      overrides: [mentorControllerProvider.overrideWith(() => fake)],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(theme: DpTheme.light(), home: const MentorPage()),
      ),
    );
    await tester.pumpAndSettle();

    final ctrl = _listView(tester).controller!;
    ctrl.jumpTo(0); // 상단(사용자가 위로 스크롤해 읽는 중)
    await tester.pump();

    fake.push('새 답변');
    await tester.pumpAndSettle();

    // 하단으로 점프하지 않고 상단 근처 유지
    expect(ctrl.position.pixels, lessThan(120));
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd apps/web && flutter test test/features/mentor/mentor_page_test.dart`
Expected: FAIL — 자동 스크롤 미구현(`ListView.controller`가 null이라 `ctrl!`에서 실패, 또는 push 후 하단 미추종).

- [ ] **Step 3: Write minimal implementation**

`mentor_page.dart` 수정:

(a) 파일 상단 `_kExamples` 근처에 상수 추가:

```dart
/// 하단에서 이 픽셀 이내면 새 메시지·토큰을 자동 추종(더 멀면 사용자가 읽는 중으로 보고 억제).
const double _kFollowThreshold = 120;
```

(b) `_MentorPageState`에 `ScrollController` 추가·해제:

```dart
class _MentorPageState extends ConsumerState<MentorPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _autoFollow() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    // 하단 근처가 아니면(위로 읽는 중) 억제.
    if (pos.maxScrollExtent - pos.pixels > _kFollowThreshold) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }
  // ... _send 유지 ...
```

(c) `build` 시작부에 `ref.listen`으로 메시지 증가·꼬리 갱신 감지:

```dart
  @override
  Widget build(BuildContext context) {
    ref.listen(mentorControllerProvider, (prev, next) {
      final grew = (prev?.messages.length ?? 0) != next.messages.length;
      final tailChanged =
          prev != null &&
          prev.messages.isNotEmpty &&
          next.messages.isNotEmpty &&
          prev.messages.last.text != next.messages.last.text;
      if (grew || tailChanged) _autoFollow();
    });

    final s = ref.watch(mentorControllerProvider);
    final c = context.dpColors;
    // ... 이하 기존 build 유지 ...
```

(d) `ListView.builder`에 컨트롤러 연결:

```dart
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(DpSpacing.lg),
                      // ... 기존 itemCount/itemBuilder 유지 ...
```

- [ ] **Step 4: Run tests to verify they pass (mentor 폴더 전체)**

Run: `cd apps/web && flutter test test/features/mentor/`
Expected: PASS — 자동 스크롤 2 신규 + 기존(빈상태/partial/references)·controller/state/sse 회귀.

> 자동 스크롤 테스트가 레이아웃 높이에 민감해 실패하면: 억제 임계값(120)과 테스트의 `Size`·메시지 수를 함께 조정하되, "하단 근처면 추종 / 상단이면 억제"의 관찰 가능한 차이는 유지한다. `closeTo` 오차는 필요 시 소폭 완화(예: 1.0→2.0).

- [ ] **Step 5: 전체 게이트**

Run: `dart pub global run melos run analyze` · `dart pub global run melos run test` · `dart pub global run melos run format`
Expected: analyze 0 issues · 전 패키지 test PASS · format clean.

- [ ] **Step 6: Commit**

```bash
git add apps/web/lib/src/features/mentor/presentation/mentor_page.dart apps/web/test/features/mentor/mentor_page_test.dart
git commit -m "feat(web): mentor 채팅 하단-근처 추종 자동 스크롤

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review (작성자 체크 결과)

**1. Spec coverage:**
- §3 ScrollController 추가·dispose → Step 3(b) ✓ / §3 메시지 증가·토큰 갱신 감지 → Step 3(c) ref.listen ✓ / §3 하단-근처 추종·억제 → Step 3(b) `_autoFollow` 임계값 ✓ / §4 자동 추종·억제·회귀 테스트 → Step 1 ✓ / §1.4 content·diagnostic 불변 → 파일 범위 mentor만 ✓ / 계약 불변 → Global Constraints ✓.

**2. Placeholder scan:** TBD/TODO 없음. 모든 코드 스텝 실제 코드 포함 ✓.

**3. Type consistency:** `_FakeMentor extends MentorController`(build override·push)·`mentorControllerProvider.overrideWith`·`MentorState`(messages/status/error/references)·`ChatMessage(fromUser/text)`가 실측과 일치 ✓. `ListView.controller`(`_scroll`)로 테스트 접근 ✓. `_autoFollow`가 정의(3b)와 호출(3c)에서 일치 ✓.

**4. 회귀 주의:** 기존 mentor 3 테스트는 SSE override 방식이라 자동 스크롤 추가와 무관하게 유지(ListView에 controller만 추가). 스트리밍/partial/references/composer 불변.
