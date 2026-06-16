/// 런타임 설정. `--dart-define`으로 주입(기본=목 프로토).
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
