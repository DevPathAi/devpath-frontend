import 'package:devpath_mobile/src/features/notifications/application/device_registrar.dart';
import 'package:devpath_mobile/src/services/push_service.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePush implements PushService {
  _FakePush(this._token);
  final String? _token;
  @override
  Future<String?> getToken() async => _token;
  @override
  Stream<PushMessage> get incoming => const Stream.empty();
}

ApiClient _client(Map<String, MockFixture> fx) {
  final c = ApiClient.create(const ApiConfig(baseUrl: 'http://test.local'));
  c.dio.httpClientAdapter = MockHttpAdapter(fx);
  return c;
}

void main() {
  group('DeviceRegistrar', () {
    test('토큰 있으면 POST /notifications/devices 등록(경로/메서드 일치)', () async {
      // 픽스처가 'POST /notifications/devices'에만 매칭 → 다른 경로면 예외.
      final c = _client({
        'POST /notifications/devices': (200, <String, dynamic>{}),
      });
      final r = DeviceRegistrar(c, _FakePush('fcm-tok'), 'ANDROID');
      await r.register(); // 무예외 = 올바른 경로로 호출됨
    });

    test('토큰 없으면 네트워크 호출 안 함', () async {
      // 픽스처 없음: 호출되면 ApiException. 호출 안 하면 무예외.
      final c = _client(const {});
      final r = DeviceRegistrar(c, _FakePush(null), 'ANDROID');
      await r.register();
    });
  });
}
