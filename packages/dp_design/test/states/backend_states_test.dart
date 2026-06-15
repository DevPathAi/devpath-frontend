import 'package:dp_design/src/states/dp_kill_switch.dart';
import 'package:dp_design/src/states/dp_offline_banner.dart';
import 'package:dp_design/src/states/dp_quota.dart';
import 'package:dp_design/src/states/dp_sse_stage.dart';
import 'package:dp_design/src/theme/dp_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  theme: DpTheme.light(),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('KillSwitch는 점검 안내 + 대체 행동을 제공한다', (tester) async {
    var alt = false;
    await tester.pumpWidget(
      _host(
        DpKillSwitch(
          altActionLabel: '커뮤니티 둘러보기',
          onAltAction: () => alt = true,
        ),
      ),
    );
    expect(find.textContaining('점검'), findsOneWidget);
    await tester.tap(find.text('커뮤니티 둘러보기'));
    expect(alt, isTrue);
  });

  testWidgets('Quota는 Retry-After 초를 노출한다', (tester) async {
    await tester.pumpWidget(_host(const DpQuota(retryAfterSeconds: 30)));
    expect(find.textContaining('30'), findsOneWidget);
  });

  // F6-b: Retry-After null(헤더 미제공)이면 0초 오안내 없이 무기한 문구로 분기.
  testWidgets('Quota는 retryAfter=null이면 무기한 문구(0초 미표시)', (tester) async {
    await tester.pumpWidget(_host(const DpQuota(retryAfterSeconds: null)));
    expect(find.textContaining('0초'), findsNothing);
    expect(find.textContaining('잠시 후 다시 시도'), findsOneWidget);
  });

  // F6-b: 음수(시계 오차 등)도 음수 표시 없이 무기한 문구로 안전 처리.
  testWidgets('Quota는 retryAfter=음수면 음수 표시 없이 무기한 문구', (tester) async {
    await tester.pumpWidget(_host(const DpQuota(retryAfterSeconds: -5)));
    expect(find.textContaining('-5'), findsNothing);
    expect(find.textContaining('잠시 후 다시 시도'), findsOneWidget);
  });

  testWidgets('OfflineBanner는 캐시 안내를 보인다', (tester) async {
    await tester.pumpWidget(_host(const DpOfflineBanner()));
    expect(find.textContaining('오프라인'), findsOneWidget);
  });

  testWidgets('SseStage는 단계 라벨과 진행을 렌더한다', (tester) async {
    await tester.pumpWidget(
      _host(
        const DpSseStageView(
          stages: ['GitHub 분석', '약점 매핑', '주차 배치'],
          currentIndex: 1,
        ),
      ),
    );
    expect(find.text('약점 매핑'), findsOneWidget);
  });
}
