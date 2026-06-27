import 'package:dp_core/dp_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/api_providers.dart';
import '../../../services/push_service.dart';

/// 인증 진입 후 FCM 디바이스 토큰을 백엔드(`POST /notifications/devices`)에 등록한다(트랙 C).
/// 타깃 푸시 발송의 전제. 토큰이 없으면(목/미초기화) 아무것도 하지 않는다.
/// 등록 실패는 호출측(app.dart)이 삼킨다 — 부가 기능이라 인증/UX를 막지 않는다.
class DeviceRegistrar {
  DeviceRegistrar(this._client, this._push, this._platform);

  final ApiClient _client;
  final PushService _push;
  final String _platform; // 'ANDROID' | 'IOS'

  Future<void> register() async {
    final token = await _push.getToken();
    if (token == null || token.isEmpty) return;
    await _client.post<dynamic>(
      '/notifications/devices',
      body: {'token': token, 'platform': _platform},
    );
  }
}

String _platformTag() =>
    defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID';

final deviceRegistrarProvider = Provider<DeviceRegistrar>(
  (ref) => DeviceRegistrar(
    ref.watch(apiClientProvider),
    ref.watch(pushServiceProvider),
    _platformTag(),
  ),
);
