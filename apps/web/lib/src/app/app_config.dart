/// 런타임 설정. `--dart-define`으로 주입(기본=목 프로토).
///
/// ## 실API 사용 시 dart-define 예시
///
/// ```
/// flutter run -d chrome \
///   --dart-define=API_BASE_URL=https://api.devpath.ai \
///   --dart-define=USE_MOCK=false
/// ```
///
/// 또는 파일로 관리할 경우:
/// ```
/// flutter run -d chrome --dart-define-from-file=.env.local
/// ```
/// `.env.local` 예시:
/// ```json
/// {
///   "API_BASE_URL": "https://api.devpath.ai",
///   "USE_MOCK": "false"
/// }
/// ```
///
/// - `API_BASE_URL`: API 게이트웨이 베이스 URL (기본: 목 프로토 URL).
/// - `USE_MOCK`: `true`이면 [MockApiClient]를 사용, `false`이면 실 HTTP 호출.
///   기본값은 `true`(목 프로토 유지 — 변경 시 회귀 주의).
/// - `APP_VERSION`: 빌드 식별자(기본 `dev`). 오류 제보에 함께 전송된다.
/// - `MISSION_SPINE_ENABLED`: immutable build flag. 기본 OFF.
/// - `ANALYTICS_CONTRACT_VERSION`: analytics replay contract version.
class AppConfig {
  const AppConfig({
    required this.baseUrl,
    required this.useMock,
    this.appVersion = 'dev',
    this.missionSpineEnabled = false,
    this.analyticsContractVersion = 'mission-spine.analytics.v1',
    this.analyticsEnvironment = 'test',
    this.sseTimeout = const Duration(seconds: 60),
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
    baseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://mock.devpath.ai',
    ),
    useMock: bool.fromEnvironment('USE_MOCK', defaultValue: true),
    appVersion: String.fromEnvironment('APP_VERSION', defaultValue: 'dev'),
    missionSpineEnabled: bool.fromEnvironment(
      'MISSION_SPINE_ENABLED',
      defaultValue: false,
    ),
    analyticsContractVersion: String.fromEnvironment(
      'ANALYTICS_CONTRACT_VERSION',
      defaultValue: 'mission-spine.analytics.v1',
    ),
    analyticsEnvironment: String.fromEnvironment(
      'ANALYTICS_ENVIRONMENT',
      defaultValue: 'test',
    ),
  );

  final String baseUrl;
  final bool useMock;

  /// 빌드 식별자. `--dart-define=APP_VERSION=0.1.0+42` 로 주입한다.
  /// 미주입이면 'dev' — 제보에 "어느 빌드였는지"가 비지 않게 기본값을 둔다.
  final String appVersion;

  final bool missionSpineEnabled;
  final String analyticsContractVersion;
  final String analyticsEnvironment;

  String get buildIdentity =>
      '$appVersion-mission-${missionSpineEnabled ? 'on' : 'off'}-analytics-$analyticsContractVersion-env-$analyticsEnvironment';

  /// SSE 무이벤트 타임아웃(D2). 초과 시 PathController가 partial로 전환.
  final Duration sseTimeout;
}
