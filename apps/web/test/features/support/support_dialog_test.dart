import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:devpath_web/src/features/support/application/support_controller.dart';
import 'package:devpath_web/src/features/support/data/support_draft.dart';
import 'package:devpath_web/src/features/support/presentation/support_dialog.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 제출 결과를 조종할 수 있는 가짜 컨트롤러.
class _FakeSupportController extends SupportController {
  _FakeSupportController(this.result);

  /// 성공이면 id, 실패면 던질 예외.
  final Object result;
  SupportDraft? lastDraft;
  SupportContext? lastContext;
  int calls = 0;

  @override
  Future<int> submit(SupportDraft draft, SupportContext context) async {
    calls++;
    lastDraft = draft;
    lastContext = context;
    if (result is int) return result as int;
    throw result;
  }
}

Future<void> _pumpHost(
  WidgetTester tester,
  _FakeSupportController fake, {
  ApiFailureLog? log,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supportControllerProvider.overrideWith(() => fake),
        if (log != null) apiFailureLogProvider.overrideWithValue(log),
      ],
      child: MaterialApp(
        theme: DpTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showSupportDialog(context),
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('빈 입력으로 제출하면 검증 메시지 — 버튼을 죽이지 않는다', (tester) async {
    final fake = _FakeSupportController(1);
    await _pumpHost(tester, fake);

    final submit = find.byKey(const ValueKey('support-submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);

    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.text('제목과 내용을 모두 입력해 주세요'), findsOneWidget);
    expect(fake.calls, 0);
  });

  testWidgets('유형을 전환할 수 있고 기본은 오류다', (tester) async {
    final fake = _FakeSupportController(7);
    await _pumpHost(tester, fake);

    await tester.enterText(find.byKey(const ValueKey('support-title')), '제목');
    await tester.enterText(find.byKey(const ValueKey('support-body')), '내용');
    await tester.tap(find.text('문의'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('support-submit')));
    await tester.pumpAndSettle();

    expect(fake.lastDraft?.type, 'INQUIRY');
  });

  testWidgets('함께 보낼 정보를 펼치면 마스킹된 실패가 보인다', (tester) async {
    final log = ApiFailureLog();
    log.add(
      ApiFailureEntry(
        method: 'POST',
        path: '/learning-paths',
        statusCode: 500,
        errorCode: 'INTERNAL_ERROR',
        message: '문의: [EMAIL]',
        occurredAt: DateTime.utc(2026, 8, 3, 10),
      ),
    );
    final fake = _FakeSupportController(1);
    await _pumpHost(tester, fake, log: log);

    expect(find.text('POST /learning-paths'), findsNothing);

    await tester.tap(find.text('함께 보낼 정보'));
    await tester.pumpAndSettle();

    expect(find.text('POST /learning-paths'), findsOneWidget);
    expect(find.textContaining('[EMAIL]'), findsOneWidget);
  });

  testWidgets('접수 실패 시 입력이 보존되고 에러가 보인다', (tester) async {
    final fake = _FakeSupportController(
      const ApiException(
        code: ApiErrorCode.network,
        message: '네트워크 연결을 확인해 주세요.',
      ),
    );
    await _pumpHost(tester, fake);

    await tester.enterText(
      find.byKey(const ValueKey('support-title')),
      '유지될 제목',
    );
    await tester.enterText(
      find.byKey(const ValueKey('support-body')),
      '유지될 내용',
    );
    await tester.tap(find.byKey(const ValueKey('support-submit')));
    await tester.pumpAndSettle();

    // 다이얼로그가 닫히지 않는다.
    expect(find.byKey(const ValueKey('support-submit')), findsOneWidget);
    expect(find.text('네트워크 연결을 확인해 주세요.'), findsOneWidget);
    // 사용자가 쓴 글을 날리지 않는다 — 제보 실패로 글을 잃으면 두 번째 사고다.
    expect(find.text('유지될 제목'), findsOneWidget);
    expect(find.text('유지될 내용'), findsOneWidget);
  });

  testWidgets('성공하면 닫힌다', (tester) async {
    final fake = _FakeSupportController(42);
    await _pumpHost(tester, fake);

    await tester.enterText(find.byKey(const ValueKey('support-title')), '제목');
    await tester.enterText(find.byKey(const ValueKey('support-body')), '내용');
    await tester.tap(find.byKey(const ValueKey('support-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('support-submit')), findsNothing);
  });
}
