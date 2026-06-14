# P4e — AI 멘토(MEN-001, SSE 스트리밍 채팅) (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `apps/web`에 **AI 멘토(MEN-001)** 를 TDD로 구현한다 — 질문을 보내면 답변이 **SSE 토큰 스트리밍**(토큰 append, 문자단위 금지)으로 누적되고, 빈 상태("첫 질문을 해보세요"+예시질문), 타이핑 인디케이터, `AI_KILL_SWITCH_ACTIVE`→점검 배너, 끊김 시 재시도를 처리한다(§9.2 멘토 행).

**Architecture:** P4a~d 토대 위. `mentorSseConnectProvider`(목=토큰 지연 emit / 실서버=`SseClient`)로 SSE 주입. `MentorController`(Riverpod `Notifier`)가 메시지 리스트를 들고 스트리밍 토큰을 마지막 멘토 메시지에 append. `ApiException.isKillSwitch`로 점검 분기. web `dio`-free.

**Tech Stack:** Flutter Web · flutter_riverpod 3.3 · dp_core(SseClient·ApiException)·dp_design(DpEmpty·DpKillSwitch·DpError) · flutter_test.

---

> **선행:** P4a~d 구현 완료. `/mentor` 라우트의 `PlaceholderPage`(P4a)를 교체.
> **참조:** 스펙 §3(SSE)·§4(멘토 SSE)·§9.2(AI 멘토 행: LOADING 타이핑/EMPTY 예시질문/ERROR 끊김·KILL_SWITCH/SUCCESS 스트리밍+후속질문/PARTIAL). DESIGN.md §7(스트리밍 텍스트=토큰 append). 샘플: `Flutter_SSE_실시간_스트림_구독`.
> **YAGNI:** 후속질문(추천 follow-up)·멘토세션 영속·REV→멘토 연결은 후속. 끊김 "재개"는 재요청(resend)로 단순화(중간 토큰 재개는 SSE id 표준화 후속 — P4b 리스크와 동일).

## P4e가 소비/수정하는 API

- P4a: `apiClientProvider`·`appConfigProvider`(providers), `routerProvider`(`/mentor`).
- dp_core(P2): `SseClient`·`SseEvent`, `ApiException`(`isKillSwitch`).
- dp_design(P3): `DpEmpty`·`DpKillSwitch`·`DpError`, `DpIcons`(mentor), `DpSpacing`, `context.dpColors`.

---

## File Structure (P4e에서 생성/수정)

```
apps/web/lib/src/features/mentor/
├─ data/mentor_sse_source.dart            # mentorSseConnectProvider + 목 토큰 — Task 1
├─ state/mentor_state.dart                # ChatMessage + MentorState — Task 2
├─ application/mentor_controller.dart     # send + 스트리밍 append + kill — Task 2
└─ presentation/mentor_page.dart          # 채팅 UI — Task 3
apps/web/lib/src/app/router.dart          # (수정) /mentor → MentorPage — Task 4
```

---

## Task 1: 멘토 SSE 소스 (`mentorSseConnectProvider`)

**Files:**
- Create: `apps/web/lib/src/features/mentor/data/mentor_sse_source.dart`
- Test: `apps/web/test/features/mentor/mentor_sse_source_test.dart`

- [ ] **Step 1: 실패 테스트(목이 토큰을 emit)**

Create `apps/web/test/features/mentor/mentor_sse_source_test.dart`:
```dart
import 'package:devpath_web/src/features/mentor/data/mentor_sse_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('목 소스는 답변 토큰을 emit한다', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final connect = c.read(mentorSseConnectProvider);
    final tokens = await connect('비동기란?').map((e) => e.data).toList();
    expect(tokens, isNotEmpty);
    expect(tokens.join(), contains('async'));
  });
}
```

- [ ] **Step 2: 실패 확인** — Run: `cd apps/web && flutter test test/features/mentor/mentor_sse_source_test.dart ; cd ../..` → FAIL

- [ ] **Step 3: 구현**

Create `apps/web/lib/src/features/mentor/data/mentor_sse_source.dart`:
```dart
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';

typedef MentorSseConnect = Stream<SseEvent> Function(String question);

const List<String> _kMockAnswer = [
  '비동기는 ',
  '`Future`와 ',
  '`async`/`await`로 ',
  '다룹니다. ',
  '스트림은 `Stream`을 구독하세요.',
];

final mentorSseConnectProvider = Provider<MentorSseConnect>((ref) {
  final config = ref.watch(appConfigProvider);
  if (config.useMock) {
    return (question) async* {
      for (final t in _kMockAnswer) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        yield SseEvent(event: 'token', data: t);
      }
    };
  }
  final client = ref.watch(apiClientProvider);
  return (question) => SseClient(client.dio)
      .connect('/ai-mentor/sessions', body: {'message': question});
});
```

