import 'package:devpath_web/src/app/app_config.dart';
import 'package:devpath_web/src/features/auth/application/oauth_launcher.dart';
import 'package:devpath_web/src/features/beta/presentation/beta_pending_page.dart';
import 'package:devpath_web/src/providers/api_providers.dart';
import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// GET /beta/status를 호출 순서대로 응답하는 fake(마지막 응답을 이후 반복).
class _StatusApiClient implements ApiClient {
  _StatusApiClient(this.responses);
  final List<Map<String, dynamic>> responses;
  int _i = 0;

  @override
  Future<T> get<T>(String path, {Map<String, dynamic>? query}) async {
    final r = responses[_i < responses.length - 1 ? _i++ : _i];
    return r as T;
  }

  @override
  Future<T> post<T>(String path, {Object? body, Map<String, dynamic>? query}) =>
      throw UnimplementedError();
  @override
  Future<T> put<T>(String path, {Object? body, Map<String, dynamic>? query}) =>
      throw UnimplementedError();
  @override
  Future<T> delete<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) => throw UnimplementedError();
  @override
  Stream<SseEvent> sse(String path, {Object? body}) =>
      throw UnimplementedError();
  @override
  Future<T> postMultipart<T>(
    String path, {
    required List<int> bytes,
    required String filename,
    String field = 'file',
    String? contentType,
  }) => throw UnimplementedError();
  @override
  Dio get dio => throw UnimplementedError();
}

class _CapturingLauncher implements OAuthLauncher {
  String? launched;
  @override
  void launch(String url) => launched = url;
}

void main() {
  testWidgets('APPROVED 수신 시 login(provider) 재-OAuth 트리거', (tester) async {
    final api = _StatusApiClient([
      {'status': 'PENDING'},
      {'status': 'APPROVED', 'provider': 'github'},
    ]);
    final launcher = _CapturingLauncher();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          oauthLauncherProvider.overrideWithValue(launcher),
          appConfigProvider.overrideWithValue(
            const AppConfig(baseUrl: 'http://x', useMock: false),
          ),
        ],
        child: const MaterialApp(home: BetaPendingPage()),
      ),
    );

    // 첫 폴링(5s) → PENDING, 둘째(10s) → APPROVED.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(launcher.launched, contains('/oauth2/authorization/github'));
  });
}
