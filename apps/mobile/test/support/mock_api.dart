import 'package:dp_core/dp_core.dart';

/// 테스트용 ApiClient — MockHttpAdapter 픽스처 장착.
ApiClient mockApiClient(Map<String, MockFixture> fixtures) {
  final c = ApiClient.create(const ApiConfig(baseUrl: 'http://test.local'));
  c.dio.httpClientAdapter = MockHttpAdapter(fixtures);
  return c;
}
