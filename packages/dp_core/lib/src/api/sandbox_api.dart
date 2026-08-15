import '../models/sandbox.dart';
import '../sse/sse_event.dart';
import 'api_client.dart';

final class SandboxApi {
  const SandboxApi(this._client);

  static const eventVersionHeader = 'X-Sandbox-Event-Version';
  static const sessionHeader = 'X-Sandbox-Session-Id';

  final ApiClient _client;

  Stream<SseEvent> run(SandboxRunRequest request) => _client.sseWithMetadata(
    '/sandbox/run',
    body: request.toJson(),
    requestHeaders: const {eventVersionHeader: '2'},
    responseHeaderEvents: const {sessionHeader: 'session'},
  );

  Future<SandboxSession> session(int sessionId) async {
    if (sessionId <= 0 || sessionId > SandboxRunRequest.maxSafeInteger) {
      throw ArgumentError.value(sessionId, 'sessionId');
    }
    final json = await _client.get<Map<String, dynamic>>(
      '/sandbox/sessions/$sessionId',
    );
    return SandboxSession.fromJson(json);
  }
}
