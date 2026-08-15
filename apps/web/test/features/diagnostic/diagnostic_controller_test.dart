import 'dart:async';

import 'package:devpath_web/src/analytics/journey_analytics.dart';
import 'package:devpath_web/src/analytics/journey_handoff.dart';
import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/features/diagnostic/application/diagnostic_controller.dart';
import 'package:devpath_web/src/features/diagnostic/application/claim_analytics_receipt.dart';
import 'package:devpath_web/src/features/diagnostic/application/guest_claim_storage.dart';
import 'package:devpath_web/src/features/diagnostic/state/diagnostic_continuation.dart';
import 'package:devpath_web/src/features/diagnostic/state/diagnostic_state.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _guestId = '123e4567-e89b-42d3-a456-426614174000';
const _journeyId = 'AQIDBAUGBwgJCgsMDQ4PEA';
const _preview = AssessmentResult(diagnosedLevel: 'MID', confidenceWeight: 0.8);
final _now = DateTime.utc(2026, 8, 15, 9);

User _user({
  String id = '101',
  ConsentStatus consent = ConsentStatus.done,
  OnboardingStatus onboarding = OnboardingStatus.pending,
}) => User(
  id: id,
  email: 'private@example.com',
  nickname: '비공개',
  role: UserRole.learner,
  onboardingStatus: onboarding,
  consentStatus: consent,
);

class _FakeApi implements AssessmentApi {
  int startGuestCalls = 0;
  int startMemberCalls = 0;
  int claimCalls = 0;
  int resultCalls = 0;
  int nextCalls = 0;
  int answerCalls = 0;
  int completeCalls = 0;
  ApiException? claimError;
  ApiException? nextError;
  Object? startGuestFailure;
  Object? startMemberFailure;
  Object? nextFailure;
  Object? answerFailure;
  Object? completeFailure;
  Object? claimFailure;
  Object? resultFailure;
  void Function()? beforeComplete;
  bool completeCommitThenLoseResponseOnce = false;
  bool claimCommitThenLoseResponseOnce = false;
  int completeCommits = 0;
  int claimCommits = 0;
  bool _completeAlreadyCommitted = false;
  bool _claimAlreadyCommitted = false;
  AssessmentResult claimedResult = _preview;
  List<NextQuestion?> nextResponses = <NextQuestion?>[null];
  List<String> guestIds = <String>[_guestId];
  List<int> claimIds = <int>[77];
  Completer<int>? claimCompleter;
  Completer<AssessmentResult>? resultCompleter;
  String? lastAnswer;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<String> startGuest(String track) async {
    startGuestCalls++;
    if (startGuestFailure case final failure?) throw failure;
    return guestIds.length == 1 ? guestIds.single : guestIds.removeAt(0);
  }

  @override
  Future<int> startMember(String track) async {
    startMemberCalls++;
    if (startMemberFailure case final failure?) throw failure;
    return 88;
  }

  @override
  Future<NextQuestion?> next({int? assessmentId, String? guestId}) async {
    nextCalls++;
    if (nextError case final error?) throw error;
    if (nextFailure case final failure?) throw failure;
    return nextResponses.isEmpty ? null : nextResponses.removeAt(0);
  }

  @override
  Future<void> answer({
    int? assessmentId,
    String? guestId,
    required int questionId,
    String? answer,
    required bool skipped,
    int? timeSpentSec,
  }) async {
    answerCalls++;
    lastAnswer = answer;
    if (answerFailure case final failure?) throw failure;
  }

  @override
  Future<AssessmentResult> complete({
    int? assessmentId,
    String? guestId,
  }) async {
    completeCalls++;
    beforeComplete?.call();
    if (completeCommitThenLoseResponseOnce) {
      if (!_completeAlreadyCommitted) {
        _completeAlreadyCommitted = true;
        completeCommits++;
        throw const ApiException(
          code: ApiErrorCode.network,
          message: 'complete response lost after commit',
        );
      }
      return _preview;
    }
    if (completeFailure case final failure?) throw failure;
    completeCommits++;
    return _preview;
  }

  @override
  Future<int> claim(String guestAssessmentId) async {
    claimCalls++;
    if (claimCommitThenLoseResponseOnce) {
      if (!_claimAlreadyCommitted) {
        _claimAlreadyCommitted = true;
        claimCommits++;
        throw const ApiException(
          code: ApiErrorCode.network,
          message: 'claim response lost after commit',
        );
      }
      return claimIds.single;
    }
    if (claimError case final error?) throw error;
    if (claimFailure case final failure?) throw failure;
    if (claimCompleter != null) return claimCompleter!.future;
    claimCommits++;
    return claimIds.length == 1 ? claimIds.single : claimIds.removeAt(0);
  }

  @override
  Future<AssessmentResult> result(int assessmentId) async {
    resultCalls++;
    if (resultFailure case final failure?) throw failure;
    if (resultCompleter case final completer?) return completer.future;
    return claimedResult;
  }
}

class _FakeStorage implements GuestClaimStorage {
  _FakeStorage([this.value, this.throwOnWrite = false]);

  String? value;
  final bool throwOnWrite;
  int clearCount = 0;
  int writeCount = 0;

  @override
  String? read() => value;

  @override
  void write(String raw) {
    writeCount++;
    if (throwOnWrite) throw StateError('session storage denied');
    value = raw;
  }

  @override
  void clear() {
    clearCount++;
    value = null;
  }
}

class _FakeClaimAnalyticsReceiptStore implements ClaimAnalyticsReceiptStore {
  _FakeClaimAnalyticsReceiptStore({
    this.throwOnContains = false,
    this.throwOnRecord = false,
  });

  final bool throwOnContains;
  final bool throwOnRecord;
  final receipts = <String>{};

  @override
  bool contains(String receiptId) {
    if (throwOnContains) throw StateError('receipt read denied');
    return receipts.contains(receiptId);
  }

  @override
  void record(String receiptId) {
    if (throwOnRecord) throw StateError('receipt write denied');
    receipts.add(receiptId);
  }
}

class _AuthHarness extends AuthController {
  _AuthHarness(this.initial);

  final AuthState initial;
  int loginCalls = 0;
  Completer<void>? loginCompleter;
  Object? loginFailure;

  @override
  AuthState build() => initial;

  @override
  Future<void> login({String provider = 'github'}) async {
    loginCalls++;
    if (loginFailure case final failure?) throw failure;
    if (loginCompleter case final completer?) await completer.future;
  }

  void replace(AuthState next) => state = next;
}

class _SpyAnalytics implements JourneyAnalytics {
  final events = <(String, Map<String, Object?>)>[];

  @override
  AnalyticsCaptureStatus capture(
    String event,
    Map<String, Object?> properties,
  ) {
    events.add((event, properties));
    return AnalyticsCaptureStatus.accepted;
  }

  @override
  bool identify(String userId) => true;

  @override
  void reset() {}

  @override
  void setOptedOut(bool optedOut) {}
}

ProviderContainer _container({
  required _FakeApi api,
  required _FakeStorage storage,
  required _AuthHarness auth,
  DiagnosticPathBranch pathBranch = DiagnosticPathBranch.newPath,
  Object? pathError,
  _SpyAnalytics? analytics,
  DateTime Function()? clock,
  JourneyIdStore? journeyStore,
  ClaimAnalyticsReceiptStore? claimReceiptStore,
  String Function()? idGenerator,
  DiagnosticCurrentPathProbe? pathProbe,
}) {
  final resolvedJourneyStore =
      journeyStore ?? (MemoryJourneyIdStore()..write(_journeyId));
  return ProviderContainer(
    overrides: [
      assessmentApiProvider.overrideWithValue(api),
      guestClaimStorageProvider.overrideWithValue(storage),
      claimAnalyticsReceiptStoreProvider.overrideWithValue(
        claimReceiptStore ?? _FakeClaimAnalyticsReceiptStore(),
      ),
      authControllerProvider.overrideWith(() => auth),
      diagnosticClockProvider.overrideWithValue(clock ?? () => _now),
      diagnosticCurrentPathProbeProvider.overrideWithValue(
        pathProbe ??
            () async {
              if (pathError != null) throw pathError;
              return pathBranch;
            },
      ),
      journeyIdStoreProvider.overrideWithValue(resolvedJourneyStore),
      if (idGenerator != null)
        analyticsIdGeneratorProvider.overrideWithValue(idGenerator),
      journeyAnalyticsProvider.overrideWithValue(analytics ?? _SpyAnalytics()),
    ],
  );
}

