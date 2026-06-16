import 'package:devpath_web/src/features/content/application/content_controller.dart';
import 'package:devpath_web/src/features/content/state/content_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('콘텐츠 로드 성공 시 마크다운을 담는다', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(contentControllerProvider.notifier).load('c1');

    final s = container.read(contentControllerProvider);
    expect(s, isA<ContentLoaded>());
    expect((s as ContentLoaded).markdown, contains('#'));
  });
}
