import 'package:devpath_mobile/src/app/app_config.dart';
import 'package:devpath_mobile/src/providers/api_providers.dart';
import 'package:devpath_mobile/src/services/push_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StubPushService 계약', () {
    test('getToken은 고정 스텁 토큰을 반환한다', () async {
      final svc = StubPushService();
      expect(await svc.getToken(), 'stub-fcm-token');
    });

    test('incoming은 빈 스트림이다(스텁: 포그라운드 수신 없음)', () async {
      final svc = StubPushService();
      expect(await svc.incoming.isEmpty, isTrue);
    });
  });

  group('pushMessageFromRemote 매핑', () {
    test('notification 필드를 PushMessage로 매핑한다', () {
      final pm = pushMessageFromRemote(
        const RemoteMessage(
          messageId: 'm1',
          notification: RemoteNotification(title: '제목', body: '본문'),
        ),
      );
      expect(pm.id, 'm1');
      expect(pm.title, '제목');
      expect(pm.body, '본문');
    });

    test('결측 필드는 빈 문자열로 매핑한다', () {
      final pm = pushMessageFromRemote(const RemoteMessage());
      expect(pm.id, '');
      expect(pm.title, '');
      expect(pm.body, '');
    });
  });

  group('pushServiceProvider 결선(교체 경계)', () {
    test('useMock=true → StubPushService', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(pushServiceProvider), isA<StubPushService>());
    });

    test('useMock=false → FcmPushService', () {
      final c = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(baseUrl: 'https://api.test', useMock: false),
          ),
        ],
      );
      addTearDown(c.dispose);
      expect(c.read(pushServiceProvider), isA<FcmPushService>());
    });
  });
}
