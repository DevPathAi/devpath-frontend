const analyticsContractVersion = 'mission-spine.analytics.v1';
const analyticsPrivacyPolicyVersion = 'mission-spine.analytics-privacy.v1';
const analyticsValuePolicyVersion = 'mission-spine.analytics-values.v1';
const analyticsConsentRequirement = 'analytics_permission';
const analyticsTimestampSource = 'client_event_time';

const analyticsCommonProperties = <String>{
  'contract_version',
  'occurred_at',
  'environment',
  'app_version',
  'session_id',
  'journey_id',
};

class AnalyticsEventSpec {
  const AnalyticsEventSpec({
    required this.allowed,
    required this.required,
    required this.dedupe,
    this.requiredAny = const [],
    this.consentRequirement = analyticsConsentRequirement,
    this.timestampSource = analyticsTimestampSource,
  });

  final List<String> allowed;
  final List<String> required;
  final List<List<String>> requiredAny;
  final List<List<String>> dedupe;
  final String consentRequirement;
  final String timestampSource;
}

// Insertion order and property lists mirror Home's versioned replay contract.
const analyticsEventSpecs = <String, AnalyticsEventSpec>{
  'landing_viewed': AnalyticsEventSpec(
    allowed: ['page_view_id'],
    required: ['page_view_id'],
    dedupe: [
      ['session_id', 'page_view_id'],
    ],
  ),
  'landing_diagnostic_cta_clicked': AnalyticsEventSpec(
    allowed: ['page_view_id', 'cta_location'],
    required: ['page_view_id', 'cta_location'],
    dedupe: [
      ['page_view_id', 'cta_location'],
    ],
  ),
  'diagnostic_started': AnalyticsEventSpec(
    allowed: ['track', 'guest_id', 'assessment_id'],
    required: ['track'],
    requiredAny: [
      ['guest_id', 'assessment_id'],
    ],
    dedupe: [
      ['guest_id'],
      ['assessment_id'],
    ],
  ),
  'diagnostic_completed': AnalyticsEventSpec(
    allowed: ['guest_id', 'assessment_id', 'diagnosed_level', 'duration_ms'],
    required: ['diagnosed_level', 'duration_ms'],
    requiredAny: [
      ['guest_id', 'assessment_id'],
    ],
    dedupe: [
      ['guest_id'],
      ['assessment_id'],
    ],
  ),
  'result_claimed': AnalyticsEventSpec(
    allowed: ['guest_id', 'assessment_id', 'user_id', 'claim_outcome'],
    required: ['guest_id', 'user_id', 'claim_outcome'],
    dedupe: [
      ['assessment_id'],
      ['guest_id', 'user_id'],
    ],
  ),
  'path_generated': AnalyticsEventSpec(
    allowed: ['path_id', 'assessment_id', 'user_id'],
    required: ['path_id', 'assessment_id', 'user_id'],
    dedupe: [
      ['path_id'],
    ],
  ),
  'existing_path_continued': AnalyticsEventSpec(
    allowed: ['user_id', 'path_id', 'assessment_id', 'guest_id'],
    required: ['user_id', 'path_id'],
    requiredAny: [
      ['assessment_id', 'guest_id'],
    ],
    dedupe: [
      ['user_id', 'path_id', 'assessment_id'],
      ['user_id', 'path_id', 'guest_id'],
    ],
  ),
  'path_first_viewed': AnalyticsEventSpec(
    allowed: ['user_id', 'path_id', 'originating_session_id'],
    required: ['user_id', 'path_id', 'originating_session_id'],
    dedupe: [
      ['user_id', 'path_id'],
    ],
  ),
  'first_mission_started': AnalyticsEventSpec(
    allowed: ['user_id', 'path_id', 'week_num', 'task_id', 'first_open'],
    required: ['user_id', 'path_id', 'week_num', 'task_id', 'first_open'],
    dedupe: [
      ['user_id', 'task_id', 'first_open'],
    ],
  ),
  'first_practice_succeeded': AnalyticsEventSpec(
    allowed: [
      'user_id',
      'path_id',
      'task_id',
      'content_id',
      'run_id',
      'first_successful_run',
    ],
    required: [
      'user_id',
      'path_id',
      'task_id',
      'content_id',
      'run_id',
      'first_successful_run',
    ],
    dedupe: [
      ['user_id', 'task_id', 'first_successful_run'],
    ],
  ),
  'contextual_review_viewed': AnalyticsEventSpec(
    allowed: [
      'user_id',
      'task_id',
      'review_id',
      'approved_context_field_count',
      'next_action_outcome',
      'first_view',
    ],
    required: [
      'user_id',
      'task_id',
      'review_id',
      'approved_context_field_count',
      'next_action_outcome',
      'first_view',
    ],
    dedupe: [
      ['user_id', 'task_id', 'review_id', 'first_view'],
    ],
  ),
};