- [ ] **Step 4: 통과 확인** — Run: `cd apps/web && flutter test test/features/mentor/mentor_sse_source_test.dart ; cd ../..` → PASS

- [ ] **Step 5: 커밋**
```bash
git add apps/web/lib/src/features/mentor/data apps/web/test/features/mentor/mentor_sse_source_test.dart
git commit -m "feat(web): 멘토 SSE 소스(목 토큰/실서버 주입)"
```

---

## Task 2: `MentorState` + `MentorController` (스트리밍 append + kill)

**Files:**
- Create: `apps/web/lib/src/features/mentor/state/mentor_state.dart`, `.../application/mentor_controller.dart`
- Test: `apps/web/test/features/mentor/mentor_controller_test.dart`

- [ ] **Step 1: 실패 테스트(스트리밍 누적 + 점검 분기)**

Create `apps/web/test/features/mentor/mentor_controller_test.dart`:
```dart
import 'package:devpath_web/src/features/mentor/application/mentor_controller.dart';
import 'package:devpath_web/src/features/mentor/data/mentor_sse_source.dart';
import 'package:devpath_web/src/features/mentor/state/mentor_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Stream<SseEvent> _tokens(List<String> t) async* {
  for (final x in t) {
    yield SseEvent(event: 'token', data: x);
  }
}

void main() {
  test('질문 전송 → 사용자+멘토 메시지, 토큰 누적 후 idle', () async {
    final c = ProviderContainer(overrides: [
      mentorSseConnectProvider
          .overrideWithValue((q) => _tokens(['안녕', '하세요'])),
    ]);
    addTearDown(c.dispose);

    await c.read(mentorControllerProvider.notifier).send('질문');

    final s = c.read(mentorControllerProvider);
    expect(s.status, MentorStatus.idle);
    expect(s.messages, hasLength(2));
    expect(s.messages[0].fromUser, isTrue);
    expect(s.messages[0].text, '질문');
    expect(s.messages[1].fromUser, isFalse);
    expect(s.messages[1].text, '안녕하세요');
  });

  test('KILL_SWITCH면 status killSwitch', () async {
    final c = ProviderContainer(overrides: [
      mentorSseConnectProvider.overrideWithValue((q) =>
          Stream<SseEvent>.error(const ApiException(
              code: ApiErrorCode.aiKillSwitchActive, message: '점검'))),
    ]);
    addTearDown(c.dispose);

    await c.read(mentorControllerProvider.notifier).send('질문');
    expect(c.read(mentorControllerProvider).status, MentorStatus.killSwitch);
  });
}
```

- [ ] **Step 2: 실패 확인** — Run: `cd apps/web && flutter test test/features/mentor/mentor_controller_test.dart ; cd ../..` → FAIL

- [ ] **Step 3: 구현 — `mentor_state.dart`**

Create `apps/web/lib/src/features/mentor/state/mentor_state.dart`:
```dart
enum MentorStatus { idle, streaming, killSwitch, failed }

class ChatMessage {
  const ChatMessage({required this.fromUser, required this.text});
  final bool fromUser;
  final String text;
  ChatMessage append(String s) => ChatMessage(fromUser: fromUser, text: text + s);
}

class MentorState {
  const MentorState({
    this.messages = const [],
    this.status = MentorStatus.idle,
    this.error,
  });
  final List<ChatMessage> messages;
  final MentorStatus status;
  final String? error;
}
```

- [ ] **Step 4: 구현 — `mentor_controller.dart`**

