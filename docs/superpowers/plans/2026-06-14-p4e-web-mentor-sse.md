# P4e — AI 멘토(MEN-001, SSE 스트리밍 채팅) (Implementation Plan)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `apps/web`에 **AI 멘토(MEN-001)** 를 TDD로 구현한다 — 질문을 보내면 답변이 **SSE 토큰 스트리밍**(토큰 append, 문자단위 금지)으로 누적되고, 빈 상태("첫 질문을 해보세요"+예시질문), 타이핑 인디케이터, `AI_KILL_SWITCH_ACTIVE`→점검 배너, 끊김 시 재시도를 처리한다(§9.2 멘토 행).

**Architecture:** P4a~d 토대 위. `mentorSseConnectProvider`(목=토큰 지연 emit / 실서버=P2 `apiClient.sse(...)` 헬퍼 경유)로 SSE 주입 — `client.dio` 직접접근 금지(D1). `MentorController`(Riverpod `Notifier`)가 메시지 리스트를 들고 스트리밍 토큰을 마지막 멘토 메시지에 append하며, 끊김 시 부분답변을 `partial`로 보존(D2). `ApiException.isKillSwitch`로 점검 분기. web `dio`-free.

**Tech Stack:** Flutter Web · flutter_riverpod 3.3 · dp_core(`apiClient.sse`·`SseEvent`·ApiException)·dp_design(DpEmpty·DpKillSwitch·DpError) · flutter_test.

---

> **선행:** P4a~d 구현 완료. `/mentor` 라우트의 `PlaceholderPage`(P4a)를 교체.
> **참조:** 스펙 §3(SSE)·§4(멘토 SSE)·§9.2(AI 멘토 행: LOADING 타이핑/EMPTY 예시질문/ERROR 끊김·KILL_SWITCH/SUCCESS 스트리밍+후속질문/PARTIAL). DESIGN.md §7(스트리밍 텍스트=토큰 append). 샘플: `Flutter_SSE_실시간_스트림_구독`.
> **YAGNI:** 후속질문(추천 follow-up)·멘토세션 영속·REV→멘토 연결은 후속. 끊김 "재개"는 재요청(resend)로 단순화(중간 토큰 재개는 SSE id 표준화 후속 — P4b 리스크와 동일).

> 🔶 **Eng Review 반영(2026-06-14, D1·D2 / F9)** — 결정 근거: [`../specs/2026-06-14-eng-review-summary.md`](../specs/2026-06-14-eng-review-summary.md)
> - **D1**: SSE 단계의 단일 출처는 P2 `SseStage`(connecting/streaming/partial/reconnecting/complete/failed). 멘토 스트리밍은 자체 enum을 갈아끼우지 않고 **DD8 단계상태를 구독·매핑**한다. `MentorStatus`에 `partial`을 추가하고(P4b `PathPhase`와 동일 정렬), feature 평행정의를 최소화(Task 2).
> - **D1**: `mentorSseConnectProvider`는 `client.dio`를 직접 만지지 않고 P2 `apiClient.sse(path, {body})` 헬퍼만 경유한다. `SseClient(client.dio)` 직접 인스턴스화 금지(Task 1).
> - **D2**: 끊김 시 부분답변을 **보존**하고(`partial`) "다시 시도/이어하기" 재전송 액션을 노출 — 전부 `failed`로 버리지 않음. 재개는 백엔드 합의 전까지 재요청(resend)로 단순화하되, 시그니처에 `fromStep`/lastToken 자리만 선확보(Task 1·2).
> - **F9**: 토큰당 visible 버블 전체 재빌드 방지 — 버블 `ValueKey` + 마지막(스트리밍 중) 메시지 분리 갱신(Task 3).

## P4e가 소비/수정하는 API

- P4a: `apiClientProvider`·`appConfigProvider`(providers), `routerProvider`(`/mentor`).
- dp_core(P2): `apiClient.sse(path, {body})`(D1 헬퍼)·`SseEvent`, `ApiException`(`isKillSwitch`).
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

