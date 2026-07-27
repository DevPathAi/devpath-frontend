import 'package:devpath_web/src/features/ads/application/ad_link_opener.dart';
import 'package:devpath_web/src/features/ads/data/ad_view.dart';
import 'package:devpath_web/src/features/ads/data/ads_source.dart';
import 'package:devpath_web/src/features/ads/presentation/ad_slot_widget.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visibility_detector/visibility_detector.dart';

class _FakeOpener implements AdLinkOpener {
  String? opened;
  @override
  void open(String url) => opened = url;
}

AdView _ad() => const AdView(
  id: 5,
  title: '테스트 광고',
  imageUrl: null,
  linkUrl: 'https://e.com/land',
  slot: 'DASHBOARD_TOP',
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

  testWidgets('fetch→AdView renders title and 광고 label', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [adFetchProvider.overrideWithValue((slot) async => _ad())],
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
          adFetchProvider.overrideWithValue((slot) async => _ad()),
          adEventProvider.overrideWithValue((id, type) async {
            events.add('$id:$type');
          }),
          adLinkOpenerProvider.overrideWithValue(opener),
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
}