class _ThrowingJourneyStore implements JourneyIdStore {
  @override
  String? read() => throw StateError('journey read denied');

  @override
  void write(String journeyId) => throw StateError('journey write denied');

  @override
  void clear() {}
}

String _stored(
  DiagnosticContinuationPhase phase, {
  DateTime? expiresAt,
  AssessmentResult preview = _preview,
  String guestId = _guestId,
}) => encodeDiagnosticContinuation(
  DiagnosticContinuation(
    guestId: phase == DiagnosticContinuationPhase.track ? null : guestId,
    track: 'BACKEND_SPRING',
    preview: switch (phase) {
      DiagnosticContinuationPhase.track ||
      DiagnosticContinuationPhase.questions => null,
      _ => preview,
    },
    expiresAt: expiresAt ?? _now.add(diagnosticContinuationTtl),
    returnStage: phase,
    journeyId: _journeyId,
  ),
);

void main() {
  test('guest complete 성공은 로그인 전에 실제 preview를 보존해 렌더 상태로 둔다', () async {
    final api = _FakeApi();
    final storage = _FakeStorage();
    final analytics = _SpyAnalytics();
    final container = _container(
      api: api,
      storage: storage,
      auth: _AuthHarness(const AuthUnauthenticated()),
      analytics: analytics,
    );
    addTearDown(container.dispose);
    final controller = container.read(diagnosticControllerProvider.notifier);

    await controller.startAsGuest('BACKEND_SPRING');

    final state = container.read(diagnosticControllerProvider);
    expect(state.phase, DiagnosticContinuationPhase.preview);
    expect(state.preview, _preview);
    expect(state.saved, isFalse);
    expect(storage.value, isNotNull);
    expect(
      decodeDiagnosticContinuation(storage.value!, now: _now).value?.preview,
      _preview,
    );
    final started = analytics.events
        .where((event) => event.$1 == 'diagnostic_started')
        .single;
    expect(started.$2, {'track': 'BACKEND_SPRING', 'guest_id': _guestId});
  });

  test('live guest complete는 factual duration으로 정확히 한 번 기록한다', () async {
    var clock = _now;
    final api = _FakeApi()
      ..beforeComplete = () => clock = clock.add(const Duration(seconds: 5));
    final analytics = _SpyAnalytics();
    final container = _container(
      api: api,
      storage: _FakeStorage(),
      auth: _AuthHarness(const AuthUnauthenticated()),
      analytics: analytics,
      clock: () => clock,
    );
    addTearDown(container.dispose);

    await container
        .read(diagnosticControllerProvider.notifier)
        .startAsGuest('BACKEND_SPRING');
    await container.read(diagnosticControllerProvider.notifier).resume();

    final completed = analytics.events
        .where((event) => event.$1 == 'diagnostic_completed')
        .toList();
    expect(completed, hasLength(1));
    expect(completed.single.$2, {
      'guest_id': _guestId,
      'diagnosed_level': 'MID',
      'duration_ms': 5000,
    });
  });

  test('reload된 guest preview는 diagnostic_completed를 합성하지 않는다', () async {
    final analytics = _SpyAnalytics();
    final container = _container(
      api: _FakeApi(),
      storage: _FakeStorage(_stored(DiagnosticContinuationPhase.preview)),
      auth: _AuthHarness(const AuthUnauthenticated()),
      analytics: analytics,
    );
    addTearDown(container.dispose);

    await container.read(diagnosticControllerProvider.notifier).resume();

    expect(
      analytics.events.where((event) => event.$1 == 'diagnostic_completed'),
      isEmpty,
    );
  });

  test('guest/member 시작 event는 각각 허용된 factual 식별자로 parity를 유지한다', () async {
    final guestAnalytics = _SpyAnalytics();
    final guestContainer = _container(
      api: _FakeApi(),
      storage: _FakeStorage(),
      auth: _AuthHarness(const AuthUnauthenticated()),
      analytics: guestAnalytics,
    );
    final memberAnalytics = _SpyAnalytics();
    final memberContainer = _container(
      api: _FakeApi(),
      storage: _FakeStorage(),
      auth: _AuthHarness(AuthAuthenticated(_user())),
      analytics: memberAnalytics,
    );
    addTearDown(guestContainer.dispose);
    addTearDown(memberContainer.dispose);

    await guestContainer
        .read(diagnosticControllerProvider.notifier)
        .startAsGuest('BACKEND_SPRING');
    await memberContainer
        .read(diagnosticControllerProvider.notifier)
        .startAsMember('BACKEND_SPRING');

    expect(guestAnalytics.events.first.$1, 'diagnostic_started');
    expect(guestAnalytics.events.first.$2, {
      'track': 'BACKEND_SPRING',
      'guest_id': _guestId,
    });
    expect(memberAnalytics.events.first.$1, 'diagnostic_started');
    expect(memberAnalytics.events.first.$2, {
      'track': 'BACKEND_SPRING',
      'assessment_id': 88,
    });
  });

  test('명시적 저장 CTA 전에는 auth/claim을 시작하지 않는다', () async {
    final auth = _AuthHarness(const AuthUnauthenticated());
    final api = _FakeApi();
    final container = _container(
      api: api,
      storage: _FakeStorage(_stored(DiagnosticContinuationPhase.preview)),
      auth: auth,
    );
    addTearDown(container.dispose);
    final controller = container.read(diagnosticControllerProvider.notifier);

    await controller.resume();
    expect(api.claimCalls, 0);
    expect(auth.loginCalls, 0);

    await controller.saveAndContinue();
    expect(
      container.read(diagnosticControllerProvider).phase,
      DiagnosticContinuationPhase.auth,
    );
    expect(auth.loginCalls, 1);
    expect(api.claimCalls, 0);
  });

  test('인증 후 필수 동의가 끝나기 전에는 claim하지 않는다', () async {
    final auth = _AuthHarness(
      AuthAuthenticated(_user(consent: ConsentStatus.pending)),
    );
    final api = _FakeApi();
    final storage = _FakeStorage(_stored(DiagnosticContinuationPhase.auth));
    final container = _container(api: api, storage: storage, auth: auth);
    addTearDown(container.dispose);
    final controller = container.read(diagnosticControllerProvider.notifier);

    await controller.resume();

    expect(
      container.read(diagnosticControllerProvider).phase,
      DiagnosticContinuationPhase.consent,
    );
    expect(api.claimCalls, 0);
    expect(storage.value, contains('"returnStage":"consent"'));
  });

  test('consent 이후 callback/retry가 겹쳐도 claim 한 번만 실행하고 preview가 같다', () async {
    final auth = _AuthHarness(AuthAuthenticated(_user()));
    final api = _FakeApi()..claimCompleter = Completer<int>();
    final storage = _FakeStorage(_stored(DiagnosticContinuationPhase.claim));
    final container = _container(
      api: api,
      storage: storage,
      auth: auth,
      pathBranch: DiagnosticPathBranch.existingActivePath,
    );
    addTearDown(container.dispose);
    final controller = container.read(diagnosticControllerProvider.notifier);
    final before = container.read(diagnosticControllerProvider).preview;

    final first = controller.resume();
    final replay = controller.claimAfterLogin();
    await Future<void>.delayed(Duration.zero);
    expect(api.claimCalls, 1);
    api.claimCompleter!.complete(77);
    await Future.wait([first, replay]);

    final state = container.read(diagnosticControllerProvider);
    expect(state.phase, DiagnosticContinuationPhase.saved);
    expect(state.saved, isTrue);
    expect(state.preview, before);
    expect(state.pathBranch, DiagnosticPathBranch.existingActivePath);
    expect(storage.value, isNotNull, reason: 'explicit handoff 전에는 지우지 않는다');
    final updatedAuth = container.read(authControllerProvider);
    expect(
      (updatedAuth as AuthAuthenticated).user.onboardingStatus,
      OnboardingStatus.done,
    );

    await controller.claimAfterLogin();
    expect(
      api.claimCalls,
      1,
      reason: 'saved 뒤 callback replay는 claim을 다시 보내지 않는다',
    );
  });

  test(
    'reload된 saved는 same-owner claim 재검증 전 현재 user를 DONE으로 만들지 않는다',
    () async {
      final auth = _AuthHarness(AuthAuthenticated(_user()));
      final api = _FakeApi()
        ..claimError = const ApiException(
          code: ApiErrorCode.forbidden,
          message: 'different owner',
          status: 403,
        );
      final storage = _FakeStorage(_stored(DiagnosticContinuationPhase.saved));
      final container = _container(api: api, storage: storage, auth: auth);
      addTearDown(container.dispose);

      await container.read(diagnosticControllerProvider.notifier).resume();

      final state = container.read(diagnosticControllerProvider);
      expect(api.claimCalls, 1);
      expect(state.preview, _preview);
      expect(state.saved, isFalse);
      expect(state.failure?.kind, DiagnosticFailureKind.ownership);
      expect(
        (container.read(authControllerProvider) as AuthAuthenticated)
            .user
            .onboardingStatus,
        OnboardingStatus.pending,
      );
    },
  );

  test('claim 실패와 ownership mismatch는 preview를 유지한 별도 오류다', () async {
    for (final entry in <(ApiException, DiagnosticFailureKind)>[
      (
        const ApiException(code: ApiErrorCode.network, message: 'offline'),
        DiagnosticFailureKind.claim,
      ),
      (
        const ApiException(
          code: ApiErrorCode.forbidden,
          message: 'forbidden',
          status: 403,
        ),
        DiagnosticFailureKind.ownership,
      ),
      (
        const ApiException(
          code: ApiErrorCode.resourceNotFound,
          message: 'expired',
          status: 404,
        ),
        DiagnosticFailureKind.guestExpired,
      ),
    ]) {
      final api = _FakeApi()..claimError = entry.$1;
      final storage = _FakeStorage(_stored(DiagnosticContinuationPhase.claim));
      final container = _container(
        api: api,
        storage: storage,
        auth: _AuthHarness(AuthAuthenticated(_user())),
      );

      await container.read(diagnosticControllerProvider.notifier).resume();

      final state = container.read(diagnosticControllerProvider);
      expect(state.preview, _preview);
      expect(state.failure?.kind, entry.$2);
      expect(
        storage.value,
        entry.$2 == DiagnosticFailureKind.guestExpired ? isNull : isNotNull,
      );
      container.dispose();
    }
  });

  test('claim 성공 뒤 path 확인 실패도 saved preview를 지우지 않는다', () async {
    final storage = _FakeStorage(_stored(DiagnosticContinuationPhase.claim));
    final container = _container(
      api: _FakeApi(),
      storage: storage,
      auth: _AuthHarness(AuthAuthenticated(_user())),
      pathError: const ApiException(
        code: ApiErrorCode.network,
        message: 'path unavailable',
      ),
    );
    addTearDown(container.dispose);

    await container.read(diagnosticControllerProvider.notifier).resume();

    final state = container.read(diagnosticControllerProvider);
    expect(state.phase, DiagnosticContinuationPhase.saved);
    expect(state.preview, _preview);
    expect(state.failure?.kind, DiagnosticFailureKind.pathGeneration);
    expect(storage.value, isNotNull);
  });

  test(
    'path probe와 continuation write가 함께 실패해도 domain retry를 덮지 않는다',
    () async {
      final storage = _FakeStorage(
        _stored(DiagnosticContinuationPhase.claim),
        true,
      );
      final container = _container(
        api: _FakeApi(),
        storage: storage,
        auth: _AuthHarness(AuthAuthenticated(_user())),
        pathError: const FormatException('raw malformed path'),
      );
      addTearDown(container.dispose);

      await container.read(diagnosticControllerProvider.notifier).resume();

      final state = container.read(diagnosticControllerProvider);
      expect(state.preview, _preview);
      expect(state.saved, isTrue);
      expect(state.failure?.kind, DiagnosticFailureKind.pathGeneration);
      expect(state.busy, isFalse);
      expect(storage.clearCount, 0);
    },
  );

  test('실제 새 path 생성 실패도 saved preview와 retry handoff를 유지한다', () async {
    final storage = _FakeStorage(_stored(DiagnosticContinuationPhase.saved));
    final container = _container(
      api: _FakeApi(),
      storage: storage,
      auth: _AuthHarness(AuthAuthenticated(_user())),
      pathBranch: DiagnosticPathBranch.newPath,
    );
    addTearDown(container.dispose);
    final controller = container.read(diagnosticControllerProvider.notifier);
    await controller.resume();
    controller.completePathHandoff();

    controller.markPathGenerationFailure('경로 생성 연결이 중단됐어요.');

    final failed = container.read(diagnosticControllerProvider);
    expect(failed.phase, DiagnosticContinuationPhase.saved);
    expect(failed.preview, _preview);
    expect(failed.failure?.kind, DiagnosticFailureKind.pathGeneration);
    expect(failed.pathHandoffRequested, isTrue);
    expect(storage.value, isNotNull);
    expect(storage.clearCount, 0);
  });

  test('clear 정책은 invalid/expired/restart/explicit handoff만 허용한다', () async {
    for (final raw in <String>[
      '{',
      _stored(DiagnosticContinuationPhase.preview, expiresAt: _now),
    ]) {
      final storage = _FakeStorage(raw);
      final container = _container(
        api: _FakeApi(),
        storage: storage,
        auth: _AuthHarness(const AuthUnauthenticated()),
      );
      container.read(diagnosticControllerProvider);
      expect(storage.clearCount, 1);
      container.dispose();
    }

    final storage = _FakeStorage(_stored(DiagnosticContinuationPhase.saved));
    final container = _container(
      api: _FakeApi(),
      storage: storage,
      auth: _AuthHarness(AuthAuthenticated(_user())),
    );
    addTearDown(container.dispose);
    final controller = container.read(diagnosticControllerProvider.notifier);
    expect(storage.clearCount, 0);
    await controller.resume();
    controller.completePathHandoff();
    expect(storage.clearCount, 0, reason: '새 경로 생성 성공 전에는 보존한다');
    expect(
      container.read(diagnosticControllerProvider).pathHandoffRequested,
      isTrue,
    );
    controller.completeSuccessfulPathHandoff();
    expect(storage.clearCount, 1);

    storage.value = _stored(DiagnosticContinuationPhase.preview);
    controller.restart();
    expect(storage.clearCount, 2);
  });

  test('기존 active path branch는 CTA 자체가 성공 handoff라 즉시 clear한다', () async {
    final storage = _FakeStorage(_stored(DiagnosticContinuationPhase.saved));
    final container = _container(
      api: _FakeApi(),
      storage: storage,
      auth: _AuthHarness(AuthAuthenticated(_user())),
      pathBranch: DiagnosticPathBranch.existingActivePath,
    );
    addTearDown(container.dispose);
    final controller = container.read(diagnosticControllerProvider.notifier);

    await controller.resume();
    expect(
      container.read(diagnosticControllerProvider).pathBranch,
      DiagnosticPathBranch.existingActivePath,
    );

    controller.completeSuccessfulPathHandoff();
    expect(
      storage.clearCount,
      0,
      reason: 'unrelated background PathPhase.complete는 CTA가 아니다',
    );
    expect(container.read(diagnosticControllerProvider).hasPreview, isTrue);

    controller.completePathHandoff();

    expect(storage.clearCount, 1);
    expect(container.read(diagnosticControllerProvider).hasPreview, isFalse);
  });

  test('questions reload는 guest pointer로 다음 문항을 복구한다', () async {
    const next = NextQuestion(
      question: AssessmentQuestion(
        id: 9,
        type: 'MCQ',
        content: '복구 문항',
        bloomLevel: 'REMEMBER',
        difficulty: 0.2,
      ),
      index: 8,
      total: 15,
    );
    final api = _FakeApi()..nextResponses = <NextQuestion?>[next];
    final container = _container(
      api: api,
      storage: _FakeStorage(_stored(DiagnosticContinuationPhase.questions)),
      auth: _AuthHarness(const AuthUnauthenticated()),
    );
    addTearDown(container.dispose);

    await container.read(diagnosticControllerProvider.notifier).resume();

    expect(container.read(diagnosticControllerProvider).nextQuestion, next);
    expect(api.nextCalls, 1);
  });

  test('guest start 뒤 첫 next 실패는 같은 guest/TTL로 next만 재시도한다', () async {
    final api = _FakeApi()
      ..nextError = const ApiException(
        code: ApiErrorCode.network,
        message: 'next unavailable',
      );
    final storage = _FakeStorage();
    final container = _container(
      api: api,
      storage: storage,
      auth: _AuthHarness(const AuthUnauthenticated()),
    );
    addTearDown(container.dispose);
    final controller = container.read(diagnosticControllerProvider.notifier);

    await controller.startAsGuest('BACKEND_SPRING');

    final failed = container.read(diagnosticControllerProvider);
    expect(failed.phase, DiagnosticContinuationPhase.questions);
    expect(failed.guestId, _guestId);
    expect(failed.expiresAt, _now.add(diagnosticContinuationTtl));
    expect(failed.failure?.kind, DiagnosticFailureKind.initialLoad);
    expect(api.startGuestCalls, 1);

    api.nextError = null;
    api.nextResponses = <NextQuestion?>[null];
    await controller.retryAdvance();

    expect(api.startGuestCalls, 1, reason: '새 guest assessment를 만들지 않는다');
    expect(api.nextCalls, 2);
    expect(container.read(diagnosticControllerProvider).preview, _preview);
  });

  test('답변 저장 뒤 next 실패는 답변 재전송 없이 현재 문항에서 복구한다', () async {
    const current = NextQuestion(
      question: AssessmentQuestion(
        id: 9,
        type: 'MCQ',
        content: '현재 문항',
        bloomLevel: 'REMEMBER',
        difficulty: 0.2,
      ),
      index: 8,
      total: 15,
    );
    final api = _FakeApi()..nextResponses = <NextQuestion?>[current];
    final container = _container(
      api: api,
      storage: _FakeStorage(_stored(DiagnosticContinuationPhase.questions)),
      auth: _AuthHarness(const AuthUnauthenticated()),
    );
    addTearDown(container.dispose);
    final controller = container.read(diagnosticControllerProvider.notifier);
    await controller.resume();
    api.nextError = const ApiException(
      code: ApiErrorCode.network,
      message: 'next unavailable',
    );

    await controller.submitAnswer(9, '{"correct":0}');

    final failed = container.read(diagnosticControllerProvider);
    expect(api.answerCalls, 1);
    expect(failed.failure?.kind, DiagnosticFailureKind.initialLoad);
    expect(failed.nextQuestion, current);

    await controller.retryLastAnswer();
    expect(api.answerCalls, 1, reason: '서버에 저장된 답변을 중복 전송하지 않는다');

    api.nextError = null;
    api.nextResponses = <NextQuestion?>[null];
    await controller.retryAdvance();
    expect(container.read(diagnosticControllerProvider).preview, _preview);
    expect(api.answerCalls, 1);
  });

  test('OAuth handoff persistence 실패는 login하지 않고 preview에서 재시도한다', () async {
    final auth = _AuthHarness(const AuthUnauthenticated());
    final storage = _FakeStorage(
      _stored(DiagnosticContinuationPhase.preview),
      true,
    );
    final container = _container(api: _FakeApi(), storage: storage, auth: auth);
    addTearDown(container.dispose);

    await container
        .read(diagnosticControllerProvider.notifier)
        .saveAndContinue();

    final state = container.read(diagnosticControllerProvider);
    expect(auth.loginCalls, 0);
    expect(state.phase, DiagnosticContinuationPhase.preview);
    expect(state.preview, _preview);
    expect(state.failure?.kind, DiagnosticFailureKind.invalidContinuation);
  });

  test('TTL 정확한 경계에서는 answer API 없이 guest pointer를 폐기하고 재시작한다', () async {
    var clock = _now;
    const current = NextQuestion(
      question: AssessmentQuestion(
        id: 9,
        type: 'MCQ',
        content: '만료 문항',
        bloomLevel: 'REMEMBER',
        difficulty: 0.2,
      ),
      index: 8,
      total: 15,
    );
    final api = _FakeApi()..nextResponses = <NextQuestion?>[current];
    final storage = _FakeStorage(
      _stored(DiagnosticContinuationPhase.questions),
    );
    final container = _container(
      api: api,
      storage: storage,
      auth: _AuthHarness(const AuthUnauthenticated()),
      clock: () => clock,
    );
    addTearDown(container.dispose);
    final controller = container.read(diagnosticControllerProvider.notifier);
    await controller.resume();
    clock = _now.add(diagnosticContinuationTtl);

    await controller.submitAnswer(9, '{"correct":0}');

    final expired = container.read(diagnosticControllerProvider);
    expect(api.answerCalls, 0);
    expect(storage.value, isNull);
    expect(expired.phase, DiagnosticContinuationPhase.track);
    expect(expired.guestId, isNull);
    expect(expired.nextQuestion, isNull);
    expect(expired.failure?.kind, DiagnosticFailureKind.guestExpired);
  });

  test('guest answer 404는 answer retry가 아닌 만료 재시작으로 종결한다', () async {
    const current = NextQuestion(
      question: AssessmentQuestion(
        id: 9,
        type: 'MCQ',
        content: '만료 문항',
        bloomLevel: 'REMEMBER',
        difficulty: 0.2,
      ),
      index: 8,
      total: 15,
    );
    final api = _FakeApi()..nextResponses = <NextQuestion?>[current];
    final storage = _FakeStorage(
      _stored(DiagnosticContinuationPhase.questions),
    );
    final container = _container(
      api: api,
      storage: storage,
      auth: _AuthHarness(const AuthUnauthenticated()),
    );
    addTearDown(container.dispose);
    final controller = container.read(diagnosticControllerProvider.notifier);
    await controller.resume();
    api.answerFailure = const ApiException(
      code: ApiErrorCode.resourceNotFound,
      message: 'raw backend guest missing',
      status: 404,
    );

    await controller.submitAnswer(9, '{"correct":0}');

    final expired = container.read(diagnosticControllerProvider);
    expect(storage.value, isNull);
    expect(expired.phase, DiagnosticContinuationPhase.track);
    expect(expired.guestId, isNull);
    expect(expired.failure?.kind, DiagnosticFailureKind.guestExpired);
    expect(expired.failure?.message, isNot(contains('raw backend')));
  });

  test(
    'guest next/complete 404도 pointer retry loop 없이 만료 재시작으로 종결한다',
    () async {
      for (final completeBoundary in <bool>[false, true]) {
        const expiredError = ApiException(
          code: ApiErrorCode.resourceNotFound,
          message: 'raw expired pointer',
          status: 404,
        );
        final api = _FakeApi();
        if (completeBoundary) {
          api.nextResponses = <NextQuestion?>[null];
          api.completeFailure = expiredError;
        } else {
          api.nextError = expiredError;
        }
        final storage = _FakeStorage(
          _stored(DiagnosticContinuationPhase.questions),
        );
        final container = _container(
          api: api,
          storage: storage,
          auth: _AuthHarness(const AuthUnauthenticated()),
        );

        await container.read(diagnosticControllerProvider.notifier).resume();

        final state = container.read(diagnosticControllerProvider);
        expect(state.phase, DiagnosticContinuationPhase.track);
        expect(state.guestId, isNull);
        expect(state.failure?.kind, DiagnosticFailureKind.guestExpired);
        expect(state.failure?.message, isNot(contains('raw expired')));
        expect(storage.value, isNull);
        container.dispose();
      }
    },
  );

  test(
    'claim 성공 뒤 result 404는 continuation을 지우지 않고 idempotent retry한다',
    () async {
      final api = _FakeApi()
        ..resultFailure = const ApiException(
          code: ApiErrorCode.resourceNotFound,
          message: 'result delayed',
          status: 404,
        );
      final storage = _FakeStorage(_stored(DiagnosticContinuationPhase.claim));
      final container = _container(
        api: api,
        storage: storage,
        auth: _AuthHarness(AuthAuthenticated(_user())),
      );
      addTearDown(container.dispose);
      final controller = container.read(diagnosticControllerProvider.notifier);

      await controller.resume();
      expect(api.claimCalls, 1);
      expect(storage.value, isNotNull);
      expect(storage.clearCount, 0);
      expect(
        container.read(diagnosticControllerProvider).failure?.kind,
        DiagnosticFailureKind.claim,
      );

      api.resultFailure = null;
      await controller.claimAfterLogin();
      expect(api.claimCalls, 2);
      expect(container.read(diagnosticControllerProvider).saved, isTrue);
    },
  );

  test('non-API start parse 실패는 busy를 끝내고 generic typed 오류만 노출한다', () async {
    for (final member in <bool>[false, true]) {
      final api = _FakeApi();
      if (member) {
        api.startMemberFailure = const FormatException('raw-secret-member');
      } else {
        api.startGuestFailure = const FormatException('raw-secret-guest');
      }
      final container = _container(
        api: api,
        storage: _FakeStorage(),
        auth: _AuthHarness(
          member ? AuthAuthenticated(_user()) : const AuthUnauthenticated(),
        ),
      );

      if (member) {
        await container
            .read(diagnosticControllerProvider.notifier)
            .startAsMember('BACKEND_SPRING');
      } else {
        await container
            .read(diagnosticControllerProvider.notifier)
            .startAsGuest('BACKEND_SPRING');
      }
      final state = container.read(diagnosticControllerProvider);
      expect(state.busy, isFalse);
      expect(state.failure?.kind, DiagnosticFailureKind.initialLoad);
      expect(state.failure?.message, isNot(contains('raw-secret')));
      container.dispose();
    }
  });

  test(
    'non-API next/complete/answer parse 실패는 usable question과 retry를 유지한다',
    () async {
      const current = NextQuestion(
        question: AssessmentQuestion(
          id: 9,
          type: 'MCQ',
          content: '유효 문항',
          bloomLevel: 'REMEMBER',
          difficulty: 0.2,
        ),
        index: 8,
        total: 15,
      );

      final nextApi = _FakeApi()
        ..nextFailure = const FormatException('raw-next');
      final nextContainer = _container(
        api: nextApi,
        storage: _FakeStorage(_stored(DiagnosticContinuationPhase.questions)),
        auth: _AuthHarness(const AuthUnauthenticated()),
      );
      await nextContainer.read(diagnosticControllerProvider.notifier).resume();
      expect(nextContainer.read(diagnosticControllerProvider).busy, isFalse);
      expect(
        nextContainer.read(diagnosticControllerProvider).failure?.kind,
        DiagnosticFailureKind.initialLoad,
      );
      nextContainer.dispose();

      final completeApi = _FakeApi()
        ..nextResponses = <NextQuestion?>[null]
        ..completeFailure = const FormatException('raw-complete');
      final completeContainer = _container(
        api: completeApi,
        storage: _FakeStorage(_stored(DiagnosticContinuationPhase.questions)),
        auth: _AuthHarness(const AuthUnauthenticated()),
      );
      await completeContainer
          .read(diagnosticControllerProvider.notifier)
          .resume();
      expect(
        completeContainer.read(diagnosticControllerProvider).busy,
        isFalse,
      );
      expect(
        completeContainer.read(diagnosticControllerProvider).failure?.message,
        isNot(contains('raw-complete')),
      );
      completeContainer.dispose();

      final answerApi = _FakeApi()
        ..nextResponses = <NextQuestion?>[current, current];
      final answerContainer = _container(
        api: answerApi,
        storage: _FakeStorage(_stored(DiagnosticContinuationPhase.questions)),
        auth: _AuthHarness(const AuthUnauthenticated()),
      );
      final answerController = answerContainer.read(
        diagnosticControllerProvider.notifier,
      );
      await answerController.resume();
      answerApi.answerFailure = const FormatException('raw-answer');
      await answerController.submitAnswer(9, '{"correct":0}');
      final answerState = answerContainer.read(diagnosticControllerProvider);
      expect(answerState.busy, isFalse);
      expect(answerState.nextQuestion, current);
      expect(answerState.failure?.kind, DiagnosticFailureKind.answer);
      expect(answerState.failure?.message, isNot(contains('raw-answer')));
      answerContainer.dispose();
    },
  );

  test('non-API claim/result parse 실패는 preview와 continuation을 유지한다', () async {
    for (final failsAtResult in <bool>[false, true]) {
      final api = _FakeApi();
      if (failsAtResult) {
        api.resultFailure = const FormatException('raw-result');
      } else {
        api.claimFailure = const FormatException('raw-claim');
      }
      final storage = _FakeStorage(_stored(DiagnosticContinuationPhase.claim));
      final container = _container(
        api: api,
        storage: storage,
        auth: _AuthHarness(AuthAuthenticated(_user())),
      );

      await container.read(diagnosticControllerProvider.notifier).resume();
      final state = container.read(diagnosticControllerProvider);
      expect(state.busy, isFalse);
      expect(state.preview, _preview);
      expect(state.failure?.kind, DiagnosticFailureKind.claim);
      expect(state.failure?.message, isNot(contains('raw-')));
      expect(storage.value, isNotNull);
      container.dispose();
    }
  });

  test(
    'claim+probe factual 성공만 result_claimed를 branch별 exactly once 기록한다',
    () async {
      for (final entry in <(DiagnosticPathBranch, String)>[
        (DiagnosticPathBranch.newPath, 'new_path_eligible'),
        (DiagnosticPathBranch.existingActivePath, 'existing_active_path'),
      ]) {
        final analytics = _SpyAnalytics();
        final container = _container(
          api: _FakeApi(),
          storage: _FakeStorage(_stored(DiagnosticContinuationPhase.claim)),
          auth: _AuthHarness(AuthAuthenticated(_user())),
          pathBranch: entry.$1,
          analytics: analytics,
        );
        final controller = container.read(
          diagnosticControllerProvider.notifier,
        );
        await controller.resume();
        await controller.retryPathProbe();

        final events = analytics.events
            .where((event) => event.$1 == 'result_claimed')
            .toList();
        expect(events, hasLength(1));
        expect(events.single.$2, {
          'guest_id': _guestId,
          'assessment_id': 77,
          'user_id': '101',
          'claim_outcome': entry.$2,
        });
        container.dispose();
      }
    },
  );

  test(
    'hard reload 뒤 same-tab receipt가 같은 result_claimed SDK capture를 억제한다',
    () async {
      final receiptStore = _FakeClaimAnalyticsReceiptStore();
      final analytics = _SpyAnalytics();
      final firstStorage = _FakeStorage(
        _stored(DiagnosticContinuationPhase.claim),
      );
      final first = _container(
        api: _FakeApi(),
        storage: firstStorage,
        auth: _AuthHarness(AuthAuthenticated(_user())),
        analytics: analytics,
        claimReceiptStore: receiptStore,
      );

      await first.read(diagnosticControllerProvider.notifier).resume();
      final reloadedRaw = firstStorage.value;
      expect(reloadedRaw, isNotNull);
      first.dispose();

      final second = _container(
        api: _FakeApi(),
        storage: _FakeStorage(reloadedRaw),
        auth: _AuthHarness(AuthAuthenticated(_user())),
        analytics: analytics,
        claimReceiptStore: receiptStore,
      );
      addTearDown(second.dispose);
      await second.read(diagnosticControllerProvider.notifier).resume();

      expect(
        analytics.events.where((event) => event.$1 == 'result_claimed'),
        hasLength(1),
      );
      expect(receiptStore.receipts, hasLength(1));
    },
  );

  test('receipt는 다른 계정의 claim을 억제하지 않고 raw account ID를 보관하지 않는다', () async {
    final receiptStore = _FakeClaimAnalyticsReceiptStore();
    final analytics = _SpyAnalytics();

    for (final userId in <String>['101', '202']) {
      final container = _container(
        api: _FakeApi(),
        storage: _FakeStorage(_stored(DiagnosticContinuationPhase.claim)),
        auth: _AuthHarness(AuthAuthenticated(_user(id: userId))),
        analytics: analytics,
        claimReceiptStore: receiptStore,
      );
      await container.read(diagnosticControllerProvider.notifier).resume();
      container.dispose();
    }

    expect(
      analytics.events.where((event) => event.$1 == 'result_claimed'),
      hasLength(2),
    );
    expect(receiptStore.receipts, hasLength(2));
    expect(receiptStore.receipts.join(), isNot(contains(_guestId)));
    expect(receiptStore.receipts.join(), isNot(contains('101')));
    expect(receiptStore.receipts.join(), isNot(contains('202')));
  });

  test('receipt read/write 장애는 claim, preview, path handoff를 막지 않는다', () async {
    for (final store in <_FakeClaimAnalyticsReceiptStore>[
      _FakeClaimAnalyticsReceiptStore(throwOnContains: true),
      _FakeClaimAnalyticsReceiptStore(throwOnRecord: true),
    ]) {
      final analytics = _SpyAnalytics();
      final container = _container(
        api: _FakeApi(),
        storage: _FakeStorage(_stored(DiagnosticContinuationPhase.claim)),
        auth: _AuthHarness(AuthAuthenticated(_user())),
        analytics: analytics,
        claimReceiptStore: store,
      );

      await container.read(diagnosticControllerProvider.notifier).resume();

      final state = container.read(diagnosticControllerProvider);
      expect(state.saved, isTrue);
      expect(state.preview, _preview);
      expect(state.pathBranch, DiagnosticPathBranch.newPath);
      expect(
        analytics.events.where((event) => event.$1 == 'result_claimed'),
        hasLength(1),
      );
      container.dispose();
    }
  });

  test(
    'claim result mismatch와 path probe 실패에는 result_claimed를 기록하지 않는다',
    () async {
      final mismatchAnalytics = _SpyAnalytics();
      final mismatchContainer = _container(
        api: _FakeApi()
          ..claimedResult = const AssessmentResult(
            diagnosedLevel: 'SENIOR',
            confidenceWeight: 0.9,
          ),
        storage: _FakeStorage(_stored(DiagnosticContinuationPhase.claim)),
        auth: _AuthHarness(AuthAuthenticated(_user())),
        analytics: mismatchAnalytics,
      );
      await mismatchContainer
          .read(diagnosticControllerProvider.notifier)
          .resume();
      expect(
        mismatchAnalytics.events.where((event) => event.$1 == 'result_claimed'),
        isEmpty,
      );
      mismatchContainer.dispose();

      final probeAnalytics = _SpyAnalytics();
      final probeContainer = _container(
        api: _FakeApi(),
        storage: _FakeStorage(_stored(DiagnosticContinuationPhase.claim)),
        auth: _AuthHarness(AuthAuthenticated(_user())),
        analytics: probeAnalytics,
        pathError: const ApiException(
          code: ApiErrorCode.network,
          message: 'path unavailable',
        ),
      );
      await probeContainer.read(diagnosticControllerProvider.notifier).resume();
      expect(
        probeAnalytics.events.where((event) => event.$1 == 'result_claimed'),
        isEmpty,
      );
      probeContainer.dispose();
    },
  );

  test(
    'member start 실패 retry는 새 start만 재시도하고 null pointer next를 호출하지 않는다',
    () async {
      final api = _FakeApi()
        ..startMemberFailure = const ApiException(
          code: ApiErrorCode.network,
          message: 'start unavailable',
        );
      final container = _container(
        api: api,
        storage: _FakeStorage(),
        auth: _AuthHarness(AuthAuthenticated(_user())),
      );
      addTearDown(container.dispose);
      final controller = container.read(diagnosticControllerProvider.notifier);

      await controller.startAsMember('BACKEND_SPRING');
      expect(
        container.read(diagnosticControllerProvider).phase,
        DiagnosticContinuationPhase.track,
      );
      expect(api.nextCalls, 0);

      api.startMemberFailure = null;
      await controller.startAsMember('BACKEND_SPRING');
      expect(api.startMemberCalls, 2);
      expect(api.nextCalls, 1);
      expect(container.read(diagnosticControllerProvider).saved, isTrue);
    },
  );

  test('answer 응답 유실은 next로 commit을 확인하고 mutation을 재전송하지 않는다', () async {
    const current = NextQuestion(
      question: AssessmentQuestion(
        id: 9,
        type: 'MCQ',
        content: '현재 문항',
        bloomLevel: 'REMEMBER',
        difficulty: 0.2,
      ),
      index: 8,
      total: 15,
    );
    const following = NextQuestion(
      question: AssessmentQuestion(
        id: 10,
        type: 'MCQ',
        content: '다음 문항',
        bloomLevel: 'APPLY',
        difficulty: 0.4,
      ),
      index: 9,
      total: 15,
    );
    final api = _FakeApi()
      ..nextResponses = <NextQuestion?>[current, following]
      ..answerFailure = const ApiException(
        code: ApiErrorCode.network,
        message: 'response lost after commit',
      );
    final container = _container(
      api: api,
      storage: _FakeStorage(_stored(DiagnosticContinuationPhase.questions)),
      auth: _AuthHarness(const AuthUnauthenticated()),
    );
    addTearDown(container.dispose);
    final controller = container.read(diagnosticControllerProvider.notifier);
    await controller.resume();

    await controller.submitAnswer(9, '{"correct":0}');
    await controller.retryLastAnswer();

    expect(api.answerCalls, 1);
    expect(api.nextCalls, 2);
    expect(
      container.read(diagnosticControllerProvider).nextQuestion,
      following,
    );
    expect(container.read(diagnosticControllerProvider).failure, isNull);
  });

  test('answer 거절은 next가 같은 문항임을 확인한 뒤에만 동일 mutation retry를 허용한다', () async {
    const current = NextQuestion(
      question: AssessmentQuestion(
        id: 9,
        type: 'MCQ',
        content: '현재 문항',
        bloomLevel: 'REMEMBER',
        difficulty: 0.2,
      ),
      index: 8,
      total: 15,
    );
    final api = _FakeApi()
      ..nextResponses = <NextQuestion?>[current, current]
      ..answerFailure = const ApiException(
        code: ApiErrorCode.validationFailed,
        message: 'rejected before commit',
      );
    final container = _container(
      api: api,
      storage: _FakeStorage(_stored(DiagnosticContinuationPhase.questions)),
      auth: _AuthHarness(const AuthUnauthenticated()),
    );
    addTearDown(container.dispose);
    final controller = container.read(diagnosticControllerProvider.notifier);
    await controller.resume();

    await controller.submitAnswer(9, '{"correct":2}');
    expect(api.nextCalls, 2, reason: 'mutation 결과를 먼저 reconcile한다');
    expect(api.answerCalls, 1);
    api.answerFailure = null;
    api.nextResponses = <NextQuestion?>[null];
    await controller.retryLastAnswer();

    expect(api.answerCalls, 2);
    expect(api.lastAnswer, '{"correct":2}');
    expect(container.read(diagnosticControllerProvider).preview, _preview);
  });

  test('answer 상태 reconcile도 실패하면 retry는 answer가 아니라 next만 재호출한다', () async {
    const current = NextQuestion(
      question: AssessmentQuestion(
        id: 9,
        type: 'MCQ',
        content: '현재 문항',
        bloomLevel: 'REMEMBER',
        difficulty: 0.2,
      ),
      index: 8,
      total: 15,
    );
    final api = _FakeApi()..nextResponses = <NextQuestion?>[current];
    final container = _container(
      api: api,
      storage: _FakeStorage(_stored(DiagnosticContinuationPhase.questions)),
      auth: _AuthHarness(const AuthUnauthenticated()),
    );
    addTearDown(container.dispose);
    final controller = container.read(diagnosticControllerProvider.notifier);
    await controller.resume();
    api.answerFailure = const ApiException(
      code: ApiErrorCode.network,
      message: 'answer uncertain',
    );
    api.nextError = const ApiException(
      code: ApiErrorCode.network,
      message: 'reconcile unavailable',
    );

    await controller.submitAnswer(9, '{"correct":1}');
    await controller.retryLastAnswer();

    expect(api.answerCalls, 1);
    expect(api.nextCalls, 3);
  });

  test(
    'member complete 응답 유실은 owner-safe result로 복구하고 새 assessment를 만들지 않는다',
    () async {
      final api = _FakeApi()
        ..nextResponses = <NextQuestion?>[null]
        ..completeFailure = const ApiException(
          code: ApiErrorCode.network,
          message: 'complete response lost',
        );
      final container = _container(
        api: api,
        storage: _FakeStorage(),
        auth: _AuthHarness(AuthAuthenticated(_user())),
      );
      addTearDown(container.dispose);

      await container
          .read(diagnosticControllerProvider.notifier)
          .startAsMember('BACKEND_SPRING');

      final state = container.read(diagnosticControllerProvider);
      expect(api.startMemberCalls, 1);
      expect(api.completeCalls, 1);
      expect(api.resultCalls, 1);
      expect(state.preview, _preview);
      expect(state.saved, isTrue);
    },
  );

  test(
    'guest complete commit 뒤 응답 유실은 pointer replay로 같은 preview를 복구한다',
    () async {
      final api = _FakeApi()
        ..nextResponses = <NextQuestion?>[null]
        ..completeCommitThenLoseResponseOnce = true;
      final storage = _FakeStorage();
      final analytics = _SpyAnalytics();
      final container = _container(
        api: api,
        storage: storage,
        auth: _AuthHarness(const AuthUnauthenticated()),
        analytics: analytics,
      );
      addTearDown(container.dispose);
      final controller = container.read(diagnosticControllerProvider.notifier);

      await controller.startAsGuest('BACKEND_SPRING');
      expect(
        container.read(diagnosticControllerProvider).failure?.kind,
        DiagnosticFailureKind.initialLoad,
      );
      await controller.retryAdvance();

      final state = container.read(diagnosticControllerProvider);
      expect(api.startGuestCalls, 1);
      expect(api.completeCalls, 2);
      expect(api.completeCommits, 1);
      expect(state.preview, _preview);
      expect(state.phase, DiagnosticContinuationPhase.preview);
      expect(storage.clearCount, 0);
      expect(
        analytics.events.where((event) => event.$1 == 'diagnostic_completed'),
        hasLength(1),
      );
    },
  );

  test(
    'claim commit 뒤 응답 유실은 replay로 같은 결과를 확인하고 mutation은 한 번만 commit한다',
    () async {
      final api = _FakeApi()..claimCommitThenLoseResponseOnce = true;
      final storage = _FakeStorage(_stored(DiagnosticContinuationPhase.claim));
      final analytics = _SpyAnalytics();
      final container = _container(
        api: api,
        storage: storage,
        auth: _AuthHarness(AuthAuthenticated(_user())),
        analytics: analytics,
      );
      addTearDown(container.dispose);
      final controller = container.read(diagnosticControllerProvider.notifier);

      await controller.resume();
      expect(container.read(diagnosticControllerProvider).preview, _preview);
      expect(container.read(diagnosticControllerProvider).saved, isFalse);
      await controller.claimAfterLogin();

      final state = container.read(diagnosticControllerProvider);
      expect(api.claimCalls, 2);
      expect(api.claimCommits, 1);
      expect(api.resultCalls, 1);
      expect(state.preview, _preview);
      expect(state.saved, isTrue);
      expect(storage.clearCount, 0);
      expect(
        analytics.events.where((event) => event.$1 == 'result_claimed'),
        hasLength(1),
      );
    },
  );

  test(
    'claim/result await 각각에서 계정이 바뀌면 새 계정 mutation 없이 ownership으로 끝난다',
    () async {
      for (final switchAtResult in <bool>[false, true]) {
        final auth = _AuthHarness(AuthAuthenticated(_user()));
        final api = _FakeApi();
        if (switchAtResult) {
          api.resultCompleter = Completer<AssessmentResult>();
        } else {
          api.claimCompleter = Completer<int>();
        }
        final storage = _FakeStorage(
          _stored(DiagnosticContinuationPhase.claim),
        );
        final container = _container(api: api, storage: storage, auth: auth);
        final controller = container.read(
          diagnosticControllerProvider.notifier,
        );
        final operation = controller.resume();
        while ((switchAtResult ? api.resultCalls : api.claimCalls) == 0) {
          await Future<void>.delayed(Duration.zero);
        }

        auth.replace(AuthAuthenticated(_user(id: '202')));
        if (switchAtResult) {
          api.resultCompleter!.complete(_preview);
        } else {
          api.claimCompleter!.complete(77);
        }
        await operation;

        final currentAuth =
            container.read(authControllerProvider) as AuthAuthenticated;
        final state = container.read(diagnosticControllerProvider);
        expect(currentAuth.user.id, '202');
        expect(currentAuth.user.onboardingStatus, OnboardingStatus.pending);
        expect(state.preview, _preview);
        expect(state.saved, isFalse);
        expect(state.failure?.kind, DiagnosticFailureKind.ownership);
        expect(storage.value, isNotNull);
        container.dispose();
      }
    },
  );

  test(
    'same-tab saved A 뒤 B resume도 DB claim replay ownership을 다시 검증한다',
    () async {
      final auth = _AuthHarness(AuthAuthenticated(_user()));
      final api = _FakeApi();
      final storage = _FakeStorage(_stored(DiagnosticContinuationPhase.claim));
      final container = _container(api: api, storage: storage, auth: auth);
      addTearDown(container.dispose);
      final controller = container.read(diagnosticControllerProvider.notifier);
      await controller.resume();
      expect(container.read(diagnosticControllerProvider).saved, isTrue);

      auth.replace(AuthAuthenticated(_user(id: '202')));
      api.claimError = const ApiException(
        code: ApiErrorCode.forbidden,
        message: 'different owner',
        status: 403,
      );
      await controller.resume();

      expect(api.claimCalls, 2);
      expect(container.read(diagnosticControllerProvider).saved, isFalse);
      expect(
        container.read(diagnosticControllerProvider).failure?.kind,
        DiagnosticFailureKind.ownership,
      );
      expect(
        (container.read(authControllerProvider) as AuthAuthenticated)
            .user
            .onboardingStatus,
        OnboardingStatus.pending,
      );
    },
  );

  test('claim path probe 중 계정 전환은 늦은 완료로 새 계정을 DONE 처리하지 않는다', () async {
    final auth = _AuthHarness(AuthAuthenticated(_user()));
    final probeStarted = Completer<void>();
    final probeResult = Completer<DiagnosticPathBranch>();
    final container = _container(
      api: _FakeApi(),
      storage: _FakeStorage(_stored(DiagnosticContinuationPhase.claim)),
      auth: auth,
      pathProbe: () {
        if (!probeStarted.isCompleted) probeStarted.complete();
        return probeResult.future;
      },
    );
    addTearDown(container.dispose);
    final controller = container.read(diagnosticControllerProvider.notifier);
    final claim = controller.resume();
    await probeStarted.future;

    auth.replace(AuthAuthenticated(_user(id: '202')));
    final switchedResume = controller.resume();
    probeResult.complete(DiagnosticPathBranch.newPath);
    await Future.wait([claim, switchedResume]);

    final currentAuth =
        container.read(authControllerProvider) as AuthAuthenticated;
    expect(currentAuth.user.id, '202');
    expect(currentAuth.user.onboardingStatus, OnboardingStatus.pending);
    expect(container.read(diagnosticControllerProvider).saved, isFalse);
    expect(
      container.read(diagnosticControllerProvider).failure?.kind,
      DiagnosticFailureKind.ownership,
    );
  });

  test('claim이 TTL 경계를 넘어 성공하면 durable recovery TTL을 성공 시점부터 갱신한다', () async {
    var clock = _now;
    final api = _FakeApi()..claimCompleter = Completer<int>();
    final storage = _FakeStorage(_stored(DiagnosticContinuationPhase.claim));
    final container = _container(
      api: api,
      storage: storage,
      auth: _AuthHarness(AuthAuthenticated(_user())),
      clock: () => clock,
    );
    addTearDown(container.dispose);
    final claim = container
        .read(diagnosticControllerProvider.notifier)
        .resume();
    while (api.claimCalls == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    clock = _now.add(diagnosticContinuationTtl + const Duration(minutes: 1));
    api.claimCompleter!.complete(77);
    await claim;

    final decoded = decodeDiagnosticContinuation(storage.value!, now: clock);
    expect(decoded.status, DiagnosticContinuationReadStatus.valid);
    expect(decoded.value?.expiresAt, clock.add(diagnosticContinuationTtl));
  });

  test('OAuth CTA 동시 호출은 continuation/login handoff를 한 번만 실행한다', () async {
    final auth = _AuthHarness(const AuthUnauthenticated())
      ..loginCompleter = Completer<void>();
    final storage = _FakeStorage(_stored(DiagnosticContinuationPhase.preview));
    final container = _container(api: _FakeApi(), storage: storage, auth: auth);
    addTearDown(container.dispose);
    final controller = container.read(diagnosticControllerProvider.notifier);

    final first = controller.saveAndContinue();
    final second = controller.saveAndContinue();
    await Future<void>.delayed(Duration.zero);
    expect(auth.loginCalls, 1);
    expect(storage.writeCount, 1);
    expect(container.read(diagnosticControllerProvider).busy, isTrue);
    auth.loginCompleter!.complete();
    await Future.wait([first, second]);
  });

  test('path probe 중에는 기존 branch CTA handoff를 허용하지 않는다', () async {
    var probeCalls = 0;
    final retryStarted = Completer<void>();
    final retryResult = Completer<DiagnosticPathBranch>();
    final container = _container(
      api: _FakeApi(),
      storage: _FakeStorage(_stored(DiagnosticContinuationPhase.claim)),
      auth: _AuthHarness(AuthAuthenticated(_user())),
      pathProbe: () {
        probeCalls++;
        if (probeCalls == 1) {
          return Future.value(DiagnosticPathBranch.newPath);
        }
        retryStarted.complete();
        return retryResult.future;
      },
    );
    addTearDown(container.dispose);
    final controller = container.read(diagnosticControllerProvider.notifier);
    await controller.resume();
    final retry = controller.retryPathProbe();
    await retryStarted.future;

    final probing = container.read(diagnosticControllerProvider);
    expect(probing.busy, isTrue);
    expect(probing.pathBranch, DiagnosticPathBranch.unknown);
    controller.completePathHandoff();
    expect(
      container.read(diagnosticControllerProvider).pathHandoffRequested,
      isFalse,
    );
    retryResult.complete(DiagnosticPathBranch.newPath);
    await retry;
  });

  test('journey storage 장애는 ephemeral ID로 core guest 진단을 계속한다', () async {
    final api = _FakeApi();
    final container = _container(
      api: api,
      storage: _FakeStorage(),
      auth: _AuthHarness(const AuthUnauthenticated()),
      journeyStore: _ThrowingJourneyStore(),
    );
    addTearDown(container.dispose);
    final controller = container.read(diagnosticControllerProvider.notifier);

    expect(() => controller.selectTrack('BACKEND_SPRING'), returnsNormally);
    await controller.startAsGuest('BACKEND_SPRING');

    expect(api.startGuestCalls, 1);
    expect(container.read(diagnosticControllerProvider).preview, _preview);
    expect(
      isValidJourneyId(container.read(diagnosticControllerProvider).journeyId),
      isTrue,
    );
  });

  test(
    'journey ID generator 장애도 core 진단은 진행하고 continuation 제한만 표시한다',
    () async {
      final api = _FakeApi();
      final container = _container(
        api: api,
        storage: _FakeStorage(),
        auth: _AuthHarness(const AuthUnauthenticated()),
        journeyStore: MemoryJourneyIdStore(),
        idGenerator: () => throw StateError('entropy unavailable'),
      );
      addTearDown(container.dispose);
      final controller = container.read(diagnosticControllerProvider.notifier);

      controller.selectTrack('BACKEND_SPRING');
      await controller.startAsGuest('BACKEND_SPRING');

      expect(api.startGuestCalls, 1);
      expect(container.read(diagnosticControllerProvider).preview, _preview);
      expect(container.read(diagnosticControllerProvider).journeyId, isNull);
      expect(
        container.read(diagnosticControllerProvider).failure?.kind,
        DiagnosticFailureKind.invalidContinuation,
      );
    },
  );

  test(
    '서로 다른 guest claim은 controller lifetime에서도 각각 result_claimed를 기록한다',
    () async {
      const secondGuest = '223e4567-e89b-42d3-a456-426614174000';
      final api = _FakeApi()
        ..guestIds = <String>[_guestId, secondGuest]
        ..claimIds = <int>[77, 78]
        ..nextResponses = <NextQuestion?>[null, null];
      final analytics = _SpyAnalytics();
      final container = _container(
        api: api,
        storage: _FakeStorage(),
        auth: _AuthHarness(AuthAuthenticated(_user())),
        analytics: analytics,
      );
      addTearDown(container.dispose);
      final controller = container.read(diagnosticControllerProvider.notifier);

      await controller.startAsGuest('BACKEND_SPRING');
      await controller.saveAndContinue();
      await controller.retryPathProbe();
      controller.restart();
      await controller.startAsGuest('BACKEND_SPRING');
      await controller.saveAndContinue();
      await controller.retryPathProbe();

      final claimed = analytics.events
          .where((event) => event.$1 == 'result_claimed')
          .toList();
      expect(claimed, hasLength(2));
      expect(claimed.map((event) => event.$2['guest_id']).toSet(), {
        _guestId,
        secondGuest,
      });
    },
  );
}
