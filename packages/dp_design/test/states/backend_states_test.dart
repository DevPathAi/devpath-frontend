import 'package:dp_design/src/states/dp_kill_switch.dart';
import 'package:dp_design/src/states/dp_offline_banner.dart';
import 'package:dp_design/src/states/dp_quota.dart';
import 'package:dp_design/src/states/dp_sse_stage.dart';
import 'package:dp_design/src/theme/dp_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) =>
    MaterialApp(theme: DpTheme.light(), home: Scaffold(body: child));

void main() {
  testWidgets('KillSwitch는 점검 안내 + 대체 행동을 제공한다', (tester) async {
    var alt = false;
    await tester.pumpWidget(_host(DpKillSwitch(
      altActionLabel: '커뮤니티 둘러보기',
      onAltAction: () => alt = true,
    )));
    expect(find.textContaining('점검'), findsOneWidget);
    await tester.tap(find.text('커뮤니티 둘러보기'));
    expect(alt, isTrue);
  });

  testWidgets('Quota는 Retry-After 초를 노출한다', (tester) async {
    await tester.pumpWidget(_host(const DpQuota(retryAfterSeconds: 30)));
    expect(find.textContaining('30'), findsOneWidget);
  });

  testWidgets('OfflineBanner는 캐시 안내를 보인다', (tester) async {
    await tester.pumpWidget(_host(const DpOfflineBanner()));
    expect(find.textContaining('오프라인'), findsOneWidget);
  });

  testWidgets('SseStage는 단계 라벨과 진행을 렌더한다', (tester) async {
    await tester.pumpWidget(_host(const DpSseStageView(
      stages: ['GitHub 분석', '약점 매핑', '주차 배치'],
      currentIndex: 1,
    )));
    expect(find.text('약점 매핑'), findsOneWidget);
  });
}
