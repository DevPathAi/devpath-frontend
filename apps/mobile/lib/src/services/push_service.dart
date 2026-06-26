import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 수신 푸시 메시지 1건. 실 FCM `RemoteMessage`를 이 형태로 매핑한다(후속).
/// 알림센터 목록·미읽음 배지의 단위.
class PushMessage {
  const PushMessage({
    required this.id,
    required this.title,
    required this.body,
  });

  /// 메시지 식별자(FCM `messageId`). 목록 키·중복 제거에 사용.
  final String id;
  final String title;
  final String body;
}

/// 푸시 추상화 — `connectivityProvider`와 동일한 **교체 경계**다.
/// 실 구현은 `firebase_messaging`(후속): `FirebaseMessaging.instance.getToken()`과
/// `onMessage` 스트림을 [PushMessage]로 매핑한 `FcmPushService`로 교체하고
/// Firebase 프로젝트 설정(google-services.json / GoogleService-Info.plist)을 추가한다.
/// 본 프로토는 스텁(Firebase 설정 없이 동작).
abstract interface class PushService {
  /// 디바이스 등록 토큰(서버 등록용, 후속). 스텁은 고정값.
  Future<String?> getToken();

  /// 포그라운드 수신 메시지 스트림. 알림센터가 구독한다.
  Stream<PushMessage> get incoming;
}

/// Firebase 없이 동작하는 스텁. 토큰은 고정값, 수신은 빈 스트림.
class StubPushService implements PushService {
  @override
  Future<String?> getToken() async => 'stub-fcm-token';

  @override
  Stream<PushMessage> get incoming => const Stream.empty();
}

/// 푸시 서비스 주입점. 실 FCM 전환 시 이 provider만 교체한다.
final pushServiceProvider = Provider<PushService>((ref) => StubPushService());
