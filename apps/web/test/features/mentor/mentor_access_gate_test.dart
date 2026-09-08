import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/features/mentor/application/mentor_access_controller.dart';
import 'package:devpath_web/src/features/mentor/presentation/mentor_access_gate.dart';
import 'package:devpath_web/src/features/mentor/state/mentor_access_state.dart';
import 'package:dp_core/dp_core.dart';
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
  Future<void> load() async => loads++;

  int loads = 0;
}

const _authenticated = AuthAuthenticated(
  User(
    id: 'mentor-user',
    email: 'mentor@example.com',
    nickname: '멘토 사용자',
    role: UserRole.learner,
    onboardingStatus: OnboardingStatus.done,
    consentStatus: ConsentStatus.done,
  ),
);

class _AuthController extends AuthController {
  _AuthController(this.initial);
  final AuthState initial;

  @override
  AuthState build() => initial;

  void replace(AuthState next) => state = next;
}

Widget _host(
  _AccessController access, {
  _AuthController? auth,
  Widget child = const Text('MENTOR WORKSPACE'),
}) {
  final authController = auth ?? _AuthController(_authenticated);
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => authController),
      mentorAccessControllerProvider.overrideWith(() => access),
    ],
    child: MaterialApp(
      theme: DpTheme.light(),
      home: MentorAccessGate(child: child),
    ),
  );
}

void main() {
  testWidgets('초대 상태 확인 중에는 로딩 상태만 표시한다', (tester) async {
    final access = _AccessController(const MentorAccessLoading());
    await tester.pumpWidget(_host(access));
    await tester.pump();

    expect(find.byType(DpLoading), findsOneWidget);
    expect(find.text('MENTOR WORKSPACE'), findsNothing);
    expect(access.loads, 1);
  });

  testWidgets('인증 복원이 끝난 뒤에만 초대 상태를 조회한다', (tester) async {
    final access = _AccessController(const MentorAccessLoading());
    final auth = _AuthController(const AuthLoading());

    await tester.pumpWidget(_host(access, auth: auth));
    await tester.pump();
    expect(access.loads, 0);

    auth.replace(_authenticated);
    await tester.pump();
    await tester.pump();
    expect(access.loads, 1);
  });

  testWidgets('초대 상태 조회 실패를 설명하고 다시 시도할 수 있다', (tester) async {
    final controller = _AccessController(
      const MentorAccessFailed('초대 상태 서버에 연결할 수 없어요.'),
    );
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    expect(find.byType(DpError), findsOneWidget);
    expect(find.textContaining('초대 상태 서버에 연결할 수 없어요.'), findsOneWidget);
    expect(find.text('MENTOR WORKSPACE'), findsNothing);
    expect(controller.loads, 1, reason: '진입 시 최초 조회');

    await tester.tap(find.text('다시 시도'));
    await tester.pump();
    expect(controller.loads, 2);
  });

  testWidgets('대기자는 비보장 일정 안내와 첫 미션 이동을 보고 멘토 본문은 보지 않는다', (tester) async {
    await tester.pumpWidget(
      _host(
        _AccessController(
          const MentorAccessReady(status: 'WAITLISTED', source: 'SELF'),
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
      _host(
        _AccessController(
          const MentorAccessReady(status: 'ACTIVE', source: 'BATCH'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('MENTOR WORKSPACE'), findsOneWidget);
  });
}
