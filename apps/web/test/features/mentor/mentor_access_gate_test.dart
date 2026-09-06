import 'package:devpath_web/src/features/mentor/application/mentor_access_controller.dart';
import 'package:devpath_web/src/features/mentor/presentation/mentor_access_gate.dart';
import 'package:devpath_web/src/features/mentor/state/mentor_access_state.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _AccessController extends MentorAccessController {
  _AccessController(this.initial);
  final MentorAccessState initial;

  @override
  MentorAccessState build() => initial;

  @override
  Future<void> load() async {}
}

void main() {
  testWidgets('대기자는 비보장 일정 안내와 첫 미션 이동을 보고 멘토 본문은 보지 않는다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mentorAccessControllerProvider.overrideWith(
            () => _AccessController(
              const MentorAccessReady(status: 'WAITLISTED', source: 'SELF'),
            ),
          ),
        ],
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const MentorAccessGate(child: Text('MENTOR WORKSPACE')),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('AI 멘토 초대 대기 중'), findsOneWidget);
    expect(find.textContaining('준비 상황에 따라 달라질 수 있어요'), findsOneWidget);
    expect(find.textContaining('1일 안에'), findsNothing);
    expect(find.text('이번 주 미션 계속하기'), findsOneWidget);
    expect(find.text('MENTOR WORKSPACE'), findsNothing);
  });

  testWidgets('활성 사용자는 멘토 본문을 본다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mentorAccessControllerProvider.overrideWith(
            () => _AccessController(
              const MentorAccessReady(status: 'ACTIVE', source: 'BATCH'),
            ),
          ),
        ],
        child: const MaterialApp(
          home: MentorAccessGate(child: Text('MENTOR WORKSPACE')),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('MENTOR WORKSPACE'), findsOneWidget);
  });
}