const analyticsBannedProperties = <String>{
  'email',
  'name',
  'full_name',
  'display_name',
  'nickname',
  'github_handle',
  'provider_subject',
  'oauth_code',
  'oauth_state',
  'access_token',
  'refresh_token',
  'guest_token',
  'password',
  'code',
  'editor_code',
  'output',
  'stdout',
  'stderr',
  'error',
  'prompt',
  'answer',
  'answers',
  'context_snapshot',
  'lcs_snapshot',
};

const _opaqueIdProperties = <String>{
  'session_id',
  'journey_id',
  'page_view_id',
  'originating_session_id',
};

const _databaseIdProperties = <String>{
  'assessment_id',
  'path_id',
  'task_id',
  'content_id',
  'run_id',
  'review_id',
};

const _tracks = <String>{
  'BACKEND_SPRING',
  'FRONTEND_REACT',
  'MOBILE_FLUTTER',
  'DEVOPS',
  'FULLSTACK',
  'PYTHON_BACKEND',
};
const _ctaLocations = <String>{'header', 'hero', 'mini_diagnostic', 'pricing'};
const _diagnosedLevels = <String>{'JUNIOR', 'MID', 'SENIOR'};
final _isoUtcMillis = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$');
final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

enum AnalyticsValidationCode {
  unknownEvent,
  invalidProperties,
  bannedProperty,
  unknownProperty,
  nestedProperty,
  missingProperty,
  contractVersionMismatch,
  invalidIdentifier,
  invalidPropertyValue,
}

class AnalyticsValidationResult {
  const AnalyticsValidationResult.valid()
    : valid = true,
      code = null,
      property = null;

  const AnalyticsValidationResult.invalid(this.code, [this.property])
    : valid = false;

  final bool valid;
  final AnalyticsValidationCode? code;
  final String? property;
}

bool isBannedAnalyticsProperty(String property) =>
    analyticsBannedProperties.contains(property.toLowerCase());

bool isOpaqueAnalyticsIdentifier(Object? value) {
  return value is String && RegExp(r'^[A-Za-z0-9_-]{22}$').hasMatch(value);
}

bool isPlatformUserId(Object? value) =>
    value is String && RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(value);

const _maxCrossRuntimeSafeInteger = 9007199254740991;

bool _isPositiveDatabaseId(Object? value) {
  if (value is int) {
    return value > 0 && value <= _maxCrossRuntimeSafeInteger;
  }
  return value is String && RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(value);
}

bool _isScalar(Object? value) =>
    value is String || value is bool || (value is num && value.isFinite);

