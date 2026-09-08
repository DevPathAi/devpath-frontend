import 'package:devpath_web/src/features/mentor/application/mentor_invite_handoff.dart';
import 'package:flutter_test/flutter_test.dart';

class _ThrowingReturnToStore extends MemoryMentorInviteHandoffStore {
  @override
  void rememberReturnTo(String path) {
    throw StateError('sessionStorage write denied');
  }

  @override
  String? takeReturnTo() {
    throw StateError('sessionStorage read denied');
  }
}

void main() {
  test('민감 parameter가 없으면 URL과 저장소를 건드리지 않는다', () {
    final store = MemoryMentorInviteHandoffStore()..writeCode('K' * 43);
    var replacements = 0;

    captureMentorInviteFromUri(
      Uri.parse('https://app.leva.ai.kr/login?utm=home#pricing'),
      store: store,
      replaceVisibleUri: (_) => replacements++,
    );

    expect(replacements, 0);
    expect(store.peekCode(), 'K' * 43);
  });

  test('fragment의 invite와 허용된 returnTo를 세션에 옮기고 즉시 URL에서 제거한다', () {
    final store = MemoryMentorInviteHandoffStore();
    Uri? cleaned;
    final code = 'A' * 43;

    captureMentorInviteFromUri(
      Uri.parse(
        'https://app.leva.ai.kr/login?utm=x#invite=$code&returnTo=%2Fmission%2F42%2Fmentor',
      ),
      store: store,
      replaceVisibleUri: (uri) => cleaned = uri,
    );

    expect(store.takeCode(), code);
    expect(store.takeCode(), isNull);
    expect(store.takeReturnTo(), '/mission/42/mentor');
    expect(cleaned.toString(), 'https://app.leva.ai.kr/login?utm=x');
  });

  test('fragment의 외부 returnTo와 비정상 code는 저장하지 않지만 URL은 지운다', () {
    final store = MemoryMentorInviteHandoffStore();
    Uri? cleaned;

    captureMentorInviteFromUri(
      Uri.parse(
        'https://app.leva.ai.kr/login#invite=raw%20secret&returnTo=https%3A%2F%2Fevil.test',
      ),
      store: store,
      replaceVisibleUri: (uri) => cleaned = uri,
    );

    expect(store.takeCode(), isNull);
    expect(store.takeReturnTo(), isNull);
    expect(cleaned.toString(), 'https://app.leva.ai.kr/login');
  });

  test('중복 invite와 returnTo는 모두 거부하되 주소에서는 전부 제거한다', () {
    final store = MemoryMentorInviteHandoffStore();
    Uri? cleaned;

    captureMentorInviteFromUri(
      Uri.parse(
        'https://app.leva.ai.kr/login#invite=${'A' * 43}&invite=${'B' * 43}'
        '&returnTo=%2Fmentor&returnTo=%2Fmission%2F7%2Fmentor&section=access',
      ),
      store: store,
      replaceVisibleUri: (uri) => cleaned = uri,
    );

    expect(store.peekCode(), isNull);
    expect(store.takeReturnTo(), isNull);
    expect(cleaned.toString(), 'https://app.leva.ai.kr/login#section=access');
  });

  test('legacy query의 invite는 제거만 하고 절대 세션으로 받아들이지 않는다', () {
    final store = MemoryMentorInviteHandoffStore();
    Uri? cleaned;
    final code = 'L' * 43;

    captureMentorInviteFromUri(
      Uri.parse(
        'https://app.leva.ai.kr/login?invite=$code&returnTo=%2Fmentor&utm=x#section-1',
      ),
      store: store,
      replaceVisibleUri: (uri) => cleaned = uri,
    );

    expect(store.takeCode(), isNull);
    expect(store.takeReturnTo(), isNull);
    expect(cleaned.toString(), 'https://app.leva.ai.kr/login?utm=x#section-1');
  });

  test('returnTo 허용 목록은 멘토 루트와 숫자 mission 멘토만 받는다', () {
    expect(isSafeMentorReturnTo('/mentor'), isTrue);
    expect(isSafeMentorReturnTo('/mission/7/mentor'), isTrue);
    expect(isSafeMentorReturnTo('/mission/not-a-number/mentor'), isFalse);
    expect(isSafeMentorReturnTo('//evil.test/mentor'), isFalse);
    expect(isSafeMentorReturnTo('/dashboard'), isFalse);
  });

  test('logout용 clear는 초대 코드와 returnTo를 함께 지운다', () {
    final store = MemoryMentorInviteHandoffStore()
      ..writeCode('A' * 43)
      ..rememberReturnTo('/mentor');

    store.clear();

    expect(store.peekCode(), isNull);
    expect(store.takeReturnTo(), isNull);
  });

  test('returnTo 선택 저장소 실패는 라우팅 helper 밖으로 전파하지 않는다', () {
    final store = _ThrowingReturnToStore();

    expect(
      () => rememberMentorReturnToBestEffort(store, '/mentor'),
      returnsNormally,
    );
    expect(takeMentorReturnToBestEffort(store), isNull);
  });
}
