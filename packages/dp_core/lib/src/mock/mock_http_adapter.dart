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
    final key = '${options.method} ${options.path}';
    final fixture = fixtures[key];
    if (fixture == null) {
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

  @override
  void close({bool force = false}) {}
}
