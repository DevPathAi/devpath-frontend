import 'package:devpath_mobile/src/data/owner_data_store.dart';
import 'package:devpath_mobile/src/features/community/data/quick_capture_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('quick capture draft is durable and owner scoped', () async {
    final data = InMemoryOwnerDataStore();
    final first = QuickCaptureStore(data);
    const draft = QuickCaptureDraft(
      title: '질문',
      body: '본문',
      tags: ['dart'],
    );
    await first.write('owner-a', draft);

    expect(await QuickCaptureStore(data).read('owner-a'), draft);
    expect(await first.read('owner-b'), isNull);
    await first.clear('owner-a');
    expect(await first.read('owner-a'), isNull);
  });
}
