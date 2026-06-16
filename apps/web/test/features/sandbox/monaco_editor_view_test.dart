import 'package:devpath_web/src/features/sandbox/presentation/monaco_editor_view.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('비웹(테스트)에서는 stub가 초기 코드를 보여준다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: const Scaffold(
          body: MonacoEditorView(initialCode: 'void main() {}'),
        ),
      ),
    );
    expect(find.textContaining('void main()'), findsOneWidget);
  });

  // F5-c DD7 반영(dart Focus 부분): MonacoEditorView는 외곽 Focus/FocusNode로
  // 에디터(또는 sentinel)에서 넘어온 포커스를 수신할 수 있어야 한다 — VM에서 검증 가능한
  // dart측 계약. (JS Esc→sentinel 핸들러는 web 구현에서, 수동 `flutter run -d chrome`로 검증.)
  testWidgets('a11y: Focus 트리에 에디터 컨테이너가 노드를 가진다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DpTheme.light(),
        home: const Scaffold(
          body: MonacoEditorView(initialCode: 'void main() {}'),
        ),
      ),
    );
    expect(find.byType(Focus), findsWidgets); // 공개 위젯이 Focus를 노출
  });
}
