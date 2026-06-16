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