AnalyticsValidationResult? _validateKnownValue(String name, Object? value) {
  if (_opaqueIdProperties.contains(name) &&
      !isOpaqueAnalyticsIdentifier(value)) {
    return AnalyticsValidationResult.invalid(
      AnalyticsValidationCode.invalidIdentifier,
      name,
    );
  }
  if (_databaseIdProperties.contains(name) && !_isPositiveDatabaseId(value)) {
    return AnalyticsValidationResult.invalid(
      AnalyticsValidationCode.invalidIdentifier,
      name,
    );
  }
  if (name == 'user_id' && !isPlatformUserId(value)) {
    return AnalyticsValidationResult.invalid(
      AnalyticsValidationCode.invalidIdentifier,
      name,
    );
  }
  if (name == 'guest_id' && (value is! String || !_uuidV4.hasMatch(value))) {
    return AnalyticsValidationResult.invalid(
      AnalyticsValidationCode.invalidIdentifier,
      name,
    );
  }
  if (name == 'occurred_at' &&
      (value is! String ||
          !_isoUtcMillis.hasMatch(value) ||
          DateTime.tryParse(value)?.toUtc().toIso8601String() != value)) {
    return AnalyticsValidationResult.invalid(
      AnalyticsValidationCode.invalidPropertyValue,
      name,
    );
  }
  if (name == 'environment' &&
      !const {'production', 'staging', 'development', 'test'}.contains(value)) {
    return AnalyticsValidationResult.invalid(
      AnalyticsValidationCode.invalidPropertyValue,
      name,
    );
  }
  if (name == 'app_version' &&
      (value is! String ||
          !RegExp(r'^[A-Za-z0-9._+-]{1,128}$').hasMatch(value))) {
    return AnalyticsValidationResult.invalid(
      AnalyticsValidationCode.invalidPropertyValue,
      name,
    );
  }
  if (name == 'track' && !_tracks.contains(value)) {
    return AnalyticsValidationResult.invalid(
      AnalyticsValidationCode.invalidPropertyValue,
      name,
    );
  }
  if (name == 'cta_location' && !_ctaLocations.contains(value)) {
    return AnalyticsValidationResult.invalid(
      AnalyticsValidationCode.invalidPropertyValue,
      name,
    );
  }
  if (name == 'diagnosed_level' && !_diagnosedLevels.contains(value)) {
    return AnalyticsValidationResult.invalid(
      AnalyticsValidationCode.invalidPropertyValue,
      name,
    );
  }
  if (name == 'claim_outcome' &&
      !const {'new_path_eligible', 'existing_active_path'}.contains(value)) {
    return AnalyticsValidationResult.invalid(
      AnalyticsValidationCode.invalidPropertyValue,
      name,
    );
  }
  if (name == 'next_action_outcome' &&
      !const {'path_adjusted', 'next_mission'}.contains(value)) {
    return AnalyticsValidationResult.invalid(
      AnalyticsValidationCode.invalidPropertyValue,
      name,
    );
  }
  if (const {'duration_ms', 'week_num'}.contains(name) &&
      (value is! int || value <= 0 || value > _maxCrossRuntimeSafeInteger)) {
    return AnalyticsValidationResult.invalid(
      AnalyticsValidationCode.invalidPropertyValue,
      name,
    );
  }
  if (name == 'approved_context_field_count' &&
      (value is! int || value <= 0 || value > _maxCrossRuntimeSafeInteger)) {
    return AnalyticsValidationResult.invalid(
      AnalyticsValidationCode.invalidPropertyValue,
      name,
    );
  }
  if (const {
        'first_open',
        'first_successful_run',
        'first_view',
      }.contains(name) &&
      value != true) {
    return AnalyticsValidationResult.invalid(
      AnalyticsValidationCode.invalidPropertyValue,
      name,
    );
  }
  return null;
}

AnalyticsValidationResult validateAnalyticsEvent(
  String event,
  Map<String, Object?> properties,
) {
  final spec = analyticsEventSpecs[event];
  if (spec == null) {
    return const AnalyticsValidationResult.invalid(
      AnalyticsValidationCode.unknownEvent,
    );
  }
  final allowed = {...analyticsCommonProperties, ...spec.allowed};
  for (final entry in properties.entries) {
    if (isBannedAnalyticsProperty(entry.key)) {
      return AnalyticsValidationResult.invalid(
        AnalyticsValidationCode.bannedProperty,
        entry.key,
      );
    }
    if (!allowed.contains(entry.key)) {
      return AnalyticsValidationResult.invalid(
        AnalyticsValidationCode.unknownProperty,
        entry.key,
      );
    }
    if (!_isScalar(entry.value)) {
      return AnalyticsValidationResult.invalid(
        AnalyticsValidationCode.nestedProperty,
        entry.key,
      );
    }
    final valueError = _validateKnownValue(entry.key, entry.value);
    if (valueError != null) return valueError;
  }

  for (final name in {...analyticsCommonProperties, ...spec.required}) {
    if (!properties.containsKey(name)) {
      return AnalyticsValidationResult.invalid(
        AnalyticsValidationCode.missingProperty,
        name,
      );
    }
  }
  for (final alternatives in spec.requiredAny) {
    if (!alternatives.any(properties.containsKey)) {
      return AnalyticsValidationResult.invalid(
        AnalyticsValidationCode.missingProperty,
        alternatives.join('|'),
      );
    }
  }
  if (properties['contract_version'] != analyticsContractVersion) {
    return const AnalyticsValidationResult.invalid(
      AnalyticsValidationCode.contractVersionMismatch,
      'contract_version',
    );
  }
  return const AnalyticsValidationResult.valid();
}

String? analyticsDeduplicationKey(
  String event,
  Map<String, Object?> properties,
) {
  final spec = analyticsEventSpecs[event];
  if (spec == null) return null;
  List<String>? fields;
  for (final candidate in spec.dedupe) {
    if (candidate.every(properties.containsKey)) {
      fields = candidate;
      break;
    }
  }
  if (fields == null) return null;
  final values = fields.map((name) => '$name=${properties[name]}').join('&');
  return '$analyticsContractVersion:$event:$values';
}
