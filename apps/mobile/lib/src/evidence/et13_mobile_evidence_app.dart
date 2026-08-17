import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';

import '../data/mobile_mock_fixtures.dart';
import '../features/learning/presentation/mobile_content_projection.dart';
import '../features/today/presentation/mobile_today_projection.dart';

export '../features/learning/presentation/mobile_content_projection.dart';
export '../features/today/presentation/mobile_today_projection.dart';

class Et13MobileEvidenceApp extends StatelessWidget {
  const Et13MobileEvidenceApp({
    super.key,
    required this.fixtureId,
    required this.brightness,
    required this.textScale,
    required this.sourceSha,
    this.waitForFonts = waitForEt13EvidenceFonts,
  });

  static const fixtureIds = <String>[
    'mobile-today-available',
    'mobile-content-reading',
  ];

  final String fixtureId;
  final Brightness brightness;
  final double textScale;
  final String sourceSha;
  final Et13ReadyWaiter waitForFonts;

  @override
  Widget build(BuildContext context) => DpEt13EvidenceFrame(
    fixtureId: fixtureId,
    brightness: brightness,
    textScale: textScale,
    sourceSha: sourceSha,
    waitForFonts: waitForFonts,
    child: buildEt13MobileFixture(fixtureId),
  );
}

Widget buildEt13MobileFixture(String fixtureId) => switch (fixtureId) {
  'mobile-today-available' => Scaffold(
    body: MobileTodayProjection(
      mission: CurrentMission.fromJson(mockCurrentMission()),
      onOpenContent: (_) {},
      onCompleteContentlessTask: (_) {},
      onRefresh: () {},
    ),
  ),
  'mobile-content-reading' => const _Et13MobileContentFixture(),
  _ => throw ArgumentError.value(
    fixtureId,
    'fixtureId',
    'unknown mobile ET13 fixture',
  ),
};

class _Et13MobileContentFixture extends StatefulWidget {
  const _Et13MobileContentFixture();

  @override
  State<_Et13MobileContentFixture> createState() =>
      _Et13MobileContentFixtureState();
}

class _Et13MobileContentFixtureState extends State<_Et13MobileContentFixture> {
  final _scrollController = ScrollController();
  bool _contextExpanded = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: MobileContentProjection(
      content: LearningContent.fromJson(mockContent('future-async-await')),
      scrollController: _scrollController,
      contextExpanded: _contextExpanded,
      onContextDisclosurePressed: () =>
          setState(() => _contextExpanded = !_contextExpanded),
      onComplete: () {},
    ),
  );
}
