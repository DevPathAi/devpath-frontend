import 'dart:async';

import 'package:devpath_mobile/src/data/key_value_store.dart';
import 'package:devpath_mobile/src/data/owner_data_store.dart';
import 'package:devpath_mobile/src/features/auth/application/account_epoch_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'owner clear removes every bucket without touching another owner',
    () async {
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
    },
  );

  test(
    'write finishing after account epoch advance cannot resurrect data',
    () async {
      final inner = _DelayedOwnerDataStore();
      final epochs = AccountEpochStore(InMemoryKeyValueStore());
      final guarded = EpochGuardedOwnerDataStore(inner, epochs);

      final writing = guarded.write('owner-a', 'draft', 'question', 'late');
      await inner.started.future;
      await epochs.advance();
      inner.release.complete();
      await writing;

      expect(await guarded.read('owner-a', 'draft', 'question'), isNull);
    },
  );

  test('older epoch cleanup cannot delete a newer same-owner write', () async {
    final inner = _DelayedOwnerDataStore();
    final epochs = AccountEpochStore(InMemoryKeyValueStore());
    final guarded = EpochGuardedOwnerDataStore(inner, epochs);

    final stale = guarded.write('owner-a', 'draft', 'question', 'stale');
    await inner.started.future;
    await epochs.advance();
    final fresh = guarded.write('owner-a', 'draft', 'question', 'fresh');
    inner.release.complete();
    await Future.wait([stale, fresh]);

    expect(
      (await guarded.read('owner-a', 'draft', 'question'))?.payload,
      'fresh',
    );
  });
}

class _DelayedOwnerDataStore extends InMemoryOwnerDataStore {
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<void> write(
    String ownerKey,
    String bucket,
    String recordKey,
    String payload, {
    DateTime? updatedAt,
  }) async {
    if (!started.isCompleted) started.complete();
    await release.future;
    await super.write(
      ownerKey,
      bucket,
      recordKey,
      payload,
      updatedAt: updatedAt,
    );
  }
}