Create `apps/web/lib/src/features/mentor/application/mentor_controller.dart`:
```dart
import 'dart:async';

import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mentor_sse_source.dart';
import '../state/mentor_state.dart';

class MentorController extends Notifier<MentorState> {
  StreamSubscription<SseEvent>? _sub;

  @override
  MentorState build() {
    ref.onDispose(() => _sub?.cancel());
    return const MentorState();
  }

  Future<void> send(String question) {
    if (question.trim().isEmpty) return Future.value();
    _sub?.cancel();
    final done = Completer<void>();

    final msgs = [
      ...state.messages,
      ChatMessage(fromUser: true, text: question),
      const ChatMessage(fromUser: false, text: ''),
    ];
    state = MentorState(messages: msgs, status: MentorStatus.streaming);

    _sub = ref.read(mentorSseConnectProvider)(question).listen(
      (e) {
        final m = [...state.messages];
        m[m.length - 1] = m.last.append(e.data);
        state = MentorState(messages: m, status: MentorStatus.streaming);
      },
      onError: (Object err) {
        final isKill = err is ApiException && err.isKillSwitch;
        state = MentorState(
          messages: state.messages,
          status: isKill ? MentorStatus.killSwitch : MentorStatus.failed,
          error: err is ApiException ? err.message : '연결이 끊겼어요',
        );
        if (!done.isCompleted) done.complete();
      },
      onDone: () {
        state = MentorState(messages: state.messages, status: MentorStatus.idle);
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );

    return done.future;
  }
}

final mentorControllerProvider =
    NotifierProvider<MentorController, MentorState>(MentorController.new);
```

- [ ] **Step 5: 통과 확인** — Run: `cd apps/web && flutter test test/features/mentor/mentor_controller_test.dart ; cd ../..` → PASS

- [ ] **Step 6: 커밋**
```bash
git add apps/web/lib/src/features/mentor/state apps/web/lib/src/features/mentor/application apps/web/test/features/mentor/mentor_controller_test.dart
git commit -m "feat(web): MentorController(SSE 토큰 스트리밍 + KILL_SWITCH)"
```

---

## Task 3: `MentorPage` (채팅 UI)

**Files:**
- Create: `apps/web/lib/src/features/mentor/presentation/mentor_page.dart`
- Test: `apps/web/test/features/mentor/mentor_page_test.dart`

- [ ] **Step 1: 실패 테스트(빈상태 예시질문 + 전송 후 답변)**

Create `apps/web/test/features/mentor/mentor_page_test.dart`:
```dart
import 'package:devpath_web/src/features/mentor/data/mentor_sse_source.dart';
import 'package:devpath_web/src/features/mentor/presentation/mentor_page.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Stream<SseEvent> _tokens(List<String> t) async* {
  for (final x in t) {
    yield SseEvent(event: 'token', data: x);
  }
}

void main() {
  testWidgets('빈 상태 안내 + 질문 전송 시 답변 누적', (tester) async {
    final c = ProviderContainer(overrides: [
      mentorSseConnectProvider
          .overrideWithValue((q) => _tokens(['도', '움말'])),
    ]);
    addTearDown(c.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: DpTheme.light(), home: const MentorPage()),
    ));

    expect(find.textContaining('첫 질문'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '비동기란?');
    await tester.tap(find.byTooltip('전송'));
    await tester.pumpAndSettle();

    expect(find.text('비동기란?'), findsOneWidget); // 사용자 메시지
    expect(find.text('도움말'), findsOneWidget); // 누적된 답변
  });
}
```

- [ ] **Step 2: 실패 확인** — Run: `cd apps/web && flutter test test/features/mentor/mentor_page_test.dart ; cd ../..` → FAIL

- [ ] **Step 3: 구현**

