import 'dart:async';

import 'analytics_contract.dart';

enum AnalyticsCaptureStatus {
  accepted,
  optedOut,
  excluded,
  duplicate,
  rejected,
}

abstract interface class JourneyAnalyticsSdk {
  FutureOr<void> capture(String event, Map<String, Object?> properties);
  FutureOr<void> identify(String userId);
  FutureOr<void> reset();
}

class NoopJourneyAnalyticsSdk implements JourneyAnalyticsSdk {
  const NoopJourneyAnalyticsSdk();

  @override
  Future<void> capture(String event, Map<String, Object?> properties) async {}

  @override
  Future<void> identify(String userId) async {}

  @override
  Future<void> reset() async {}
}

abstract interface class JourneyAnalytics {
  AnalyticsCaptureStatus capture(String event, Map<String, Object?> properties);
  bool identify(String userId);
  void reset();
  void setOptedOut(bool optedOut);
}

class OptedOutJourneyAnalytics implements JourneyAnalytics {
  const OptedOutJourneyAnalytics();

  @override
  AnalyticsCaptureStatus capture(
    String event,
    Map<String, Object?> properties,
  ) => AnalyticsCaptureStatus.optedOut;

  @override
  bool identify(String userId) => false;

  @override
  void reset() {}

  @override
  void setOptedOut(bool optedOut) {}
}

class JourneyAnalyticsContext {
  JourneyAnalyticsContext({
    required this.environment,
    required this.appVersion,
    required this.sessionId,
    required this.journeyId,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final String environment;
  final String appVersion;
  final String sessionId;
  final String journeyId;
  final DateTime Function() now;
}

typedef AnalyticsSchedule = void Function(void Function() work);
typedef InternalAnalyticsUserPolicy = bool Function(String userId);

void _defaultSchedule(void Function() work) => Timer.run(work);

bool shouldExcludeAnalyticsTraffic({
  required String environment,
  required String appVersion,
  String userAgent = '',
  bool isInternalAccount = false,
}) =>
    environment != 'production' ||
    appVersion == 'dev' ||
    isInternalAccount ||
    RegExp(
      'bot|crawler|spider|playwright|headless|selenium',
      caseSensitive: false,
    ).hasMatch(userAgent);

class JourneyAnalyticsAdapter implements JourneyAnalytics {
  JourneyAnalyticsAdapter({
    this._sdk = const NoopJourneyAnalyticsSdk(),
    required JourneyAnalyticsContext context,
    this._optedOut = true,
    bool excluded = false,
    InternalAnalyticsUserPolicy? isInternalUser,
    this._schedule = _defaultSchedule,
  }) : _context = context,
       _baseExcluded =
           excluded ||
           shouldExcludeAnalyticsTraffic(
             environment: context.environment,
             appVersion: context.appVersion,
           ),
       _isInternalUser = isInternalUser ?? _neverInternal;

  final JourneyAnalyticsSdk _sdk;
  final JourneyAnalyticsContext _context;
  final AnalyticsSchedule _schedule;
  final InternalAnalyticsUserPolicy _isInternalUser;
  bool _optedOut;
  final bool _baseExcluded;
  bool _accountExcluded = false;
  bool _sdkActivated = false;
  final _dedupe = <String>{};
  String? _currentUserId;
  String? _identifiedUserId;

  static bool _neverInternal(String _) => false;

  @override
  void setOptedOut(bool optedOut) {
    if (optedOut == _optedOut) return;
    if (optedOut) {
      _resetSdkIdentity();
      _optedOut = true;
      _dedupe.clear();
      return;
    }
    _optedOut = false;
    _activateCurrentIdentity();
  }

  @override
  AnalyticsCaptureStatus capture(
    String event,
    Map<String, Object?> eventProperties,
  ) {
    if (analyticsCommonProperties.any(eventProperties.containsKey)) {
      return AnalyticsCaptureStatus.rejected;
    }
    final properties = <String, Object?>{
      'contract_version': analyticsContractVersion,
      'occurred_at': DateTime.fromMillisecondsSinceEpoch(
        _context.now().millisecondsSinceEpoch,
        isUtc: true,
      ).toIso8601String(),
      'environment': _context.environment,
      'app_version': _context.appVersion,
      'session_id': _context.sessionId,
      'journey_id': _context.journeyId,
      ...eventProperties,
    };
    if (!validateAnalyticsEvent(event, properties).valid) {
      return AnalyticsCaptureStatus.rejected;
    }
    if (_optedOut) return AnalyticsCaptureStatus.optedOut;
    if (_baseExcluded || _accountExcluded) {
      return AnalyticsCaptureStatus.excluded;
    }
    final dedupeKey = analyticsDeduplicationKey(event, properties);
    if (dedupeKey == null) return AnalyticsCaptureStatus.rejected;
    if (!_dedupe.add(dedupeKey)) return AnalyticsCaptureStatus.duplicate;
    _sdkActivated = true;
    _deliver(() => _sdk.capture(event, Map.unmodifiable(properties)));
    return AnalyticsCaptureStatus.accepted;
  }

  @override
  bool identify(String userId) {
    if (!isPlatformUserId(userId)) return false;
    if (_currentUserId != null && _currentUserId != userId) {
      _dedupe.clear();
      _resetSdkIdentity();
    }
    _currentUserId = userId;
    if (_isInternalUser(userId)) {
      _resetSdkIdentity();
      _accountExcluded = true;
      return false;
    }
    _accountExcluded = false;
    return _activateCurrentIdentity();
  }

  bool _activateCurrentIdentity() {
    if (_optedOut ||
        _baseExcluded ||
        _accountExcluded ||
        _currentUserId == null) {
      return false;
    }
    final userId = _currentUserId!;
    if (_identifiedUserId == userId) return true;
    if (_identifiedUserId != null) _resetSdkIdentity();
    _identifiedUserId = userId;
    _sdkActivated = true;
    _deliver(() => _sdk.identify(userId));
    return true;
  }

  @override
  void reset() {
    _dedupe.clear();
    _currentUserId = null;
    _accountExcluded = false;
    _resetSdkIdentity();
  }

  void _resetSdkIdentity() {
    final shouldDeliver = _sdkActivated && !_baseExcluded;
    _sdkActivated = false;
    _identifiedUserId = null;
    if (shouldDeliver) _deliver(_sdk.reset);
  }

  void _deliver(FutureOr<void> Function() work) {
    try {
      _schedule(() {
        unawaited(
          Future<void>.sync(() async {
            await work();
          }).catchError((Object _) {}),
        );
      });
    } catch (_) {
      // Scheduler failures are isolated for the same reason.
    }
  }
}
