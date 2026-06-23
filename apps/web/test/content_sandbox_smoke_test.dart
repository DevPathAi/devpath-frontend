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

    final c = ProviderContainer(
      overrides: [
        sandboxRunConnectProvider.overrideWithValue((_, _) => _logs(['OK'])),
      ],
    );
    addTearDown(c.dispose);

    // 콘텐츠 (실제 앱은 DevPathWebApp이 항상 DpTheme를 깔아두므로 동일하게 테마 제공)
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const ContentPage(contentId: 'future-async-await'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Future/async-await 정리'), findsOneWidget);

    // Sandbox 실행
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(theme: DpTheme.light(), home: const SandboxPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('실행'));
    await tester.pumpAndSettle();
    expect(find.textContaining('OK'), findsOneWidget);
  });
}
