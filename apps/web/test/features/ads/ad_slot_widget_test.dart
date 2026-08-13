import 'package:devpath_web/src/features/common/application/external_link_opener.dart';
import 'package:devpath_web/src/features/ads/data/ad_slot_content.dart';
import 'package:devpath_web/src/features/ads/data/ad_view.dart';
import 'package:devpath_web/src/features/ads/data/ads_source.dart';
import 'package:devpath_web/src/features/ads/presentation/ad_slot_widget.dart';
import 'package:devpath_web/src/features/ads/presentation/adsense_unit_view.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

class _FakeOpener implements ExternalLinkOpener {
  String? opened;
  @override
  void open(String url) => opened = url;
}

HouseAd _house() => const HouseAd(
  AdView(
    id: 5,
    title: '테스트 광고',
    imageUrl: null,
    linkUrl: 'https://e.com/land',
    slot: 'DASHBOARD_TOP',
  ),
);

void main() {
  setUp(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  testWidgets('fetch→null renders nothing (fail-silent)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [adFetchProvider.overrideWithValue((slot) async => null)],
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const Scaffold(body: AdSlotWidget(slot: 'DASHBOARD_TOP')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(InkWell), findsNothing);
    expect(find.text('광고'), findsNothing);
  });

  testWidgets('fetch→HouseAd renders title and 광고 label', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adFetchProvider.overrideWithValue((slot) async => _house()),
        ],
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const Scaffold(body: AdSlotWidget(slot: 'DASHBOARD_TOP')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('테스트 광고'), findsOneWidget);
    expect(find.text('광고'), findsOneWidget);
    // VisibilityDetector가 남긴 타이머를 배출(pending timer assertion 방지).
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('tap fires CLICK and opens link', (tester) async {
    final events = <String>[];
    final opener = _FakeOpener();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adFetchProvider.overrideWithValue((slot) async => _house()),
          adEventProvider.overrideWithValue((id, type) async {
            events.add('$id:$type');
          }),
          externalLinkOpenerProvider.overrideWithValue(opener),
        ],
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const Scaffold(body: AdSlotWidget(slot: 'DASHBOARD_TOP')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    expect(opener.opened, 'https://e.com/land');
    expect(events, contains('5:CLICK'));
  });

  testWidgets('fetch→AdsenseUnit renders AdSenseUnitView', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adFetchProvider.overrideWithValue(
            (slot) async => const AdsenseUnit('1234567890'),
          ),
        ],
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const Scaffold(body: AdSlotWidget(slot: 'DASHBOARD_TOP')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final view = tester.widget<AdSenseUnitView>(find.byType(AdSenseUnitView));
    expect(view.slotId, '1234567890');
    // 하우스 광고 카드는 그려지지 않는다.
    expect(find.byType(InkWell), findsNothing);
    expect(find.text('광고'), findsNothing);
  });

  testWidgets('애드센스 가지는 노출·클릭 이벤트를 전혀 보내지 않는다 (구글 정책)', (tester) async {
    final events = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adFetchProvider.overrideWithValue(
            (slot) async => const AdsenseUnit('1234567890'),
          ),
          adEventProvider.overrideWithValue((id, type) async {
            events.add('$id:$type');
          }),
        ],
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const Scaffold(body: AdSlotWidget(slot: 'DASHBOARD_TOP')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    expect(events, isEmpty);
    expect(find.byType(VisibilityDetector), findsNothing);
  });
}
