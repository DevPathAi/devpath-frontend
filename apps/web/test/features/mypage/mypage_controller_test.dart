import 'package:devpath_web/src/features/mypage/application/mypage_controller.dart';
import 'package:devpath_web/src/features/mypage/data/mypage_source.dart';
import 'package:devpath_web/src/features/mypage/state/mypage_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('load()는 프로필+집계를 병렬 로드해 합성한다', () async {
    final c = ProviderContainer(
      overrides: [
        myProfileFetchProvider.overrideWithValue(
          () async =>
              const ProfileView(bio: '백엔드 지망', targetTrack: 'BACKEND_SPRING'),
        ),
        myDashboardFetchProvider.overrideWithValue(
          () async => const DashboardSummary(
            streakDays: 3,
            progressPercent: 40,
            completedContentCount: 7,
          ),
        ),
        myActivityFetchProvider.overrideWithValue(
          () async => const MyActivity(questionCount: 2, answerCount: 5),
        ),
      ],
    );
    addTearDown(c.dispose);

    await c.read(myPageControllerProvider.notifier).load();
    final s = c.read(myPageControllerProvider);

    expect(s, isA<MyPageLoaded>());
    final loaded = s as MyPageLoaded;
    expect(loaded.profile.bio, '백엔드 지망');
    expect(loaded.dashboard?.completedContentCount, 7);
    expect(loaded.activity?.questionCount, 2);
  });

  test('집계 svc 부분 실패는 해당 섹션만 null, 전체 유지', () async {
    final c = ProviderContainer(
      overrides: [
        myProfileFetchProvider.overrideWithValue(
          () async => const ProfileView(bio: 'x'),
        ),
        myDashboardFetchProvider.overrideWithValue(
          () async => throw const ApiException(
            code: ApiErrorCode.unknown,
            message: 'down',
            status: 500,
          ),
        ),
        myActivityFetchProvider.overrideWithValue(
          () async => const MyActivity(questionCount: 1, answerCount: 0),
        ),
      ],
    );
    addTearDown(c.dispose);

    await c.read(myPageControllerProvider.notifier).load();
    final loaded = c.read(myPageControllerProvider) as MyPageLoaded;

    expect(loaded.dashboard, isNull); // 실패 섹션
    expect(loaded.activity?.questionCount, 1); // 성공 섹션 유지
  });

  test('프로필(핵심) 실패는 전체 MyPageFailed', () async {
    final c = ProviderContainer(
      overrides: [
        myProfileFetchProvider.overrideWithValue(
          () async => throw const ApiException(
            code: ApiErrorCode.unknown,
            message: '프로필 실패',
            status: 500,
          ),
        ),
        myDashboardFetchProvider.overrideWithValue(
          () async => const DashboardSummary(streakDays: 0, progressPercent: 0),
        ),
        myActivityFetchProvider.overrideWithValue(
          () async => const MyActivity(),
        ),
      ],
    );
    addTearDown(c.dispose);

    await c.read(myPageControllerProvider.notifier).load();
    expect(c.read(myPageControllerProvider), isA<MyPageFailed>());
  });
}
