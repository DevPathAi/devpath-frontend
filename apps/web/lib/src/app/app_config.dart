/// 런타임 설정. `--dart-define`으로 주입(기본=목 프로토).
///
/// ## 실API 사용 시 dart-define 예시
///
/// ```
/// flutter run -d chrome \
///   --dart-define=API_BASE_URL=https://api.devpath.ai/api/v1 \
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
///   "API_BASE_URL": "https://api.devpath.ai/api/v1",
///   "USE_MOCK": "false"
/// }
/// ```
///
/// - `API_BASE_URL`: API 게이트웨이 베이스 URL (기본: 목 프로토 URL).
/// - `USE_MOCK`: `true`이면 [MockApiClient]를 사용, `false`이면 실 HTTP 호출.
///   기본값은 `true`(목 프로토 유지 — 변경 시 회귀 주의).
class AppConfig {
  const AppConfig({
    required this.baseUrl,
    required this.useMock,
    this.sseTimeout = const Duration(seconds: 60),
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
    baseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://mock.devpath.ai/api/v1',
    ),
    useMock: bool.fromEnvironment('USE_MOCK', defaultValue: true),
  );

  final String baseUrl;
  final bool useMock;

  /// SSE 무이벤트 타임아웃(D2). 초과 시 PathController가 partial로 전환.
  final Duration sseTimeout;
}
