/// 런타임 설정. `--dart-define`으로 주입(기본=목 프로토).
class AppConfig {
  const AppConfig({required this.baseUrl, required this.useMock});

  factory AppConfig.fromEnvironment() => const AppConfig(
    baseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://mock.devpath.ai/api/v1',
    ),
    useMock: bool.fromEnvironment('USE_MOCK', defaultValue: true),
  );

  final String baseUrl;
  final bool useMock;
}
