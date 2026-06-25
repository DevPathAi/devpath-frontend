import 'dart:convert';

import 'package:devpath_web/src/features/mentor/data/mentor_sse_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('목 소스는 답변 토큰을 emit한다', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final connect = c.read(mentorSseConnectProvider);
    final events = await connect('비동기란?').toList();
    final tokens = events
        .where((e) => e.event == 'token')
        .map((e) => e.data)
        .toList();
    expect(tokens, isNotEmpty);
    expect(tokens.join(), contains('async'));
  });

  test('목 소스는 references 이벤트를 1회 방출한다(JSON 배열)', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final connect = c.read(mentorSseConnectProvider);
    final refs = await connect(
      '비동기란?',
    ).where((e) => e.event == 'references').toList();
    expect(refs, hasLength(1));
    final decoded = jsonDecode(refs.single.data) as List<dynamic>;
    expect(decoded, isNotEmpty);
    final first = decoded.first as Map<String, dynamic>;
    expect(first['contentId'], isA<int>());
    expect(first['slug'], isA<String>());
    expect(first['title'], isA<String>());
  });
}
