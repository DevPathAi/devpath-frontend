import 'dart:async';

import 'package:devpath_mobile/src/features/auth/application/deep_link_service.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeDeepLinkSource implements DeepLinkSource {
  final initial = Completer<Uri?>();
  final links = StreamController<Uri>.broadcast(sync: true);

  @override
  Future<Uri?> getInitialLink() => initial.future;

  @override
  Stream<Uri> get uriLinkStream => links.stream;

  Future<void> close() => links.close();
}

void main() {
  test(
    'initial OAuth callback and its first stream replay exchange once',
    () async {
      final source = _FakeDeepLinkSource();
      addTearDown(source.close);
      final codes = <String>[];
      final service = DeepLinkService(source, onCode: codes.add);
      addTearDown(service.dispose);
      final starting = service.start();
      source.links.add(Uri.parse('devpath://callback#code=one-use'));
      source.initial.complete(Uri.parse('devpath://callback?code=one-use'));

      await starting;
      await pumpEventQueue();
      source.links.add(Uri.parse('devpath://callback?code=one-use'));
      await pumpEventQueue();

      expect(codes, ['one-use']);
    },
  );

  test(
    'warm route during initial lookup is kept and startup echo deduped',
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
      final route = Uri.parse('https://app.leva.ai.kr/path/301/today');
      final starting = service.start();
      source.links.add(route);
      source.initial.complete(route);

      await starting;
      expect(routes, ['/path/301/today']);

      source.links.add(route);
      await pumpEventQueue();
      expect(routes, ['/path/301/today', '/path/301/today']);
    },
  );

  test(
    'dispose before initial lookup completion discards every late link',
    () async {
      final source = _FakeDeepLinkSource();
      addTearDown(source.close);
      final codes = <String>[];
      final routes = <String>[];
      final service = DeepLinkService(
        source,
        onCode: codes.add,
        onRoute: routes.add,
      );
      final starting = service.start();
      source.links.add(Uri.parse('https://app.leva.ai.kr/path/301/today'));
      await service.dispose();
      source.initial.complete(Uri.parse('devpath://callback?code=late'));

      await starting;
      await pumpEventQueue();

      expect(codes, isEmpty);
      expect(routes, isEmpty);
    },
  );

  test(
    'initial lookup failure does not disable subscribed warm links',
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
      final starting = service.start();
      source.links.add(
        Uri.parse('https://app.leva.ai.kr/mission/302/content/77'),
      );
      source.initial.completeError(StateError('platform initial-link failure'));

      await expectLater(starting, throwsStateError);
      expect(routes, ['/mission/302/content/77']);
    },
  );
}
