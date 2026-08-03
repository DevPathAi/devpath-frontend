import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:test/test.dart';

Future<(int, dynamic)> _call(
  MockHttpAdapter adapter,
  String method,
  String path,
) async {
  final res = await adapter.fetch(
    RequestOptions(path: path, method: method),
    null,
    null,
  );
  final text = await utf8.decodeStream(res.stream);
  return (res.statusCode, text.isEmpty ? null : jsonDecode(text));
}

void main() {
  group('순차 응답', () {
    test('같은 키를 호출할 때마다 다음 응답을 돌려준다', () async {
      final adapter = MockHttpAdapter(
        const {},
        sequences: {
          'GET /next': [
            (200, {'q': 1}),
            (200, {'q': 2}),
          ],
        },
      );

      final first = await _call(adapter, 'GET', '/next');
      final second = await _call(adapter, 'GET', '/next');

      expect((first.$2 as Map)['q'], 1);
      expect((second.$2 as Map)['q'], 2);
    });

    test('소진되면 마지막 항목을 계속 돌려준다', () async {
      final adapter = MockHttpAdapter(
        const {},
        sequences: {
          'GET /next': [
            (200, {'q': 1}),
            (200, null),
          ],
        },
      );

      await _call(adapter, 'GET', '/next');
      final second = await _call(adapter, 'GET', '/next');
      final third = await _call(adapter, 'GET', '/next');
      final fourth = await _call(adapter, 'GET', '/next');

      // 마지막이 null 이면 그 뒤로도 계속 null 이다.
      expect(second.$2, isNull);
      expect(third.$2, isNull);
      expect(fourth.$2, isNull);
    });

    test('★본문 null 을 표현할 수 있다 — 진단 완료 판정의 근거★', () async {
      // AssessmentApi.next 는 본문이 null 일 때만 null 을 돌려주고,
      // DiagnosticController 는 그때만 complete() 로 넘어간다.
      // 고정 픽스처(Object body)로는 이 상태를 만들 수 없어 진단이 완주하지 못했다.
      final adapter = MockHttpAdapter(
        const {},
        sequences: {
          'GET /next': [(200, null)],
        },
      );

      final res = await _call(adapter, 'GET', '/next');
      expect(res.$1, 200);
      expect(res.$2, isNull);
    });

    test('키마다 커서가 독립적이다', () async {
      final adapter = MockHttpAdapter(
        const {},
        sequences: {
          'GET /a': [
            (200, {'v': 'a1'}),
            (200, {'v': 'a2'}),
          ],
          'GET /b': [
            (200, {'v': 'b1'}),
            (200, {'v': 'b2'}),
          ],
        },
      );

      await _call(adapter, 'GET', '/a');
      final b1 = await _call(adapter, 'GET', '/b');
      final a2 = await _call(adapter, 'GET', '/a');

      expect((b1.$2 as Map)['v'], 'b1');
      expect((a2.$2 as Map)['v'], 'a2');
    });

    test('sequences 가 fixtures 보다 우선한다', () async {
      final adapter = MockHttpAdapter(
        const {
          'GET /x': (200, {'from': 'fixtures'}),
        },
        sequences: {
          'GET /x': [
            (200, {'from': 'sequences'}),
          ],
        },
      );

      final res = await _call(adapter, 'GET', '/x');
      expect((res.$2 as Map)['from'], 'sequences');
    });

    test('sequences 를 주지 않으면 기존 동작 그대로다 — 하위 호환', () async {
      final adapter = MockHttpAdapter(const {
        'GET /y': (200, {'ok': true}),
      });

      final first = await _call(adapter, 'GET', '/y');
      final second = await _call(adapter, 'GET', '/y');

      expect((first.$2 as Map)['ok'], isTrue);
      expect((second.$2 as Map)['ok'], isTrue);
    });

    test('reset 하면 커서가 처음으로 돌아간다', () async {
      final adapter = MockHttpAdapter(
        const {},
        sequences: {
          'GET /next': [
            (200, {'q': 1}),
            (200, {'q': 2}),
          ],
        },
      );

      await _call(adapter, 'GET', '/next');
      adapter.resetSequences();
      final again = await _call(adapter, 'GET', '/next');

      expect((again.$2 as Map)['q'], 1);
    });
  });
}
