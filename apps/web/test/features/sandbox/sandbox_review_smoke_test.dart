import 'package:devpath_web/src/features/sandbox/presentation/sandbox_page.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 실 ai-svc엔 동기 생성(POST /reviews)이 없다 — 리뷰는 샌드박스 실행 시 Kafka로
  // 비동기 생성되고 웹은 sandboxSessionId로 폴링한다(GET /reviews?sandboxSessionId).
  // 따라서 실행(세션) 없이 수동 요청하면 생성이 아니라 "먼저 실행" 안내만 뜬다.
  testWidgets('실행 전 수동 리뷰 요청 → 세션 없음 안내(먼저 코드 실행)', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final c = ProviderContainer();
    addTearDown(c.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(theme: DpTheme.light(), home: const SandboxPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('AI 리뷰 요청'));
    await tester.pump(); // SnackBar 등장 프레임
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('먼저 코드를 실행하세요.'), findsOneWidget);
    // 세션이 없으므로 리뷰 본문(신뢰도)은 렌더되지 않는다.
    expect(find.textContaining('신뢰도'), findsNothing);
  });
}
