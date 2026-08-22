import 'package:devpath_web/src/app/app_config.dart';
import 'package:devpath_web/src/app/router.dart';
import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/features/diagnostic/application/diagnostic_controller.dart';
import 'package:devpath_web/src/features/diagnostic/state/diagnostic_continuation.dart';
import 'package:devpath_web/src/features/diagnostic/state/diagnostic_state.dart';
import 'package:devpath_web/src/features/path/application/path_controller.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _DoneAuthController extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(
    User(
      id: '101',
      email: 'private@example.com',
      nickname: '사용자',
      role: UserRole.learner,
      onboardingStatus: OnboardingStatus.done,
      consentStatus: ConsentStatus.done,
    ),
  );

  void replace(AuthState next) => state = next;
}

class _HandoffDiagnosticController extends DiagnosticController {
  int successCalls = 0;
  int failureCalls = 0;
  int handoffCalls = 0;

  @override
  DiagnosticState build() => const DiagnosticState(
    phase: DiagnosticContinuationPhase.saved,
    track: 'BACKEND_SPRING',
    guestId: '123e4567-e89b-42d3-a456-426614174000',
    preview: AssessmentResult(diagnosedLevel: 'MID', confidenceWeight: 0.8),
    saved: true,
    pathBranch: DiagnosticPathBranch.existingActivePath,
  );

  void requestNewPath() {
    state = state.copyWith(
      pathBranch: DiagnosticPathBranch.newPath,
      pathHandoffRequested: true,
    );
  }

  void emitSavedExistingPath() {
    state = state.copyWith(busy: true);
    state = state.copyWith(
      busy: false,
      failure: null,
      pathBranch: DiagnosticPathBranch.existingActivePath,
      pathHandoffRequested: false,
    );
  }

  @override
  void completePathHandoff() {
    handoffCalls++;
    super.completePathHandoff();
  }

  @override
  void completeSuccessfulPathHandoff() {
    successCalls++;
    state = const DiagnosticState();
  }

  @override
  void markPathGenerationFailure(String? message) {
    failureCalls++;
    state = state.copyWith(
      failure: const DiagnosticFailure(
        DiagnosticFailureKind.pathGeneration,
        'path unavailable',
      ),
    );
  }
}

class _EmittingPathController extends PathController {
  int resetCalls = 0;
  int loadCalls = 0;

  @override
  PathState build() => const PathState();

  void emit(PathState next) => state = next;

  @override
  Future<void> loadOrStart() async {
    loadCalls++;
    state = const PathState(phase: PathPhase.complete);
  }

  @override
  void reset() {
    resetCalls++;
    super.reset();
  }
}

void main() {
  const missionSpineOn = AppConfig(
    baseUrl: 'https://test.devpath.ai',
    useMock: true,
    missionSpineEnabled: true,
  );

  test('router path listener는 explicit new-path handoff만 성공/실패 처리한다', () {
    final diagnostic = _HandoffDiagnosticController();
    final path = _EmittingPathController();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(missionSpineOn),
        authControllerProvider.overrideWith(_DoneAuthController.new),
        diagnosticControllerProvider.overrideWith(() => diagnostic),
        pathControllerProvider.overrideWith(() => path),
      ],
    );
    final router = container.read(routerProvider);
    addTearDown(() {
      router.dispose();
      container.dispose();
    });

    path.emit(const PathState(phase: PathPhase.complete));
    expect(diagnostic.successCalls, 0);
    expect(diagnostic.failureCalls, 0);

    diagnostic.requestNewPath();
    path.emit(
      const PathState(phase: PathPhase.failed, error: 'path unavailable'),
    );
    expect(diagnostic.failureCalls, 1);
    expect(diagnostic.successCalls, 0);

    diagnostic.requestNewPath();
    path.emit(const PathState(phase: PathPhase.complete));
    expect(diagnostic.successCalls, 1);
  });

  test(
    'router는 logout/account switch에만 user-scoped PathState를 reset한다',
    () async {
      final auth = _DoneAuthController();
      final diagnostic = _HandoffDiagnosticController();
      final createdPaths = <_EmittingPathController>[];
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(missionSpineOn),
          authControllerProvider.overrideWith(() => auth),
          diagnosticControllerProvider.overrideWith(() => diagnostic),
          pathControllerProvider.overrideWith(() {
            final path = _EmittingPathController();
            createdPaths.add(path);
            return path;
          }),
        ],
      );
      final router = container.read(routerProvider);
      addTearDown(() {
        router.dispose();
        container.dispose();
      });

      final first =
          container.read(pathControllerProvider.notifier)
              as _EmittingPathController;
      first.emit(const PathState(phase: PathPhase.complete));
      auth.replace(const AuthUnauthenticated());
      expect(container.read(pathControllerProvider).phase, PathPhase.idle);
      expect(first.resetCalls, 1);

      auth.replace(
        const AuthAuthenticated(
          User(
            id: '101',
            email: 'private@example.com',
            nickname: '사용자',
            role: UserRole.learner,
            onboardingStatus: OnboardingStatus.pending,
            consentStatus: ConsentStatus.done,
          ),
        ),
      );
      final second =
          container.read(pathControllerProvider.notifier)
              as _EmittingPathController;
      second.emit(const PathState(phase: PathPhase.complete));
      auth.replace(
        const AuthAuthenticated(
          User(
            id: '101',
            email: 'private@example.com',
            nickname: '사용자',
            role: UserRole.learner,
            onboardingStatus: OnboardingStatus.done,
            consentStatus: ConsentStatus.done,
          ),
        ),
      );
      expect(container.read(pathControllerProvider).phase, PathPhase.complete);

      auth.replace(
        const AuthAuthenticated(
          User(
            id: '202',
            email: 'other@example.com',
            nickname: '다른 사용자',
            role: UserRole.learner,
            onboardingStatus: OnboardingStatus.pending,
            consentStatus: ConsentStatus.done,
          ),
        ),
      );
      expect(container.read(pathControllerProvider).phase, PathPhase.idle);
      expect(first.resetCalls, 2);
      expect(createdPaths, hasLength(1));

      diagnostic.requestNewPath();
      await first.loadOrStart();
      expect(first.loadCalls, 1, reason: 'B는 idle state에서 자신의 path를 새로 load한다');
      expect(diagnostic.successCalls, 1);
      expect(container.read(diagnosticControllerProvider).hasPreview, isFalse);
    },
  );

  test(
    'router provider는 flag OFF만 saved result를 자동 handoff하고 ON은 explicit CTA를 기다린다',
    () async {
      for (final enabled in <bool>[false, true]) {
        final diagnostic = _HandoffDiagnosticController();
        final container = ProviderContainer(
          overrides: [
            appConfigProvider.overrideWithValue(
              AppConfig(
                baseUrl: 'https://test.devpath.ai',
                useMock: true,
                missionSpineEnabled: enabled,
              ),
            ),
            authControllerProvider.overrideWith(_DoneAuthController.new),
            diagnosticControllerProvider.overrideWith(() => diagnostic),
            pathControllerProvider.overrideWith(_EmittingPathController.new),
          ],
        );
        final router = container.read(routerProvider);

        diagnostic.emitSavedExistingPath();
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(diagnostic.handoffCalls, enabled ? 0 : 1);
        expect(
          container.read(diagnosticControllerProvider).hasPreview,
          enabled,
        );
        router.dispose();
        container.dispose();
      }
    },
  );
}
