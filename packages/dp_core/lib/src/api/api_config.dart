/// 런타임 주입 설정(스펙 §3 — baseUrl·SSE 타임아웃·목 토글).
class ApiConfig {
  const ApiConfig({
    required this.baseUrl,
    this.connectTimeout = const Duration(seconds: 15),
    this.receiveTimeout = const Duration(seconds: 30),
    this.sseTimeout = const Duration(seconds: 60),
    this.useMock = false,
  });

  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Duration sseTimeout;
  final bool useMock;
}
