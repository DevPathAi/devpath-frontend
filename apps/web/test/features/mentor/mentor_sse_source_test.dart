import 'package:devpath_web/src/features/mentor/data/mentor_sse_source.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('목 소스는 답변 토큰을 emit한다', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final connect = c.read(mentorSseConnectProvider);
    final tokens = await connect('비동기란?').map((e) => e.data).toList();
    expect(tokens, isNotEmpty);
    expect(tokens.join(), contains('async'));
  });
}
