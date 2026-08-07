import 'package:devpath_web/src/features/auth/application/auth_controller.dart';
import 'package:devpath_web/src/features/auth/state/auth_state.dart';
import 'package:devpath_web/src/features/path/data/path_sse_source.dart';
import 'package:devpath_web/src/features/path/presentation/path_page.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _AuthedAuthController extends AuthController {
  @override
  AuthState build() => const AuthAuthenticated(
    User(
      id: '73',
      email: 'e2e@devpath.local',
      nickname: 'E2E',
      role: UserRole.learner,
      onboardingStatus: OnboardingStatus.done,
      consentStatus: ConsentStatus.done,
    ),
  );
}

/// 화면 제목의 소재(所在) 계약: **제목은 페이지 헤더에만 있고 본문은 반복하지 않는다.**
///
/// 이전 판은 테스트가 직접 조립한 `Column`에 `DpPageHeader(title: '학습 경로')`를
/// 넣고 본문만 실제 위젯을 썼다. 그러면 **화면(`PathPage`)의 제목을 바꿔도 red가
/// 나지 않는다** — 기대값과 렌더 대상이 둘 다 테스트 안에 있어 동어반복이었다.
/// 실제 `PathPage`를 렌더해 그 헤더에서 제목을 읽는다.
void main() {
  testWidgets('헤더가 화면 제목을 갖고 본문은 그것을 반복하지 않는다', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // 제목은 SSE 진행과 무관하게 렌더되므로 빈 스트림으로 충분하다.
    final c = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_AuthedAuthController.new),
        pathSseConnectProvider.overrideWithValue(
          () => const Stream<SseEvent>.empty(),
        ),
      ],
    );
    addTearDown(c.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(theme: DpTheme.light(), home: const PathPage()),
      ),
    );
    await tester.pumpAndSettle();

    // 화면이 실제로 갖는 제목을 읽는다 — PathPage의 제목이 바뀌면 red다.
    final header = tester.widget<DpPageHeader>(find.byType(DpPageHeader));
    expect(header.title, '학습 경로');

    // 본문 반복 금지는 텍스트의 **개수**가 계약이므로 find.text로만 확인할 수 있다.
    // (셸 없이 PathPage만 렌더하므로 레일 라벨·브레드크럼과 충돌하지 않는다.)
    expect(find.text('학습 경로'), findsOneWidget);
  });
}
