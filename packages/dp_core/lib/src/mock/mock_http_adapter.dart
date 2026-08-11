import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// `'METHOD /path'` → (status, jsonBody) 픽스처 맵.
typedef MockFixture = (int status, Object body);

/// 같은 키를 여러 번 호출할 때 순서대로 돌려줄 응답 목록.
///
/// 본문이 `Object?` 라 **null 응답을 표현할 수 있다** — 이것이 [MockFixture] 와의
/// 결정적 차이다. 목록이 소진되면 마지막 항목을 계속 돌려준다.
typedef MockSequence = List<(int status, Object? body)>;

class MockHttpAdapter implements HttpClientAdapter {
  MockHttpAdapter(this.fixtures, {Map<String, MockSequence>? sequences})
    : sequences = sequences ?? const {};

  final Map<String, MockFixture> fixtures;

  /// 호출 순서에 따라 다른 응답이 필요한 키만 등록한다.
  ///
  /// 고정 픽스처로는 "첫 호출은 문항, 다음엔 없음" 같은 진행 상태를 표현할 수 없어
  /// 온보딩 진단이 완주하지 못했다(`AssessmentApi.next` 는 본문이 null 일 때만 null 을
  /// 돌려주고, `DiagnosticController` 는 그때만 완료로 넘어간다).
  final Map<String, MockSequence> sequences;

  /// 키별 호출 커서. 시퀀스가 등록된 키에만 쓰인다.
  final Map<String, int> _cursors = {};

  /// 커서를 모두 처음으로 되돌린다. 테스트에서 같은 어댑터를 재사용할 때 쓴다.
  void resetSequences() => _cursors.clear();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? rs,
    Future? cancelFuture,
  ) async {
    // 시퀀스가 고정 픽스처보다 우선한다.
    final seq = _resolveSequence(options);
    if (seq != null) {
      final (status, body) = seq;
      return _json(body, status);
    }

    final fixture = _resolve(options);
    if (fixture == null) {
      final key = '${options.method} ${options.path}';
      // 사용자에게는 사람이 읽는 문장만 보인다. 개발자 원문은 debug 필드에만 둔다
      // (프론트는 error.message 를 그대로 화면에 렌더한다).
      assert(() {
        // ignore: avoid_print
        print('[MockHttpAdapter] 등록되지 않은 픽스처: $key');
        return true;
      }());
      return _json({
        'error': {
          'code': 'RESOURCE_NOT_FOUND',
          'message': '아직 준비되지 않은 화면이에요. 잠시 후 다시 시도해 주세요.',
          'debug': 'no mock: $key',
        },
      }, 404);
    }
    final (status, body) = fixture;
    return _json(body, status);
  }

  ResponseBody _json(Object? body, int status) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  /// 시퀀스 조회 + 커서 전진. 소진되면 마지막 항목에 머문다.
  (int, Object?)? _resolveSequence(RequestOptions options) {
    final key = _matchKey(options, sequences.containsKey);
    if (key == null) return null;
    final list = sequences[key]!;
    if (list.isEmpty) return null;

    final i = _cursors[key] ?? 0;
    final picked = list[i < list.length ? i : list.length - 1];
    if (i < list.length - 1) _cursors[key] = i + 1;
    return picked;
  }

  /// D3: query-aware. 'METHOD /path?k=v&...'(키 정렬) 우선 매칭, 없으면 'METHOD /path' 폴백.
  MockFixture? _resolve(RequestOptions options) {
    final key = _matchKey(options, fixtures.containsKey);
    return key == null ? null : fixtures[key];
  }

  /// 쿼리 포함 키를 먼저, 없으면 base 키를 찾는다. [has] 로 대상 맵을 바꾼다.
  String? _matchKey(RequestOptions options, bool Function(String) has) {
    final base = '${options.method} ${options.path}';
    final q = options.queryParameters;
    if (q.isNotEmpty) {
      final sorted = (q.keys.toList()..sort())
          .map((k) => '$k=${q[k]}')
          .join('&');
      final keyed = '$base?$sorted';
      if (has(keyed)) return keyed;
    }
    return has(base) ? base : null;
  }

  @override
  void close({bool force = false}) {}
}
