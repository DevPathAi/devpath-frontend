import 'package:devpath_web/src/features/auth/presentation/login_page.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('로그인은 AppBar 없이 헤더 + 테마 전환 버튼을 유지', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: DpTheme.light(), home: const LoginPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AppBar), findsNothing);
    final header = tester.widget<DpPageHeader>(find.byType(DpPageHeader));
    expect(header.title, '로그인');
    expect(find.byTooltip('테마 전환'), findsOneWidget);
    // T3: brandRow(context) 호출 자체를 지워도 byTooltip 단언은 깨지지 않는다
    // (버튼이 brandRow 밖으로 옮겨져도 통과한다) — brandRow의 key로 호출
    // 자체를 직접 단언한다(find.text보다 brandRow 위젯 유무에 견고하다 —
    // F4, 4화면 전부 이 형태로 통일).
    expect(find.byKey(const ValueKey('brand-row')), findsOneWidget);
    expect(find.text('Leva'), findsOneWidget);
  });
}
