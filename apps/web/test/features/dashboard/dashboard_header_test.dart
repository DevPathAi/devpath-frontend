import 'package:devpath_web/src/features/ads/data/ads_source.dart';
import 'package:devpath_web/src/features/dashboard/presentation/dashboard_page.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('대시보드는 AppBar 대신 DpPageHeader를 쓴다', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // 광고 위젯은 이 테스트 범위 밖 — 네트워크 미실행(fail-silent null).
        // content_page_test.dart와 같은 패턴.
        overrides: [adFetchProvider.overrideWithValue((slot) async => null)],
        child: MaterialApp(theme: DpTheme.light(), home: const DashboardPage()),
      ),
    );
    // 단일 pump는 initState의 postFrameCallback이 시작한 목 API 호출이 쓰는
    // 0-duration Timer를 비우지 못해 테스트 종료 시 "pending timer" 단언이
    // 깨진다(dio 내부 타이머). 두 번째 pump로 그 타이머를 흘려보낸다 —
    // 로딩 완주까지 기다릴 필요는 없다(헤더/AppBar 부재만 검증).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AppBar), findsNothing);
    final header = tester.widget<DpPageHeader>(find.byType(DpPageHeader));
    expect(header.title, '대시보드');
    expect(header.description, '이번 주 학습 현황과 다음 과제를 한눈에 봅니다');
  });
}
