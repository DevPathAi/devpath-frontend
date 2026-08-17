import 'dart:async';

import 'package:devpath_mobile/src/data/owner_data_store.dart';
import 'package:devpath_mobile/src/features/community/data/quick_capture_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quick capture draft is durable and owner scoped', () async {
    final data = InMemoryOwnerDataStore();
    final first = QuickCaptureStore(data);
    const draft = QuickCaptureDraft(title: '질문', body: '본문', tags: ['dart']);
    await first.write('owner-a', draft);

    expect(await QuickCaptureStore(data).read('owner-a'), draft);
    expect(await first.read('owner-b'), isNull);
    await first.clear('owner-a');
    expect(await first.read('owner-a'), isNull);
  });

  test(
    'submit clear waits for an older draft write and cannot resurrect it',
    () async {
      final data = _DelayedWriteStore();
      final store = QuickCaptureStore(data);
      const draft = QuickCaptureDraft(title: '질문', body: '본문');

      final writing = store.write('owner-a', draft);
      await data.started.future;
      final clearing = store.clear('owner-a');
      data.release.complete();
      await Future.wait([writing, clearing]);

      expect(await store.read('owner-a'), isNull);
    },
  );
}

class _DelayedWriteStore extends InMemoryOwnerDataStore {
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
    started.complete();
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
