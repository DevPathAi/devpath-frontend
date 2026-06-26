import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

bool isOnline(List<ConnectivityResult> results) =>
    results.any((r) => r != ConnectivityResult.none);

/// 온라인 여부 스트림. 재연결(오프라인→온라인) 감지에 사용한다.
/// 테스트는 이 provider를 제어 가능한 Stream으로 오버라이드한다.
final connectivityProvider = StreamProvider<bool>(
  (ref) => Connectivity().onConnectivityChanged.map(isOnline),
);
