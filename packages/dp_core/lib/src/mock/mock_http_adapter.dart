import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// `'METHOD /path'` → (status, jsonBody) 픽스처 맵.
typedef MockFixture = (int status, Object body);

class MockHttpAdapter implements HttpClientAdapter {
  MockHttpAdapter(this.fixtures);
  final Map<String, MockFixture> fixtures;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? rs,
      Future? cancelFuture) async {
    final fixture = _resolve(options);
    if (fixture == null) {
      final key = '${options.method} ${options.path}';
      return ResponseBody.fromString(
        jsonEncode({'error': {'code': 'RESOURCE_NOT_FOUND', 'message': 'no mock: $key'}}),
        404,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }
    final (status, body) = fixture;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  /// D3: query-aware. 'METHOD /path?k=v&...'(키 정렬) 우선 매칭, 없으면 'METHOD /path' 폴백.
  MockFixture? _resolve(RequestOptions options) {
    final base = '${options.method} ${options.path}';
    final q = options.queryParameters;
    if (q.isNotEmpty) {
      final sorted = (q.keys.toList()..sort()).map((k) => '$k=${q[k]}').join('&');
      final keyed = fixtures['$base?$sorted'];
      if (keyed != null) return keyed;
    }
    return fixtures[base];
  }

  @override
  void close({bool force = false}) {}
}
