import 'package:devpath_web/src/features/sandbox/presentation/sandbox_page.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ApiClient _reviewClient() {
  final c = ApiClient.create(const ApiConfig(baseUrl: 'https://t/api/v1'));
  c.dio.httpClientAdapter = MockHttpAdapter({
    'POST /reviews': (
      200,
      {
        'confidence': 70,
        'strengths': <String>[],
        'improvements': [
          {'line': 1, 'severity': 'warning', 'message': '예외 처리 추가'},
        ],
        'security': <Map<String, dynamic>>[],
      },
    ),
  });
  return c;
}

void main() {
  testWidgets('AI 리뷰 요청 → 신뢰도/개선 표시(넓은 화면)', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final c = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(_reviewClient())],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(theme: DpTheme.light(), home: const SandboxPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('AI 리뷰 요청'));
    await tester.pumpAndSettle();
    expect(find.textContaining('70'), findsWidgets);
    expect(find.textContaining('예외 처리 추가'), findsOneWidget);
  });
}
