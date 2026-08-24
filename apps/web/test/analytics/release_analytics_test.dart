import 'dart:convert';
import 'dart:typed_data';

import 'package:devpath_web/src/analytics/release_analytics.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

const _markerJson = '''{
  "schema_version": "mission-spine.release-analytics.v1",
  "permission_url": "https://api.leva.ai.kr/v1/release/browser/analytics-permission",
  "capture_url": "https://analytics-spy.staging.leva.ai.kr/v1/release/browser/analytics-events"
}''';

final class _ReleaseAdapter implements HttpClientAdapter {
  _ReleaseAdapter({required this.granted});

  final bool granted;
  final requests = <RequestOptions>[];
  final bodies = <Object?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (requestStream != null) {
      final bytes = <int>[];
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
      bodies.add(bytes.isEmpty ? null : jsonDecode(utf8.decode(bytes)));
    } else {
      bodies.add(null);
    }
    if (options.path.contains('analytics-permission')) {
      return ResponseBody.fromString(
        jsonEncode({
          'schema_version': 'mission-spine.staging-control.v1',
          'candidate_spec_sha256': List.filled(64, 'a').join(),
          'granted': granted,
          'analytics_origin': 'https://analytics-spy.staging.leva.ai.kr',
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'accepted': true}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('release marker accepts only exact non-secret endpoints', () {
    expect(parseReleaseAnalyticsMarker(_markerJson), isNotNull);
    expect(parseReleaseAnalyticsMarker(null), isNull);
    expect(parseReleaseAnalyticsMarker('{broken'), isNull);
    expect(
      parseReleaseAnalyticsMarker(
        _markerJson.replaceFirst('api.leva.ai.kr', 'attacker.example'),
      ),
      isNull,
    );
    expect(
      parseReleaseAnalyticsMarker(
        _markerJson.replaceFirst(
          '"capture_url"',
          '"extra": true, "capture_url"',
        ),
      ),
      isNull,
    );
  });

  test('permission denial makes zero analytics-spy requests', () async {
    final adapter = _ReleaseAdapter(granted: false);
    final dio = Dio()..httpClientAdapter = adapter;
    final sdk = ReleaseJourneyAnalyticsSdk(
      parseReleaseAnalyticsMarker(_markerJson)!,
      dio,
    );

    await sdk.capture('landing_viewed', const {'page_view_id': 'P123'});

    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.uri.host, 'api.leva.ai.kr');
    expect(adapter.requests.single.extra['withCredentials'], isFalse);
  });

  test('permission grant sends exact ordered event payloads to spy', () async {
    final adapter = _ReleaseAdapter(granted: true);
    final dio = Dio()..httpClientAdapter = adapter;
    final sdk = ReleaseJourneyAnalyticsSdk(
      parseReleaseAnalyticsMarker(_markerJson)!,
      dio,
    );

    await Future.wait([
      sdk.capture('diagnostic_started', const {'track_id': 'backend'}),
      sdk.capture('diagnostic_completed', const {'score_band': 'ready'}),
    ]);

    expect(adapter.requests.map((request) => request.uri.host), [
      'api.leva.ai.kr',
      'analytics-spy.staging.leva.ai.kr',
      'analytics-spy.staging.leva.ai.kr',
    ]);
    expect(adapter.bodies.skip(1), [
      {
        'event': 'diagnostic_started',
        'properties': {'track_id': 'backend'},
      },
      {
        'event': 'diagnostic_completed',
        'properties': {'score_band': 'ready'},
      },
    ]);
  });
}
