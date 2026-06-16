import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('apiClientProvider에 AuthInterceptor가 결선된다', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final client = c.read(apiClientProvider);
    expect(client.dio.interceptors.whereType<AuthInterceptor>(), isNotEmpty);
  });
}
