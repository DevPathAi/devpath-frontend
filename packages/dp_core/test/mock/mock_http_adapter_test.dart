import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:dp_core/dp_core.dart';
import 'package:test/test.dart';

void main() {
  test('픽스처 미등록 시 사용자용 카피를 내고 경로를 노출하지 않는다', () async {
    final adapter = MockHttpAdapter(const {});
    final res = await adapter.fetch(
      RequestOptions(path: '/consents/me', method: 'GET'),
      null,
      null,
    );
    final body = jsonDecode(await utf8.decodeStream(res.stream))
        as Map<String, dynamic>;
    final err = body['error'] as Map<String, dynamic>;

    expect(res.statusCode, 404);
    expect(err['code'], 'RESOURCE_NOT_FOUND');
    // 사용자에게 개발자 원문을 보이지 않는다.
    expect(err['message'], isNot(contains('no mock')));
    expect(err['message'], isNot(contains('/consents/me')));
    expect(err['message'], isNotEmpty);
    // 프로토 진단은 계속 가능해야 하므로 debug 필드에는 남긴다.
    expect(err['debug'], contains('GET /consents/me'));
  });

  test('등록된 픽스처는 그대로 돌려준다', () async {
    final adapter = MockHttpAdapter(const {
      'GET /ping': (200, {'ok': true}),
    });
    final res = await adapter.fetch(
      RequestOptions(path: '/ping', method: 'GET'),
      null,
      null,
    );
    expect(res.statusCode, 200);
  });
}
