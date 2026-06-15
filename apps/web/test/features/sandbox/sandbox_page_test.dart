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

    final c = ProviderContainer(
      overrides: [
        sandboxRunConnectProvider.overrideWithValue(
          (_) => _logs(['실행 결과: OK']),
        ),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(theme: DpTheme.light(), home: const SandboxPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MonacoEditorView), findsOneWidget);
    await tester.tap(find.text('실행'));
    await tester.pumpAndSettle();
    expect(find.textContaining('실행 결과: OK'), findsOneWidget);
  });
}
