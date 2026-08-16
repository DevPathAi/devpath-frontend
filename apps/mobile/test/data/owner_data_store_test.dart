import 'package:devpath_mobile/src/data/owner_data_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('owner clear removes every bucket without touching another owner', () async {
    final store = InMemoryOwnerDataStore();
    await store.write('owner-a', 'content', '101', 'content-a');
    await store.write('owner-a', 'progress', '101', 'progress-a');
    await store.write('owner-a', 'draft', 'question', 'draft-a');
    await store.write('owner-a', 'notification', 'n1', 'notification-a');
    await store.write('owner-a', 'device', 'token', 'device-a');
    await store.write('owner-b', 'content', '101', 'content-b');

    await store.clearOwner('owner-a');

    expect(await store.list('owner-a'), isEmpty);
    expect(
      (await store.read('owner-b', 'content', '101'))?.payload,
      'content-b',
    );
  });
}
