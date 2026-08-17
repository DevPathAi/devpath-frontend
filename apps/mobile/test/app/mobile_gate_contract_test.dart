import 'package:devpath_mobile/src/app/router.dart';
import 'package:devpath_mobile/src/app/app_config.dart';
import 'package:devpath_mobile/src/features/auth/application/web_activation_launcher.dart';
import 'package:devpath_mobile/src/features/auth/state/auth_state.dart';
import 'package:devpath_mobile/src/features/mission/state/mobile_mission_route.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_test/flutter_test.dart';

User _user({
  ConsentStatus consent = ConsentStatus.done,
  OnboardingStatus onboarding = OnboardingStatus.done,
}) => User(
  id: 'owner-1',
  email: 'learner@example.com',
  nickname: '지수',
  role: UserRole.learner,
  onboardingStatus: onboarding,
  consentStatus: consent,
);

void main() {
  group('mobile activation gate', () {
    test('필수 동의가 웹 activation보다 먼저다', () {
      final auth = AuthAuthenticated(
        _user(
          consent: ConsentStatus.pending,
          onboarding: OnboardingStatus.pending,
        ),
      );

      expect(gateRedirect(auth, '/home'), '/consent');
      expect(gateRedirect(auth, '/activation'), '/consent');
      expect(gateRedirect(auth, '/consent'), isNull);
    });

    test('동의 뒤 진단 미완료 계정은 native 진단이 아닌 웹 activation으로 간다', () {
      final auth = AuthAuthenticated(
        _user(onboarding: OnboardingStatus.pending),
      );

      expect(gateRedirect(auth, '/home'), '/activation');
      expect(gateRedirect(auth, '/activation'), isNull);
    });

    test('모든 gate 완료 뒤 로그인 전 보존한 canonical route를 복구한다', () {
      final auth = AuthAuthenticated(_user());
      const pending = '/mission/302/content/77';

      expect(gateRedirect(auth, '/login', pendingLocation: pending), pending);
      expect(gateRedirect(auth, pending, pendingLocation: pending), isNull);
    });

    test('세션 transport 장애는 로그인 화면으로 축소하지 않는다', () {
      const auth = AuthSessionUnavailable('네트워크 연결을 확인해 주세요.');

      expect(gateRedirect(auth, '/home'), '/session-unavailable');
      expect(gateRedirect(auth, '/session-unavailable'), isNull);
    });

    test('웹 handoff는 단계와 검증된 canonical return route만 전달한다', () {
      const config = AppConfig(
        baseUrl: 'https://api.devpath.ai',
        useMock: false,
      );
      final uri = buildWebActivationUri(
        config,
        step: WebActivationStep.consent,
        pendingLocation: '/mission/302/content/77',
      );

      expect(uri.origin, 'https://app.leva.ai.kr');
      expect(uri.path, '/consent');
      expect(
        uri.queryParameters['mobile_return_to'],
        '/mission/302/content/77',
      );
      expect(
        () => buildWebActivationUri(
          config,
          step: WebActivationStep.diagnostic,
          pendingLocation: '/review',
        ),
        throwsFormatException,
      );
    });
  });

  group('canonical mobile routes', () {
    test('Today와 Content 두 route만 양수 JS-safe ID로 허용한다', () {
      expect(
        MobileMissionRoute.tryParse('/path/301/today')?.location,
        '/path/301/today',
      );
      expect(
        MobileMissionRoute.tryParse('/mission/302/content/77')?.location,
        '/mission/302/content/77',
      );

      for (final location in [
        'https://app.leva.ai.kr/path/301/today',
        '/path/0/today',
        '/path/01/today',
        '/mission/-1/content/77',
        '/mission/302/content/9007199254740992',
        '/mission/302/sandbox',
        '/mission/302/mentor',
        '/review',
      ]) {
        expect(MobileMissionRoute.tryParse(location), isNull, reason: location);
      }
    });

    test('Universal Link는 선언된 app.leva.ai.kr origin만 허용한다', () {
      expect(
        MobileMissionRoute.tryParseUri(
          Uri.parse('https://app.leva.ai.kr/mission/302/content/77'),
        )?.location,
        '/mission/302/content/77',
      );
      expect(
        MobileMissionRoute.tryParseUri(
          Uri.parse('https://attacker.example/mission/302/content/77'),
        ),
        isNull,
      );
      for (final location in [
        'https://app.leva.ai.kr:444/mission/302/content/77',
        'https://app.leva.ai.kr/mission/302/content/77?next=/review',
        'https://app.leva.ai.kr/mission/302/content/77#mentor',
      ]) {
        expect(
          MobileMissionRoute.tryParseUri(Uri.parse(location)),
          isNull,
          reason: location,
        );
      }
    });
  });
}
