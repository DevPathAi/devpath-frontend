import 'dart:convert';

import 'package:devpath_web/src/features/mentor/application/mentor_controller.dart';
import 'package:devpath_web/src/features/mentor/data/mentor_sse_source.dart';
import 'package:devpath_web/src/features/mentor/presentation/mentor_page.dart';
import 'package:devpath_web/src/features/mentor/state/mentor_state.dart';
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

void main() {
  testWidgets('빈 상태 안내 + 질문 전송 시 답변 누적', (tester) async {
    final c = ProviderContainer(
      overrides: [
        mentorSseConnectProvider.overrideWithValue(
          (q, {String? contentId, int fromStep = 0}) => _tokens(['도', '움말']),
        ),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(theme: DpTheme.light(), home: const MentorPage()),
      ),
    );

    expect(find.textContaining('첫 질문'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '비동기란?');
    await tester.tap(find.byTooltip('전송'));
    await tester.pumpAndSettle();

    expect(find.text('비동기란?'), findsOneWidget); // 사용자 메시지
    expect(find.text('도움말'), findsOneWidget); // 누적된 답변
  });

  // ENG-REVIEW D2: 끊김(partial) 시 부분답변 + "다시 시도" 재전송 버튼 노출.
  testWidgets('끊김 시 부분답변 보존 + "다시 시도" 노출', (tester) async {
    Stream<SseEvent> partial(
      String q, {
      String? contentId,
      int fromStep = 0,
    }) async* {
      yield SseEvent(event: 'token', data: '부분응답');
      throw Exception('끊김');
    }

    final c = ProviderContainer(
      overrides: [mentorSseConnectProvider.overrideWithValue(partial)],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(theme: DpTheme.light(), home: const MentorPage()),
      ),
    );

    await tester.enterText(find.byType(TextField), '비동기란?');
    await tester.tap(find.byTooltip('전송'));
    await tester.pumpAndSettle();

    expect(find.text('부분응답'), findsOneWidget); // 부분답변 보존
    expect(find.text('다시 시도'), findsOneWidget); // 재전송 액션
  });

  testWidgets('참고자료 references 도착 시 칩으로 렌더', (tester) async {
    Stream<SseEvent> withRefs(
      String q, {
      String? contentId,
      int fromStep = 0,
    }) async* {
      yield SseEvent(event: 'token', data: '답변본문');
      yield SseEvent(
        event: 'references',
        data: jsonEncode(const [
          {'contentId': 9, 'slug': 'streams', 'title': 'Stream 가이드'},
        ]),
      );
    }

    final c = ProviderContainer(
      overrides: [mentorSseConnectProvider.overrideWithValue(withRefs)],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(theme: DpTheme.light(), home: const MentorPage()),
      ),
    );

    await tester.enterText(find.byType(TextField), '비동기란?');
    await tester.tap(find.byTooltip('전송'));
    await tester.pumpAndSettle();

    expect(find.text('답변본문'), findsOneWidget); // 답변 누적
    expect(find.text('참고자료'), findsOneWidget); // 패널 헤더
    expect(find.text('Stream 가이드'), findsOneWidget); // 참고자료 칩(제목)
  });

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

    expect(ctrl.position.pixels, closeTo(ctrl.position.maxScrollExtent, 1.0));
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
}
