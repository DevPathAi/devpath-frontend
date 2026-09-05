import 'package:devpath_web/src/features/mentor/application/mentor_invite_handoff.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('invite와 허용된 returnTo를 세션에 옮기고 즉시 URL에서 제거한다', () {
    final store = MemoryMentorInviteHandoffStore();
    Uri? cleaned;
    final code = 'A' * 43;

    captureMentorInviteFromUri(
      Uri.parse(
        'https://app.leva.ai.kr/login?invite=$code&returnTo=%2Fmission%2F42%2Fmentor&utm=x',
      ),
      store: store,
      replaceVisibleUri: (uri) => cleaned = uri,
    );

    expect(store.takeCode(), code);
    expect(store.takeCode(), isNull);
    expect(store.takeReturnTo(), '/mission/42/mentor');
    expect(cleaned.toString(), 'https://app.leva.ai.kr/login?utm=x');
  });

  test('외부·비허용 returnTo와 비정상 code는 저장하지 않지만 URL은 지운다', () {
    final store = MemoryMentorInviteHandoffStore();
    Uri? cleaned;

    captureMentorInviteFromUri(
      Uri.parse(
        'https://app.leva.ai.kr/login?invite=raw%20secret&returnTo=https%3A%2F%2Fevil.test',
      ),
      store: store,
      replaceVisibleUri: (uri) => cleaned = uri,
    );

    expect(store.takeCode(), isNull);
    expect(store.takeReturnTo(), isNull);
    expect(cleaned.toString(), 'https://app.leva.ai.kr/login');
  });

  test('returnTo 허용 목록은 멘토 루트와 숫자 mission 멘토만 받는다', () {
    expect(isSafeMentorReturnTo('/mentor'), isTrue);
    expect(isSafeMentorReturnTo('/mission/7/mentor'), isTrue);
    expect(isSafeMentorReturnTo('/mission/not-a-number/mentor'), isFalse);
    expect(isSafeMentorReturnTo('//evil.test/mentor'), isFalse);
    expect(isSafeMentorReturnTo('/dashboard'), isFalse);
  });
}