Create `apps/web/lib/src/features/mentor/presentation/mentor_page.dart`:
```dart
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/mentor_controller.dart';
import '../state/mentor_state.dart';

const _kExamples = ['비동기란?', '테스트는 어떻게 작성하나요?', 'Riverpod이 뭔가요?'];

class MentorPage extends ConsumerStatefulWidget {
  const MentorPage({super.key});

  @override
  ConsumerState<MentorPage> createState() => _MentorPageState();
}

class _MentorPageState extends ConsumerState<MentorPage> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send(String q) {
    _input.clear();
    ref.read(mentorControllerProvider.notifier).send(q);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(mentorControllerProvider);
    final c = context.dpColors;

    return Scaffold(
      appBar: AppBar(title: const Text('AI 멘토')),
      body: Column(
        children: [
          if (s.status == MentorStatus.killSwitch)
            const DpKillSwitch()
          else
            Expanded(
              child: s.messages.isEmpty
                  ? _Empty(onPick: _send)
                  : ListView.builder(
                      padding: const EdgeInsets.all(DpSpacing.lg),
                      itemCount: s.messages.length,
                      itemBuilder: (_, i) => _Bubble(message: s.messages[i]),
                    ),
            ),
          if (s.status == MentorStatus.failed && s.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DpSpacing.lg),
              child: Text(s.error!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: c.danger)),
            ),
          if (s.status != MentorStatus.killSwitch) _Composer(controller: _input, onSend: _send),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onPick});
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DpEmpty(
              icon: DpIcons.mentor,
              title: '첫 질문을 해보세요',
              message: '학습 중 막힌 부분을 물어보세요.',
            ),
            Wrap(
              spacing: DpSpacing.sm,
              children: [
                for (final e in _kExamples)
                  ActionChip(label: Text(e), onPressed: () => onPick(e)),
              ],
            ),
          ],
        ),
      );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final c = context.dpColors;
    final align = message.fromUser ? Alignment.centerRight : Alignment.centerLeft;
    final bg = message.fromUser ? c.primary : c.surface;
    final fg = message.fromUser ? c.onPrimary : c.textPrimary;
    final showTyping = !message.fromUser && message.text.isEmpty;

    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: DpSpacing.xs),
        padding: const EdgeInsets.all(DpSpacing.md),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: c.border),
          borderRadius: BorderRadius.circular(DpRadius.card),
        ),
        child: showTyping
            ? const SizedBox(
                width: 24, height: 12,
                child: LinearProgressIndicator()) // 타이핑 인디케이터
            : Text(message.text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: fg)),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend});
  final TextEditingController controller;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(DpSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onSubmitted: onSend,
                decoration: const InputDecoration(
                  hintText: '질문을 입력하세요',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: DpSpacing.sm),
            IconButton.filled(
              tooltip: '전송',
              onPressed: () => onSend(controller.text),
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      );
}
```
> `Icons.send`는 임시 → `DpIcons` 이관 후속(DD3). 타이핑 인디케이터는 간소(LinearProgressIndicator).

- [ ] **Step 4: 통과 확인** — Run: `cd apps/web && flutter test test/features/mentor/mentor_page_test.dart ; cd ../..` → PASS

- [ ] **Step 5: 커밋**
```bash
git add apps/web/lib/src/features/mentor/presentation apps/web/test/features/mentor/mentor_page_test.dart
git commit -m "feat(web): MentorPage(스트리밍 채팅 + 예시질문 + 점검)"
```

---

## Task 4: `/mentor` 라우트 결선 + 검증

**Files:**
- Modify: `apps/web/lib/src/app/router.dart`(`/mentor` → `MentorPage`)

- [ ] **Step 1: 라우트 교체**

`apps/web/lib/src/app/router.dart`의 ShellRoute `/mentor` builder를 교체(import 포함):
```dart
import '../features/mentor/presentation/mentor_page.dart';
// ...
GoRoute(path: '/mentor', builder: (_, __) => const MentorPage()),
```

- [ ] **Step 2: 전체 검증**

Run (레포 루트):
```bash
melos run analyze
melos run test
```
Expected: `devpath_web` analyze 이슈 없음, 전 멤버 test PASS(골든 제외).

- [ ] **Step 3: 커밋**
```bash
git add apps/web/lib/src/app/router.dart
git commit -m "feat(web): /mentor 라우트를 MentorPage로 결선"
```

---

## 검증 기준 (Definition of Done)

- [ ] `melos run analyze`/`test` — mentor(sse-source·controller·page) PASS
- [ ] 빈 상태: "첫 질문을 해보세요" + 예시질문 칩(탭 → 전송)
- [ ] 질문 전송 → 사용자 버블 + 멘토 버블에 **토큰 스트리밍 누적**(타이핑 인디케이터 → 텍스트)
- [ ] `AI_KILL_SWITCH_ACTIVE` → `DpKillSwitch`(입력 숨김), 끊김 → 에러 문구 + 재전송 가능
- [ ] `/mentor` 라우트가 `PlaceholderPage`→`MentorPage`로 교체

## 리스크 / 후속 (명시)

- **중간 재개 단순화**: 끊김 시 "이어서"는 재요청(resend)로 단순화. SSE `id:`/`Last-Event-ID` 기반 토큰 재개는 dp_core `SseClient` 표준화 후속(P4b 리스크와 공통).
- **후속질문·세션 영속 미구현**: SUCCESS의 "후속질문" 추천, 멘토 세션 히스토리 저장은 후속(필요 시 dp_core 모델).
- **REV→멘토 연결**: P4d 리뷰의 "멘토에게 질문"으로 이 화면에 prefill 전달은 후속 결선.
- **임시 아이콘**: `Icons.send` → `DpIcons` 이관(DD3, dp_design 추가).
- **타이핑 인디케이터**: 간소(LinearProgressIndicator). DESIGN §7 정교화는 후속.
