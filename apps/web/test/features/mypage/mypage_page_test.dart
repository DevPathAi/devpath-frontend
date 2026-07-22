import 'package:devpath_web/src/features/mypage/application/mypage_controller.dart';
import 'package:devpath_web/src/features/mypage/presentation/mypage_page.dart';
import 'package:devpath_web/src/features/mypage/state/mypage_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// MyPageState를 고정하는 컨트롤러. load()는 no-op이라 fetch provider 의존 없이
/// 페이지 위젯 렌더만 검증한다(initState의 postFrameCallback도 무해).
class _FixedController extends MyPageController {
  _FixedController(this._initial);
  final MyPageState _initial;

  @override
  MyPageState build() => _initial;

  @override
  Future<void> load() async {}
}

Widget _host(MyPageState state) => ProviderScope(
  overrides: [
    myPageControllerProvider.overrideWith(() => _FixedController(state)),
  ],
  child: MaterialApp(theme: DpTheme.light(), home: const MyPagePage()),
);

void main() {
  testWidgets('MyPageLoaded: 프로필 편집 폼 + 활동 집계 + 설정 진입 렌더', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        const MyPageLoaded(
          profile: ProfileView(
            bio: '백엔드 지망',
            targetTrack: 'BACKEND_SPRING',
            experienceYears: 2,
          ),
          dashboard: DashboardSummary(
            streakDays: 3,
            progressPercent: 40,
            completedContentCount: 7,
          ),
          activity: MyActivity(questionCount: 2, answerCount: 5),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('마이페이지'), findsOneWidget); // AppBar 타이틀
    expect(find.text('프로필 편집'), findsOneWidget);
    expect(find.text('저장'), findsOneWidget);
    // 활동 집계(성공 섹션)
    expect(find.text('완료한 콘텐츠 7개'), findsOneWidget);
    expect(find.textContaining('작성한 질문 2'), findsOneWidget);
    // 설정 진입 카드
    expect(find.text('설정'), findsOneWidget);

    // 소스의 설정 카드는 ListTile을 배경색 있는 DecoratedBox로 감싸 프레임워크가
    // "ink splashes may be invisible" 경고 assertion을 던진다(디버그 전용, 렌더 정상).
    // lib/ 소스는 이 작업 범위 밖(불변)이므로 여기서 소비만 한다.
    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('MyPageLoaded: 집계 부분 실패 시 안내 문구 렌더', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        const MyPageLoaded(
          profile: ProfileView(bio: 'x'),
          // dashboard·activity 모두 null → 실패 안내
        ),
      ),
    );
    await tester.pump();

    expect(find.text('학습 활동을 불러오지 못했습니다'), findsOneWidget);
    expect(find.text('커뮤니티 활동을 불러오지 못했습니다'), findsOneWidget);

    // 설정 카드 ListTile-in-DecoratedBox 디버그 assertion 소비(위 참조).
    expect(tester.takeException(), isAssertionError);
  });

  testWidgets('MyPageLoading: 로딩 인디케이터 렌더', (tester) async {
    await tester.pumpWidget(_host(const MyPageLoading()));
    await tester.pump();

    expect(find.byType(DpLoading), findsOneWidget);
  });

  testWidgets('MyPageFailed: 에러 + 재시도 렌더', (tester) async {
    await tester.pumpWidget(_host(const MyPageFailed('프로필을 불러오지 못했습니다')));
    await tester.pump();

    expect(find.byType(DpError), findsOneWidget);
    expect(find.textContaining('프로필을 불러오지 못했습니다'), findsWidgets);
  });
}
