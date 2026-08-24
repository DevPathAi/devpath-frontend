import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'journey_analytics.dart';

const _releaseSchema = 'mission-spine.release-analytics.v1';
const _controlSchema = 'mission-spine.staging-control.v1';
const _permissionUrl =
    'https://api.leva.ai.kr/v1/release/browser/analytics-permission';
const _captureUrl =
    'https://analytics-spy.staging.leva.ai.kr/v1/release/browser/analytics-events';
const _analyticsOrigin = 'https://analytics-spy.staging.leva.ai.kr';
final _candidateSha256 = RegExp(r'^[0-9a-f]{64}$');

class ReleaseAnalyticsMarker {
  const ReleaseAnalyticsMarker({
    required this.permissionUrl,
    required this.captureUrl,
  });

  final String permissionUrl;
  final String captureUrl;
}

ReleaseAnalyticsMarker? parseReleaseAnalyticsMarker(String? raw) {
  if (raw == null) return null;
  try {
    final value = jsonDecode(raw);
    if (value is! Map<String, dynamic> ||
        value.keys.toSet().difference({
          'schema_version',
          'permission_url',
          'capture_url',
        }).isNotEmpty ||
        value.length != 3 ||
        value['schema_version'] != _releaseSchema ||
        value['permission_url'] != _permissionUrl ||
        value['capture_url'] != _captureUrl) {
      return null;
    }
    return const ReleaseAnalyticsMarker(
      permissionUrl: _permissionUrl,
      captureUrl: _captureUrl,
    );
  } catch (_) {
    return null;
  }
}

class ReleaseJourneyAnalyticsSdk implements JourneyAnalyticsSdk {
  ReleaseJourneyAnalyticsSdk(this.marker, this._dio);

  final ReleaseAnalyticsMarker marker;
  final Dio _dio;
  Future<void> _tail = Future<void>.value();
  bool _permissionGranted = false;

  @override
  Future<void> capture(String event, Map<String, Object?> properties) {
    _tail = _tail.then((_) => _capture(event, properties)).catchError((_) {});
    return _tail;
  }

  Future<void> _capture(String event, Map<String, Object?> properties) async {
    if (!_permissionGranted) {
      final response = await _dio.get<Object?>(
        marker.permissionUrl,
        options: Options(
          headers: {Headers.acceptHeader: Headers.jsonContentType},
          extra: {'withCredentials': false},
        ),
      );
      final body = response.data;
      if (body is! Map<String, dynamic> ||
          body['schema_version'] != _controlSchema ||
          body['candidate_spec_sha256'] is! String ||
          !_candidateSha256.hasMatch(body['candidate_spec_sha256'] as String) ||
          body['granted'] != true ||
          body['analytics_origin'] != _analyticsOrigin) {
        return;
      }
      _permissionGranted = true;
    }
    await _dio.post<void>(
      marker.captureUrl,
      data: {'event': event, 'properties': properties},
      options: Options(
        contentType: Headers.jsonContentType,
        extra: {'withCredentials': false},
      ),
    );
  }

  @override
  Future<void> identify(String userId) async {}

  @override
  Future<void> reset() async {}
}
