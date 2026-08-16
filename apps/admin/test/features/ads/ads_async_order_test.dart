import 'dart:async';

import 'package:devpath_admin/src/features/ads/application/ads_controller.dart';
import 'package:devpath_admin/src/features/ads/data/ad_row.dart';
import 'package:devpath_admin/src/features/ads/data/ads_source.dart';
import 'package:devpath_admin/src/features/ads/state/ads_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AdRow _ad(int id, String slot) => AdRow(
  id: id,
  title: 'ad-$id',
  imageUrl: null,
  linkUrl: 'https://example.com/$id',
  slot: slot,
  weight: 1,
  status: 'ACTIVE',
  startsAt: null,
  endsAt: null,
);

void main() {
  test(
    'an older successful load cannot replace the latest ad filter',
    () async {
      final dashboard = Completer<List<AdRow>>();
      final community = Completer<List<AdRow>>();
      final requestedSlots = <String?>[];
      final container = ProviderContainer(
        overrides: [
          adsListProvider.overrideWithValue(({slot, status}) {
            requestedSlots.add(slot);
            return switch (slot) {
              'DASHBOARD_TOP' => dashboard.future,
              'COMMUNITY_FEED' => community.future,
              _ => throw StateError('unexpected ad slot: $slot'),
            };
          }),
          adSettingsGetProvider.overrideWithValue(() async => true),
          adSlotConfigListProvider.overrideWithValue(() async => []),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(adsProvider.notifier);
      final olderRequest = notifier.setSlotFilter('DASHBOARD_TOP');
      final latestRequest = notifier.setSlotFilter('COMMUNITY_FEED');
      expect(requestedSlots, ['DASHBOARD_TOP', 'COMMUNITY_FEED']);

      community.complete([_ad(2, 'COMMUNITY_FEED')]);
      await latestRequest;
      dashboard.complete([_ad(1, 'DASHBOARD_TOP')]);
      await olderRequest;

      final state = container.read(adsProvider);
      expect(state.phase, AdsPhase.loaded);
      expect(state.slotFilter, 'COMMUNITY_FEED');
      expect(state.rows.single.id, 2);
    },
  );
}
