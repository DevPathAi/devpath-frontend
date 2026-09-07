import 'dart:async';

import 'package:devpath_web/src/features/mentor/application/mentor_access_controller.dart';
import 'package:devpath_web/src/features/mentor/data/mentor_access_source.dart';
import 'package:devpath_web/src/features/mentor/state/mentor_access_state.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('대기 상태와 활성 상태를 서버 응답 그대로 보존한다', () async {
    var response = <String, dynamic>{
      'status': 'WAITLISTED',
      'source': 'SELF',
      'waitlistedAt': '2026-09-05T00:00:00Z',
      'activatedAt': null,
    };
    final container = ProviderContainer(
      overrides: [
        mentorAccessFetchProvider.overrideWithValue(() async => response),
      ],
    );
    addTearDown(container.dispose);

    await container.read(mentorAccessControllerProvider.notifier).load();
    final waiting = container.read(mentorAccessControllerProvider);
    expect(waiting, isA<MentorAccessReady>());
    expect((waiting as MentorAccessReady).isActive, isFalse);

    response = <String, dynamic>{
      'status': 'ACTIVE',
      'source': 'INVITE_CODE',
      'waitlistedAt': '2026-09-05T00:00:00Z',
      'activatedAt': '2026-09-05T01:00:00Z',
    };
    await container.read(mentorAccessControllerProvider.notifier).load();
    expect(
      (container.read(mentorAccessControllerProvider) as MentorAccessReady)
          .isActive,
      isTrue,
    );
  });

  test('늦게 끝난 이전 요청이 최신 활성 상태를 덮지 않는다', () async {
    final first = Completer<Map<String, dynamic>>();
    final second = Completer<Map<String, dynamic>>();
    var request = 0;
    final container = ProviderContainer(
      overrides: [
        mentorAccessFetchProvider.overrideWithValue(() {
          request++;
          return request == 1 ? first.future : second.future;
        }),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(mentorAccessControllerProvider.notifier);
    final older = controller.load();
    final newer = controller.load();
    second.complete({
      'status': 'ACTIVE',
      'source': 'INVITE_CODE',
      'waitlistedAt': '2026-09-05T00:00:00Z',
      'activatedAt': '2026-09-05T01:00:00Z',
    });
    await newer;
    first.complete({
      'status': 'WAITLISTED',
      'source': 'SELF',
      'waitlistedAt': '2026-09-05T00:00:00Z',
      'activatedAt': null,
    });
    await older;

    final state = container.read(mentorAccessControllerProvider);
    expect(state, isA<MentorAccessReady>());
    expect((state as MentorAccessReady).isActive, isTrue);
  });

  test('API 오류 메시지와 비정상 응답 오류를 사용자 상태로 변환한다', () async {
    var apiFailure = true;
    final container = ProviderContainer(
      overrides: [
        mentorAccessFetchProvider.overrideWithValue(() async {
          if (apiFailure) {
            throw const ApiException(
              code: ApiErrorCode.network,
              message: '초대 상태 서버에 연결할 수 없어요.',
            );
          }
          return const <String, dynamic>{'status': 7, 'source': 'SELF'};
        }),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(mentorAccessControllerProvider.notifier);

    await controller.load();
    expect(
      container.read(mentorAccessControllerProvider),
      isA<MentorAccessFailed>().having(
        (state) => state.message,
        'message',
        '초대 상태 서버에 연결할 수 없어요.',
      ),
    );

    apiFailure = false;
    await controller.load();
    expect(
      container.read(mentorAccessControllerProvider),
      isA<MentorAccessFailed>().having(
        (state) => state.message,
        'message',
        'AI 멘토 초대 상태를 불러오지 못했어요.',
      ),
    );
  });
}
