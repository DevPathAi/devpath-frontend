import 'dart:async';

import 'package:devpath_mobile/src/features/auth/application/deep_link_service.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeDeepLinkSource implements DeepLinkSource {
  final links = StreamController<Uri>.broadcast(sync: true);

  @override
  Stream<Uri> get uriLinkStream => links.stream;

  Future<void> close() => links.close();
}

void main() {
  test('first OAuth event and a later same code are both delivered', () async {
    final source = _FakeDeepLinkSource();
    addTearDown(source.close);
    final codes = <String>[];
    final service = DeepLinkService(source, onCode: codes.add);
    addTearDown(service.dispose);
    await service.start();

    source.links.add(Uri.parse('devpath://callback#code=one-use'));
    await pumpEventQueue();
    source.links.add(Uri.parse('devpath://callback?code=one-use'));
    await pumpEventQueue();

    // AuthController coalesces only concurrent exchange of the exact code;
    // a later delivery reaches server consumed-code handling.
    expect(codes, ['one-use', 'one-use']);
  });

  test(
    'first route and later intentional same-route tap are delivered',
    () async {
      final source = _FakeDeepLinkSource();
      addTearDown(source.close);
      final routes = <String>[];
      final service = DeepLinkService(
        source,
        onCode: (_) {},
        onRoute: routes.add,
      );
      addTearDown(service.dispose);
      await service.start();
      final route = Uri.parse('https://app.leva.ai.kr/path/301/today');

      source.links.add(route);
      source.links.add(route);
      await pumpEventQueue();

      expect(routes, ['/path/301/today', '/path/301/today']);
    },
  );

  test('start is idempotent and keeps one stream subscription', () async {
    final source = _FakeDeepLinkSource();
    addTearDown(source.close);
    final routes = <String>[];
    final service = DeepLinkService(
      source,
      onCode: (_) {},
      onRoute: routes.add,
    );
    addTearDown(service.dispose);

    await service.start();
    await service.start();
    source.links.add(Uri.parse('https://app.leva.ai.kr/path/18/today'));

    expect(routes, ['/path/18/today']);
  });

  test('dispose discards all later links', () async {
    final source = _FakeDeepLinkSource();
    addTearDown(source.close);
    final codes = <String>[];
    final service = DeepLinkService(source, onCode: codes.add);
    await service.start();
    await service.dispose();

    source.links.add(Uri.parse('devpath://callback?code=late'));
    await pumpEventQueue();

    expect(codes, isEmpty);
  });

  test('stream error is contained and later links remain usable', () async {
    final source = _FakeDeepLinkSource();
    addTearDown(source.close);
    final routes = <String>[];
    final service = DeepLinkService(
      source,
      onCode: (_) {},
      onRoute: routes.add,
    );
    addTearDown(service.dispose);
    await service.start();

    source.links.addError(StateError('platform stream failure'));
    source.links.add(
      Uri.parse('https://app.leva.ai.kr/mission/302/content/77'),
    );
    await pumpEventQueue();

    expect(routes, ['/mission/302/content/77']);
  });
}