/// 질문을 보내 SSE 토큰을 흘리는 함수.
/// ENG-REVIEW D2: 끊김 후 재요청 시 `fromStep`(이미 받은 토큰 수)/lastToken 자리를
/// 시그니처에 선확보 — 현재 목/실서버는 처음부터 재전송(resend)하지만, 백엔드가
/// `Last-Event-ID`/토큰 재개를 합의하면 여기로 흘려보낸다(추측 금지, 자리만 둠).
typedef MentorSseConnect = Stream<SseEvent> Function(
  String question, {
  int fromStep,
});

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
    return (question, {int fromStep = 0}) async* {
      for (final t in _kMockAnswer.sublist(fromStep.clamp(0, _kMockAnswer.length))) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        yield SseEvent(event: 'token', data: t);
      }
    };
  }
  // ENG-REVIEW D1: `client.dio`를 직접 만지지 않는다 — `SseClient(client.dio)` 직접
  // 인스턴스화 금지. P2 `apiClient.sse(path, {body})` 헬퍼만 경유한다.
  final apiClient = ref.watch(apiClientProvider);
  return (question, {int fromStep = 0}) => apiClient.sse(
        '/ai-mentor/sessions',
        body: {'message': question, 'fromStep': fromStep},
      );
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
import 'dart:async';

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
          .overrideWithValue((q, {int fromStep = 0}) => _tokens(['안녕', '하세요'])),
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
      mentorSseConnectProvider.overrideWithValue((q, {int fromStep = 0}) =>
          Stream<SseEvent>.error(const ApiException(
              code: ApiErrorCode.aiKillSwitchActive, message: '점검'))),
    ]);
    addTearDown(c.dispose);

    await c.read(mentorControllerProvider.notifier).send('질문');
    expect(c.read(mentorControllerProvider).status, MentorStatus.killSwitch);
  });

  // ENG-REVIEW D2: 끊김 시 부분답변 보존(partial) — failed로 버리지 않는다.
  test('부분 토큰 후 끊기면 status partial + 받은 토큰 보존', () async {
    Stream<SseEvent> partial(String q, {int fromStep = 0}) async* {
      yield SseEvent(event: 'token', data: '부분');
      throw Exception('연결 끊김');
    }

    final c = ProviderContainer(overrides: [
      mentorSseConnectProvider.overrideWithValue(partial),
    ]);
    addTearDown(c.dispose);

    await c.read(mentorControllerProvider.notifier).send('질문');
    final s = c.read(mentorControllerProvider);
    expect(s.status, MentorStatus.partial);
    expect(s.messages.last.text, '부분'); // 보존
  });

  // ENG-REVIEW(F9 인접): 토큰 0개로 끝나면 빈 멘토 버블이 남지 않는다.
  test('토큰 0개 onDone 시 빈 멘토 버블은 제거된다', () async {
    final c = ProviderContainer(overrides: [
      mentorSseConnectProvider
          .overrideWithValue((q, {int fromStep = 0}) => const Stream<SseEvent>.empty()),
    ]);
    addTearDown(c.dispose);

    await c.read(mentorControllerProvider.notifier).send('질문');
    final s = c.read(mentorControllerProvider);
    expect(s.status, MentorStatus.idle);
    // 사용자 버블만 — 빈 멘토 버블 잔류 없음.
    expect(s.messages, hasLength(1));
    expect(s.messages.single.fromUser, isTrue);
  });

  // ENG-REVIEW(취소 경쟁조건): 연속 send 시 잔여 콜백이 새 버블에 오append되지 않는다.
  test('연속 send: 이전 스트림의 잔여 토큰이 새 버블을 오염시키지 않는다', () async {
    final first = StreamController<SseEvent>();
    var call = 0;
    final c = ProviderContainer(overrides: [
      mentorSseConnectProvider.overrideWithValue((q, {int fromStep = 0}) {
        call++;
        return call == 1 ? first.stream : _tokens(['두번째']);
      }),
    ]);
    addTearDown(c.dispose);
    final ctrl = c.read(mentorControllerProvider.notifier);

    final f1 = ctrl.send('첫'); // 미완 스트림(보류)
    await ctrl.send('둘'); // 새 send → 첫 구독 취소
    first.add(SseEvent(event: 'token', data: '늦은토큰')); // 잔여 콜백
    await first.close();
    await f1;

    final s = c.read(mentorControllerProvider);
    // 둘째 답변 버블이 '늦은토큰'으로 오염되지 않음.
    expect(s.messages.last.text, '두번째');
    expect(s.messages.map((m) => m.text), isNot(contains('늦은토큰')));
  });
}
```

- [ ] **Step 2: 실패 확인** — Run: `cd apps/web && flutter test test/features/mentor/mentor_controller_test.dart ; cd ../..` → FAIL

- [ ] **Step 3: 구현 — `mentor_state.dart`**

Create `apps/web/lib/src/features/mentor/state/mentor_state.dart`:
```dart
/// 멘토 스트리밍 상태. ENG-REVIEW D1: P2 `SseStage`
/// (connecting/streaming/partial/reconnecting/complete/failed)를 단일 출처로 두고
/// 멘토가 **구독·매핑**한다 — 여기 enum은 그 평행정의를 최소화한 멘토 뷰 모델이며,
/// `partial`은 P4b `PathPhase.partial`과 동일 의미(끊김 시 부분답변 보존 + 재전송 가능).
enum MentorStatus { idle, streaming, partial, killSwitch, failed }

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

  /// 마지막으로 보낸 질문 — partial 끊김 후 "다시 시도"(재전송)용.
  String? _lastQuestion;

  Future<void> send(String question) {
    if (question.trim().isEmpty) return Future.value();
    _sub?.cancel();
    _lastQuestion = question;
    final done = Completer<void>();

    final msgs = [
      ...state.messages,
      ChatMessage(fromUser: true, text: question),
      const ChatMessage(fromUser: false, text: ''),
    ];
    state = MentorState(messages: msgs, status: MentorStatus.streaming);

    // ENG-REVIEW(취소 경쟁조건): 토큰 대상 인덱스를 send 시점에 클로저로 캡처한다.
    // 연속 send 시 이전 스트림의 잔여 콜백이 새 멘토 버블(state.messages.last)에
    // 오append되는 것을 막는다 — append 대상은 항상 이 send가 만든 버블(targetIndex).
    final targetIndex = msgs.length - 1;

    _sub = ref.read(mentorSseConnectProvider)(question).listen(
      (e) {
        // 이 send가 만든 버블이 아직 마지막일 때만 갱신(취소된 잔여 콜백 무시).
        if (state.messages.length <= targetIndex) return;
        final m = [...state.messages];
        m[targetIndex] = m[targetIndex].append(e.data);
        state = MentorState(messages: m, status: MentorStatus.streaming);
      },
      onError: (Object err) {
        final isKill = err is ApiException && err.isKillSwitch;
        // ENG-REVIEW D2: 부분답변은 보존하고 재전송 가능한 partial로 둔다.
        // KILL_SWITCH만 점검 분기 — 나머지 끊김은 partial(다시 시도) / API 에러는 failed.
        final MentorStatus status;
        if (isKill) {
          status = MentorStatus.killSwitch;
        } else if (err is ApiException) {
          status = MentorStatus.failed;
        } else {
          status = MentorStatus.partial; // 네트워크 끊김 — 부분답변 보존
        }
        state = MentorState(
          messages: _pruneEmptyMentorBubble(state.messages, targetIndex),
          status: status,
          error: err is ApiException ? err.message : '연결이 끊겼어요',
        );
        if (!done.isCompleted) done.complete();
      },
      onDone: () {
        // ENG-REVIEW(빈/부분 버블 잔류): 토큰 0개로 끝나면 빈 멘토 버블을 제거한다.
        state = MentorState(
          messages: _pruneEmptyMentorBubble(state.messages, targetIndex),
          status: MentorStatus.idle,
        );
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );

    return done.future;
  }

  /// 끊김/완료 시 [targetIndex]의 멘토 버블이 비어 있으면 제거(빈 버블 잔류 방지).
  List<ChatMessage> _pruneEmptyMentorBubble(List<ChatMessage> msgs, int targetIndex) {
    if (targetIndex < msgs.length &&
        !msgs[targetIndex].fromUser &&
        msgs[targetIndex].text.isEmpty) {
      return [...msgs]..removeAt(targetIndex);
    }
    return msgs;
  }

  /// partial 끊김 후 "다시 시도" — 마지막 질문을 재전송(resend).
  /// ENG-REVIEW D2: 토큰 단위 재개(Last-Event-ID)는 백엔드 합의 후속. 현재는 resend.
  Future<void> retry() {
    final q = _lastQuestion;
    if (q == null) return Future.value();
    return send(q);
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
          .overrideWithValue((q, {int fromStep = 0}) => _tokens(['도', '움말'])),
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

  // ENG-REVIEW D2: 끊김(partial) 시 부분답변 + "다시 시도" 재전송 버튼 노출.
  testWidgets('끊김 시 부분답변 보존 + "다시 시도" 노출', (tester) async {
    Stream<SseEvent> partial(String q, {int fromStep = 0}) async* {
      yield SseEvent(event: 'token', data: '부분응답');
      throw Exception('끊김');
    }

    final c = ProviderContainer(overrides: [
      mentorSseConnectProvider.overrideWithValue(partial),
    ]);
    addTearDown(c.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(theme: DpTheme.light(), home: const MentorPage()),
    ));

    await tester.enterText(find.byType(TextField), '비동기란?');
    await tester.tap(find.byTooltip('전송'));
    await tester.pumpAndSettle();

    expect(find.text('부분응답'), findsOneWidget); // 부분답변 보존
    expect(find.text('다시 시도'), findsOneWidget); // 재전송 액션
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
                      // ENG-REVIEW F9: 각 버블에 ValueKey 부여 + 스트리밍 중(마지막) 버블만
                      // 변하는 텍스트를 들고 갱신. 토큰당 visible 버블 전체 재빌드 방지 —
                      // 완료된 앞쪽 버블은 동일 Key·동일 text라 element 재사용(rebuild 스킵).
                      itemBuilder: (_, i) {
                        final isStreamingTail =
                            i == s.messages.length - 1 && s.status == MentorStatus.streaming;
                        return _Bubble(
                          key: ValueKey('msg-$i-${s.messages[i].fromUser}'),
                          message: s.messages[i],
                          // 스트리밍 꼬리만 텍스트가 자주 바뀜을 명시(앞쪽은 안정).
                          isStreamingTail: isStreamingTail,
                        );
                      },
                    ),
            ),
          // ENG-REVIEW D2: 끊김(partial) → 부분답변 보존 안내 + "다시 시도"(재전송) 버튼.
          if (s.status == MentorStatus.partial)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: DpSpacing.lg, vertical: DpSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(s.error ?? '연결이 끊겼어요. 부분답변을 받았어요.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: c.warning)),
                  ),
                  const SizedBox(width: DpSpacing.sm),
                  TextButton(
                    onPressed: () =>
                        ref.read(mentorControllerProvider.notifier).retry(),
                    child: const Text('다시 시도'),
                  ),
                ],
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
          // ENG-REVIEW(P3): 응답 완료(idle) 시 후속질문 슬롯 — 자리표시만.
          // 후속질문 *추천*(서버 payload 기반)은 후속(리스크 절 참조).
          if (s.status == MentorStatus.idle && s.messages.isNotEmpty)
            const _FollowUpSlot(),
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
  const _Bubble({super.key, required this.message, this.isStreamingTail = false});
  final ChatMessage message;

  /// 스트리밍 중인 마지막 멘토 버블 여부(F9: 자주 갱신되는 유일한 버블).
  final bool isStreamingTail;

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

