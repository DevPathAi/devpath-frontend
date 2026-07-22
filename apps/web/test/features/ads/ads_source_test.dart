import 'package:devpath_web/src/features/ads/data/ad_view.dart';
import 'package:devpath_web/src/features/ads/data/ads_source.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ThrowingClient implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw const ApiException(code: ApiErrorCode.unknown, message: 'boom');
}

void main() {
  test('AdView.fromJson parses fields', () {
    final a = AdView.fromJson({
      'id': 3,
      'title': '광고',
      'imageUrl': null,
      'linkUrl': 'https://e.com',
      'slot': 'DASHBOARD_TOP',
    });
    expect(a.id, 3);
    expect(a.linkUrl, 'https://e.com');
    expect(a.imageUrl, isNull);
  });

  test('adFetchProvider returns null on ApiException (fail-silent)', () async {
    final c = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(_ThrowingClient())],
    );
    addTearDown(c.dispose);
    final result = await c.read(adFetchProvider)('DASHBOARD_TOP');
    expect(result, isNull);
  });
}
