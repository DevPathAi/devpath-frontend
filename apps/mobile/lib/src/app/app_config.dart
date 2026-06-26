/// 런타임 설정. `--dart-define`(또는 `--dart-define-from-file`)으로 주입한다.
/// 기본값은 목 프로토(웹과 동일 정책). 비밀값은 절대 포함하지 않는다.
class AppConfig {
  const AppConfig({
    required this.baseUrl,
    required this.useMock,
    this.sseTimeout = const Duration(seconds: 60),
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
    baseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://mock.devpath.ai',
    ),
    useMock: bool.fromEnvironment('USE_MOCK', defaultValue: true),
  );

  final String baseUrl;
  final bool useMock;
  final Duration sseTimeout;
}
