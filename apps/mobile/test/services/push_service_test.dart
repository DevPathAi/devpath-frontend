import 'package:devpath_mobile/src/services/push_service.dart';
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
}