/// 응답 완료 후 후속질문 슬롯 — ENG-REVIEW(P3 수용): 자리표시만 둔다.
/// 후속질문 *추천*(서버가 내려주는 follow-up payload 렌더)은 후속. 와이어 미명세라
/// 추측하지 않고 자리만 확보(리스크 절 참조).
class _FollowUpSlot extends StatelessWidget {
  const _FollowUpSlot();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: DpSpacing.lg),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('후속질문 추천은 후속',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: context.dpColors.textSecondary)),
        ),
      );
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
              icon: const Icon(DpIcons.send),
            ),
          ],
        ),
      );
}
```
> P4e 아이콘: `DpIcons.send`(Symbols, P3 추가) 사용 — DD3 준수. 타이핑 인디케이터는 간소(LinearProgressIndicator).

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
- [ ] **(F9)** 각 버블에 `ValueKey` + 스트리밍 꼬리만 분리 갱신 — 토큰당 visible 버블 전체 재빌드 없음
- [ ] **(D2)** 끊김 시 부분답변 **보존**(`partial`) + "다시 시도"(재전송) 버튼 노출 — 단위·위젯 테스트로 실증
- [ ] **(빈/부분 버블)** 토큰 0개 onDone/끊김 시 빈 멘토 버블 제거(멀티턴 잔류 없음)
- [ ] **(취소 경쟁조건)** 연속 send 시 잔여 콜백이 새 버블에 오append되지 않음(send 시점 `targetIndex` 캡처) — 테스트로 실증
- [ ] `AI_KILL_SWITCH_ACTIVE` → `DpKillSwitch`(입력 숨김), API 에러 → `failed` 문구
- [ ] 응답 완료(idle) 시 후속질문 **슬롯 자리표시**(추천 렌더는 후속)
- [ ] `/mentor` 라우트가 `PlaceholderPage`→`MentorPage`로 교체

## 리스크 / 후속 (명시)

- **실서버 SSE 와이어 미정의(ENG-REVIEW UNRESOLVED)**: 멘토 토큰의 **event 이름**(`token` 가정)·**완료(DONE) 마커**·**후속질문 payload** 형식이 백엔드와 미합의 상태다. 목은 `SseEvent(event:'token')`로 가정하나 실서버 분기(`apiClient.sse('/ai-mentor/sessions')`)는 프로토에선 미실행 — 실연동 시 토큰 이벤트/DONE/후속질문 스키마를 백엔드와 합의해 매핑한다(추측 금지, 합의 전까지 자리만 둠).
- **중간 재개 단순화**: 끊김 시 "다시 시도"는 재요청(resend)로 단순화. SSE `id:`/`Last-Event-ID` 기반 토큰 재개는 dp_core `SseClient` 표준화 + 백엔드 합의 후속(P4b 리스크와 공통). 소스 시그니처에 `fromStep` 자리만 선확보.
- **후속질문 슬롯만(P3 수용)**: 응답 완료(idle) 시 후속질문 **자리표시 슬롯**(`_FollowUpSlot`)만 둔다. 서버 follow-up payload 기반 *추천* 렌더와 멘토 세션 히스토리 저장은 후속(필요 시 dp_core 모델). 와이어 미명세라 추측하지 않는다.
- **REV→멘토 연결**: P4d 리뷰의 "멘토에게 질문"으로 이 화면에 prefill 전달은 후속 결선.
- **아이콘**: ✅ 반영 — `DpIcons.send`(Symbols, P3 추가)로 교체. DD3 준수.
- **타이핑 인디케이터**: 간소(LinearProgressIndicator). DESIGN §7 정교화는 후속.
