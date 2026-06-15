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
    final c = ProviderContainer(
      overrides: [
        mentorSseConnectProvider.overrideWithValue(
          (q, {int fromStep = 0}) => _tokens(['도', '움말']),
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
    Stream<SseEvent> partial(String q, {int fromStep = 0}) async* {
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
}
