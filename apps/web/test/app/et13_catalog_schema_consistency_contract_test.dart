import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ET13 스키마는 어디에서도 기계 검증되지 않는다(`$id` 와 파일 존재만 확인한다).
/// 그래서 fixture 가 12 → 15 → 13 으로 바뀌는 동안 `catalog.schema.json` 의
/// `projection_contract_sha256` const 가 12-fixture 시절 값으로 남아, 카탈로그가
/// 자기 스키마를 통과하지 못하는 상태가 드러나지 않았다. gitops 는 이 스키마를
/// 바이트 핀하므로 틀린 const 는 그대로 공급망 계약에 들어간다.
///
/// 최상위 속성의 `const` 와 배열 길이 제약을 실제 카탈로그와 대조해 잠근다.
void main() {
  final schema =
      jsonDecode(
            File('../../evidence/et13/catalog.schema.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final catalog =
      jsonDecode(File('../../evidence/et13/catalog.v1.json').readAsStringSync())
          as Map<String, dynamic>;
  final properties = schema['properties'] as Map<String, dynamic>;

  test('the catalog carries exactly the properties its schema declares', () {
    expect(schema['additionalProperties'], isFalse);
    expect(catalog.keys.toSet(), properties.keys.toSet());
    expect((schema['required'] as List).toSet(), properties.keys.toSet());
  });

  test('every top-level schema const equals the catalog value', () {
    final consts = {
      for (final entry in properties.entries)
        if ((entry.value as Map).containsKey('const'))
          entry.key: (entry.value as Map)['const'],
    };
    expect(consts, isNotEmpty);
    expect(consts.keys, contains('projection_contract_sha256'));
    for (final entry in consts.entries) {
      expect(catalog[entry.key], entry.value, reason: entry.key);
    }
  });

  test('every top-level array length satisfies its schema bounds', () {
    var checked = 0;
    for (final entry in properties.entries) {
      final rule = entry.value as Map;
      final value = catalog[entry.key];
      if (value is! List) continue;
      if (rule['minItems'] case final int min) {
        expect(value.length, greaterThanOrEqualTo(min), reason: entry.key);
        checked++;
      }
      if (rule['maxItems'] case final int max) {
        expect(value.length, lessThanOrEqualTo(max), reason: entry.key);
        checked++;
      }
    }
    expect(checked, greaterThan(0));
  });
}
