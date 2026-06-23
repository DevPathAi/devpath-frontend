import 'package:devpath_admin/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin apiClientProvider에 AuthInterceptor가 결선된다', () {
    // 실서버 모드에서 Authorization 헤더가 빠져 401이 나지 않도록 admin도 AuthInterceptor를 결선한다.
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final client = c.read(apiClientProvider);
    expect(client.dio.interceptors.whereType<AuthInterceptor>(), isNotEmpty);
  });
}
