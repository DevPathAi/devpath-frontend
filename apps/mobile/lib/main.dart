import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app/app.dart';
import 'src/app/app_config.dart';
import 'src/services/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 실 FCM 결선 지점. 목/CI(USE_MOCK=true, 기본값)는 Firebase를 일절 건드리지 않는다.
  // 활성화: --dart-define=USE_MOCK=false + google-services.json/GoogleService-Info.plist.
  // (`Firebase.initializeApp()`은 네이티브 설정 파일을 자동으로 읽는다 → docs/FCM_SETUP.md)
  if (!AppConfig.fromEnvironment().useMock) {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  runApp(const ProviderScope(child: DevPathMobileApp()));
}
