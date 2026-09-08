import 'package:devpath_web/src/features/mypage/application/mypage_controller.dart';
import 'package:devpath_web/src/features/mypage/presentation/mypage_page.dart';
import 'package:devpath_web/src/features/mypage/state/mypage_state.dart';
import 'package:devpath_web/src/features/mentor/application/mentor_access_controller.dart';
import 'package:devpath_web/src/features/mentor/state/mentor_access_state.dart';
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

class _FixedMentorAccessController extends MentorAccessController {
  _FixedMentorAccessController(this._initial);
  final MentorAccessState _initial;

  @override
  MentorAccessState build() => _initial;

  @override
  Future<void> load() async {}
}

Widget _host(
  MyPageState state, {
  MentorAccessState mentorAccess = const MentorAccessReady(
    status: 'WAITLISTED',
    source: 'SELF',
  ),
}) => ProviderScope(
  key: UniqueKey(),
  overrides: [
    myPageControllerProvider.overrideWith(() => _FixedController(state)),
    mentorAccessControllerProvider.overrideWith(
      () => _FixedMentorAccessController(mentorAccess),
    ),
  ],
  child: MaterialApp(theme: DpTheme.light(), home: const MyPagePage()),
);

void main() {
  const loaded = MyPageLoaded(
    profile: ProfileView(bio: '백엔드 지망'),
    dashboard: DashboardSummary(
      streakDays: 3,
      progressPercent: 40,
      completedContentCount: 7,
    ),
    activity: MyActivity(questionCount: 2, answerCount: 5),
  );

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

    expect(tester.takeException(), isNull);
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

    expect(tester.takeException(), isNull);
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

  testWidgets('AI 멘토 카드는 네 상태를 구분하고 대기 일정을 보장하지 않는다', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    for (final testCase in <(MentorAccessState, String)>[
      (const MentorAccessLoading(), '초대 상태를 확인하는 중입니다.'),
      (const MentorAccessFailed('offline'), '초대 상태를 불러오지 못했습니다.'),
      (
        const MentorAccessReady(status: 'WAITLISTED', source: 'SELF'),
        '담당자가 확인 후 초대 일정을 이메일로 안내해 드립니다.',
      ),
      (
        const MentorAccessReady(status: 'ACTIVE', source: 'INVITE_CODE'),
        'AI 멘토를 사용할 수 있습니다.',
      ),
    ]) {
      await tester.pumpWidget(_host(loaded, mentorAccess: testCase.$1));
      await tester.pump();
      expect(find.textContaining(testCase.$2), findsOneWidget);
      expect(find.textContaining('1일 안에'), findsNothing);
    }
  });
}
