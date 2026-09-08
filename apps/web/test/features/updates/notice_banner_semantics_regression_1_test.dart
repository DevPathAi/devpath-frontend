import 'dart:ui' as ui;

import 'package:devpath_web/src/features/updates/application/notice_banner_controller.dart';
import 'package:devpath_web/src/features/updates/data/notice_feed_client.dart';
import 'package:devpath_web/src/features/updates/presentation/notice_banner_bar.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ReadyController extends NoticeBannerController {
  @override
  NoticeBannerState build() => NoticeBannerReady(
    NoticeBanner(
      id: 'mentor-invite',
      title: 'AI 멘토 순차 초대 안내',
      summary: '담당자가 확인 후 이메일로 안내해 드립니다.',
      startsAt: DateTime.utc(2026),
      endsAt: DateTime.utc(2027),
      ctaLabel: 'AI 멘토 보기',
      ctaPath: '/mentor',
    ),
  );
}

void main() {
  // Regression: ISSUE-003 — notice actions were missing from web semantics.
  // Found by /qa on 2026-09-08.
  // Report: .gstack/qa-reports/qa-report-127.0.0.1-2026-09-08.md
  testWidgets('screen readers can discover and activate notice actions', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          noticeBannerControllerProvider.overrideWith(_ReadyController.new),
        ],
        child: MaterialApp(
          theme: DpTheme.light(),
          home: const Scaffold(body: NoticeBannerBar()),
        ),
      ),
    );

    final cta = tester.getSemantics(find.bySemanticsLabel('AI 멘토 보기'));
    expect(cta.getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
    expect(
      cta.getSemanticsData().hasFlag(ui.SemanticsFlag.isFocusable),
      isTrue,
    );

    final dismiss = tester.getSemantics(find.bySemanticsLabel('공지 닫기'));
    expect(
      dismiss.getSemanticsData().hasAction(ui.SemanticsAction.tap),
      isTrue,
    );
    expect(
      dismiss.getSemanticsData().hasFlag(ui.SemanticsFlag.isFocusable),
      isTrue,
    );
    tester.platformDispatcher.onSemanticsActionEvent!(
      ui.SemanticsActionEvent(
        type: ui.SemanticsAction.tap,
        viewId: tester.view.viewId,
        nodeId: dismiss.id,
      ),
    );
    await tester.pump();

    expect(find.textContaining('AI 멘토 순차 초대 안내'), findsNothing);
    semantics.dispose();
  });
}
