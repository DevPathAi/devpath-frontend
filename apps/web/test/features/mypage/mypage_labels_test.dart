import 'package:devpath_web/src/features/mypage/application/mypage_controller.dart';
import 'package:devpath_web/src/features/mypage/presentation/mypage_page.dart';
import 'package:devpath_web/src/features/mypage/state/mypage_state.dart';
import 'package:devpath_web/src/features/mentor/data/mentor_access_source.dart';
import 'package:dp_core/dp_core.dart';
import 'package:dp_design/dp_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 3-A Task 14-2: 학습 목표·목표 트랙 드롭다운이 서버 enum 원문(`CAREER_CHANGE`·
/// `BACKEND_SPRING`)을 그대로 노출했다. **표시 라벨만** 한국어로 바꾸고 전송
/// payload(`learningGoal`·`targetTrack`)의 값은 원문 그대로 유지해야 한다.
///
/// 라벨 표시만 단언하면 "라벨을 value로도 써버리는" 회귀를 못 잡는다. 그래서
/// 저장 payload를 캡처해 원문 값이 실려 나가는지 함께 잠근다.
class _CapturingController extends MyPageController {
  _CapturingController(this._initial);
  final MyPageState _initial;

  /// 마지막 saveProfile 호출의 payload.
  Map<String, dynamic>? seen;

  @override
  MyPageState build() => _initial;

  @override
  Future<void> load() async {}

  @override
  Future<void> saveProfile(Map<String, dynamic> body) async {
    seen = body;
  }
}

Widget _host(_CapturingController ctrl) => ProviderScope(
  overrides: [
    myPageControllerProvider.overrideWith(() => ctrl),
    mentorAccessFetchProvider.overrideWithValue(
      () async => const {'status': 'WAITLISTED', 'source': 'SELF'},
    ),
  ],
  child: MaterialApp(theme: DpTheme.light(), home: const MyPagePage()),
);

const _loaded = MyPageLoaded(
  profile: ProfileView(
    bio: '백엔드 지망',
    learningGoal: 'CAREER_CHANGE',
    targetTrack: 'BACKEND_SPRING',
    experienceYears: 2,
  ),
);

void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('학습 목표·트랙이 한국어 라벨로 표시된다 (enum 원문 노출 없음)', (tester) async {
    _tallView(tester);
    final ctrl = _CapturingController(_loaded);
    await tester.pumpWidget(_host(ctrl));
    await tester.pump();

    expect(find.text('CAREER_CHANGE'), findsNothing);
    expect(find.text('BACKEND_SPRING'), findsNothing);
    expect(find.text('커리어 전환'), findsWidgets);
    expect(find.text('백엔드 (Spring)'), findsWidgets);
  });

  testWidgets('라벨을 바꿔도 저장 payload에는 enum 원문이 실린다', (tester) async {
    _tallView(tester);
    final ctrl = _CapturingController(_loaded);
    await tester.pumpWidget(_host(ctrl));
    await tester.pump();

    // 학습 목표 드롭다운을 열어 '역량 강화'(UPSKILL)로 바꾼다.
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('역량 강화').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pump();

    expect(ctrl.seen, isNotNull);
    expect(ctrl.seen!['learningGoal'], 'UPSKILL');
    expect(ctrl.seen!['targetTrack'], 'BACKEND_SPRING'); // 손대지 않은 값도 원문 유지
  });
}
