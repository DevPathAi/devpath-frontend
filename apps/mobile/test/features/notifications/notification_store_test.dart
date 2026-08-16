import 'package:devpath_mobile/src/data/owner_data_store.dart';
import 'package:devpath_mobile/src/features/notifications/data/notification_store.dart';
import 'package:devpath_mobile/src/services/push_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification store deduplicates IDs and preserves typed target', () async {
    final store = NotificationStore(InMemoryOwnerDataStore());
    final first = DateTime.utc(2026, 8, 16, 1);
    const message = PushMessage(
      id: 'm1',
      title: '계속 학습',
      body: 'Async',
      target: PushTarget.content(taskId: 302, contentId: 77),
    );
    expect(await store.add('owner-a', message, receivedAt: first), isTrue);
    expect(await store.add('owner-a', message, receivedAt: first), isFalse);

    final saved = await store.list('owner-a');
    expect(saved, hasLength(1));
    expect(saved.single.message.target?.location, '/mission/302/content/77');
    expect(saved.single.isRead, isFalse);
    await store.markAllRead('owner-a');
    expect((await store.list('owner-a')).single.isRead, isTrue);
  });
}
