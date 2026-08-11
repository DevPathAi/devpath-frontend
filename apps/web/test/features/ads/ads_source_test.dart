import 'package:devpath_web/src/features/ads/data/ad_slot_content.dart';
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

  test('type=HOUSE parses into HouseAd', () {
    final c = adSlotContentFromJson({
      'type': 'HOUSE',
      'ad': {
        'id': 3,
        'title': '광고',
        'imageUrl': null,
        'linkUrl': 'https://e.com',
        'slot': 'DASHBOARD_TOP',
      },
    });
    expect(c, isA<HouseAd>());
    expect((c! as HouseAd).ad.id, 3);
  });

  test('type=ADSENSE parses into AdsenseUnit', () {
    final c = adSlotContentFromJson({
      'type': 'ADSENSE',
      'adsenseSlotId': '1234567890',
    });
    expect(c, isA<AdsenseUnit>());
    expect((c! as AdsenseUnit).adsenseSlotId, '1234567890');
  });

  test('unknown type returns null (forward compatible)', () {
    expect(adSlotContentFromJson({'type': 'TAKEOVER'}), isNull);
  });

  test('HOUSE without ad payload returns null', () {
    expect(adSlotContentFromJson({'type': 'HOUSE'}), isNull);
  });

  test('ADSENSE without unit id returns null', () {
    expect(adSlotContentFromJson({'type': 'ADSENSE'}), isNull);
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
