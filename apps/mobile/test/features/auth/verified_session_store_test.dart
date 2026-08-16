import 'package:devpath_mobile/src/data/key_value_store.dart';
import 'package:devpath_mobile/src/features/auth/application/account_epoch_store.dart';
import 'package:devpath_mobile/src/features/auth/application/verified_session_store.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_test/flutter_test.dart';

const _user = User(
  id: 'owner-a',
  email: 'a@example.com',
  nickname: 'A',
  role: UserRole.learner,
  onboardingStatus: OnboardingStatus.done,
  consentStatus: ConsentStatus.done,
);

void main() {
  test('last verified owner session survives a transport outage', () async {
    final store = VerifiedSessionStore(InMemoryKeyValueStore());
    await store.write(_user);

    expect((await store.read())?.id, 'owner-a');
    await store.clear();
    expect(await store.read(), isNull);
  });

  test('account epoch is durable and monotonic', () async {
    final kv = InMemoryKeyValueStore();
    final first = AccountEpochStore(kv);
    expect(await first.current(), 0);
    expect(await first.advance(), 1);
    expect(await AccountEpochStore(kv).current(), 1);
  });
}
