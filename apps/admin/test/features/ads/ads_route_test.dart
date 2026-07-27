import 'package:devpath_admin/src/features/ads/data/ads_source.dart';
import 'package:devpath_admin/src/features/ads/presentation/ads_page.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AdminAdsPage builds under ProviderScope', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adsListProvider.overrideWithValue(({slot, status}) async => []),
          adSettingsGetProvider.overrideWithValue(() async => false),
        ],
        child: MaterialApp(theme: DpTheme.light(), home: const AdminAdsPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('광고 관리'), findsOneWidget);
  });
}
