import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/api_providers.dart';

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

/// FCM `RemoteMessage` → [PushMessage] 매핑(순수 함수). 단위 테스트 대상.
PushMessage pushMessageFromRemote(RemoteMessage m) => PushMessage(
  id: m.messageId ?? '',
  title: m.notification?.title ?? '',
  body: m.notification?.body ?? '',
);

/// 백그라운드/종료 상태 수신 진입점. **반드시 top-level**(앱이 비활성일 때 별
/// isolate에서 호출됨)이며 `@pragma('vm:entry-point')`로 release tree-shaking을
/// 막는다. 별 isolate이므로 Firebase를 다시 초기화한다.
///
/// 알림형(`notification`) 메시지는 OS 트레이가 자동 표시하므로 여기서는 초기화만
/// 보장한다. data 전용 메시지의 후속 처리 훅 지점(스펙 확정 시 확장).
/// `main`의 실 모드 분기에서 `FirebaseMessaging.onBackgroundMessage`에 등록한다.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// 실 FCM 구현. `firebase_messaging`의 토큰·`onMessage`(포그라운드)를
/// [PushService]로 어댑팅한다.
///
/// 활성화 조건: `--dart-define=USE_MOCK=false`.
/// **선행 후속(설정 제공 시)**: Firebase 프로젝트 + `google-services.json` /
/// `GoogleService-Info.plist`(+ iOS APNs 키) 추가, `main`에서 `Firebase.initializeApp`
/// 호출. 본 골격은 그 결선 지점만 제공한다.
///
/// `FirebaseMessaging.instance`는 **lazy** 참조 — 생성자에서 Firebase를 건드리지
/// 않으므로 미초기화 환경에서도 인스턴스화는 가능(실제 토큰·수신 호출 시점에만 초기화 필요).
class FcmPushService implements PushService {
  /// [messaging]은 테스트 주입용(미지정 시 `FirebaseMessaging.instance`를 lazy 사용).
  FcmPushService([this._messaging]);

  final FirebaseMessaging? _messaging;

  FirebaseMessaging get _fm => _messaging ?? FirebaseMessaging.instance;

  @override
  Future<String?> getToken() => _fm.getToken();

  @override
  Stream<PushMessage> get incoming =>
      FirebaseMessaging.onMessage.map(pushMessageFromRemote);
}

/// 푸시 서비스 주입점(교체 경계). 목 모드=스텁, 실 모드=FCM.
final pushServiceProvider = Provider<PushService>((ref) {
  return ref.watch(appConfigProvider).useMock
      ? StubPushService()
      : FcmPushService();
});
