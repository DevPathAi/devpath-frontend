import 'package:devpath_web/src/features/mentor/application/mentor_access_controller.dart';
import 'package:devpath_web/src/features/mentor/data/mentor_access_source.dart';
import 'package:devpath_web/src/features/mentor/state/mentor_access_state.dart';
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
}
