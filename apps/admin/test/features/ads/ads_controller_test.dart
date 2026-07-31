import 'package:devpath_admin/src/features/ads/application/ads_controller.dart';
import 'package:devpath_admin/src/features/ads/data/ad_row.dart';
import 'package:devpath_admin/src/features/ads/data/ads_source.dart';
import 'package:devpath_admin/src/features/ads/state/ads_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AdRow _ad({int? id, String status = 'ACTIVE'}) => AdRow(
  id: id,
  title: 't',
  imageUrl: null,
  linkUrl: 'https://e.com',
  slot: 'DASHBOARD_TOP',
  weight: 1,
  status: status,
  startsAt: null,
  endsAt: null,
);

void main() {
  test('load fills rows and globalEnabled → loaded', () async {
    final c = ProviderContainer(
      overrides: [
        adsListProvider.overrideWithValue(
          ({slot, status}) async => [_ad(id: 1)],
        ),
        adSettingsGetProvider.overrideWithValue(() async => true),
      ],
    );
    addTearDown(c.dispose);
    await c.read(adsProvider.notifier).load();
    final s = c.read(adsProvider);
    expect(s.phase, AdsPhase.loaded);
    expect(s.rows.length, 1);
    expect(s.globalEnabled, isTrue);
  });

  test('toggleStatus flips ACTIVE→PAUSED via update then reloads', () async {
    int? updatedId;
    String? sentStatus;
    final c = ProviderContainer(
      overrides: [
        adsListProvider.overrideWithValue(
          ({slot, status}) async => [_ad(id: 9)],
        ),
        adSettingsGetProvider.overrideWithValue(() async => false),
        adUpdateProvider.overrideWithValue((id, draft) async {
          updatedId = id;
          sentStatus = draft.status;
          return draft.copyWith(id: id);
        }),
      ],
    );
    addTearDown(c.dispose);
    await c
        .read(adsProvider.notifier)
        .toggleStatus(_ad(id: 9, status: 'ACTIVE'));
    expect(updatedId, 9);
    expect(sentStatus, 'PAUSED');
  });

  test('toggleGlobal updates globalEnabled', () async {
    final c = ProviderContainer(
      overrides: [
        adsListProvider.overrideWithValue(({slot, status}) async => []),
        adSettingsGetProvider.overrideWithValue(() async => false),
        adSettingsSetProvider.overrideWithValue((enabled) async => enabled),
      ],
    );
    addTearDown(c.dispose);
    await c.read(adsProvider.notifier).load();
    await c.read(adsProvider.notifier).toggleGlobal(true);
    expect(c.read(adsProvider).globalEnabled, isTrue);
  });

  test('ApiException on load → failed with message', () async {
    final c = ProviderContainer(
      overrides: [
        adsListProvider.overrideWithValue(
          ({slot, status}) async => throw const ApiException(
            code: ApiErrorCode.unknown,
            message: '실패',
          ),
        ),
        adSettingsGetProvider.overrideWithValue(() async => false),
      ],
    );
    addTearDown(c.dispose);
    await c.read(adsProvider.notifier).load();
    final s = c.read(adsProvider);
    expect(s.phase, AdsPhase.failed);
    expect(s.error, '실패');
  });

  test('bulkDelete: 선택 id로 POST 후 재조회·선택 초기화', () async {
    List<int>? sentIds;
    final c = ProviderContainer(
      overrides: [
        adsListProvider.overrideWithValue(
          ({slot, status}) async => [_ad(id: 1), _ad(id: 2)],
        ),
        adSettingsGetProvider.overrideWithValue(() async => false),
        adBulkDeleteProvider.overrideWithValue((ids) async {
          sentIds = ids;
        }),
      ],
    );
    addTearDown(c.dispose);

    await c.read(adsProvider.notifier).load();
    c.read(adsProvider.notifier).toggleSelect(1);
    c.read(adsProvider.notifier).toggleSelect(2);
    expect(c.read(adsProvider).selectedIds, {1, 2});

    await c.read(adsProvider.notifier).bulkDelete();
    expect(sentIds, [1, 2]);
    expect(c.read(adsProvider).selectedIds, isEmpty);
  });
}
